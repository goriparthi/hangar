import XCTest
@testable import HangarCore

/// /usr/local/bin is the line every README reaches for and it is root-owned on a
/// stock Mac, so the first install attempt used to be a sudo prompt for something
/// that did not need one.
final class CommandLineInstallTests: XCTestCase {

    private let localBin = NSString(string: "~/.local/bin").expandingTildeInPath
    private let homeBin = NSString(string: "~/bin").expandingTildeInPath

    func testItPrefersADirectoryTheUserAlreadyOwns() {
        let destination = CommandLineInstall.destination(
            onPath: ["/usr/bin", "/usr/local/bin", localBin, "/opt/homebrew/bin"],
            writable: [localBin, "/opt/homebrew/bin", "/usr/local/bin"])
        XCTAssertEqual(destination, localBin)
    }

    func testItFallsDownThePreferenceOrder() {
        XCTAssertEqual(
            CommandLineInstall.destination(onPath: ["/opt/homebrew/bin", homeBin],
                                           writable: ["/opt/homebrew/bin", homeBin]),
            "/opt/homebrew/bin")
        XCTAssertEqual(
            CommandLineInstall.destination(onPath: ["/usr/local/bin", homeBin],
                                           writable: ["/usr/local/bin", homeBin]),
            homeBin, "the user's own beats the one that usually needs sudo")
    }

    /// A directory that is writable but not on PATH would install a command the
    /// shell never finds, which looks exactly like an install that failed.
    func testADirectoryOffThePathIsNotADestination() {
        XCTAssertNil(CommandLineInstall.destination(onPath: ["/usr/bin"],
                                                    writable: [localBin]))
    }

    func testADirectoryOnThePathThatCannotBeWrittenIsNotADestination() {
        XCTAssertNil(CommandLineInstall.destination(onPath: ["/usr/local/bin"],
                                                    writable: []))
    }

    /// PATH entries are whatever a shell profile accumulated over the years.
    func testATrailingSlashIsStillTheSameDirectory() {
        XCTAssertEqual(
            CommandLineInstall.destination(onPath: ["/opt/homebrew/bin/"],
                                           writable: ["/opt/homebrew/bin"]),
            "/opt/homebrew/bin")
    }

    func testPathIsSplitOnColonsWithTheEmptyEntriesDropped() {
        XCTAssertEqual(CommandLineInstall.searchPath("/usr/bin::/bin:"),
                       ["/usr/bin", "/bin"])
        XCTAssertEqual(CommandLineInstall.searchPath(nil), [])
    }

    /// An app can live under a path with a space in it, and the line is pasted
    /// into a shell.
    func testTheManualCommandQuotesBothPaths() {
        let command = CommandLineInstall.manualCommand(
            tool: "/Applications/My Apps/Hangar.app/Contents/Helpers/hangar")
        XCTAssertTrue(command.hasPrefix("sudo ln -sfn "), command)
        XCTAssertTrue(command.contains("'/Applications/My Apps/Hangar.app"), command)
        XCTAssertTrue(command.hasSuffix("'/usr/local/bin/hangar'"), command)
    }

    // MARK: - What the check says about each state

    func testAnInstalledCommandIsReportedRatherThanOffered() {
        let check = Preflight.commandLineCheck(.installed(link: "/x/hangar"),
                                               toolPath: "/tool")
        XCTAssertEqual(check.level, .ok)
        XCTAssertNil(check.remedy)
    }

    func testAMissingCommandOffersToInstallItself() {
        let check = Preflight.commandLineCheck(.absent(destination: "/x/bin"),
                                               toolPath: "/tool")
        XCTAssertEqual(check.level, .warning)
        XCTAssertEqual(check.remedy, .installCommandLine)
        XCTAssertTrue(check.detail.contains("/x/bin"), check.detail)
    }

    /// Nowhere writable is not a button, it is a line the user runs.
    func testNowhereWritableOffersTheCommandInstead() {
        let check = Preflight.commandLineCheck(.absent(destination: nil),
                                               toolPath: "/tool")
        XCTAssertEqual(check.remedy,
                       .copyCommand(CommandLineInstall.manualCommand(tool: "/tool")))
    }

    /// Somebody else's `hangar` is far more likely to be deliberate than stale.
    func testSomebodyElsesCommandIsLeftAloneAndSaidSo() {
        let check = Preflight.commandLineCheck(.claimed(link: "/x/hangar"),
                                               toolPath: "/tool")
        XCTAssertEqual(check.level, .warning)
        XCTAssertNil(check.remedy, "Hangar does not overwrite what it did not write")
        XCTAssertTrue(check.detail.contains("left alone"), check.detail)
    }

    func testALinkToADeletedCopyCanBeRepointed() {
        let check = Preflight.commandLineCheck(.broken(link: "/x/hangar"),
                                               toolPath: "/tool")
        XCTAssertEqual(check.remedy, .installCommandLine)
    }

    func testABuildWithNoToolSaysSoRatherThanOfferingAnInstall() {
        let check = Preflight.commandLineCheck(.absent(destination: "/x/bin"),
                                               toolPath: nil)
        XCTAssertEqual(check.level, .warning)
        XCTAssertNil(check.remedy)
    }
}

/// A menubar app opened from Finder inherits launchd's PATH, so walking the app's
/// own PATH never reached a link the user had made, and said it was missing.
final class CommandLineStateTests: TemporaryDirectoryTestCase {

