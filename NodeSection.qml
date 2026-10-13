import QtQuick
import qs.Commons
import qs.Ui

// The Node section: the Install as the launcher left it (zones, timer, apps,
// what waits for approval, earnings, agent key), then the agent node's state,
// read with free `toon` commands, in groups. One cursor runs down every row;
// Enter or a click copies the row's value, which for an app that waits is the
// command that approves it. Where the cursor is lives on the service, so it
// survives the panel closing.
Item {
  id: root

  required property var service

  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  readonly property var node: service.nodeState
  readonly property var install: service.installPresent ? service.install : null
  readonly property string balancesText: "not shown: needs the passphrase"
  readonly property var hints: [["j/k", "move"], ["Enter", "copy"]]
  readonly property bool typing: false

  // Why nothing of the node can be read, and what to do; "" while it can.
  readonly property string absentText: {
    if (!service.loaded) return "Loading…"
    if (node) return ""
    if (!install) return "No agent node. Make an Install with spaceturtle start, or run toon up."
    if (install.connector_zone !== "running") return "The connector's zone is " + install.connector_zone + ", so the node cannot be read. Bring it back with spaceturtle start."
    if (install.supervisor === false) return "The supervisor is not running, so the node cannot be read. Run spaceturtle start."
    return "The node does not answer. journalctl --user -u spaceturtle-connector says why."
  }

  function yesNo(value) { return value === null || value === undefined ? "unknown" : (value ? "running" : "stopped") }
  function plural(n, one, many) { return n + " " + (n === 1 ? one : many) }
  function process(p) { return yesNo(p.running) + ", " + plural(p.restarts, "restart", "restarts") }
  function ago(iso) {
    var ms = Date.parse(iso)
    if (isNaN(ms)) return iso
    var delta = Math.max(0, Math.floor((clock.now - ms) / 1000))
    if (delta < 60) return "just now"
    var unit = delta < 3600 ? [60, "minute"] : (delta < 86400 ? [3600, "hour"] : [86400, "day"])
    var n = Math.floor(delta / unit[0])
    return n + " " + unit[1] + (n === 1 ? "" : "s") + " ago"
  }
  // Drives the relative timestamps.
  Timer {
    id: clock
    property real now: Date.now()
    interval: 30000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: now = Date.now()
  }
  // The parts that are not empty, joined.
  function joined(parts) { return parts.filter(function(x) { return x !== "" }).join(", ") }

  // Rows: { group } starts a group; { label, value, note } is a row the cursor
  // can stand on. `note` marks a row that is said of the group, not a value of it.
  readonly property var rows: {
    var list = []
    var st = node
    var current = ""
    function group(name) { current = name; list.push({ group: name }) }
    function row(label, value) { list.push({ label: label, value: String(value), under: current }) }
    function note(text) { list.push({ label: "", value: text, note: true, under: current }) }
    function unavailable() { note("unavailable") }
    function none() { note("none") }
    function units(n) { return n === null || n === undefined || n === "" ? "–" : String(n) }

    // ---------- The Install, as the launcher left it ----------
    var inst = install
    if (inst) {
      group("Install")
      row("Network", inst.network || "devnet")
      row("Connector's zone", inst.connector_zone)
      row("Supervisor", inst.supervisor === null ? "unknown" : (inst.supervisor ? "running" : "not running"))
      row("Agent's zone", inst.agent_zone)
      var timer = inst.timer || {}
      var timerText = timer.on ? "on, every " + timer.interval : "off"
      if (timer.on && timer.active === false) timerText += " (not armed: spaceturtle start)"
      else if (timer.on && service.nextSession > 0) timerText += ", next session " + service.inWords(service.nextSession)
      row("Timer", timerText)
      row("Last session", typeof timer.last_unattended === "number" ? ago(new Date(timer.last_unattended * 1000).toISOString()) + ", unattended" : "no unattended one yet")
      row("Model", inst.model || "–")
      row("Ceiling", "$" + inst.ceiling + " of model cost per unattended session")

      group("Apps")
      var apps = inst.apps || []
      if (!st) note("cannot be read now")
      else if (apps.length === 0) none()
      else for (var ai = 0; ai < apps.length; ai++) {
        var app = apps[ai]
        row(app.name, joined([app.running ? "running" : "stopped", app.price !== "" ? "price " + app.price : "", app.image]))
      }

      var waiting = inst.waiting_apps || []
      if (waiting.length > 0) {
        group("Waiting for your approval")
        for (var wi = 0; wi < waiting.length; wi++) {
          var w = waiting[wi]
          row(w.name, joined([w.image, w.asks ? "asks for " + w.asks : "asks for nothing more"]))
          row("", "spaceturtle approve " + w.name)
          row("", "spaceturtle refuse " + w.name)
        }
        note("The agent cannot start these. Enter copies the command; run it in a terminal")
      }

      group("Earnings")
      var earn = inst.earnings
      if (!earn) note(st ? "unavailable" : "cannot be read now")
      else {
        row("Received", units(earn.received) + (earn.landed !== null && earn.landed !== undefined ? " (" + earn.landed + " landed)" : ""))
        row("This run", units(earn.fees) + " in fees, " + units(earn.packets) + (earn.packets === 1 ? " packet" : " packets"))
        note("In the token's base units. This run is since the connector last started")
      }

      group("Agent key")
      var key = inst.agent_key
      if (!key) note(st ? "none: spaceturtle agent-key replace makes one" : "cannot be read now")
      else {
        row("Public key", key.public_key || "–")
        row("Scope", (key.scope || []).length > 0 ? key.scope.join(", ") : "–")
        row("Per command", units(key.per_command))
        row("Per day", units(key.per_day))
        note("What is left today is read by the key, in a session's sidebar")
      }
    }

    if (!st) {
      if (inst) { group("Node"); note(absentText) }
      return list
    }

    group("Processes")
    if (!st.status) unavailable()
    else {
      row("Supervisor", process(st.status.supervisor))
      row("Connector", process(st.status.connector))
      for (var a = 0; a < st.status.apps.length; a++) row(st.status.apps[a].name, process(st.status.apps[a]))
    }

    group("Relay")
    if (!st.relay) unavailable()
    else {
      row("Name", st.relay.name || "–")
      for (var p = 0; p < st.relay.prices.length; p++) row("Price " + st.relay.prices[p].name, st.relay.prices[p].price)
      row("Blocklist", st.relay.blocklist.length === 0 ? "empty" : plural(st.relay.blocklist.length, "entry", "entries"))
      for (var b = 0; b < st.relay.blocklist.length; b++) row("Blocked", st.relay.blocklist[b])
    }

    group("Peerings")
    if (!st.peers) unavailable()
    else if (st.peers.length === 0) none()
    else for (var i = 0; i < st.peers.length; i++)
      row(st.peers[i].id, joined([st.peers[i].direction, st.peers[i].status]))

    group("Channels")
    if (!st.channels) unavailable()
    else if (st.channels.length === 0) none()
    else for (var c = 0; c < st.channels.length; c++) {
      var ch = st.channels[c]
      row(ch.peer, joined([ch.direction, ch.status, ch.collateral !== "" ? "collateral " + ch.collateral : ""]))
    }

    group("Routes")
    if (!st.routes) unavailable()
    else if (st.routes.length === 0) none()
    else for (var r = 0; r < st.routes.length; r++)
      row(st.routes[r].prefix, joined([st.routes[r].peer, st.routes[r].price !== "" ? "price " + st.routes[r].price : ""]))

    // In an Install this is the limit of the node itself; the agent's is its key's.
    group(inst ? "Node's spending limit" : "Spending limit")
    if (!st.limits) unavailable()
    else {
      row("Per command", st.limits.per_command || "–")
      row("Per day", st.limits.per_day || "–")
      row("Left today", st.limits.remaining_today || "–")
    }

    group("Packets")
    if (!st.packets) unavailable()
    else {
      row("Fulfilled", String(st.packets.fulfilled))
      row("Rejected", String(st.packets.rejected))
      for (var k = 0; k < st.packets.rejects.length; k++)
        row("Rejected " + st.packets.rejects[k].code, String(st.packets.rejects[k].count))
      row("Fees earned", st.packets.fees_earned + " (base units)")
      note("Counts are since the connector last started")
    }

    var history = st.packet_history
    if (history && history.packets.length > 0) {
      group("Packet history")
      for (var m = 0; m < history.packets.length; m++) {
        var pk = history.packets[m]
        var peers = pk.from && pk.to ? pk.from + " → " + pk.to : (pk.to ? "→ " + pk.to : (pk.from || ""))
        row(ago(pk.time), joined([pk.direction || "", pk.outcome + (pk.code ? " " + pk.code : ""), pk.amount || "",
          pk.fee ? "fee " + pk.fee : "", peers, pk.destination || "", pk.message || ""]))
      }
      note("Recent packets only, since the connector last started. Amounts are in base units")
      if (history.dropped > 0) note(plural(history.dropped, "packet", "packets") + " not recorded")
    } else {
      group("Rejected packets")
      if (!st.rejected_packets) unavailable()
      else if (st.rejected_packets.length === 0) none()
      else for (var q = 0; q < st.rejected_packets.length; q++) {
        var rp = st.rejected_packets[q]
        row(ago(rp.time), rp.destination + ", " + rp.code + ": " + rp.message)
      }
    }

    group("Subscriptions")
    if (!st.subscriptions) unavailable()
    else {
      var held = st.subscriptions.held
      row("Held", held === null ? "unavailable" : (held.length === 0 ? "none" : plural(held.length, "subscription", "subscriptions")))
      if (held) for (var h = 0; h < held.length; h++) row("", held[h])
      row("To your relay", st.subscriptions.incoming === null ? "–" : String(st.subscriptions.incoming))
    }

    group("Addresses")
    row("ILP", service.nodeIlp || "–")
    row("Connector", service.nodeConnector || "–")

    group("Wallet")
    list.push({ label: "Balances", value: balancesText, note: true })

    group("Log")
    if (!st.logs) unavailable()
    else if (st.logs.length === 0) none()
    else for (var l = 0; l < st.logs.length; l++) row("", st.logs[l])
    return list
  }

  // The cursor's targets are the rows that hold a value: not a group heading,
  // not a note said of a group.
  readonly property var targets: {
    var list = []
    for (var i = 0; i < rows.length; i++) if (rows[i].group === undefined && rows[i].note !== true) list.push(i)
    return list
  }
  readonly property int cursor: Math.max(0, Math.min(service.nodeCursor, targets.length - 1))
  property bool scrollOnCursor: true
  // The row whose value was just copied, for its "copied" flash; -1 for none.
  property int copiedIndex: -1

  function move(dy) {
    pointerGate.reset()
    root.scrollOnCursor = true
    service.nodeCursor = Math.max(0, Math.min(root.cursor + dy, root.targets.length - 1))
    if (service.nodeCursor === 0) scroll.contentY = 0
  }

  // Stand on the item an Activity entry concerns: its row in its group, or the
  // group's first row when the item is gone (a channel that closed). Before the
  // rows are in, the focus waits for them.
  function focusOn(focus) {
    if (!focus || root.targets.length === 0) return
    var first = -1
    for (var t = 0; t < root.targets.length; t++) {
      var r = root.rows[root.targets[t]]
      if (r.under !== focus.group) continue
      if (first < 0) first = t
      if (r.label === focus.label) { first = t; break }
    }
    service.nodeFocus = null
    root.scrollOnCursor = true
    service.nodeCursor = first < 0 ? 0 : first
    if (service.nodeCursor === 0) scroll.contentY = 0
  }

  Connections {
    target: root.service
    function onNodeFocusChanged() { root.focusOn(root.service.nodeFocus) }
  }
  onTargetsChanged: focusOn(service.nodeFocus)
  Component.onCompleted: focusOn(service.nodeFocus)

  function hover(target) {
    root.scrollOnCursor = false
    service.nodeCursor = target
  }

  // Enter: copy the value under the cursor. Notes ("unavailable", "not shown") are not values.
  function activate() {
    if (root.targets.length === 0) return
    var row = root.rows[root.targets[root.cursor]]
    if (row.note || row.value === "" || row.value === "–") return
    service.copy(row.value)
    root.copiedIndex = root.targets[root.cursor]
    copiedTimer.restart()
  }

  // Nothing below the top level: Esc closes the panel.
  function back() { return false }

  function key(text) {}

  function ensureVisible(item) {
    if (!item) return
    var top = item.mapToItem(column, 0, 0).y
    var bottom = top + item.height
    var margin = Style.space(12)
    if (top < scroll.contentY + margin) scroll.contentY = Math.max(0, top - margin)
    else if (bottom > scroll.contentY + scroll.height - margin)
      scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, bottom + margin - scroll.height))
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: root
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root.copiedIndex = -1
  }

  // No agent node and no Install: say so, and how to start one.
  Text {
    visible: root.rows.length === 0
    anchors.centerIn: parent
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    text: root.absentText
    color: root.dim
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.italic: true
  }

  Flickable {
    id: scroll
    visible: root.rows.length > 0
    anchors.fill: parent
    contentWidth: width
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: column
      width: scroll.width

      Repeater {
        model: root.rows

        Item {
          id: entry
          required property var modelData
          required property int index
          readonly property bool heading: modelData.group !== undefined
          readonly property int target: root.targets.indexOf(index)

          width: parent ? parent.width : 0
          height: heading ? headingText.implicitHeight + Style.space(entry.index === 0 ? 6 : 18) : rowSurface.height

          PanelSectionHeader {
            id: headingText
            visible: entry.heading
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.lg
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(4)
            text: entry.heading ? entry.modelData.group : ""
          }

          CursorSurface {
            id: rowSurface
            visible: !entry.heading
            hasCursor: !entry.heading && root.cursor === entry.target
            width: parent.width
            height: Math.max(valueText.implicitHeight, labelText.implicitHeight) + Style.spacing.sm * 2

            onHasCursorChanged: if (hasCursor && root.scrollOnCursor) root.ensureVisible(entry)

            Text {
              id: labelText
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.lg
              anchors.baseline: valueText.baseline
              width: Style.space(120)
              elide: Text.ElideRight
              text: entry.heading ? "" : entry.modelData.label
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              id: valueText
              textFormat: Text.PlainText
              anchors.left: labelText.right
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.lg
              anchors.verticalCenter: parent.verticalCenter
              wrapMode: Text.Wrap
              text: entry.heading ? "" : (root.copiedIndex === entry.index ? "copied" : entry.modelData.value)
              color: root.copiedIndex === entry.index ? Color.accent : (!entry.heading && entry.modelData.note ? root.dim : Color.foreground)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.italic: !entry.heading && entry.modelData.note === true
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: function(mouse) { if (pointerGate.moved(rowSurface, mouse)) root.hover(entry.target) }
              onClicked: {
                root.hover(entry.target)
                root.activate()
              }
            }
          }
        }
      }
    }
  }
}
