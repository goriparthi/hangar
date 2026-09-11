# Hangar

A native macOS menubar launcher for every host you can ssh to: the hosts already
in `~/.ssh/config`, any CSV you hand it, and an EC2 fleet turned into aliases that
maintain themselves. Swift 6, AppKit, no package dependencies.

This file is the institutional knowledge for the repo: conventions, commands,
architecture, and the mistakes that have actually bitten. Read it before changing
anything. The workflow it belongs to is described in
[docs/ai-native-sdlc.md](docs/ai-native-sdlc.md).

## Commands

```sh
make test            # the offline suite. Must be green before any commit.
make testbed         # every host source against a fake home, proving yours is untouched
make bundle          # assemble and sign dist/Hangar.app
make verify-assets   # prove every brand asset resolves in the built bundle
make run             # build, install to ~/Applications, launch
make dmg             # signed, notarized DMG. See RELEASING.md
```

`swift build` needs only the Command Line Tools. Two steps need Xcode: `actool`
for the asset catalog, and XCTest. `make test` points `DEVELOPER_DIR` at Xcode for
the run and uses its own scratch path, because two toolchains sharing one `.build`
leave modules the other cannot read.

## Architecture

```
app/Sources/HangarCore/   UI-free: AWS config, SigV4, SSO, EC2, ssh config writer,
                          tag mapping, fuzzy search, truncation, sanitizing,
                          the fleet cache and index both front ends read, and
                          the command line's parsing, filters and formatting
app/Sources/Hangar/       AppKit: menubar, panel, rows, editor, updater, brand
app/Sources/hangar-cli/   the `hangar` command, bundled at Contents/Helpers.
                          Only the parts that talk to the process live here:
                          files, streams, exit codes, and starting something.
                          Everything it decides is in HangarCore and is tested
app/Tests/                the offline suite
site/                     the landing page, deployed by .github/workflows/pages.yml
design/                   brand kit, wordmark, and their source assets
intent/                   one directory per change: intent, spec, plan
evals/                    behavioural checks the agent workflow is gated on
```

**Logic belongs in `HangarCore`.** It is UI-free and therefore testable. If
something in the AppKit layer is worth a test, move it down first. That is how
`SSHCommand` and `UpdateSchedule` ended up in the core.

## Conventions

- **Swift 6 language mode, warning-free.** A change that needs `@unchecked
  Sendable` or `nonisolated(unsafe)` to compile needs rethinking instead.
- **No package dependencies, no AWS SDK, no runtime dependency on the `aws` CLI.**
  This is a product property, not an accident. Keep it.
- **Comments say why, not what, and stay to two lines.** The code shows the what.
- **No em dashes** anywhere: UI copy, comments, commit messages, docs.
- Commit messages: one imperative line, then at most three or four lines of body
  when the why is not obvious. No Claude co-author trailers. No ticket prefixes;
  this repo has no Jira.
- **Commits are dated outside business hours.** Every commit here is stamped
  Monday to Friday before 08:00 or after 18:00 local time, and never on a
  Saturday or Sunday. This is a personal project, and its history says so. When
  committing inside those hours, set both dates explicitly:

  ```sh
  GIT_AUTHOR_DATE="2026-09-02T07:15:00" \
  GIT_COMMITTER_DATE="2026-09-02T07:15:00" \
  git commit -m "..."
  ```

  Both variables, not just the author date: the committer date is what `git log
  --date` and GitHub show by default.

## Untrusted input

EC2 tags are written by anyone who can tag the account, and `~/.hangar/config.json`
is hand-edited. Neither is trusted just because it arrived over TLS.

- Anything written into `ssh_config` goes through `SSHConfigValue`: quoted when it
  contains whitespace, refused outright when it contains a newline, CR, NUL or a
  double quote. A newline would let a tag append its own directive, and
  `ProxyCommand` is a directive ssh executes.
- Anything used as a *name* on a `Host` line is held to `isSafeAlias`, which is
  stricter still, because that line is a pattern list rather than a value.
- Anything reaching an `ssh` argument vector followed by another argument needs
  `--` before it. Use `SSHProbe` rather than building the vector by hand.
- Anything written under `~/.hangar` goes through `PrivateFile`, which creates at
  0600 rather than tightening afterwards.
- Anything interpolated into a command handed to a terminal goes through `Shell`.
- Region names go through `AWSRegion` before reaching an endpoint hostname.
- A host that cannot be represented is skipped and **reported**, never silently
  dropped. Silence looks like the instance was terminated.

## Mistakes this repo has already made

Kept because each one cost real debugging and would be easy to reintroduce.

1. **One bad tag took out every alias.** EC2 allows spaces in tag values. An
   unquoted `HostName web 1` made ssh reject the whole generated file, so a single
   sloppy tag cost the user all 249 aliases. Quote, and validate per entry.
