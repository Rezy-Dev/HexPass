import QtQuick
import qs.Commons
import qs.Ui

// Small settings surface. Every row is one click: cycle a value, open the
// store, or hand a maintenance command to a terminal.
Item {
  id: root

  property bool opened: false
  property bool syncOnOpen: false
  property bool autoUnlock: true
  property int autoLockSeconds: 900
  property bool locked: false
  property int clipboardClear: 45
  property int genLength: 24
  property string storePath: ""
  property string remote: ""
  property string branch: ""
  property int ahead: 0
  property int behind: 0
  property bool dirty: false
  property string lastCommit: ""
  property color foreground: Color.popups.text
  property color accent: Color.accent
  property color dim: Color.muted
  property string fontFamily: Style.font.family

  signal closed()
  signal toggleSync()
  signal toggleAutoUnlock()
  signal cycleAutoLock()
  signal lockNow()
  signal cycleClipboard()
  signal cycleLength()
  signal openStore()
  signal maintenance(string action)
  signal openCredit()

  visible: opened
  z: 10

  function open() {
    Qt.callLater(function() { root.forceActiveFocus() })
  }

  function close() {
  }

  function clipboardLabel() {
    return clipboardClear > 0 ? clipboardClear + "s" : "Never"
  }

  function lockLabel() {
    if (autoLockSeconds === 0) return "Never"
    if (autoLockSeconds === 300) return "5 min"
    if (autoLockSeconds === 900) return "15 min"
    if (autoLockSeconds === 1800) return "30 min"
    if (autoLockSeconds === 3600) return "1 hour"
    return autoLockSeconds + "s"
  }

  function gitLabel() {
    if (!branch) return ""
    var text = branch
    if (ahead > 0) text += "  \u2191" + ahead
    if (behind > 0) text += "  \u2193" + behind
    if (dirty) text += "  \u2022"
    return text
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      root.closed()
      event.accepted = true
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.72)

    MouseArea {
      anchors.fill: parent
      onClicked: root.closed()
    }
  }

  BorderSurface {
    id: card

    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(32), Style.space(500))
    height: Math.min(content.implicitHeight + card.contentTopInset + card.contentBottomInset,
      parent.height - Style.space(8))
    color: Color.popups.background
    borderSpec: Border.flat(Color.popups.border, Style.normalBorderWidth)
    radius: Style.cornerRadius
    padding: Style.space(18)

    MouseArea { anchors.fill: parent }

    Flickable {
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
      contentWidth: width
      contentHeight: content.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: content
        width: parent.width
        spacing: Style.spacing.sm

        Item {
          width: parent.width
          height: Math.max(headerIcon.implicitHeight, headerTitle.implicitHeight, headerClose.implicitHeight)

          Text {
            id: headerIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf013"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }

          Text {
            id: headerTitle
            anchors.left: headerIcon.right
            anchors.leftMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            text: "Settings"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          PanelActionButton {
            id: headerClose
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "\uf00d"
            tooltipText: "Close"
            foreground: root.foreground
            hoverColor: root.accent
            fontFamily: root.fontFamily
            onClicked: root.closed()
          }
        }

        Text {
          width: parent.width
          visible: root.gitLabel() !== ""
          text: root.gitLabel() + (root.lastCommit ? "  \u00b7  " + root.lastCommit : "")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        PanelSeparator { foreground: root.foreground }

        SettingsRow {
          label: "Sync on open"
          value: root.syncOnOpen ? "On" : "Off"
          active: root.syncOnOpen
          onClicked: root.toggleSync()
        }

        SettingsRow {
          label: "Clear clipboard"
          value: root.clipboardLabel()
          onClicked: root.cycleClipboard()
        }

        SettingsRow {
          label: "Generator length"
          value: String(root.genLength)
          onClicked: root.cycleLength()
        }

        PanelSeparator { foreground: root.foreground }

        SettingsRow {
          label: "Unlock on open"
          value: root.autoUnlock ? "On" : "Off"
          active: root.autoUnlock
          onClicked: root.toggleAutoUnlock()
        }

        SettingsRow {
          label: "Lock after"
          value: root.lockLabel()
          onClicked: root.cycleAutoLock()
        }

        Text {
          width: parent.width
          text: "Passphrase: gpg-agent. HexPass never stores it."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        SettingsRow {
          label: "Lock now"
          value: ""
          visible: !root.locked
          onClicked: root.lockNow()
        }

        PanelSeparator { foreground: root.foreground }

        SettingsRow {
          label: "Store"
          value: root.remote || "Open folder"
          onClicked: root.openStore()
        }

        SettingsRow {
          label: "Check store"
          value: "fsck"
          onClicked: root.maintenance("fsck")
        }

        SettingsRow {
          label: "Audit passwords"
          value: "audit"
          onClicked: root.maintenance("audit")
        }

        SettingsRow {
          label: "Doctor"
          value: "doctor"
          onClicked: root.maintenance("doctor")
        }

        PanelSeparator { foreground: root.foreground }

        Item {
          width: parent.width
          height: creditText.implicitHeight + Style.spacing.sm

          Text {
            id: creditText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "HexPass by Rezy Dev"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            id: creditLink
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "rezydev.com"
            color: creditMouse.containsMouse ? root.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: creditMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openCredit()
          }
        }
      }
    }
  }

}
