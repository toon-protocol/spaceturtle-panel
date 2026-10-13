# How it gets its data

## The three parts

```
 the bar, on every monitor            a floating window
 ┌───────────────────┐               ┌────────────────────────────────┐
 │  turtle, and dot  │──── click ───►│  panel: six sections           │
 └─────────▲─────────┘               └───────▲───────────────┬────────┘
           │        views of one state       │               │ writes a Request
           └──────────────┬──────────────────┘               ▼
                 ┌────────┴─────────┐          ┌─────────────────────────────────┐
                 │  service         │◄─ reads ─│ ~/.local/state/spaceturtle/agent │
                 │  one per shell   │          └───────────────▲─────────────────┘
                 └────────┬─────────┘                          │ mounted into
                          │ runs relay-events on a timer       │ the agent's zone
                          ▼                                    │
                 msb exec st-connector -- toon status,   the agent, in its
                 toon event query … (free, read-only)    next session
```

- **The service** is headless, one per shell. It runs `relay-events` on a timer and holds
  what it printed. It is the only part that starts a process.
- **The turtle** and **the panel** are views of what the service holds.

Every refresh, `relay-events` asks `toon status` for the relay's read address, which
changes on each `toon up`, and reads the relay with `toon event query`, which costs
nothing.

## Where the node is

An Install's node runs inside the connector's zone, a virtual machine under the
launcher's microsandbox, and its relay's read address is the zone's loopback, which this
machine cannot reach. So, in an Install, every command below, the relay query and the
fetch of the relay's NIP-11 document are run in that zone, as the launcher runs them:

```sh
MSB_HOME=~/.local/share/spaceturtle/msb ~/.local/share/spaceturtle/msb/bin/msb \
  exec --quiet --no-stdin st-connector -- sh -c 'toon status --json'
```

Nothing run there is given `TOON_PASSPHRASE_FILE`, so no command the panel runs can
open the wallet. A zone that is not running is never started: the node then reads as
absent, and the Install is still described from the launcher's settings and zone list.
The panel never enters the agent's zone, which holds the agent key.

The panel recognises an Install by `launcher.conf` in the config folder or the `agent`
directory in the state folder. Without either, the commands run on this machine, with
`toon` on `PATH`.

## The commands it runs

Only free, read-only `toon` commands:

- `toon status`
- `toon event query`
- `toon relay config`
- `toon relay subscriptions`
- `toon peer list`
- `toon channel list`
- `toon route list`
- `toon limit show`
- `toon packet count`
- `toon packet list`
- `toon packet history`
- `toon logs` (`toon logs --connector --lines 20 -- <toon app>` with `toon` 0.2.0, which
  reads a TOON app's connector's log by name)
- `toon agent-key list`, for the agent key's public half, scope and limits; a private half,
  were one ever printed, is dropped before anything is read
- `toon message list`

None of them opens the wallet's keystore, so nothing needs its passphrase. `toon message
list` prints the private messages the node's supervisor already opened, with the agent
identity's secret that the agent node keeps for it. A `toon` without that command leaves
the Messages section locked and the rest as it is.

It also runs `curl`, to fetch the relay's NIP-11 document from the relay's read address,
and `wl-copy`, to copy a value. In an Install it runs `msb ls` for the state of the zones
and `systemctl --user` for the timer, and reads `launcher.conf`, the launcher's settings,
and `last-unattended`, when the timer last started a session.

What the Node section shows of the Install comes from these: the earnings are the sum of
the inbound channels' watermarks and of what has landed, and the fees and packets since
the connector last started; the apps and the ones waiting for approval are what `toon
status` lists; the agent key is what `toon agent-key list` says of it. What the agent key
may still spend today is read by the key itself, in the agent's zone, so the panel does not
show it; a session's sidebar does.

## The files it reads and writes

In an Install, the agent's files are where the launcher mounts them into the agent's
zone, under `~/.local/state/spaceturtle/agent/`; the agent sees them as its own
`~/.config/spaceturtle` and `~/.local/state/spaceturtle`.

| File | Written by | Holds |
| --- | --- | --- |
| `~/.local/state/spaceturtle/agent/config/agent-pubkey` | The agent | The agent identity: its public key, 64 lowercase hex characters |
| `~/.local/state/spaceturtle/agent/config/renderers/*.json` | The agent | [Renderer descriptions](renderers.md) |
| `~/.local/state/spaceturtle/agent/state/requests/*.json` | The `request` script, then the agent | One Request per file |
| `~/.config/spaceturtle/launcher.conf` | The launcher | The model, the ceiling, the timer and its interval, the network |
| `~/.local/state/spaceturtle/last-unattended` | The launcher | When the timer last started a session |
| `~/.local/state/spaceturtle/node-snapshot.json` | `relay-events` | The node as the last refresh saw it, and which node that was |
| `~/.local/state/spaceturtle/last-looked` | `mark-seen` | When you last opened the panel |

Without an Install, the first three are `~/.config/spaceturtle/agent-pubkey`,
`~/.config/spaceturtle/renderers/*.json` and `~/.local/state/spaceturtle/requests/*.json`.

Without `agent-pubkey`, or if it is not 64 lowercase hex characters, the feed still works
and no page is marked as the agent's.

The node's ILP address and connector address come from the relay's NIP-11 document
(`ilp_address` and `connector`). The same fields of a profile are not read.

## What it treats as untrusted

A profile is untrusted input, and so is an event.

- Everything from them is rendered as plain text.
- A picture, a profile's or an event's, is loaded only from an `http(s)` URL. Loading it
  tells the host that serves it that this machine asked. The one picture not loaded from
  the web is a stored file (kind 5094): it is drawn from the bytes in the event.
- A video or a sound is loaded only from an `http(s)` URL too, and only when the Observer
  plays it.
- A copied value is passed to `wl-copy` as an argument, never through a shell.

## Requests

A Request is one JSON file in the queue, written by the `request` script: in an Install
`~/.local/state/spaceturtle/agent/state/requests/`, which the agent's zone mounts, else
`~/.local/state/spaceturtle/requests/`. The UI runs the script with arguments, never
through a shell.

```sh
request add [--kind KIND --pubkey KEY --event ID] TEXT
request persona [--name N] [--character C] [--picture URL]
request withdraw ID
```

Follow and unfollow need `--pubkey`. Reply, react and repost need `--event`.

Only the agent changes these fields of a file:

| Field | Value |
| --- | --- |
| `state` | `waiting`, `done` or `declined` |
| `result` | `{"event": id}` |
| `reason` | Why it was declined |

A file that is not a valid Request is skipped.

## Environment variables

This is how the tests run the scripts against a stub.

| Variable | Read by | Sets |
| --- | --- | --- |
| `SPACETURTLE_STATE_DIR` | `relay-events`, `mark-seen`, `request` | The state folder |
| `SPACETURTLE_CONFIG_DIR` | `relay-events`, `request` | The config folder |
| `SPACETURTLE_TOON` | `relay-events` | The `toon` command, without an Install |
| `SPACETURTLE_NOW` | `relay-events` | The time now, in seconds |
| `SPACETURTLE_MSB_HOME`, `SPACETURTLE_MSB` | `relay-events` | microsandbox's home and program, as the launcher names them |
| `SPACETURTLE_ZONE`, `SPACETURTLE_AGENT_ZONE` | `relay-events` | The names of the connector's and the agent's zones |
| `SPACETURTLE_SYSTEMCTL` | `relay-events` | The `systemctl` program, which reports the timer |
