import QtQuick
import qs.Commons
import qs.Ui

// One tab per section of the panel, each labelled with the number key that
// selects it. Omarchy's kit has no tabs; these are its CursorSurface, side by
// side, with the open section painted as the kit paints a current row.
Flow {
  id: root

  property var names: []
  // One short mark per section, "" for none: how many Requests wait, say.
  property var badges: []
  // The open section, numbered from 1 as its key is.
  property int current: 1

  signal selected(int number)

  spacing: Style.spacing.xs

  Repeater {
    model: root.names

    CursorSurface {
      id: tab
      required property string modelData
      required property int index

      readonly property color dim: Qt.darker(Color.foreground, 1.5)

      current: index + 1 === root.current
      // Tighter than a control, so the six fit on one line with their marks.
      width: label.implicitWidth + Style.space(7) * 2
      height: label.implicitHeight + Style.spacing.controlPaddingY * 2

      Row {
        id: label
        anchors.centerIn: parent
        spacing: Style.spacing.md

        Text {
          id: key
          textFormat: Text.PlainText
          anchors.baseline: name.baseline
          text: String(tab.index + 1)
          color: tab.current ? Color.accent : tab.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Text {
          id: name
          textFormat: Text.PlainText
          text: tab.modelData
          color: tab.current ? Color.foreground : tab.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: tab.current
        }

        Text {
          readonly property string badge: tab.index < root.badges.length ? String(root.badges[tab.index] || "") : ""
          visible: badge !== ""
          textFormat: Text.PlainText
          anchors.baseline: name.baseline
          text: badge
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.selected(tab.index + 1)
      }
    }
  }
}
