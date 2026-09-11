import AppKit
import HangarCore

/// Opens ssh sessions in the user's terminal. Once the ssh_config include is in
/// place every host is reachable by alias, so the command is just `ssh <alias>`
/// and the terminal inherits user, key, and ProxyJump from ssh itself.
@MainActor
enum Launcher {
    /// Where a terminal lives on this machine, and whether it is here at all.
    /// `TerminalChoice` itself stays UI-free, so the lookup is here.
    static func location(of terminal: TerminalChoice) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleID)
    }

    static func isInstalled(_ terminal: TerminalChoice) -> Bool {
        location(of: terminal) != nil
    }

    /// Every terminal Hangar can drive that is actually on this machine.
    static var installed: [TerminalChoice] {
        TerminalChoice.allCases.filter(isInstalled)
    }

    static func sshCommand(for target: String, settings: HangarConfig.SSHSettings?,
                           managedByConfig: Bool) -> String {
        SSHCommand.line(target: target, user: settings?.user,
                        identityFile: settings?.identityFile,
                        managedByConfig: managedByConfig)
    }

    /// Opens the session, and reports a problem through `report` rather than a
    /// return value: one mechanism fails synchronously and the other fails in a
    /// completion handler, and a caller should not have to know which is which.
    static func open(command: String, in terminal: TerminalChoice,
                     report: @escaping @MainActor @Sendable (String) -> Void) {
        // A newline here would end the AppleScript string literal and, worse,
        // submit the line to the shell early. Nothing legitimate contains one.
        guard Shell.isSingleLine(command) else {
            report("That host's tags contain a line break; Hangar will not run it.")
            return
        }
        // Falls back rather than failing: Terminal ships with macOS, so a chosen
        // terminal that has been uninstalled costs a session in a different app
        // rather than no session at all.
        let target = isInstalled(terminal) ? terminal : TerminalChoice.fallback
        guard let script = script(for: target, command: command) else {
            launch(command: command, in: target, report: report)
            return
        }

        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -1743 {
                report("Hangar needs permission to control \(target.displayName). "
                    + "Allow it in System Settings under Privacy and Security, Automation.")
                return
            }
            report(error[NSAppleScript.errorMessage] as? String
                   ?? "could not open a terminal")
        }
    }

    /// The AppleScript that writes the command into a live session, or nil for a
    /// terminal that is not scriptable and takes the command as arguments.
    ///
    /// Written into a live session rather than passed as the session's command:
    /// passed as the command, a failing ssh exits immediately and the tab closes,
    /// so the user sees an empty window and never learns why. A shell that
    /// outlives ssh shows the error.
    private static func script(for terminal: TerminalChoice, command: String) -> String? {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        switch terminal {
        case .iterm:
            return """
            tell application "iTerm"
              activate
              if (count of windows) is 0 then
                create window with default profile
              else
                tell current window to create tab with default profile
              end if
              tell current session of current window
                write text "\(escaped)"
              end tell
            end tell
            """
        case .terminal:
            return """
            tell application "Terminal"
              activate
              do script "\(escaped)"
            end tell
            """
        case .ghostty:
            return nil
        }
    }

    /// A terminal that takes the command in its argument vector. No AppleScript,
    /// so no Automation permission, and no shell string of our own: the command
    /// is one element of the vector rather than something the launch re-parses.
    private static func launch(command: String, in terminal: TerminalChoice,
                               report: @escaping @MainActor @Sendable (String) -> Void) {
        guard let url = location(of: terminal) else {
            report("\(terminal.displayName) is not installed.")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = TerminalChoice.arguments(for: command)
        // Each session is its own window, which is what the scripted terminals
        // do with a new tab. Without this the arguments reach a running copy as
        // a reopen and the command is dropped.
        configuration.createsNewApplicationInstance = true
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            guard let error else { return }
            Log.warning(.fleet, "terminal launch failed",
                        ["terminal": terminal.rawValue,
                         "error": error.localizedDescription])
            Task { @MainActor in
                report("Could not open \(terminal.displayName): "
                       + error.localizedDescription)
            }
        }
    }

    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// The `hangar` command line tool that ships inside the app bundle, and the
/// symlink that puts it on the user's PATH.
///
/// It lives in Contents/Helpers rather than Contents/MacOS because macOS
/// filesystems are case insensitive and the app's own executable is `Hangar`.
enum CommandLineTool {
    static var path: String? {
        let candidate = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/hangar")
        return FileManager.default.isExecutableFile(atPath: candidate.path)
            ? candidate.path : nil
    }

    /// Running from the mounted DMG. Linking to a volume that is about to be
    /// ejected would leave a dangling command behind on every download.
    static var isRunningFromDiskImage: Bool {
        Bundle.main.bundlePath.hasPrefix("/Volumes/")
    }

    /// Where the shell would find `hangar` today, and whether it is ours.
    static func state() -> CommandLineInstall.State {
        CommandLineInstall.state(shellPath: CommandLineInstall.shellPath())
    }

    enum Outcome: Equatable {
        case linked(String)
        case failed(String)
        /// Nowhere on PATH is writable, so the user runs one line themselves.
        case needsCommand(String)
    }

    /// Installs, or replaces a link of ours that points at a bundle that has
    /// gone. Never touches a `hangar` somebody else put on the PATH.
    @discardableResult
    static func install() -> Outcome {
        guard let tool = path else {
            return .failed("This build carries no command line tool.")
        }
        let fm = FileManager.default
        switch state() {
        case .installed(let link):
            return .linked(link)
        case .claimed(let link):
            return .failed("\(link) is already something else; Hangar left it alone.")
        case .broken(let existing):
            try? fm.removeItem(atPath: existing)
            return symlink(tool, to: existing)
        case .absent(let destination):
            guard let destination else {
                return .needsCommand(CommandLineInstall.manualCommand(tool: tool))
            }
            return symlink(tool, to: (destination as NSString)
                .appendingPathComponent(CommandLineInstall.commandName))
        }
    }

    private static func symlink(_ tool: String, to link: String) -> Outcome {
        do {
            try FileManager.default.createSymbolicLink(atPath: link,
                                                       withDestinationPath: tool)
            Log.info(.app, "command line tool linked", ["at": link])
            return .linked(link)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// The automatic case: nothing named `hangar` on the PATH yet, a writable
    /// directory to put it in, and an app that is not running from a disk image.
    /// Anything else waits to be asked, the way adopting an agent key does.
    @discardableResult
    static func installIfUnclaimed() -> String? {
        guard !isRunningFromDiskImage, path != nil else { return nil }
        guard case .absent(let destination) = state(), destination != nil else {
            return nil
        }
        if case .linked(let at) = install() { return at }
        return nil
    }
}
