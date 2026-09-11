import Foundation

/// Reads the local setup and reports what works and what does not.
///
/// Everything Hangar needs lives in the user's home directory, so all of this is
/// checkable before the user hits a failure. UI-free on purpose: the same checks
/// back the first-run screen and the menubar's setup item, and they are testable.
public struct Preflight: Sendable {
    public enum Level: Sendable, Equatable { case ok, warning, problem }

    public struct Check: Sendable, Identifiable {
        public var id: String
        public var title: String
        public var detail: String
        public var level: Level
        /// A machine-readable name for the remedy the UI should offer, if any.
        public var remedy: Remedy?

        public init(id: String, title: String, detail: String,
                    level: Level, remedy: Remedy? = nil) {
            self.id = id
            self.title = title
            self.detail = detail
            self.level = level
            self.remedy = remedy
        }
    }

    public enum Remedy: Sendable, Hashable {
        case addIncludeLine
        case copyLoginCommand(String)
        case openConfig
        /// Bring the agent's own app forward so the user can unlock it.
        case openApp(bundleID: String, name: String)
        case importHostsFile
        /// Put `hangar` on the user's PATH.
        case installCommandLine
        /// Nothing on PATH is writable, so the user runs one line themselves.
        case copyCommand(String)
    }

    public var checks: [Check]

    public init(checks: [Check]) { self.checks = checks }

    public var worst: Level {
        if checks.contains(where: { $0.level == .problem }) { return .problem }
        if checks.contains(where: { $0.level == .warning }) { return .warning }
        return .ok
    }

    public var isUsable: Bool { worst != .problem }

    // MARK: - Individual checks, each independently testable

    /// AWS profiles found across ~/.aws/config and ~/.aws/credentials, and which
    /// one Hangar is using. Counting them without naming the pick was the whole
    /// reason a machine with three profiles could fail on the one it chose for
    /// itself with nothing on screen admitting which that was.
    public static func profilesCheck(_ files: AWSConfigFiles,
                                     using requested: String? = nil,
                                     env: [String: String]
                                        = ProcessInfo.processInfo.environment) -> Check {
        let names = files.profileNames
        if names.isEmpty {
            return Check(
                id: "profiles", title: "AWS profiles",
                detail: "No profiles found in ~/.aws/config or ~/.aws/credentials.",
                level: .problem)
        }
        let title = names.count == 1 ? "1 AWS profile found"
                                     : "\(names.count) AWS profiles found"
        let others = { (active: String) -> String in
            let rest = names.filter { $0 != active }
            guard !rest.isEmpty else { return "" }
            let listed = rest.prefix(3).joined(separator: ", ")
            let more = rest.count > 3 ? ", and \(rest.count - 3) more" : ""
            return " Also available: \(listed)\(more)."
        }

        guard let active = AWSConfigFiles.activeProfileName(requested: requested, env: env) else {
            return Check(
                id: "profiles", title: title,
                detail: "AWS_ACCESS_KEY_ID is exported, so Hangar uses those "
                    + "credentials and reads no profile at all. Pick a profile to "
                    + "override that. Profiles: \(names.prefix(4).joined(separator: ", ")).",
                level: .ok)
        }

        // A profile that is set but not in either file is its own fault, and one
        // the credential error describes badly: it reads as a credentials problem
        // when the name is simply wrong.
        guard let summary = files.profileSummaries.first(where: { $0.name == active }) else {
            return Check(
                id: "profiles", title: title,
                detail: "Hangar is set to use \(active), which is not in ~/.aws/config "
                    + "or ~/.aws/credentials." + others(active),
                level: .warning, remedy: .openConfig)
        }

        let how = requested == nil ? "Using \(active) by default" : "Using \(active)"
        return Check(
            id: "profiles", title: title,
            detail: "\(how): \(summary.detail)." + others(active), level: .ok)
    }

