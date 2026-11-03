import QtQuick
import qs.Commons
import qs.Ui

// Password generator overlay. It only renders the current value and options;
// the controller owns gopass pwgen.
Item {
  id: root

  property bool opened: false
  property string output: ""
  property string error: ""
  property bool loading: false
  property int length: 24
  property bool symbols: true
  property string mode: "cryptic"
  property string target: "clipboard"
  property string entryPath: ""
  property color foreground: Color.popups.text
  property color accent: Color.accent
  property color urgent: Color.urgent
  property color dim: Color.muted
  property string fontFamily: Style.font.family

  signal closed()
  signal optionsChanged()
  signal copyRequested()
  signal useRequested()

  visible: opened
  z: 10

  function open(targetMode, path, nextLength, nextSymbols, nextMode) {
    target = targetMode || "clipboard"
    entryPath = path || ""
    length = nextLength || 24
    symbols = nextSymbols === true
    mode = nextMode || "cryptic"
    error = ""
    output = ""
    Qt.callLater(function() { root.forceActiveFocus() })
  }

  function close() {
  }

  function setOutput(value) {
    output = String(value || "")
    loading = false
  }

  function showError(text) {
    error = String(text || "Generator failed")
    loading = false
  }

  function cycleMode() {
    mode = mode === "cryptic" ? "xkcd" : (mode === "xkcd" ? "memorable" : "cryptic")
    error = ""
    optionsChanged()
  }

  function adjustLength(delta) {
    length = Math.max(8, Math.min(128, length + delta))
    error = ""
    optionsChanged()
  }

  function toggleSymbols() {
    symbols = !symbols
    error = ""
    optionsChanged()
  }

  function modeLabel() {
    if (mode === "xkcd") return "XKCD"
    if (mode === "memorable") return "Memorable"
    return "Cryptic"
  }

  Keys.onPressed: function(event) {
    if (!root.opened) return
    if (event.key === Qt.Key_Escape) {
      root.closed()
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.copyRequested()
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
    height: content.implicitHeight + card.contentTopInset + card.contentBottomInset
    color: Color.popups.background
    borderSpec: Border.flat(Color.popups.border, Style.normalBorderWidth)
    radius: Style.cornerRadius
    padding: Style.space(18)

    MouseArea { anchors.fill: parent }

    Item {
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset

      Column {
        id: content
        width: parent.width
        spacing: Style.spacing.md

        Item {
          width: parent.width
          height: Math.max(headerIcon.implicitHeight, headerTitle.implicitHeight, headerClose.implicitHeight)

          Text {
            id: headerIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf0d0"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }

          Text {
            id: headerTitle
            anchors.left: headerIcon.right
            anchors.leftMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            text: "Generate"
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

        Rectangle {
          width: parent.width
          height: outputText.implicitHeight + Style.spacing.lg * 2
          radius: Style.cornerRadius
          color: Util.alpha(root.foreground, 0.06)
          border.width: Style.normalBorderWidth
          border.color: Util.alpha(root.foreground, 0.16)

          Text {
            id: outputText
            anchors.left: parent.left
            anchors.right: copyButton.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.spacing.md
            anchors.rightMargin: Style.spacing.sm
            text: root.loading ? "\u2026" : (root.output || "\u2014")
            color: root.loading || !root.output ? root.dim : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            wrapMode: Text.WrapAnywhere
          }

          PanelActionButton {
            id: copyButton
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            iconText: "\uf0c5"
            tooltipText: "Copy"
            foreground: root.foreground
            hoverColor: root.accent
            fontFamily: root.fontFamily
            onClicked: root.copyRequested()
          }
        }

        Text {
          width: parent.width
          visible: root.error !== ""
          text: root.error
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Row {
          width: parent.width
          spacing: Style.spacing.sm

          PanelActionButton {
            iconText: "\uf068"
            tooltipText: "Shorter"
            foreground: root.foreground
            hoverColor: root.accent
            fontFamily: root.fontFamily
            onClicked: root.adjustLength(-1)
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(38)
            text: root.length
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          PanelActionButton {
            iconText: "\uf067"
            tooltipText: "Longer"
            foreground: root.foreground
            hoverColor: root.accent
            fontFamily: root.fontFamily
            onClicked: root.adjustLength(1)
          }

          Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Symbols"
            selected: root.symbols
            visible: root.mode === "cryptic"
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            bordered: true
            onClicked: root.toggleSymbols()
          }

          Button {
            anchors.verticalCenter: parent.verticalCenter
            text: root.modeLabel()
            selected: root.mode !== "cryptic"
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            bordered: true
            onClicked: root.cycleMode()
          }
        }

        Text {
          width: parent.width
          visible: root.target === "entry" && root.entryPath !== ""
          text: root.entryPath
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideMiddle
        }

        Row {
          anchors.right: parent.right
          spacing: Style.spacing.sm

          Button {
            text: "Copy"
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            bordered: true
            onClicked: root.copyRequested()
          }

          Button {
            text: root.target === "form" ? "Use" : "Set password"
            visible: root.target !== "clipboard"
            width: visible ? implicitWidth : 0
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            bordered: true
            selected: true
            onClicked: root.useRequested()
          }
        }
      }
    }
  }
}
