<div align="center">

<img src="site/assets/hangar-icon.png" alt="Hangar" width="128" height="128">

# Hangar

**Spotlight for your SSH hosts.**

A native macOS launcher for every host you can ssh to. It reads the hosts already
in your ssh config, takes a CSV of any others, and turns an EC2 fleet that will
not sit still into aliases that maintain themselves.

Press <kbd>⌘</kbd><kbd>⇧</kbd><kbd>H</kbd>, type a few characters, press
<kbd>Return</kbd>, and you are on the box. No account, no server, and no AWS
permission required.

### [Download Hangar](https://github.com/goriparthi/hangar/releases/latest)

**[hangar homepage](https://goriparthi.github.io/hangar/)**

Signed and notarized by Apple. Open the DMG, drag Hangar to Applications, launch it.
No Gatekeeper warning, no `xattr` command, no Homebrew, no Xcode.

<img src="site/assets/shot-panel.png" alt="The Hangar panel with payments prod web typed into it, two matching hosts listed with their ssh aliases, PROD badges and hostnames" width="760">

<sub>The panel, three words in. The fleet in every screenshot here is fictional.</sub>

</div>

---

## It works before you configure anything

Hangar gathers hosts from four places and merges them, richest first. Every one is
on by default, because a source that finds nothing costs nothing.

**Hosts you already have.** On first launch Hangar reads `~/.ssh/config`, and the
files it `Include`s, and puts every host in there behind the same shortcut as
everything else. Your file is never rewritten: those hosts already resolve, and a
second copy in Hangar's include would sit above yours and win. Patterns, `Match`
blocks and git remotes are recognised and skipped.

**Hosts on a spreadsheet.** Drop a CSV anywhere on the window. `alias` or
`hostname` is enough; any column Hangar has no meaning for becomes a tag, so you
can group the menu by `datacenter` or `owner`.

**An AWS fleet.** One read-only `ec2:DescribeInstances` gives you aliases built
from your own tags, so they survive the instance being replaced, plus a dashboard
computed from the same response. If that call is denied, Systems Manager is tried
on its own, and it finds on-prem hosts EC2 never could.

The first two need no AWS account at all. The third is where it gets interesting.

## Thousands of hosts to the right one

A hand-kept ssh config goes stale, and an autoscaling group replaces the hostname
you saved. Either way the lookup is the work, and you do it again every time.

**Without Hangar.** Remember roughly what the box is called. Run
`aws ec2 describe-instances --filters …` and read JSON to find it. Copy a
58-character `ip-10-0-42-17.us-west-2.compute.internal`. `ssh ec2-user@…` and
hope the login is right. Tomorrow the instance is replaced and the hostname you
saved is gone.

**With Hangar.** Press <kbd>⌘</kbd><kbd>⇧</kbd><kbd>H</kbd>. Type
`payments prod web`; terms match in any order. Press <kbd>Return</kbd>; the first
match is already selected. You are on the box, in iTerm2 or Terminal, with the
right login. Tomorrow the alias still works, because it follows the tags rather
than the hostname.

Search stays under half a millisecond per keystroke at ten thousand hosts.

## Built for the way you already work

Standard SSH underneath. Nothing to learn, nothing to migrate.

- **Fuzzy fleet search.** Terms match in any order across alias, hostname and
  tags. Type the three things you remember.
- **Stable SSH aliases.** Hangar owns one `ssh_config` include and rewrites it on
  every sync, so terminated instances drop out on their own. `ssh
  payments-prod-web-1` works from any terminal, and from `scp`, `rsync`, Ansible
  and VS Code Remote.
- **Native terminal launch.** <kbd>Return</kbd> opens a real session in iTerm2,
  Terminal or Ghostty, whichever you pick. <kbd>⌘</kbd><kbd>Return</kbd> copies
  the command instead.
- **A command for the rest of your tools.** `hangar ssh web prod` connects to
  the one host that matches, and `hangar -s "web prod"` prints the same ranked
  hosts the panel shows, for tmux, fzf, herder or a shell function.
  No AWS call: it reads the cache the app already refreshed.
- **Works with your tags, not ours.** `product`/`env`, `Service`/`Environment`,
  `app`/`stage`, or a single `Name` tag all work with no configuration. The setup
  screen shows the tag keys your fleet actually uses and lets you point each one
  at the right key.
- **Four sources, merged.** EC2, Systems Manager, the hosts already in your
  `~/.ssh/config`, and any CSV you drop on the window. No AWS permission at all is
  required to use Hangar, and a denied `DescribeInstances` falls back on its own
  instead of showing you an error page.
- **Your ssh config is read, never rewritten.** Imported hosts are searchable and
  launchable and Hangar writes nothing for them, so it can never outrank a file
  you wrote by hand.
- **1Password and any other ssh agent, with no setup.** If an agent is holding
  your key, Hangar finds it and uses it. One key is adopted without asking; several
  are listed by their vault item title. No `op` CLI, and no private key is ever
  read, exported or stored.
- **Credentials stay local.** The same resolution order the AWS CLI uses, read
  from your home directory. Expired SSO tokens refresh in place.
- **Fix a wrong login in place.** <kbd>⌘</kbd>-click a host to set its ssh user
  or key, with a **Detect Login** button that probes the usual cloud-image logins
  and keeps the one that authenticates.
- **The whole fleet in the menu bar.** A `HOSTS` section groups the fleet by your
  own tags, as many levels deep as you configure, down to the instances
  themselves. A host that is not running says so rather than relying on its icon.
- **Fleet health at a glance.** The menubar aircraft is green while the cache is
  fresh and breathes green while a refresh is in flight. It turns amber once the
  cache passes `stale_after_minutes`, and red once it passes
  `healthy_within_hours` or a refresh fails. The tooltip says the age in words,
  so the colour is not carrying it alone.
- **A dashboard over the same one call.** Drill the fleet product by
  environment by host, open any host for everything `DescribeInstances` returned
  about it, and read the tag, placement, age and exposure findings behind it.
  No second API call and no second permission.

<div align="center">

<img src="site/assets/shot-menu.png" alt="Hangar's menubar menu: a HOSTS heading over product groups, an environment submenu, and the instances under it" width="380">

</div>

## Install

**Download the DMG**, drag Hangar to Applications, and open it. On first launch a
setup check reads your machine and says what works; after that Hangar lives in
your menu bar. That is the whole install. The app is signed with a Developer ID certificate and notarized by Apple,
so Gatekeeper opens it without complaint on any Mac running macOS 14 or newer.

Hangar puts a glyph in your menubar and nothing in your Dock, except while one
of its windows is open: the Dock icon and the app switcher entry come and go with
the window, so you can command-tab back to it. On first launch it
runs a **setup check** that reads your machine and tells you exactly what works and
what does not, with a fix button beside anything actionable:

```
✓ 3 AWS profiles found          Using default by default: SSO · us-west-2
✓ Credentials resolved          SSO profile default
✓ 249 hosts indexed             6 products, 5 environments
✓ SSH aliases active            223 aliases, Include line in ~/.ssh/config
✓ iTerm2 found                  Sessions open in iTerm2. Also installed: Terminal
✓ Shortcut ready                Press ⌘⇧H from any app
```

Nothing to configure before it works. If a check fails it says why and what to run.
You can reopen it any time from **Settings… → Setup Check**.

**Write SSH config aliases** covers the whole job. Hangar writes
`~/.ssh/config.d/hangar` and adds the one-line `Include` to your `~/.ssh/config`
that makes those aliases work in `ssh`, `scp`, `rsync`, Ansible and anything else
that reads ssh_config. It goes in at the top, because ssh_config is
first-match-wins per keyword and a `Host *` block above it would beat every entry
Hangar generates, and your file is copied to `~/.ssh/config.hangar-backup` first.
Set `"manage_ssh_include": false` in `~/.hangar/config.json` if you would rather
place that line yourself; Hangar will then stop putting it back, and the setup
screen offers a button instead.

Two options are offered there rather than assumed: **Write SSH config aliases** and
**Open Hangar at login**. The login item is registered with `SMAppService`, so it
appears in System Settings under General, Login Items, where you can revoke it
independently of Hangar.

Closing the setup window leaves Hangar running in the menu bar; it says so rather
than just vanishing. <kbd>⌘</kbd><kbd>Q</kbd> closes a Hangar window the same way
the panel has always closed, because the reflex that shuts a window should not
take the app out of your menu bar. **Quit Hangar** in the menubar item is the one
thing that ends it. If your menu bar has an overflow manager such as Ice or
Bartender, you may need to unhide the icon there once.

**Help** in the menubar lists every shortcut and the intended flow, so the app
explains itself without this README.

### Starting over

**Settings → Clear Fleet Cache** forgets the cached fleet and refetches, keeping
your settings, tag mapping and menu levels. **Settings → Reset Hangar** also
forgets the config, the onboarding marker and the ssh aliases Hangar generated,
so it starts as it does on a fresh install. Neither touches your own
`~/.ssh/config`, your `known_hosts`, or anything under `~/.aws`.

**Settings → Uninstall Hangar** goes further still: it removes `~/.hangar`
entirely, removes the generated aliases, takes the `Include` line back out of your
`~/.ssh/config` (keeping a `.hangar-backup` copy of it), stops Hangar opening at
login, then quits and moves the app to the Trash. Your AWS credentials and the
rest of your `~/.ssh/config` are untouched, and the app is in the Trash rather
than deleted, so Put Back undoes it.

Every installed copy goes, not just the one you opened: copies under
`/Applications` and `~/Applications`, plus whichever one you uninstalled from.
The confirmation lists the bundles it found, so you approve the removal with the
paths in front of you. Anything else it turns up, a build in a source tree, a
copy on a mounted DMG it cannot move, is named as left alone rather than skipped
in silence. Other running instances are quit first: one of them would otherwise
write `~/.hangar` straight back.

<div align="center">

<img src="site/assets/shot-settings.png" alt="Hangar's Settings submenu in sections: Account, Startup, Updates, Configuration, Start Over, and Uninstall" width="560">

</div>

Deleting the app and installing the DMG again also starts fresh: Hangar notices a
newly installed bundle at a version that did not increase, drops the cache and
runs the setup check. Your settings survive that, on the grounds that reinstalling
to replace a damaged binary should not cost you your tag mapping.

### Fleet dashboard

**Fleet Dashboard** in the menubar, or <kbd>⌘</kbd><kbd>D</kbd> with the menu
open. Every number and every circle on it comes out of the `DescribeInstances`
response Hangar already fetched, so the whole window costs no extra AWS call and
no extra IAM permission.

<div align="center">

<img src="site/assets/shot-dashboard.png" alt="The Fleet tab of Hangar's dashboard: an EC2 hub in the middle reading 110 hosts, seven product circles around it carrying their host counts, host particles arcing around each one, and four stat cards down the left for total hosts, running, stopped and groups" width="820">

</div>

Two tabs. **Fleet** is the picture, **Insights** is the same fleet in words.
Down the left of both are four cards, total hosts, running, stopped and groups,
and they always describe whatever the picture is currently showing rather than
the whole account.

#### Drilling the cluster

The picture goes down the same levels the menubar cascade uses, which are the
tag keys in `group_by`. One click goes in. The hub in the middle goes back out
and is labelled with where back is; on the Insights tab, where the hub is not on
screen, the same step out sits at the top of the column as a button.

Below the fleet the hub carries a ring, and the pointer turns to a hand over it
and over every circle, so the way back out is visible before it is read.

It works without a mouse. <kbd>←</kbd> <kbd>→</kbd> move around the ring,
<kbd>Return</kbd> opens what is selected, and <kbd>esc</kbd> steps back out.

1. **Products.** A circle per product around the EC2 hub, area tracking the host
   count, so a group twice the size looks twice the size.
2. **Environments.** Production sits nearest the hub and each tier steps outward,
   so the ring reads inside out: production, staging, test, development, then
   anything Hangar cannot place.
3. **Hosts.** One circle per instance, **sized by its instance type** with the
   short size written inside it, `8xl`, `2xl`, `lg`. Colour is state, and a host
   that is not running says so in its label rather than relying on the colour.

Product and environment circles are coloured from a band of the wheel running
teal to magenta. Red, amber and green are reserved for instance state, so a
product is never drawn in the colour that means terminated.

<div align="center">

<img src="site/assets/shot-envs.png" alt="The dashboard drilled into the payments product: five environment circles around the hub, prod nearest with 24 hosts, then stage, qa, dev and perf stepping outward, with the hub reading Back to the fleet" width="820">

<sub>Click a product for its environments. The hub is the way back, and says
where back is.</sub>

<img src="site/assets/shot-hosts.png" alt="The dashboard drilled into payments prod: 24 host circles around the hub, each sized by its instance type with 8xl, 4xl, 2xl, xl, lg or md written inside, two of them grey and labelled api-1 stopped and api-6 stopped" width="820">

<sub>Then the hosts inside one. The circles are sized by the machine, not by the
count.</sub>

</div>

#### The host record

Open a host and the window follows you to the Insights tab, which becomes
everything `DescribeInstances` said about that one instance: state, launch time, instance type with its vCPUs and
architecture, instance id, availability zone, VPC, subnet, private and public
addresses, private DNS, hostname tag, AMI, key pair, IAM instance profile,
security groups, spot or scheduled lifecycle, monitoring, root device, its
autoscaling group or that it does not have one, the ssh alias Hangar generated
for it, and every tag it carries.

<div align="center">

<img src="site/assets/shot-host.png" alt="The host record for payments-prod-web-2: state, launch time, instance type, id, zone, VPC, subnet, addresses, AMI, key pair, IAM profile, security groups, monitoring, root device, autoscaling group and ssh alias, with all seven tags listed below, under a Back to payments prod button" width="820">

</div>

#### Insights

The four panels, computed in `HangarCore` and tested there:

- **Tag hygiene.** Hosts missing the tags your mapping points at, hosts with no
  hostname tag, and aliases two instances would share. Every row names the hosts
  it counted, a few inline and all of them in its tooltip: two hosts you cannot
  identify is a number, not a finding.
- **Placement and autoscaling.** Which zones each product and environment
  occupies, single-zone groups called out, and how many hosts sit outside an
  autoscaling group.
- **Age and instance families.** Uptime buckets from launch time, and the type
  mix with AWS's previous-generation families and burstables flagged.
- **Change and exposure.** The host count against the last refresh, from a short
  history kept beside the cache, and how many hosts hold a public address.

<div align="center">

<img src="site/assets/shot-insights.png" alt="The Insights tab: tag hygiene reporting five hosts with no hostname tag, placement reporting eight single-zone groups and 34 hosts outside an autoscaling group, uptime buckets with the burstable and previous-generation families called out, and a change and exposure panel" width="820">

</div>

Nothing here is advice. Hangar does not know why a `t3.micro` is in production,
so it reports the count and stops.

### Logs

Hangar writes `~/.hangar/logs/hangar.log`, `0600`, rotating at half a megabyte
with one previous generation kept. It records launches, refreshes with host
counts and timings, which credential source resolved, alias writes, updates and
uninstalls, plus every error. **Settings → Reveal Log in Finder** opens it.

Instance ids and hostnames are replaced with short digests such as `host#4f2a`,
so the file can be attached to an issue without scrubbing it first, and two lines
about the same host can still be tied together. Credentials never reach it. The
same lines also go to the unified log, under the subsystem `com.goriparthi.hangar`,
where Console.app can filter them.

### Updates

**Check for Updates…** is its own item in the menubar menu: Check Now, the
installed version and what is available, a **Check Daily** toggle and the
channel. When a release is waiting, **Install Hangar <version>** appears there
and in the menu itself. Hangar reads the GitHub releases API only when you ask,
or once at launch if you set `check_updates_on_launch`.

Two channels: `stable` sees full releases, `beta` also sees prereleases. An update is installed only if Apple
notarized it *and* it is signed by this project's Developer ID team, verified as a
cryptographic codesign requirement rather than by parsing text.

<details>
<summary>Building from source instead</summary>

```sh
git clone git@github.com:goriparthi/hangar.git
cd hangar
make run
```

`swift build` needs only **Command Line Tools**. Two steps need Xcode: `actool`,
which compiles the asset catalog, and XCTest; `make` finds Xcode.app for both and
says so if it is missing. There are **no Swift package dependencies**, no AWS SDK,
and no runtime dependency on the `aws` CLI.

| Target | What it does |
|---|---|
| `make run` | build, install to `~/Applications`, launch |
| `make test` | the offline test suite, no network needed |
| `make verify-assets` | proves every brand asset resolves in the built bundle |
| `make bundle` | assemble and sign `dist/Hangar.app` |
| `make dmg` | signed, notarized DMG. See [RELEASING.md](RELEASING.md) |

</details>

## First run

Hangar creates `~/.hangar/config.json` and indexes your fleet on launch. The setup
check offers the one optional step: adding this as the **first** line of
`~/.ssh/config`, which is what makes the aliases work outside Hangar.

```
Include ~/.ssh/config.d/hangar
```

The **Add Include Line** button does it and keeps a backup. It must sit above any
`Host *` block: ssh_config is first-match-wins per keyword, so a catch-all above it
would beat every generated entry. Hangar connects fine without it; only the
`ssh payments-prod-web-1` shorthand needs it.

## Discovery

### Four ways to find a host

Hangar gathers from four sources and merges them, richest first. They are all on
by default, because a source that finds nothing costs nothing.

| Source | What it needs | Notes |
|---|---|---|
| **EC2** | `ec2:DescribeInstances` | Tags, state, zone, instance type; everything the dashboard reads |
| **Systems Manager** | `ssm:DescribeInstanceInformation` | Tried automatically when EC2 is denied. Finds on-prem `mi-` instances EC2 never could |
| **`~/.ssh/config`** | nothing at all | The hosts you already have. Indexed for search and launch, **never rewritten** |
| **`~/.hangar/hosts.csv`** | a CSV you drop on the window | Any spreadsheet, inventory export or script output |

**No AWS permission is required to use Hangar.** If `DescribeInstances` is denied,
Hangar falls back to Systems Manager on its own, and your own `~/.ssh/config` and
a CSV work with no AWS account at all. The setup screen shows what each source
found rather than presenting one failure as the end of the road.

When two sources describe the same machine, the richest copy wins: EC2, then
Systems Manager, then the CSV, then your ssh config. Duplicates are matched on
instance id, hostname and alias.

#### Your own ssh config is read, never rewritten

Hosts imported from `~/.ssh/config` are searchable, groupable and launchable, and
Hangar writes **nothing** for them. Those hosts already resolve; a second
definition in Hangar's include would sit *above* yours, and `ssh_config` is
first-match-wins, so Hangar would silently outrank a file you wrote by hand. The
port, the `ProxyJump` and the login in your file are the ones that get used.

`Host *`, `Host prod-*` and `Match` blocks are skipped and reported, because a
pattern is not a host. `Include` is followed the way ssh follows it.

**Git remotes are skipped too.** Nearly every developer's ssh config has entries
for GitHub, GitLab, Bitbucket or CodeCommit, and none of them is a machine:
`ssh git@github.com` prints a greeting and exits. Hangar recognises them by
`User git`, which is how every self-hosted forge is reached as well, and by the
known forge hostnames for entries that leave `User` to the remote URL. A host
merely *named* for git, logged into as a person, is still a host. Everything
skipped is listed on the setup screen rather than silently dropped.

#### A CSV of hostnames

Drop one anywhere on the Hangar window, or use **Import Hosts CSV** on the setup
screen. Importing copies it to `~/.hangar/hosts.csv`; there is no other state, so
a script, a cron job or an inventory export can write that file directly.

```
alias,hostname,user,port,product,env,role,datacenter
legacy-dc-app-1,192.168.10.5,root,22,legacy,prod,app,ams3
```

`alias` or `hostname` is enough. Any column Hangar has no meaning for becomes a
tag, so you can group the menu by `datacenter` or `owner`. A row that cannot be
written safely is refused **with its line number** rather than dropped.

### The only permission Hangar asks for

**`ec2:DescribeInstances`, and nothing else.** One read-only call per refresh,
against the region in your profile. Hangar does not create, modify, tag,
terminate or stop anything, and it asks for nothing beyond that one action. The
menubar list, the ssh aliases, the fleet dashboard and every number on it are all
read out of that single response.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": "ec2:DescribeInstances", "Resource": "*" }
  ]
}
```

`Resource: "*"` is not a choice Hangar makes: `ec2:DescribeInstances` does not
support resource-level permissions, so AWS accepts no narrower resource for it.
Narrow it with a condition key if your account uses them.

If the profile you point Hangar at assumes a role, the `sts:AssumeRole` for that
is your own configuration, and an SSO profile exchanges its cached token the way
the AWS CLI does. Neither is an extra permission on the fleet.

The Systems Manager fallback asks for one more read-only action, and only after
EC2 has already refused:

```json
{ "Effect": "Allow", "Action": "ssm:DescribeInstanceInformation", "Resource": "*" }
```

Discovery only. Hangar does not start a Session Manager session, which would
need the `aws` CLI and its session-manager plugin at runtime.

Hangar calls `ec2:DescribeInstances` once and caches the result locally. Hosts are
grouped and named from four ideas:

| Idea | Used for | Tag keys tried by default |
|---|---|---|
| product | top-level grouping | `product`, `Service`, `app`, `project`, `system` |
| env | environment grouping and the production treatment | `env`, `Environment`, `stage`, `tier` |
| env_name | disambiguating parallel environments | `env_name`, `cluster`, `instance_name` |
| role | the host's role, used in the alias | `Name`, `role`, `Component`, `function` |
| hostname | what ssh connects to | `hostname`, `FQDN`, `dns`; private IP if unset |

Each is a list of candidate keys, tried in order and matched case-insensitively,
so the conventions in common use work untouched. **If your fleet uses something
else, the setup screen lists the tag keys it actually found, with how many hosts
carry each and a couple of real values, and you point each one at the right
key.** That takes effect immediately, without a refresh. It can also be set by
hand under `"tags"` in `~/.hangar/config.json`.

### Menu levels

The menubar cascade is an ordered list of tag keys, and you compose it. One level
is a perfectly good answer, and so is none:

```json
"group_by": ["Team", "Environment"]
```

Any tag key works, not only the ones above. A level no host carries adds no
submenu, and the fleet dashboard skips it too, so nothing produces an "untagged"
level containing everything. Add, remove and reorder from the setup screen, or
edit `group_by` directly. The default is `["product", "env", "env_name"]`.

The setup screen says what each level actually does where it sits, because a tag
key is not good or bad on its own. `env_name` reads fine across a fleet and is
still a poor third level on that same fleet if most of its product and
environment groups have nobody carrying one:

```
1.  product    5 groups, every host tagged
2.  env        20 groups, every host tagged
3.  env_name   25 groups  ·  141 of 223 hosts have no value here
```

The same line appears against each key in **Add a level**, computed for the
position it would take, so the question is answered before you commit to it.

**A tag that makes a poor level can still make a good name.** Drop it from
`group_by` and it stays in the alias, because only the levels you grouped by are
trimmed off the label. A fleet grouped by product and environment shows
`archive` and `repl-archive` side by side rather than putting one replica behind
its own submenu.

Each host gets three ssh names: a readable alias, a stable instance-id alias, and
its real hostname.

```
Host payments-prod-web-1 payments-prod-web-i-0a1b2c3d web.prod.payments.internal.example.com
  HostName web.prod.payments.internal.example.com
  User deploy-user
  UserKnownHostsFile ~/.ssh/known_hosts.ec2
  StrictHostKeyChecking accept-new
