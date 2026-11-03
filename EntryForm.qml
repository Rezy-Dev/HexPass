import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "Model.js" as Model

// New/edit entry form. It owns the fields so the panel only has to hand it a
// payload and take the result back.
Item {
  id: root

  property bool opened: false
  property string mode: "new"
  property string path: ""
  property string error: ""
  property bool saving: false
  property bool reveal: false
  property color foreground: Color.popups.text
  property color accent: Color.accent
  property color urgent: Color.urgent
  property color dim: Color.muted
  property string fontFamily: Style.font.family

  signal canceled()
  signal saveRequested(var payload)
  signal generateRequested()

  visible: opened
  z: 10

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      root.canceled()
      event.accepted = true
    }
  }

  function open(payload) {
    mode = payload.mode || "new"
    path = payload.path || ""
    error = ""
    saving = false
    reveal = false

    pathField.text = payload.path || ""
    usernameField.text = payload.username || ""
    passwordField.text = payload.password || ""
    urlField.text = payload.url || ""
    notesField.text = payload.notes || ""

    Qt.callLater(function() { root.focusField(0) })
  }

  function close() {
  }

  function showError(text) {
    error = String(text || "Could not save")
    saving = false
    Qt.callLater(function() { root.focusField(0) })
  }

  function setPassword(value) {
    passwordField.text = String(value || "")
    reveal = true
  }

  function hasPassword() {
    return passwordField.text !== ""
  }

  function fieldList() {
    if (mode === "new") return [pathField, usernameField, passwordField, urlField, notesField]
    return [usernameField, passwordField, urlField, notesField]
  }

  function focusField(index) {
    var fields = fieldList()
    if (fields.length === 0) return
    var next = ((index % fields.length) + fields.length) % fields.length
    fields[next].forceActiveFocus()
    fields[next].selectAll()
  }

  function fieldKey(event, field) {
    if (event.key === Qt.Key_Escape) {
      root.canceled()
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.save()
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      var fields = fieldList()
      var index = fields.indexOf(field)
      if (index === -1) index = 0
      root.focusField(index + (event.key === Qt.Key_Tab ? 1 : -1))
      event.accepted = true
    }
  }

  function save() {
    if (saving) return
    var target = mode === "new" ? pathField.text : path
    var pathError = Model.validatePath(target)
    if (pathError) {
      error = pathError
      return
    }
    if (!passwordField.text) {
      error = "A password is required"
      return
    }

    error = ""
    saving = true
    saveRequested({
      path: Model.normalizePath(target),
      username: usernameField.text.trim(),
      password: passwordField.text,
      url: urlField.text.trim(),
      notes: notesField.text
    })
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.72)

    MouseArea {
      anchors.fill: parent
      onClicked: root.canceled()
    }
  }

  BorderSurface {
    id: card

    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(32), Style.space(520))
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
          height: Math.max(formIcon.implicitHeight, formTitle.implicitHeight, formClose.implicitHeight)

          Text {
            id: formIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf084"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }

          Text {
            id: formTitle
            anchors.left: formIcon.right
            anchors.leftMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            text: root.mode === "new" ? "New entry" : "Edit entry"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          PanelActionButton {
            id: formClose
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "\uf00d"
            tooltipText: "Close"
            foreground: root.foreground
            hoverColor: root.accent
            fontFamily: root.fontFamily
            onClicked: root.canceled()
          }
        }

        Text {
          width: parent.width
          visible: root.mode !== "new"
          text: root.path
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideMiddle
        }

        TextField {
          id: pathField
          width: parent.width
          visible: root.mode === "new"
          placeholderText: "site.com/username"
          foreground: root.foreground
          accent: root.accent
          font.family: root.fontFamily
          Keys.onPressed: function(event) { root.fieldKey(event, pathField) }
        }

        TextField {
          id: usernameField
          width: parent.width
          placeholderText: "username"
          foreground: root.foreground
          accent: root.accent
          font.family: root.fontFamily
          Keys.onPressed: function(event) { root.fieldKey(event, usernameField) }
        }

        Row {
          width: parent.width
          spacing: Style.spacing.xs

          TextField {
            id: passwordField
            width: parent.width - generateButton.width - revealButton.width - parent.spacing * 2
            placeholderText: "password"
            password: !root.reveal
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            Keys.onPressed: function(event) { root.fieldKey(event, passwordField) }
          }

          PanelActionButton {
            id: generateButton
            iconText: "\uf0d0"
            tooltipText: "Generate"
            foreground: root.foreground
            hoverColor: root.accent
            fontFamily: root.fontFamily
            onClicked: root.generateRequested()
          }

          PanelActionButton {
            id: revealButton
            iconText: root.reveal ? "\uf070" : "\uf06e"
            tooltipText: root.reveal ? "Hide" : "Reveal"
            foreground: root.foreground
            hoverColor: root.accent
            fontFamily: root.fontFamily
            onClicked: root.reveal = !root.reveal
          }
        }

        TextField {
          id: urlField
          width: parent.width
          placeholderText: "url"
          foreground: root.foreground
          accent: root.accent
          font.family: root.fontFamily
          Keys.onPressed: function(event) { root.fieldKey(event, urlField) }
        }

        QQC.TextArea {
          id: notesField
          width: parent.width
          height: Style.space(64)
          placeholderText: "notes"
          color: root.foreground
          placeholderTextColor: Qt.darker(root.foreground, 1.6)
          selectionColor: Style.selectionFillFor(root.foreground, root.accent)
          selectedTextColor: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: TextEdit.Wrap
          leftPadding: Style.spacing.controlPaddingX
          rightPadding: Style.spacing.controlPaddingX
          topPadding: Style.spacing.controlPaddingY
          bottomPadding: Style.spacing.controlPaddingY
          background: BorderSurface {
            color: Util.alpha(root.foreground, 0.05)
            borderSpec: Border.controlSpec(notesField.activeFocus ? "focus" : "normal", root.foreground, root.accent)
            radius: Style.cornerRadius
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.canceled()
              event.accepted = true
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
              var fields = root.fieldList()
              var index = fields.indexOf(notesField)
              root.focusField(index + (event.key === Qt.Key_Tab ? 1 : -1))
              event.accepted = true
            }
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
          anchors.right: parent.right
          spacing: Style.spacing.sm

          Button {
            text: "Cancel"
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            bordered: true
            onClicked: root.canceled()
          }

          Button {
            text: root.saving ? "Saving" : "Save"
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            bordered: true
            selected: true
            enabled: !root.saving
            onClicked: root.save()
          }
        }
      }
    }
  }
}
