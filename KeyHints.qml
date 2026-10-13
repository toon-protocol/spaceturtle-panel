import QtQuick
import qs.Commons

// The keys that do something where the cursor is, as "key  what it does"
// pairs along the bottom of the panel. Each section names its own; the panel
// adds the ones that work everywhere.
Flow {
  id: root

  // [[key, label], ...]
  property var hints: []
  readonly property color dim: Qt.darker(Color.foreground, 1.5)

  spacing: Style.space(14)

  Repeater {
    model: root.hints

    Row {
      required property var modelData
      spacing: Style.space(5)

      Text {
        textFormat: Text.PlainText
        text: String(parent.modelData[0])
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        text: String(parent.modelData[1])
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