```

Ordinals appear only where aliases collide, oldest instance first. The id-based
alias is built from the unnumbered stem, so it survives an autoscaling group
reshuffling the ordinals.

The generated file is rewritten wholesale on every sync, so terminated instances
drop out on their own and there is no merge logic to get wrong in a file that can
lock you out of every host you have.

## Credentials

Resolved the way the AWS CLI resolves them, reading only files already in your
home directory:

1. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` from the environment
2. static keys in `~/.aws/credentials`
3. SSO, via `~/.aws/config` and the token cache in `~/.aws/sso/cache`
4. `role_arn` with `source_profile`, assumed through STS
5. `credential_process`

Which profile, when you have several: **Setup Check → Which AWS profile**, or
**Settings… → AWS Profile** in the menubar. Both list every profile in your
`~/.aws` files with how each one authenticates, so the one with no credentials in
it is not an equal-looking choice. Automatic follows `AWS_PROFILE`, then
`default`, the same as the `aws` CLI. Only the EC2 and Systems Manager sources
use it.

Expired SSO tokens are refreshed in place using the cached refresh token, so you
are not sent back to `aws sso login` until the refresh token itself lapses.

The `aws` CLI is not required to run Hangar: the signing, the `DescribeInstances`
call and the SSO refresh are all implemented here, and nothing shells out to it.
It is needed for the first `aws sso login` on a machine, because that is a browser
sign-in Hangar does not perform, and for whatever your own `credential_process`
happens to invoke.