    /// Whether the ssh aliases Hangar writes can actually be resolved by ssh.
    ///
    /// `hostCount` is what Hangar wrote, not the size of the fleet. Hosts imported
    /// from the user's own config are launched from their file rather than ours,
    /// so quoting the fleet size here would claim aliases that are not in the file.
    public static func sshIncludeCheck(
        includePresent: Bool, fileExists: Bool, hostCount: Int, importedCount: Int = 0
    ) -> Check {
        if includePresent {
            let imported = importedCount > 0
                ? " \(importedCount) more are already in your own config and are left there."
                : ""
            return Check(
                id: "ssh-include", title: "SSH aliases active",
                detail: fileExists
                    ? "~/.ssh/config includes \(hostCount) Hangar aliases.\(imported)"
                    : "~/.ssh/config has the Include line; aliases appear after the first sync.",
                level: .ok)
        }
        return Check(
            id: "ssh-include", title: "SSH aliases not active yet",
            detail: "Add Include ~/.ssh/config.d/hangar to ~/.ssh/config so aliases "
                + "work in ssh, scp, rsync, and Ansible. Hangar connects either way.",
            level: .warning, remedy: .addIncludeLine)
    }

    /// Hangar groups and names hosts from tags, so untagged fleets look broken.
    public static func taggingCheck(instances: [Instance]) -> Check {
        guard !instances.isEmpty else {
            return Check(
                id: "tags", title: "No hosts discovered",
                detail: "No running or stopped instances were found in this region.",
                level: .warning)
        }
        let untagged = instances.filter(TagMapping.isUngrouped)
        if untagged.isEmpty {
            let products = Set(instances.map(\.product)).filter { !$0.isEmpty }.count
            let environments = Set(instances.map(\.env)).filter { !$0.isEmpty }.count
            return Check(
                id: "tags", title: "\(instances.count) hosts indexed",
                detail: "\(products) products, \(environments) environments.", level: .ok)
        }
        if untagged.count == instances.count {
            return Check(
                id: "tags", title: "Hangar cannot read this fleet's tags",
                detail: "All \(instances.count) instances came back with no tag Hangar "
                    + "recognises, so they group under untagged and are named by "
                    + "instance id. Map your own tag keys under \"tags\" in "
                    + "~/.hangar/config.json, or tag hosts with Name.",
                level: .warning, remedy: .openConfig)
        }
        return Check(
            id: "tags", title: "\(instances.count) hosts indexed",
            detail: "\(untagged.count) carry no tag Hangar recognises and group under "
                + "untagged. Map your tag keys under \"tags\" in "
                + "~/.hangar/config.json if they use different names.",
            level: .warning, remedy: .openConfig)
    }

    /// Where the ssh key comes from.
    ///
    /// Reports rather than asks. An agent that is already holding the key needs
    /// no configuration at all, and the common failure is not a missing key but a
    /// locked vault, which looks identical to an empty one from outside.
    public static func keyCheck(agents: [SSHAgent], keyFiles: [String],
                                settings: HangarConfig.SSHSettings?) -> Check {
        // A pinned key with IdentitiesOnly and no agent is the shape that used to
        // lock an agent user out of every host at once, so it is called out.
        if let agent = agents.first(where: { $0.isUsable }) {
            let pinned = settings?.identityAgent == agent.socket
            let count = agent.keys.count
            return Check(
                id: "key",
                title: "\(agent.name) is holding your ssh key",
                detail: pinned
                    ? "Hangar points ssh at \(agent.name) for every host. The private "
                        + "key stays in the vault; only its public half is written."
                    : "\(count == 1 ? "1 key" : "\(count) keys") available. Hangar will "
                        + "use \(count == 1 ? "it" : "the one you pick below") and never "
                        + "reads the private half.",
                level: .ok)
        }
        if let agent = agents.first {
            return Check(
                id: "key", title: "\(agent.name) is there but locked",
                detail: agent.problem ?? "The agent offered no keys.",
                level: .warning,
                remedy: agent.kind == .onePassword
                    ? .openApp(bundleID: "com.1password.1password", name: "1Password")
                    : nil)
        }
        if settings?.identityFile?.isEmpty == false {
            return Check(id: "key", title: "SSH key set",
                         detail: "Hangar pins \(settings?.identityFile ?? "") on every host.",
                         level: .ok)
        }
        if !keyFiles.isEmpty {
            return Check(
                id: "key", title: "SSH keys found in ~/.ssh",
                detail: keyFiles.joined(separator: ", ")
                    + ". Hangar says nothing about keys unless you pick one, so ssh "
                    + "uses these exactly as it already does.",
                level: .ok)
        }
        return Check(
            id: "key", title: "No ssh key found",
            detail: "No agent and no key in ~/.ssh. Hangar still connects; ssh will "
                + "ask for a password unless your own config says otherwise.",
            level: .warning)
    }

