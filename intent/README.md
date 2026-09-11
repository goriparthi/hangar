# Intent

One directory per unit of change, numbered in the order the work started. Each
holds up to three artifacts, written in this order:

| File | Stage | Answers |
|---|---|---|
| `intent.md` | Plan | Which question surfaced this, what was actually true, and what was decided |
| `spec.md` | Design | What the behaviour will be, precisely enough to disagree with |
| `plan.md` | Build | Which files change, in what order, and which tests prove it |

An `intent.md` here leads with the question that produced the work, not a
template. That is deliberate: the question is the reusable part. "If someone
downloads this for their fleet, does it work?" found more than any checklist
did, and reads back years later in a way that "## Problem" does not.

The point is that each stage is reviewable before the next one costs anything.
Disagreeing with a paragraph in `intent.md` is cheap; disagreeing with a merged
branch is not.

Small changes do not need all three. A one-line fix needs a commit message. The
threshold is roughly: if it changes behaviour a user could notice, or it touches
credentials, `ssh_config`, or the updater, it gets an `intent.md`.

`0001` through `0007` were written after the fact, on the day the workflow was
adopted, from the actual diffs and the conversation that produced them, and they
quote the questions that were genuinely asked. They are accurate about what was
done and why. They are not a pretence that the process was followed
prospectively; see [docs/ai-native-sdlc.md](../docs/ai-native-sdlc.md).
`0008` onward were written in order.

## Status

| Intent | Title | State |
|---|---|---|
| 0001 | Public release hardening | Shipped |
| 0002 | Swift 6 language mode | Shipped |
| 0003 | Configurable tag mapping | Shipped |
| 0004 | Credential advice per profile type | Shipped |
| 0005 | Automatic updates with in-place install | Shipped |
| 0006 | Landing page | Shipped |
| 0007 | Layered app icon | Open |
| 0008 | ssh argument and pattern injection | Shipped |
| 0009 | Tag picker on the setup screen | Shipped |
| 0010 | Composable menu levels | Shipped |
| 0011 | Reinstall behaves like one, and reset | Shipped |
| 0012 | Uninstall from the menu | Shipped |
| 0013 | Menu heading, EC2 glyph, honest empty state, landing page | Shipped |
| 0014 | A hanging credential helper, a lying leaf label, a setup screen that shows its work | Shipped |
| 0015 | Uninstall removes every copy | Shipped |
| 0016 | App logging | Shipped |
| 0017 | The Include line looks after itself | Shipped |
| 0018 | A window you can command-tab back to | Shipped |
| 0019 | Icon rendered from source, larger and brighter | Shipped |
| 0020 | Fleet dashboard | Shipped |
| 0021 | A dashboard you can navigate | Shipped |
| 0022 | A window closes rather than quitting | Shipped |
| 0023 | A key you never have to name | Shipped |
| 0024 | More than one way to find a host | Shipped |
| 0025 | A wider door, not a different house | Shipped |
| 0026 | Three things the first real install found | Shipped |
| 0027 | A command line you can drive | Shipped |
| 0028 | A fleet with no AWS | Open |
| 0029 | A glyph that was amber for half an hour | Shipped |
| 0030 | Typing more narrows | Shipped |
| 0031 | A command the app could not see | Shipped |