## Security

- **Nothing is uploaded.** There is no Hangar server, account, or telemetry.
- **No private keys are read.** Hangar reads `~/.aws/config`,
  `~/.aws/credentials`, the SSO token cache, EC2 instance tags, `~/.ssh/config`
  and `~/.hangar/hosts.csv`. Key material stays with `ssh` and your agent. When an
  agent is used, only the *public* half of the chosen key is written, under
  `~/.hangar/keys`, and it is asked for over the agent socket rather than read
  from a vault.
- **One AWS call to list the fleet**, `ec2:DescribeInstances`, signed with SigV4.
  Depending on the profile it is preceded by an STS `AssumeRole` or an SSO token
  exchange, and nothing else. A denied call adds one more read-only call,
  `ssm:DescribeInstanceInformation`, and nothing else.
- **Read-only against AWS.** Hangar never mutates infrastructure.
- **It owns one file**, `~/.ssh/config.d/hangar`, written atomically at `0600`
  after `ssh` itself validates the syntax. Your own `~/.ssh/config` is touched
  only by the explicit menu action, which keeps a backup.
- **Tags are untrusted input.** Anyone who can tag the account can influence what
  Hangar writes, so values are quoted on the way into `ssh_config` and
  shell-quoted on the way into a terminal. A value carrying a line break is
  dropped and the host reported as skipped.