    /// Where the hosts came from. The point of this check is that a denied EC2
    /// call is no longer a dead end: it sits directly above whatever did work.
    ///
    /// `fleetSize` is the merged count, not the sum of the rows. They differ when
    /// two sources named the same machine, and a headline that disagrees with the
    /// list under it is the same fault as a cluster that disagrees with the menu.
    public static func sourcesCheck(_ reports: [SourceReport], fleetSize: Int) -> Check {
        let working = reports.filter { $0.attempted && $0.hosts > 0 }
        let gathered = working.reduce(0) { $0 + $1.hosts }
        let total = fleetSize
        let detail = reports
            .filter { $0.attempted }
            .map { report -> String in
                if let problem = report.problem, report.hosts == 0 {
                    return "\(report.source.label): \(clipped(problem))"
                }
                return "\(report.source.label): \(report.hosts)"
            }
            .joined(separator: "  ·  ")
            + (gathered > total ? "  ·  \(gathered - total) named by two sources" : "")

        if working.isEmpty {
            return Check(
                id: "sources", title: "No hosts from any source",
                detail: detail.isEmpty
                    ? "EC2 returned nothing, and there is no ~/.ssh/config and no "
                        + "~/.hangar/hosts.csv to fall back on."
                    : detail + ". Drop a CSV of hostnames on this window to add hosts "
                        + "without any AWS permission at all.",
                level: .problem, remedy: .importHostsFile)
        }
        let failed = reports.filter { $0.attempted && $0.problem != nil && $0.hosts == 0 }
        return Check(
            id: "sources",
            title: working.count == 1
                ? "\(total) hosts from \(working[0].source.label)"
                : "\(total) hosts from \(working.count) sources",
            detail: detail,
            level: failed.isEmpty ? .ok : .warning)
    }

    /// A failing source's problem, short enough that the other sources' counts
    /// survive. A credential paragraph in here used to fill all three lines this
    /// detail gets, hiding every number the check exists to report. The whole
    /// message is on the credentials card.
    static func clipped(_ problem: String, limit: Int = 64) -> String {
        guard problem.count > limit else { return problem }
        return String(problem.prefix(limit - 1)) + "\u{2026}"
    }

    /// The `hangar` command, and whether the shell can find it.
    ///
    /// Reported rather than assumed: the tool ships inside the bundle, where
    /// nobody would look, so an install that quietly did not happen would leave
    /// "command not found" as the only evidence.
    public static func commandLineCheck(_ state: CommandLineInstall.State,
                                        toolPath: String?) -> Check {
        guard toolPath != nil else {
            return Check(id: "cli", title: "No command line tool in this build",
                         detail: "Reinstall Hangar from a release DMG to get the "
                            + "hangar command.",
                         level: .warning)
        }
        switch state {
        case .installed(let link):
            return Check(
                id: "cli", title: "hangar is on your PATH",
                detail: "\(link) runs the same search the panel does, and "
                    + "connects. Try hangar ssh web prod.",
                level: .ok)
        case .broken(let link):
            return Check(
                id: "cli", title: "hangar points at a copy that is gone",
                detail: "\(link) is a link Hangar wrote to an app that has moved or "
                    + "been deleted. Installing again points it here.",
                level: .warning, remedy: .installCommandLine)
        case .claimed(let link):
            return Check(
                id: "cli", title: "Something else is called hangar",
                detail: "\(link) is not Hangar's, so it was left alone. Rename or "
                    + "remove it if you want this one on your PATH.",
                level: .warning)
        case .absent(let destination):
            guard let destination else {
                return Check(
                    id: "cli", title: "hangar is not on your PATH",
                    detail: "No directory Hangar knows is on your PATH can be "
                        + "written without sudo, so this one is yours to run.",
                    level: .warning,
                    remedy: .copyCommand(
                        CommandLineInstall.manualCommand(tool: toolPath ?? "")))
            }
            return Check(
                id: "cli", title: "hangar is not on your PATH yet",
                detail: "The command ships inside the app. Hangar can link it into "
                    + "\(destination), which is already on your PATH.",
                level: .warning, remedy: .installCommandLine)
        }
    }

