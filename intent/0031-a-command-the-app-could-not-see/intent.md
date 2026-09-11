# 0031: a command the app could not see

## How this came about

Issue 5. On 0.8.0-beta.1 Setup Check said the command line tool was not installed
and offered the `sudo ln -sfn ...` line to copy. The line was run, `hangar` worked
in the shell, and the check still said it was not installed. Running the line
again changed nothing.

```
$ ls -l /usr/local/bin/hangar
lrwxr-xr-x  1 root  wheel  48  /usr/local/bin/hangar -> /Applications/Hangar.app/Contents/Helpers/hangar
$ hangar --version
0.8.0-beta.1
```

The link was exactly the shape the check looks for. The question was why the
check could not see it.

## What was actually true

`CommandLineTool.state()` walked `CommandLineInstall.searchPath()`, which reads
`ProcessInfo.processInfo.environment["PATH"]`. That is the PATH of the app
process, not of a shell. A menubar app started by launchd, from Finder or as a
login item, gets launchd's default:

```
$ ps eww -p $(pgrep -x Hangar) | tr ' ' '\n' | grep ^PATH=
PATH=/usr/bin:/bin:/usr/sbin:/sbin
```

None of the four `preferred` directories is on it, so:

- the walk never looked in `/usr/local/bin` and returned `.absent`;
- `destination(onPath:writable:)` requires a directory to be on that PATH, so it
  could never return one either, and the automatic install the README describes
  could not fire;
- the only reachable answer was `.absent(destination: nil)`, whose remedy is the
  manual line, which installs into `/usr/local/bin`, which the check then does not
  look in.

The advice and the detection disagreed. Launching Hangar from a terminal inherits
that shell's PATH and hides all of it, which is why development never saw it.

## What was decided

The issue named four directions. The one taken is its fourth: two questions, two
answers.

**Is it installed** is a question about the filesystem. `state` now looks on the
PATH first, so the link a shell would find still wins, and then in every
`preferred` directory whether or not it is on any PATH. `manualDirectory` is one
of them by construction, so the line Setup Check hands out always installs
somewhere Setup Check looks. A test pins that.

**Where to install** does need the shell's PATH, and the part of it Hangar can
read without running the shell is what `path_helper` builds every login shell
from: `/etc/paths`, then `/etc/paths.d` in name order. `shellPath` is the app's
own PATH plus that. On a stock Mac it adds `/usr/local/bin`, which is root's, so
the usual first run still hands over the line. On a machine where the user owns
`/usr/local/bin`, an Intel Homebrew install for instance, the automatic install
now fires where before it never could.

Not taken:

- **Asking a login shell** (`$SHELL -lc 'echo $PATH'`). It is the only thing that
  knows about `~/.local/bin` added in an rc file, but zsh reads `.zshrc` only
  when interactive, so `-l` alone misses the common case and `-il` runs whatever
  the user's rc does, with no terminal, from a menubar app. A setup check should
  not start the user's shell to find out where a symlink is.
- **Treating any writable preferred directory as a destination.** A directory
  the shell does not search would install a command it never finds, which looks
  exactly like an install that failed. `testADirectoryOffThePathIsNotADestination`
  already says so and still holds.

The walk moved from `Launcher.swift` into `CommandLineInstall.state` in the core,
with the directories and the writability check passed in, because the bug was in
the walk and the AppKit layer cannot be tested. `CommandLineStateTests` builds a
fake bundle and links in a scratch directory and hands it launchd's PATH; three of
its cases fail against the old walk.

The Setup Check copy for `.absent(destination: nil)` said "No directory on your
PATH can be written without sudo", which is a claim about the shell's PATH that
Hangar cannot make. It now says "No directory Hangar knows is on your PATH".