- **So is an imported host.** A hand-edited `~/.ssh/config` and a CSV from
  anywhere are held to exactly the same rules as an EC2 tag. A name that could act
  as a pattern is refused, and a CSV row that cannot be written safely is reported
  with its line number rather than dropped.
- **Every external process has a deadline.** A credential helper, an ssh agent
  behind a locked vault, `ssh` itself: each gets a timeout, a terminate and a
  kill, so nothing the user's own machine does can hang the app.
- **`credential_process` runs through `/bin/sh`** when a profile configures one,
  exactly as the AWS CLI does. That command is yours, from your `~/.aws/config`.

Full detail, and how to report a hole, in [SECURITY.md](SECURITY.md).

## Configuration

`~/.hangar/config.json`:

```json
{
  "profile": null,
  "region": null,
  "terminal": "iterm",
  "ssh": {
    "user": "your-login",
    "identity_file": null,
    "identity_agent": null,
    "identities_only": null,
    "known_hosts_file": "~/.ssh/known_hosts.ec2",
    "strict_host_key_checking": "accept-new"
  },
  "sources": {
    "ec2": true,
    "ssm": null,
    "ssh_config": true,
    "hosts_file": true
  },
  "overrides": [
    { "match": { "product": "payments", "env": "prod" },
      "user": "rocky", "identity_file": "~/payments_prod.pem" }
  ],
  "hotkeys": [
    { "keys": "cmd+shift+h", "title": "All hosts", "filter": {} },
    { "keys": "cmd+shift+p", "title": "Prod", "filter": { "env": "prod" } }
  ],
  "refresh_minutes": 30,
  "stale_after_minutes": 60,
  "healthy_within_hours": 24,
  "sync_ssh_config_on_refresh": true,
  "update_channel": "stable",
  "check_updates_on_launch": false,
  "launch_at_login": false
}
```