    /// What `ps eww` showed for the app in issue 5.
    private let launchdPath = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]

    private var tool: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let helpers = path("Hangar.app/Contents/Helpers")
        try FileManager.default.createDirectory(atPath: helpers,
                                                withIntermediateDirectories: true)
        tool = (helpers as NSString).appendingPathComponent("hangar")
        FileManager.default.createFile(atPath: tool, contents: Data("#!/bin/sh\n".utf8),
                                       attributes: [.posixPermissions: 0o755])
    }

    private func bin(_ name: String) throws -> String {
        let directory = path(name)
        try FileManager.default.createDirectory(atPath: directory,
                                                withIntermediateDirectories: true)
        return directory
    }

    private func link(in directory: String, to destination: String) throws -> String {
        let link = (directory as NSString).appendingPathComponent("hangar")
        try FileManager.default.createSymbolicLink(atPath: link,
                                                   withDestinationPath: destination)
        return link
    }

    func testALinkOffTheAppsOwnPathIsStillFound() throws {
        let local = try bin("usr-local-bin")
        let link = try link(in: local, to: tool)
        let state = CommandLineInstall.state(shellPath: launchdPath,
                                             preferred: [try bin("local-bin"), local],
                                             isWritable: { _ in false })
        XCTAssertEqual(state, .installed(link: link))
    }

    /// The link a shell would find wins over one it would not.
    func testTheShellPathIsLookedAtBeforeThePreferredDirectories() throws {
        let preferred = try bin("local-bin")
        let onPath = try bin("on-path")
        _ = try link(in: preferred, to: tool)
        let expected = try link(in: onPath, to: tool)
        let state = CommandLineInstall.state(shellPath: [onPath], preferred: [preferred],
                                             isWritable: { _ in true })
        XCTAssertEqual(state, .installed(link: expected))
    }

    func testALinkToAMissingCopyOffThePathIsBroken() throws {
        let local = try bin("local-bin")
        let link = try link(in: local, to: path("Gone.app/Contents/Helpers/hangar"))
        let state = CommandLineInstall.state(shellPath: launchdPath, preferred: [local],
                                             isWritable: { _ in true })
        XCTAssertEqual(state, .broken(link: link))
    }

    func testSomebodyElsesCommandOffThePathIsStillTheirs() throws {
        let local = try bin("local-bin")
        let theirs = (local as NSString).appendingPathComponent("hangar")
        FileManager.default.createFile(atPath: theirs, contents: Data())
        let state = CommandLineInstall.state(shellPath: launchdPath, preferred: [local],
                                             isWritable: { _ in true })
        XCTAssertEqual(state, .claimed(link: theirs))
    }

    /// Finding a link anywhere does not make anywhere a place to install: a
    /// directory the shell may not search would look like an install that failed.
    func testNothingFoundInstallsOnlyWhereTheShellLooks() throws {
        let local = try bin("local-bin")
        let usrLocal = try bin("usr-local-bin")
        XCTAssertEqual(
            CommandLineInstall.state(shellPath: launchdPath, preferred: [local, usrLocal],
                                     isWritable: { _ in true }),
            .absent(destination: nil))
        XCTAssertEqual(
            CommandLineInstall.state(shellPath: launchdPath + [usrLocal],
                                     preferred: [local, usrLocal],
                                     isWritable: { _ in true }),
            .absent(destination: usrLocal))
    }

    // MARK: - The PATH a shell starts from

    func testSystemPathReadsPathsThenPathsDInNameOrder() throws {
        let etc = try bin("etc")
        let listed = try bin("etc/paths.d")
        try "/usr/local/bin\n/usr/bin\n\n/bin\n".write(
            toFile: (etc as NSString).appendingPathComponent("paths"),
            atomically: true, encoding: .utf8)
        try "/opt/b\n".write(toFile: (listed as NSString).appendingPathComponent("20-b"),
                             atomically: true, encoding: .utf8)
        try "  /opt/a  \n".write(toFile: (listed as NSString).appendingPathComponent("10-a"),
                                 atomically: true, encoding: .utf8)
        XCTAssertEqual(CommandLineInstall.systemPath(etc: etc),
                       ["/usr/local/bin", "/usr/bin", "/bin", "/opt/a", "/opt/b"])
    }

    func testAMissingEtcIsAnEmptyPathNotACrash() {
        XCTAssertEqual(CommandLineInstall.systemPath(etc: path("no-such-etc")), [])
    }

    /// The case in issue 5: /usr/local/bin was in /etc/paths all along, just not
    /// in the environment launchd handed the app.
    func testTheShellPathAddsWhatEveryLoginShellGets() {
        let shell = CommandLineInstall.shellPath(
            process: launchdPath,
            system: ["/usr/local/bin", "/usr/bin/", "/bin"])
        XCTAssertEqual(shell, launchdPath + ["/usr/local/bin"])
        XCTAssertEqual(CommandLineInstall.destination(onPath: shell,
                                                      writable: ["/usr/local/bin"]),
                       "/usr/local/bin")
    }

    /// The advice and the detection disagreed: the app told the user to install
    /// into a directory it then did not look in.
    func testTheManualCommandsDirectoryIsAlwaysLookedIn() {
        XCTAssertTrue(CommandLineInstall.preferred.contains(CommandLineInstall.manualDirectory))
        XCTAssertTrue(CommandLineInstall.manualCommand(tool: "/tool")
            .hasSuffix(Shell.quoted(CommandLineInstall.manualDirectory + "/hangar")))
    }
}
