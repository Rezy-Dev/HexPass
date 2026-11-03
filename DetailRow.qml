import QtQuick
import qs.Commons
import qs.Ui

// One line in the detail pane: glyph, value, and the actions that make sense
// for that kind of value.
Item {
  id: root

  property string icon: ""
  property string value: ""
  property string trailing: ""
  property bool secret: false
  property bool revealed: false
  property bool revealable: false
  property bool copyable: true
  property bool openable: false
  property int elideMode: Text.ElideRight
  property color foreground: Color.popups.text
  property color accent: Color.accent
  property color dim: Color.muted
  property string fontFamily: Style.font.family

  signal copyRequested()
  signal revealRequested()
  signal openRequested()

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(iconText.implicitHeight, valueText.implicitHeight, actions.implicitHeight)
    + Style.spacing.sm
  height: implicitHeight

  Text {
    id: iconText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(18)
    text: root.icon
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  Text {
    id: valueText
    anchors.left: iconText.right
    anchors.right: trailingText.visible ? trailingText.left : actions.left
    anchors.leftMargin: Style.spacing.sm
    anchors.rightMargin: Style.spacing.sm
    anchors.verticalCenter: parent.verticalCenter
    text: root.value
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    font.letterSpacing: root.secret && !root.revealed ? Style.space(1) : 0
    elide: root.elideMode
    textFormat: Text.PlainText
  }

  Text {
    id: trailingText
    anchors.right: actions.left
    anchors.rightMargin: Style.spacing.sm
    anchors.verticalCenter: parent.verticalCenter
    visible: root.trailing !== ""
    text: root.trailing
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Row {
    id: actions
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.xxs

    PanelActionButton {
      visible: root.revealable
      iconText: root.revealed ? "\uf070" : "\uf06e"
      tooltipText: root.revealed ? "Hide" : "Reveal"
      foreground: root.foreground
      hoverColor: root.accent
      fontFamily: root.fontFamily
      onClicked: root.revealRequested()
    }

    PanelActionButton {
      visible: root.openable
      iconText: "\uf08e"
      tooltipText: "Open"
      foreground: root.foreground
      hoverColor: root.accent
      fontFamily: root.fontFamily
      onClicked: root.openRequested()
    }

    PanelActionButton {
      visible: root.copyable
      iconText: "\uf0c5"
      tooltipText: "Copy"
      foreground: root.foreground
      hoverColor: root.accent
      fontFamily: root.fontFamily
      onClicked: root.copyRequested()
    }
  }
}