`identity_file: null` means Hangar says nothing about keys and lets `ssh` and your
agent behave as they already do. That is the default, and it is why an agent you
have already set up globally keeps working untouched.

`identities_only` is the escape hatch: `null` adds `IdentitiesOnly yes` whenever a
key is pinned, which is the old behaviour, and `false` pins a key while still
letting your agent offer its own.

`sources.ssm: null` means "only when EC2 is denied". Set it to `true` to always
ask, or `false` to never.

### Which terminal

`terminal` is `iterm`, `terminal` or `ghostty`, and the picker for it is **Setup
Check → Open sessions in**, or **Settings… → Terminal** in the menubar. A
terminal that is not on this Mac is listed and disabled rather than hidden.

iTerm2 and Terminal are scripted, so macOS asks once for permission to control
them, and the command is written into a live session: a failing `ssh` leaves its
error on screen instead of closing the window. Ghostty is not scriptable, so it
takes the command in its argument vector and needs no permission at all; the
session hands over to your login shell afterwards for the same reason.

If the terminal you picked has been uninstalled, Hangar opens Terminal rather
than nothing, and the setup check says so.

### The ssh login

Hangar ships **no** login. Saying nothing lets `ssh` do what it already does, and
it means Hangar cannot outrank a `Host * / User ec2-user` you wrote yourself,
which matters because Hangar's `Include` sits at the top of `~/.ssh/config` and
`ssh_config` is first-value-wins.

Once, on the first launch with a fleet, it works out the login by asking **one**
host and records the answer in `~/.hangar/config.json`. The bounds are the point:

- one running host, never the fleet, never a Windows host, never a host imported
  from your own config
- at most six logins tried, not the full candidate list, because a dozen failed
  authentications against one host is what trips `fail2ban`