    /// The terminal Hangar will hand sessions to, and what else it could use.
    ///
    /// `installed` is what the app layer found on this machine; the core cannot
    /// ask, and a check that assumed the answer would be reporting a guess.
    public static func terminalCheck(configured: TerminalChoice,
                                     installed: [TerminalChoice]) -> Check {
        let others = installed.filter { $0 != configured }
        let alternatives = others.isEmpty
            ? ""
            : " Also installed: "
                + others.map(\.displayName).joined(separator: ", ") + "."
        if installed.contains(configured) {
            // Only the scripted terminals need Automation permission, and being
            // asked for it out of nowhere on a first connect is worth a warning.
            let permission = configured.mechanism == .appleScript
                ? " macOS asks once for permission to control it."
                : ""
            return Check(
                id: "terminal", title: "\(configured.displayName) found",
                detail: "Sessions open in \(configured.displayName)."
                    + permission + alternatives,
                level: .ok)
        }
        if installed.contains(TerminalChoice.fallback) {
            return Check(
                id: "terminal", title: "\(configured.displayName) not installed",
                detail: "Sessions will open in \(TerminalChoice.fallback.displayName) "
                    + "instead. Pick another below." + alternatives,
                level: .warning)
        }
        return Check(id: "terminal", title: "No terminal found",
                     detail: "None of "
                        + TerminalChoice.allCases.map(\.displayName)
                            .joined(separator: ", ")
                        + " could be located on this Mac.",
                     level: .problem)
    }

    public static func hotkeyCheck(problem: String?, combination: String) -> Check {
        if let problem {
            return Check(id: "hotkey", title: "Shortcut unavailable",
                         detail: problem, level: .warning, remedy: .openConfig)
        }
        return Check(id: "hotkey", title: "Shortcut ready",
                     detail: "Press \(combination) from any app.", level: .ok)
    }

    /// Credentials, with a recovery only when one actually applies. The advice is
    /// computed from the profile that was tried, so a static-keys user is never
    /// told to run an SSO command they have no use for.
    /// `hasHostsAnyway` downgrades the failure. Since hosts can come from the
    /// user's own ssh config and from a CSV, an expired token is no longer the
    /// difference between a working app and a broken one, and calling it a
    /// blocker in front of a fleet that is on screen would be a lie.
    public static func credentialsCheck(sourceLabel: String?,
                                        advice: CredentialAdvice.Advice?,
                                        hasHostsAnyway: Bool = false) -> Check {
        if let advice {
            return Check(
                id: "credentials",
                title: advice.command != nil ? "Credentials expired"
                                             : "Credentials unavailable",
                detail: hasHostsAnyway
                    ? advice.message + " Your other sources still worked, so Hangar "
                        + "is usable; AWS hosts are missing until this is fixed."
                    : advice.message,
                level: hasHostsAnyway ? .warning : .problem,
                remedy: advice.command.map { Remedy.copyLoginCommand($0) })
        }
        return Check(id: "credentials", title: "Credentials resolved",
                     detail: sourceLabel ?? "Ready.", level: .ok)
    }

    /// The one row that stands in for the profile and credential checks when AWS
    /// is not part of this setup.
    ///
    /// Informational, never a fault: a configuration the user chose is not a
    /// problem, and a permanent red teaches them to ignore the colour, which is
    /// how a real one gets missed. Present rather than absent, because a row that
    /// disappears when a toggle flips is a row nobody can find again, and someone
    /// wondering where their EC2 fleet went needs one line saying it is off and
    /// where the switch is.
    public static func awsOffCheck() -> Check {
        Check(id: "aws-off", title: "AWS sources are off",
              detail: "EC2 and Systems Manager are switched off, so no profile or "
                + "credential was read. Turn either on in Where the hosts come "
                + "from, below, to add an AWS fleet.",
              level: .ok)
    }
}
