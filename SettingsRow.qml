import QtQuick
import qs.Commons

// One clickable settings line: label on the left, current value on the right.
Item {
  id: root

  property string label: ""
  property string value: ""
  property bool active: false
  property color foreground: Color.popups.text
  property color accent: Color.accent
  property color dim: Color.muted
  property string fontFamily: Style.font.family

  signal clicked()

  width: parent ? parent.width : implicitWidth
  height: Math.max(labelText.implicitHeight, valueText.implicitHeight) + Style.spacing.md * 2

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: rowMouse.containsMouse ? Util.alpha(root.accent, 0.08) : "transparent"
  }

  Text {
    id: labelText
    anchors.left: parent.left
    anchors.leftMargin: Style.spacing.sm
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  Text {
    id: valueText
    anchors.right: parent.right
    anchors.rightMargin: Style.spacing.sm
    anchors.verticalCenter: parent.verticalCenter
    text: root.value
    color: root.active ? root.accent : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideMiddle
    width: Math.min(implicitWidth, parent.width * 0.55)
    horizontalAlignment: Text.AlignRight
  }

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