- the platform first. `DescribeInstances` already told Hangar whether the image is
  Ubuntu, Red Hat, SUSE or Debian, which usually turns six attempts into one
- once per machine, behind `~/.hangar/.login-probed`, written before the attempt
  so a probe that dies does not come back

Set `ssh.user` yourself and no probe ever runs. <kbd>⌘</kbd>-click a host to
change it for one host or a whole group.

### 1Password, and any other ssh agent

If 1Password's ssh agent is running, Hangar finds it and uses it. There is
nothing to configure and no `op` CLI to install.

Hangar asks the agent what it holds the same way ssh does, over the agent socket.
If it holds exactly one key, that key is used and you are never asked. If it holds
several, the setup screen lists them by their vault item title and you click one.
What gets written is:

```
Host payments-prod-web-1
  HostName 10.20.30.10
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  IdentityFile ~/.hangar/keys/prod-sre-a1b2c3d4.pub
  IdentitiesOnly yes
```

**Hangar never reads, exports or stores a private key.** The file it writes under
`~/.hangar/keys` is the *public* half, and it is there for a practical reason:
with `IdentitiesOnly`, naming the public key is how ssh is told which of the
agent's keys to offer. A vault holding a dozen keys otherwise runs past
`MaxAuthTries` and fails on a host that would have worked.

Secretive, a forwarded agent, and anything else on `SSH_AUTH_SOCK` work through
exactly the same path; 1Password is not a special case.

Each hotkey gets its own registration and its own filter, so
<kbd>⌘</kbd><kbd>⇧</kbd><kbd>P</kbd> can open straight into production. Hotkeys
use `RegisterEventHotKey`, which needs **no Accessibility permission**.

### Fixing a host whose login is wrong

<kbd>⌘</kbd>-click a host in the panel or the menubar, or press <kbd>⌘</kbd><kbd>E</kbd>.

**Detect Login** probes the usual cloud-image logins in parallel and keeps the
first that authenticates. **Test** checks whatever is in the fields.
**Applies to** decides the blast radius: this host only, every host of that role
in that environment, or the whole product.

Edits are saved as overrides in `~/.hangar/config.json` and the ssh include is
regenerated. They are never written straight into `~/.ssh/config.d/hangar`,
because that file is regenerated on every refresh and a direct edit would not
survive it.

## Keyboard

| Key | Action |
|---|---|
| <kbd>⌘</kbd><kbd>⇧</kbd><kbd>H</kbd> | open the panel from anywhere |
| <kbd>Return</kbd> | connect in your terminal |
| <kbd>⌘</kbd><kbd>Return</kbd> | copy the ssh command |
| <kbd>⌘</kbd><kbd>E</kbd> | edit this host's ssh user or key |
| <kbd>⌘</kbd><kbd>R</kbd> | refresh the fleet |
| <kbd>↑</kbd> <kbd>↓</kbd> | move selection |
| <kbd>⌘</kbd>-click | edit a host's ssh user or key |
| <kbd>⌘</kbd><kbd>D</kbd> | open the fleet dashboard |
| <kbd>←</kbd> <kbd>→</kbd> | in the dashboard, move around the ring |
| <kbd>Return</kbd> | in the dashboard, open the selected circle |
| <kbd>esc</kbd> | in the dashboard, step back out a level |
| <kbd>esc</kbd> / <kbd>⌘</kbd><kbd>Q</kbd> | close the panel or window, leaving Hangar running |

## Command line

The same fleet, for tmux, fzf, herder, or anything else that can run a program.

`hangar` ships inside the app at `Contents/Helpers/hangar` and **installs itself**
when it can: on launch, if nothing is called `hangar` already, Hangar links it
into the first directory you own that is on your PATH, preferring
`~/.local/bin`, then the Homebrew prefix, then `~/bin`. Setup Check reports where
it went, and offers the install if it has not happened. `/usr/local/bin` is last
on that list on purpose: it belongs to root on a stock Mac, so reaching for it
first turns a one-second install into a sudo prompt.

An app opened from Finder is not given your shell's PATH, and Hangar does not run
your shell to ask for it. "On your PATH" means what it can see without doing
that: its own PATH, plus `/etc/paths` and `/etc/paths.d`, which every login shell
starts from. On a stock Mac that is `/usr/local/bin`, so a first run usually hands
you the line to run rather than installing. Finding an install is not limited
that way: Setup Check looks in all four directories, so a link made by that line,
by hand, or from a copy launched in a terminal is found however Hangar was opened.

A `hangar` that Hangar did not write is never overwritten. It is far more likely
to be something you put there deliberately, so it is reported and left alone.
When nothing on your PATH can be written, Setup Check hands you the one line to
run yourself.

```
hangar                     every host, in the order the menu lists them
hangar <query>             hosts matching a fuzzy query, best match first
hangar -s <query>          the same, spelled out

-a, --alias                aliases alone, one per line
    --tsv                  alias, hostname, product, env, state, id
    --json                 one JSON array
-n, --limit <n>            at most n hosts
-f, --filter <key=value>   only hosts whose tag matches; repeat to narrow
    --cache <path>         read this cache instead of ~/.hangar/cache
    --config <path>        read this config instead of ~/.hangar/config.json;
                           a path that cannot be read is fatal, like --cache
```

```sh
ssh "$(hangar -a -s 'web prod' | head -1)"
hangar | fzf | awk '{print $1}' | xargs ssh
tmux new-window "ssh $(hangar -a db-prod | head -1)"
hangar --json -f env=prod | jq -r '.[].hostname'
```

### Connecting

```sh
hangar ssh web prod          connect to the one host that matches
hangar ssh -1 db-prod        take the best match without asking
hangar ssh web --dry-run     print the command, run nothing
```

One match connects. Several, and it asks: the matches are numbered on stderr and
you type one, or press Return to cancel. Several with nobody to ask, because
stdin has no terminal or stderr is not one either, exits **3** and lists them
rather than picking one for you. That is the case a script or an agent hits, and
having a host chosen for it is exactly what `| head -1` was quietly doing. Both
halves have to be there: the question goes to stderr, so
`hangar ssh web 2>/dev/null` would otherwise block on a prompt you could not see.

