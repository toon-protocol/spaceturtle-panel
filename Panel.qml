import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The floating window: six sections, one number key each, all views of the
// service. The shell loads this when the panel is summoned and unloads it when
// it closes, so what must outlive a close (section, cursor) is on the service.
Item {
  id: root

  // Injected by the shell.
  property var shell: null
  property var service: null

  readonly property string pluginId: "toon.spaceturtle"
  // Read by the shell to decide what `toggle` does.
  readonly property bool opened: window.visible
  property bool closingFromHost: false

  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  // In key order: section n is opened by number key n.
  readonly property var sections: ["Activity", "Network", "Messages", "Requests", "Node", "Persona"]
  readonly property int activitySection: 1
  readonly property int networkSection: 2
  readonly property int messagesSection: 3
  readonly property int requestsSection: 4
  readonly property int nodeSection: 5
  readonly property int personaSection: 6
  readonly property int section: service ? service.section : activitySection
  // Who this Install is, or null: the header shows an unnamed turtle.
  readonly property var personaProfile: service && service.persona ? service.persona : null
  // A mark on a tab: how many Requests wait, how many apps wait for approval.
  readonly property var badges: {
    var marks = ["", "", "", "", "", ""]
    if (!service) return marks
    if (service.waitingCount > 0) marks[requestsSection - 1] = String(service.waitingCount)
    if (service.waitingApps > 0) marks[nodeSection - 1] = String(service.waitingApps)
    return marks
  }
  // Whether a text box of the section has the keys.
  readonly property bool typing: cursorSection ? cursorSection.typing === true : false
  // The keys of the section showing, then the ones that work everywhere.
  readonly property var hints: {
    if (typing) return [["Enter", "send"], ["Esc", "leave the box"]]
    var own = cursorSection && cursorSection.hints ? cursorSection.hints : []
    return own.concat([["1-6", "section"], ["r", "refresh"], ["Esc", "close"]])
  }
  // The section that has a cursor to move, if the one showing does.
  readonly property var cursorSection: section === activitySection ? activity.item
    : (section === networkSection ? network.item
    : (section === messagesSection ? messages.item
    : (section === requestsSection ? requests.item
    : (section === nodeSection ? node.item
    : (section === personaSection ? persona.item : null)))))

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    if (service) service.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // Closed by the shell (`shell hide`, or the toggle): it already knows.
  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  // Closed from here (Esc): tell the shell, so its next toggle opens the panel.
  function requestClose() {
    if (shell) shell.hide(pluginId)
    else window.visible = false
  }

  function showSection(number) {
    if (!service || number < 1 || number > sections.length) return
    service.section = number
    // The keys are the panel's again; in Requests, i gives them to the text box.
    keyCatcher.forceActiveFocus()
  }

  // Esc: back within the section, and out of the panel from its top level.
  function back() {
    if (!cursorSection || !cursorSection.back()) requestClose()
  }

  function syncLooking() {
    if (service) service.looking = window.visible
  }

  onServiceChanged: syncLooking()
  Component.onDestruction: if (service) service.looking = false

  // A small bordered mark in the header; a click goes where it points.
  component Pill: BorderSurface {
    id: pill
    property string text: ""
    property bool accent: false
    signal clicked()
    implicitWidth: pillText.implicitWidth + Style.space(10)
    implicitHeight: pillText.implicitHeight + Style.space(5)
    radius: Style.cornerRadius
    color: pill.accent ? Qt.alpha(Color.accent, 0.18) : "transparent"
    borderSpec: Border.controlSpec("normal", pill.accent ? Color.accent : Color.foreground, Color.accent)

    Text {
      id: pillText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: pill.text
      color: pill.accent ? Color.accent : root.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.clicked()
    }
  }

  FloatingWindow {
    id: window
    // Hyprland window rules match on this; see docs/guide/install.md.
    title: "Spaceturtle"
    color: Color.background
    implicitWidth: Style.space(560)
    implicitHeight: Style.space(720)
    minimumSize: Qt.size(Style.space(380), Style.space(320))

    onVisibleChanged: {
      root.syncLooking()
      // Closed by Hyprland: the shell has not been told yet.
      if (!visible && !root.closingFromHost && root.shell) root.shell.hide(root.pluginId)
    }

    FocusScope {
      anchors.fill: parent
      focus: true

      PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        onMoveRequested: function(dx, dy) {
          if (!root.cursorSection) return
          if (dy !== 0) root.cursorSection.move(dy)
          else if (dx < 0) root.cursorSection.back()
          else root.cursorSection.activate()
        }
        onActivateRequested: if (root.cursorSection) root.cursorSection.activate()
        // The catcher reports x as a delete, not as a text key; the sections read it as x.
        onDeleteRequested: if (root.cursorSection) root.cursorSection.key("x")
        onCloseRequested: root.back()
        onTabRequested: function(direction) {
          var count = root.sections.length
          root.showSection((root.section - 1 + direction + count) % count + 1)
        }
        onTextKey: function(text) {
          if (Number(text) >= 1 && Number(text) <= root.sections.length) root.showSection(Number(text))
          else if (text === "r") { if (root.service) root.service.refresh() }
          else if (root.cursorSection) root.cursorSection.key(text)
        }

        Column {
          id: head
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.spacing.panelPadding
          spacing: Style.spacing.panelGap

          // Each Install is called by its Persona; until it has one, an unnamed
          // turtle. Under the name, one line on how the Install is; at the
          // right, what waits for the Observer.
          Item {
            width: parent.width
            implicitHeight: Math.max(picture.height, heroLabels.implicitHeight)

            Item {
              id: picture
              width: Style.space(36)
              height: Style.space(36)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter

              Avatar {
                visible: root.personaProfile !== null
                size: Style.space(36)
                source: root.personaProfile ? root.personaProfile.picture : ""
                label: root.personaProfile ? root.personaProfile.name : ""
              }
              TurtleIcon {
                visible: root.personaProfile === null
                anchors.centerIn: parent
                iconSize: Style.space(30)
                variant: root.service ? root.service.iconVariant : 1
                swimming: root.service ? root.service.online : false
              }
            }

            Column {
              id: heroLabels
              anchors.left: picture.right
              anchors.leftMargin: Style.space(12)
              anchors.right: pills.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: root.personaProfile ? root.personaProfile.name : "Who is this?"
                color: root.personaProfile ? Color.foreground : root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: root.personaProfile !== null
                font.italic: root.personaProfile === null
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: (root.service ? root.service.summary : "").toUpperCase()
                color: root.service && root.service.urgent ? Color.urgent : root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }
            }

            // What waits for the Observer: apps to approve, Requests still open.
            Row {
              id: pills
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Pill {
                visible: root.service && root.service.waitingApps > 0
                text: root.service ? root.service.waitingApps + (root.service.waitingApps === 1 ? " app to approve" : " apps to approve") : ""
                accent: true
                onClicked: root.showSection(root.nodeSection)
              }
              Pill {
                visible: root.service && root.service.waitingCount > 0
                text: root.service ? root.service.waitingCount + " waiting" : ""
                accent: false
                onClicked: root.showSection(root.requestsSection)
              }
            }
          }

          SectionTabs {
            width: parent.width
            names: root.sections
            badges: root.badges
            current: root.section
            onSelected: function(number) { root.showSection(number) }
          }

          PanelSeparator {}
        }

        // The keys that work where the cursor is, along the bottom.
        Column {
          id: foot
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.spacing.panelPadding
          anchors.topMargin: 0
          spacing: Style.spacing.lg

          PanelSeparator {}

          KeyHints {
            width: parent.width
            hints: root.hints
          }
        }

        Item {
          anchors.top: head.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: foot.top
          anchors.margins: Style.spacing.panelPadding
          anchors.bottomMargin: Style.spacing.lg

          // Waits for the service, so the section never has to ask whether it has one.
          Loader {
            id: activity
            anchors.fill: parent
            active: root.service !== null
            visible: root.section === root.activitySection
            sourceComponent: ActivitySection { service: root.service }
          }

          Loader {
            id: network
            anchors.fill: parent
            active: root.service !== null
            visible: root.section === root.networkSection
            sourceComponent: NetworkSection { service: root.service }
          }

          Loader {
            id: messages
            anchors.fill: parent
            active: root.service !== null
            visible: root.section === root.messagesSection
            sourceComponent: MessagesSection { service: root.service }
          }

          Loader {
            id: requests
            anchors.fill: parent
            active: root.service !== null
            visible: root.section === root.requestsSection
            sourceComponent: RequestsSection { service: root.service }
          }

          Connections {
            target: requests.item
            function onLeaveInput() { keyCatcher.forceActiveFocus() }
          }

          Connections {
            target: network.item
            function onLeaveInput() { keyCatcher.forceActiveFocus() }
          }

          Loader {
            id: persona
            anchors.fill: parent
            active: root.service !== null
            visible: root.section === root.personaSection
            sourceComponent: PersonaSection { service: root.service }
          }

          Connections {
            target: persona.item
            function onLeaveInput() { keyCatcher.forceActiveFocus() }
          }

          Loader {
            id: node
            anchors.fill: parent
            active: root.service !== null
            visible: root.section === root.nodeSection
            sourceComponent: NodeSection { service: root.service }
          }

          // A panel with no service.
          Text {
            visible: !root.service
            anchors.centerIn: parent
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: "The service is not running. Run: omarchy restart shell"
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.italic: true
          }
        }
      }
    }
  }
}
