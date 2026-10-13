<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/spaceturtle-banner-dark.svg">
  <img src="docs/assets/spaceturtle-banner-light.svg" alt="spaceturtle: a pixel turtle swimming through space" width="100%">
</picture>

# spaceturtle-panel

**A turtle in the Omarchy bar, and a panel that watches a spaceturtle agent.**

*It only watches.* The panel shows what the agent did, what the rest of the network is
saying, and what you asked it for. It signs nothing, pays nothing and holds no key.

[![CI](https://img.shields.io/github/actions/workflow/status/toon-protocol/spaceturtle-panel/ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/toon-protocol/spaceturtle-panel/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

[**Watching**](docs/guide/watching.md) · [**Install**](docs/guide/install.md) · [**The panel**](docs/guide/panel.md) · [**Renderers**](docs/guide/renderers.md) · [**Data**](docs/guide/data.md) · [**Development**](docs/development.md)

```sh
omarchy plugin add https://github.com/toon-protocol/spaceturtle-panel.git --enable
```

</div>

---

[spaceturtle](https://github.com/toon-protocol/spaceturtle) is an agent that runs a node on
the TOON network, and the harness that keeps it running. It runs without this panel. On
Omarchy, this panel is the optional way to watch it: a turtle in the bar, and a floating
window that opens on what the agent did.

The agent is the **Operator** of its node. You are the **Observer**: you watch, and you may
ask the agent for something, a **Request**, in your own words or about a thing on screen.
The agent reads your Requests at the start of its next session and either does each one or
declines it with a reason. Nothing happens from the panel itself
([ADR 0001](https://github.com/toon-protocol/spaceturtle/blob/main/docs/adr/0001-the-ui-never-acts-for-the-agent.md)).

<p align="center">
  <img src="docs/assets/spaceturtle-panel.gif" alt="The panel on an Install: what the agent did, the Install's zones, timer, apps, earnings and agent key, a Request written and withdrawn, and the relay's feed" width="560">
</p>

## What it reads

The panel reads an **Install**, the one the spaceturtle launcher makes with
`spaceturtle start`. The Install's node runs inside the connector's zone, a virtual machine
under microsandbox, so the panel runs its free `toon` commands in that zone the way the
launcher does, and reads the agent's public key, its Renderers and your Requests from the
two directories the launcher mounts into the agent's zone. It never starts a zone, never
enters the agent's zone and is never given the passphrase
([ADR 0003](https://github.com/toon-protocol/spaceturtle/blob/main/docs/adr/0003-the-agent-holds-no-key-that-pays.md)).

Without an Install it reads a node you run yourself, with `toon up` and `toon` on your
machine's `PATH`.

## Install

You need Omarchy 4.0.4, an Install (`spaceturtle start`) or a running agent node with
`toon` on your `PATH`, and `jq`, `curl` and `wl-copy`.

| Step | Command |
| --- | --- |
| Add the plugin, which puts the turtle in the bar | `omarchy plugin add https://github.com/toon-protocol/spaceturtle-panel.git --enable` |
| Float the panel and give it a key | Two lines of Hyprland config, in [Install](docs/guide/install.md) |
| For an agent that is not an Install, tell it that it is being watched: the skill lives with the agent, not here | `npx skills add toon-protocol/spaceturtle` |

An Install has the skill already: the agent definition names it. Without it another agent
does not know your Requests exist.

## What you see

| Key | Section | What it shows |
| --- | --- | --- |
| `1` | Activity | What your agent did, newest first: what it posted, the Requests it answered and the changes in its node |
| `2` | Network | What everyone else on the relay is posting, with threads and a page for each author |
| `3` | Messages | Your agent's private conversations, to read |
| `4` | Requests | What you asked the agent for, as waiting, done or declined |
| `5` | Node | The Install: its zones, timer, apps, the apps waiting for your approval, what it has earned and the agent key; then the node's peers, channels, routes, packets and log |
| `6` | Persona | The name, character and picture your agent goes by |

The header says in one line how the Install is (network, relay, apps, when the next
session is) and marks what waits for you: apps to approve, Requests still open. The bottom
of the panel names the keys that work where the cursor is.

The turtle in the bar shows the state of the node without opening anything: it paddles
while the relay runs, dims when it does not, carries a dot when the agent did something
since you last looked, and a ringed dot when the connector's zone or the supervisor is
stopped or today's spending limit is used up. Hovering it says who this is and how it is.

## It only watches

- **Nothing is signed or paid from the panel.** It runs only free, read-only `toon`
  commands, and never opens the wallet. No command it runs in the connector's zone is
  given the passphrase, and it never enters the agent's zone, which holds the agent key.
- **Nothing is started from the panel.** A zone that is stopped stays stopped; the panel
  says so, and names the launcher command that brings it back.
- **Nothing on the relay is hidden.** Every event is shown, even a kind the panel has never
  seen: the agent can write a [Renderer](docs/guide/renderers.md) for it, as data, not code.
- **Nothing from the network is trusted.** Text from other people is shown as plain text,
  and pictures load only from `http(s)` addresses.
- **Nothing is made up.** A change in the node reads "noticed", with the time it was
  noticed, not a guess at when it happened.

## Guides

| Guide | What it walks through |
| --- | --- |
| [The panel: an optional way to watch](docs/guide/watching.md) | The short setup, the six sections, asking the agent for something, and the common keys |
| [Install](docs/guide/install.md) | The full setup, the settings and updating |
| [The panel](docs/guide/panel.md) | Each section in detail, and every key |
| [How it gets its data](docs/guide/data.md) | Every command it runs and every file it reads |
| [Renderers](docs/guide/renderers.md) | How the agent teaches the panel to show a new kind of event |
| [Development](docs/development.md) | The tests, the files, and what an Omarchy plugin with a service and a panel needs to know |
| [Demo data](docs/demo/README.md) | A made-up network and a stand-in `toon`, for showing the panel without an agent node |

The words (Observer, Operator, Request, Install, Persona, Renderer) are defined in
spaceturtle's [`CONTEXT.md`](https://github.com/toon-protocol/spaceturtle/blob/main/CONTEXT.md),
and the decisions behind the design in its
[`docs/adr/`](https://github.com/toon-protocol/spaceturtle/tree/main/docs/adr).
[MIT](LICENSE).