`hangar ssh` needs a query or a filter. Without either every host matches, and
`--first` would open a session on whatever sorts first.

`hangar ssh` replaces itself with `ssh`, so the session owns the terminal, your
signals reach it, and its exit status is the command's.

### Running something on every host that matched

```sh
hangar -f env=prod web --exec herdr pane new --cmd 'ssh {alias}'
hangar -f env=prod --parallel 8 -y --exec ssh {alias} uptime
```

`--exec` takes the rest of the line and runs it once per matched host. These are
replaced **per argument**, so a value never has to survive a round trip through
a shell:

```
{alias} {hostname} {id} {private_ip} {public_ip} {product} {env} {env_name}
{role} {state} {type} {zone} {asg}
```

**Prefer `{alias}`.** It is the only one that cannot look like a flag: aliases
are slugged, and every other source is held to `isSafeAlias`, which refuses a
leading hyphen. The rest are tag values, and an argument vector stops a value
becoming a second *command* but not a second *option*. A `hostname` tag of
`-oProxyCommand=...` under `--exec ssh {hostname}` would reach ssh as an option,
and `ProxyCommand` is something ssh executes.

Hangar refuses that host rather than running it, names it on stderr, and carries
on with the rest, so one badly tagged instance does not stop the other twenty.
That catches a value that becomes a flag and nothing more: a value landing in an
option's own argument, as in `--exec ssh -o {hostname}`, is still the program's
business, and no tool can know an arbitrary program's option grammar.
Put `--` before the placeholder if you want it passed anyway:

```sh
hangar -f env=prod --exec ssh -- '{hostname}' uptime
```

An unknown `{name}` is left exactly as written. Silently dropping part of your
command would be worse than failing.

Nothing here goes through a shell. `$(hangar -a …)` in a shell loop re-parses
whatever your tags contain, and tags are written by anyone who can tag the
account: a `Name` of `web; rm -rf /` is a real shape. Under `--exec` that value
arrives at the program as one argument and stays one argument.

Hangar deliberately does not learn about multiplexers. It already drives three
terminals; herdr, tmux, kitty and WezTerm would make that a matrix. One vector
per host composes with all of them.

**Fanning out asks first.** More than one host and it shows you the command and
the hosts and waits for a `y`. With no terminal to ask, `-y` is required and its
absence is an error rather than a fan-out, which is the case a script or an agent
hits. `--parallel` bounds how many run at once, `--timeout` bounds each one, and
`--dry-run` prints every vector and runs none of them.

At one at a time the command inherits your terminal, so interactive things work.
Above one, each host's output is collected and printed under its alias, because
eight hosts interleaved is not output.

**Ctrl-C does not stop what is running.** It returns your prompt, and the command
keeps going against the host: Foundation starts each child in its own process
group, so a signal the terminal generates for the foreground group never reaches
it.

`--timeout` does not rescue you here either. The deadline is enforced by
`hangar` itself, so it dies with `hangar` and an orphan runs unbounded. It bounds
a run you leave alone, not one you interrupt. After interrupting an `--exec`,
check `ps` and stop the children yourself. Making Ctrl-C stop them is its own
change.

### Reading it, versus piping it

The listing has two readers, and it tells them apart with one `isatty` call.

Piped into anything, the default listing is byte for byte what it has always
been: alias, group, hostname, in padded columns. So are `-a` and `--tsv`. Every
pipeline reading those keeps working, including the ones nobody mentioned.

`--json` is the exception, and deliberately: it gained fields at #3, and it now
prints `[]` rather than nothing when no host matched and when there is no cache
yet. Those are the point of that change, but a script reading the old shape
should know it moved.

The `state` column moved once more at 0.8.0. A host whose source has no notion
of state, which is every host from `~/.ssh/config` and any CSV row without a
`state` column, now reports an empty string where 0.7.0 printed `unknown`. The
column and the JSON key are always there; only the vocabulary changed, and it
changed because `unknown` was never true. `-f state=running` and
`-f state!=running` are unaffected. `-f state=unknown` no longer matches those
hosts, and `hangar values state` will no longer offer it.

Read by a person, the fleet is grouped under headings built from the same levels
the menu uses, `group_by` included, hosts are indented under them, and a host
known not to be running is dimmed **and** says its state in words. A host whose
source never reported one is neither, because there is nothing to report. A fleet that none
of those levels group gets no headings at all rather than one "untagged" over
everything. A search is not grouped: it is ranked by relevance, and a heading
over a ranked list would either lie about the order or throw the ranking away.