2. **Hardcoded advice for a failure that has several causes.** "Run aws sso login"
   was shown for any error containing "expired", which is useless to someone with
   a key pair in `~/.aws/credentials`. Recovery advice must come from the profile
   that was actually tried, via `CredentialAdvice`.
3. **Hardcoded tag names.** `product`/`env`/`env_name`/`Name` were assumed, so the
   app was useless to a fleet tagged `Service`/`Environment`/`Component`. Tag keys
   are a mapping with candidates, not constants.
4. **A force-unwrapped interpolated URL.** `URL(string: "https://ec2.\(region)…")!`
   traps on a region containing a space, which is a plausible typo in a
   hand-edited config. Validate, then throw a readable error.
5. **Dead code the documentation described as shipping.** The verified in-place
   updater existed and was never called, while the README explained how it
   worked. If the docs claim it, wire it or delete it.
6. **`rm -rf` before the replacement succeeded.** The update helper deleted the
   installed app and then moved the new one in. Move aside, swap, then clean up.
7. **A shared build directory across two toolchains.** See Commands above.
8. **`text-transform: uppercase` on a product name.** It rendered "MACOS".
   Capitalisation can be part of a name.
9. **An argument vector is not enough for `ssh`.** A hostname tag of
   `-oProxyCommand=…` followed by a trailing argument is parsed as an option and
   the command runs. `--` before the host is the only fix. See `SSHProbe`.
10. **The `Host` line is a pattern list, not a value.** A tag of `*` produced a
    catch-all that ssh accepted and that outranked the user's whole
    `~/.ssh/config`, silently, because `ssh -G` validates it happily. Names on
    that line go through `SSHConfigValue.isSafeAlias`, which is stricter than
    `isEmittable`.
11. **`replaceItemAt` keeps the destination's file mode.** A pre-existing 0644
    ssh include stayed 0644 no matter how tight the temporary file was. Chmod
    after the replace, not only before.
12. **`createDirectory(attributes:)` does not tighten an existing directory.** A
    hand-made `mkdir ~/.hangar` stayed at the umask. `PrivateFile.ensureDirectory`
    sets the mode either way.
13. **A label that assumed the default config.** `leafLabel` cut `product-env`
    off every alias, so a fleet grouped by product alone showed `web-1` three
    times for prod, stage and qa. Anything that trims a label has to be told the
    levels the menu was actually built from.
14. **A screen with no way off it.** Opening a host put its record on the
    Insights tab, and the only control that stepped back out was the hub in the
    middle of the cluster, which is on the other tab. Every view that can be
    navigated into carries its own way out, on itself.
15. **`NSStackView.fittingSize` leaves the stack's own `edgeInsets` out** of the
    cross-axis width. Sizing a panel from it produced a notice card exactly as
    wide as its text column, so 30 points of padding a side became none and the
    body printed against the rounded edge. Size from the content plus the
    padding, both as numbers.
16. **An eval that could never fail.** `security-no-force-unwrapped-endpoints`
    was green for weeks while checking nothing: its regex escaped a parenthesis
    in a way `grep` read as an unbalanced group, `grep` exited 2, and the
    leading `!` turned that error into a pass. A guard shaped `! grep …` passes
    when the grep is broken. Plant the mistake and watch the case fail before
    trusting it.
17. **Uppercasing a name that came from outside.** Mistake 8 was fixed on the
    landing page and left alone in the app, where the panel's group header ran
    `product.uppercased()` on an EC2 tag value. Same bug, different file.
18. **Two answers to the same question.** `FleetGrouping` skips a grouping key
    no host carries, so the menubar never shows a level holding one "untagged"
    entry. The cluster grew its own drill and did not, so the picture and the
    menu disagreed about how deep the same fleet went, and 89 hosts on a real
    fleet sat behind a circle that said nothing. When a second thing answers a
    question the first already answers, it has to call the first one.
19. **A mono variant hand-simplified away from its source.** The wordmark ships
    in colour and in a single-colour version, and the mono one had its aircraft
    redrawn small by hand: one wing, a lopsided fuselage, and a subpath that
    never closed. It read as a smudge inside the arch at every size. A mono
    variant is the same drawing without colour, so its geometry comes from the
    primary asset, scaled. `make wordmark` re-renders the raster fallbacks and
    the manifest from the SVGs, so this stays checkable.
20. **An external process with no deadline.** `credential_process` is the user's
    own command, and `readDataToEndOfFile` waits for the pipe to close, which a
    helper that hangs never does. The fleet refreshed forever and the setup
    window sat blank. Every process Hangar runs gets a deadline and a kill.
21. **A merge key that was not a key.** `FleetMerge` deduplicated on `aliasStem`,
    and two members of one autoscaling group share a stem by design; the writer
    exists to number them apart. On the first run against a live account it
    silently dropped 18 hosts out of 223. Deduplicate on a name a source actually
    *gave* a host, never on one derived from its tags.