`NO_COLOR` and `HANGAR_NO_COLOR` turn the sequences off when set to a non-empty
value, per [no-color.org](https://no-color.org), so `NO_COLOR= hangar` undoes it
for one command. `TERM=dumb` does the same. The layout stays either way.

### Finding out what to filter on

`-f` is no use if you do not already know the keys and the values. Hangar knows
both, because the fleet it cached says so.

```sh
hangar tags                  the keys, how many hosts carry each, and examples
hangar values env            the values one key takes, most used first
hangar values env -a         the values alone, one per line
```

```
$ hangar tags
env             243        4  prod, qa, stage
product         243       12  checkout, payments, search
team            201        9  growth, payments, platform
cost-centre      88       14  4021, 4022, 4100
```

`hangar values` reads the fleet the way `-f` does, so its values are what a
filter will match, including for names Hangar resolves rather than tags in their
own right: `hangar values state` works.

`hangar tags` lists the fleet's own key names, which is not the same question.
Nine of those names are resolved by `-f` rather than looked up, so a fleet with
its own `Role` tag alongside a `Name` tag sees `Role` here and gets the `Name`
value back from `-f role=`.

Being one of those nine is not enough to be a problem: on a fleet that spells
them the canonical way, `env` resolves from `env` and `-f env=prod` reads the tag
it looks like it reads. Hangar checks your fleet rather than the list, and names a key only where some
host answers differently from the tag it carries. That is not always a key you
cannot select on: a fleet spelling one idea two ways, `env` on some hosts and
`Environment` on others, has `env` named here and both values still filter. What
the line tells you is that the key was resolved rather than read, which is when
it is worth checking:

```
-f resolves these names rather than reading the tag: Role
```

`--json` and `--tsv` carry the same fact per row, as `resolved_by_filter`.

`-a` prints values verbatim, and EC2 permits a space in a tag value, so
`for v in $(hangar values env -a)` splits `staging west` into two. Read it a line
at a time, or take the field from `--tsv`:

```sh
hangar values env -a | while IFS= read -r v; do echo "[$v]"; done
```

### Filters

```sh
hangar -f env=prod                    exact, or a * wildcard
hangar -f env=prod,staging            any of them
hangar -f env!=prod                   none of them
hangar -f name!='*canary*'            wildcards work on both sides
hangar -f 'owner=smith\, jane'        a backslash is a comma, not a separator
```

Repeating `-f` narrows: every clause has to hold, including two on the same key,
so `-f name='web*' -f name!='*canary*'` is the web hosts that are not canaries.

A stray comma is an error rather than a filter. An empty value is the wildcard,
so `-f env=prod,` would quietly match every host and the `prod` would count for
nothing. Bare `-f env=` still means "any value", which is what it always meant.

The key is any tag the host carries, plus the names Hangar resolves for you:
`name`, `product`, `env`, `env_name`, `role`, `asg`, `state`, `id` and
`instance_id`. `state` is
how you leave out the ones that are not running. Those names take precedence: a
fleet with its own tag called `Role` or `State` filters on Hangar's resolved
value under that key, not on the tag. See [JSON](#json).

Hotkey filters in `~/.hangar/config.json` are unaffected: they keep the exact
matching they were written against.

### JSON

`--json` prints one array. **Every run that reaches the fleet prints a valid
document**: the matching hosts, `[]` when nothing matched, and `[]` when there
is no cache yet, which is the state a fresh install is in and the likeliest
place a first pipeline runs. The exit code says which of the three it was, and
`jq` downstream always has something to read.

A usage error is the exception, deliberately: `hangar --json --oops` writes
nothing to stdout and exits 64, because the command never ran.

Each host carries `alias`, `hostname`, `command`, `id`, `state`, `type`,
`vcpus`, `launch_time`, `zone`, `private_ip`, `public_ip`, `private_dns`,
`lifecycle`, `asg`, `source`, the resolved `product`, `env`, `env_name` and
`role`, and `tags`.

`tags` is the host's tags as Hangar resolved them: the keys it knows carry the
resolved value, and every other tag is the fleet's own, untouched.

Seeing a tag here is not quite the same as being able to select on it. Nine key
names are *resolved* rather than looked up, matched without regard to case:
`name`, `role`, `env`, `env_name`, `product`, `asg`, `state`, `id` and
`instance_id`. If your fleet has its own tag called `Role`, the document shows
it and `-f Role=...` still filters on the role Hangar resolved, which is
probably a different value. Filter on a key outside that list, or on the
resolved value.

```sh
hangar --json -f env=prod | jq -r '.[] | select(.type|startswith("m5")) | .alias'
hangar --json | jq -r '.[] | select(.tags["cost-centre"]=="4021") | .command'
```

`vcpus` is a number, and it is absent rather than zero on a host whose response
did not say how its cores are laid out.

It reads `~/.hangar/cache`, which the app refreshes, so it costs no credential,
no network round trip and no AWS call. The ranking is the panel's ranking:
both call `FleetIndex`, because a menubar and a shell must not disagree about
which host best matches `web prod`.

Exit codes are meant for pipelines: `0` when hosts were printed or the work
finished, `1` when nothing matched, `2` when there is no cache yet, `3` when
more than one host matched and none was chosen, `4` when something run with
`--exec` failed on at least one host, and `64` when the command line was wrong or
a fan-out was refused for want of `-y`. Under `--json`, a run that matched nothing
and a run with no cache both still print `[]`, so stdout stays parseable and the
code carries the difference. A cache older than `healthy_within_hours`, and a
missing `Include` line that would stop `ssh <alias>` resolving, are both said
once on stderr so a pipe is unaffected.

## Architecture

```
app/
  Resources/      asset catalog, layered app-icon sources, Info.plist
  Sources/
    HangarCore/   AWS config, SigV4, SSO, EC2, ssh config writer, fuzzy, truncation,
                  and the command line's parsing, filters and output
    Hangar/       brand tokens, hotkeys, panel, rows, menubar, editor, launcher
    hangar-cli/   the `hangar` command, bundled at Contents/Helpers
  Tests/          the offline test suite
design/           brand kit and its source assets
site/             the landing page published to GitHub Pages
intent/           one directory per change: intent, spec, plan
evals/            product promises, checked in CI
scripts/          build, test, and release
```

`HangarCore` is UI-free, which is what makes it testable. Search is byte-level
subsequence matching over a precomputed index. Typing a seventeen-character query
costs 0.44 ms across 249 hosts and 7.35 ms across 10,000, measured on a release
build, so the per-keystroke cost stays under half a millisecond at ten thousand
hosts. The suite asserts the shape of that curve rather than an absolute time,
because it runs unoptimized.

## Status

Early but in daily use. The layered app icon is a
[remaining manual step](intent/0007-layered-app-icon/intent.md); the bundle currently ships
a flattened icon.

Releases are signed and notarized. See [RELEASING.md](RELEASING.md) for how a DMG
is cut and what the updater will refuse to install, and
[CONTRIBUTING.md](CONTRIBUTING.md) if you want to change something.

## How it is built

Hangar is written by a person working with an agent, and the repository is laid
out so that arrangement produces something trustworthy rather than something that
merely compiles. The working method, the review passes, and an honest account of
what it has caught are in
[docs/ai-native-sdlc.md](docs/ai-native-sdlc.md).

## Links

- [Homepage](https://goriparthi.github.io/hangar/)
- [Releases](https://github.com/goriparthi/hangar/releases)
- [Security policy](SECURITY.md)
- [Contributing](CONTRIBUTING.md)
- [How this repository is built](docs/ai-native-sdlc.md)

## License

[MIT](LICENSE)