22. **A git remote is not a host.** Importing `~/.ssh/config` pulled in the
    GitHub and Bitbucket entries every developer has. `ssh git@github.com` prints
    a greeting and exits, so those rows could never be connected to, and they
    sorted above the whole fleet because they carry no product. The rule is
    `User git`, which also covers every self-hosted forge. A machine merely named
    for git is still a host.
23. **An empty string sorts first.** Untagged hosts opened the panel, above
    everything tagged. Survivable while untagged meant a few forgotten EC2 boxes,
    not once a source existed that produces them by the handful.
24. **A default that outranked the user.** `HangarConfig.standard()` wrote
    `User <macOS account>` on every host, and because Hangar's `Include` sits at
    the top of `~/.ssh/config` and ssh_config is first-value-wins, that guess beat
    a `Host * / User ec2-user` the user had written themselves. Hangar now ships
    no login and learns one by asking a single host, once. Anything Hangar asserts
    in that file beats the user's own config, so it must only assert what it knows.
25. **A feature only the first run could reach.** Adopting the agent's key ran
    inside the setup window's checks, and that window opens on launch only before
    onboarding completes. Fresh installs got it; every upgrade did not.
26. **Three numbers for one fleet.** The sources card summed its rows, the tag
    check counted the merged fleet, and the alias check quoted the fleet size for
    a file that does not hold every host. 225, 225 and 223 for the same question.
    A number on screen has to name the set it counted.

27. **An invalidated timer whose last frame had not landed yet.** The menubar
    pulse ticked at 20 Hz and each tick queued its draw into a detached
    `Task { @MainActor }`. `stopPulse` invalidated the timer and the settled glyph
    was repainted, then a frame already in the queue repainted the pulse colour
    over it, and nothing repainted again until the next refresh. The icon was
    amber for 30 minutes at a time while every refresh in the log had finished in
    under two seconds. Invalidating a timer does not recall the work its ticks
    already handed off; a frame drawn one hop from the tick has to re-read the
    state that justified it.
28. **State that only changed when something published.** The same glyph was
    repainted from `$fetchedAt` and `$status`, and both only change at a refresh,
    which is the one moment a cache's age is not worth reporting. A cache going
    stale is a thing that happens while nothing is being published at all.
    Anything derived from elapsed time needs something that ticks.
29. **A haystack that repeated itself.** `SearchEntry.metadata` joined product,
    env, env_name and Name. For an **apex** name with a sibling, `SSHConfigImport`
    takes product and role from that same first label, so the value appeared twice.
    A subsequence could start in one copy and finish in the next, which matched
    what no single field held: on a `webstore` host, `wers` matched though neither
    the alias nor the tag contains it. Typing more stopped narrowing, which is the
    one thing a person is doing when they keep typing. Deduplicate before joining,
    and deduplicate on **the lowered bytes the search compares**, not on a Unicode
    case fold. `Fuzzy.lowered` folds ASCII only, so folding wider collapses `Über`
    and `über` into one copy and then the lowercase spelling is in no field at all.
    A dedupe wider than the haystack turns a phantom match into a missing host.
30. **A GUI app's PATH is not the user's.** Setup Check walked
    `ProcessInfo`'s PATH for the `hangar` link. Opened from Finder or as a login
    item, the app inherits launchd's `/usr/bin:/bin:/usr/sbin:/sbin`, which holds
    none of the four directories the tool goes in. So it said "not installed"
    beside a link the user had just made with the `sudo ln` line it handed them,
    and could never offer a directory to install into. Launching from a terminal
    hides it. Whether a file exists is a filesystem question; only choosing where
    to put one needs the shell's PATH, and the part of that readable without
    running the shell is `/etc/paths` and `/etc/paths.d`.

## Testing against a fake fleet

`make testbed` builds a fabricated home directory, runs every host source, the
merge and the writer against it, and then proves your own `~/.ssh/config` and
`~/.hangar` are byte for byte unchanged.

That last part is not ceremony. `expandingTildeInPath` reads the real home on
macOS whatever `HOME` says, so a testbed built on an environment variable would
quietly read and rewrite the developer's own ssh config. Every path in the
testbed is passed in explicitly, and the fingerprint check is the proof.

`hangar-probe --sources` and `hangar-probe --keys` report the local sources and
the ssh agents on this machine, read-only, with no credentials needed.

## Permissions and file modes

Everything Hangar writes under `~/.hangar` and `~/.ssh/config.d` is `0600` inside
`0700` directories, including the fleet cache and the update timestamp. The cache
is the whole inventory: instance ids, private addresses, every tag.

## Before you commit

1. `make test` green.
2. Read the staged diff for anything that should not be public: account ids, real
   hostnames, internal IPs, key material. Test fixtures use `example.com`,
   `123456789012` and `10.0.0.1` deliberately.
3. Check [REVIEW.md](REVIEW.md) for the passes that apply to what you touched.
