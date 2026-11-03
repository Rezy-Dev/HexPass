import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// HexPass: a gopass browser for the Omarchy bar. The bar icon opens a
// searchable list; the right pane decrypts the selected entry on demand.
Panel {
  id: root

  moduleName: "rezydev.hexpass"
  ipcTarget: "rezydev.hexpass"
  manageIpc: false

  implicitWidth: barSlot.implicitWidth
  implicitHeight: barSlot.implicitHeight

  readonly property int panelWidth: Style.space(760)
  readonly property int panelHeight: Style.space(520)
  readonly property int listWidth: Style.space(292)
  readonly property int rowHeight: Style.space(46)

  property string filter: ""
  property int cursor: 0
  property bool revealPassword: false

  property string notice: ""
  property bool noticeIsError: false

  property bool formOpen: false
  property bool generatorOpen: false
  property bool settingsOpen: false
  property bool deleteOpen: false
  property string pendingDelete: ""
  property bool pendingEdit: false
  property string pendingSelectPath: ""

  property int genLength: 24
  property bool genSymbols: true
  property string genMode: "cryptic"
  property string genTarget: "clipboard"

  readonly property color foreground: Color.popups.text
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color dim: Color.muted
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool syncOnOpen: {
    var value = setting("syncOnOpen", false)
    return value === true || value === "true" || value === 1 || value === "1"
  }
  readonly property int clipboardClear: Model.clipboardSeconds(setting("clipboardClear", 45))
  readonly property int defaultLength: clampLength(setting("genLength", 24))
  readonly property bool defaultSymbols: setting("genSymbols", true) !== false
  readonly property string defaultMode: {
    var value = String(setting("genMode", "cryptic"))
    return ["cryptic", "xkcd", "memorable"].indexOf(value) >= 0 ? value : "cryptic"
  }

  readonly property var visibleEntries: Model.filterEntries(controller.entries, filter)
  readonly property int selectedIndex: visibleEntries.length > 0
    ? Math.max(0, Math.min(cursor, visibleEntries.length - 1))
    : -1
  readonly property var selectedRow: selectedIndex >= 0 ? visibleEntries[selectedIndex] : null
  readonly property string selectedPath: selectedRow ? selectedRow.path : ""

  readonly property var detail: controller.detail && controller.detail.path === selectedPath
    ? controller.detail
    : null
  readonly property bool detailLoading: controller.detailLoading && controller.detailPath === selectedPath
  readonly property string detailError: controller.detailPath === selectedPath ? controller.detailError : ""
  readonly property var otp: controller.otp && controller.otp.path === selectedPath ? controller.otp : null

  // ------------------------------------------------------------------ setup

  Component.onCompleted: {
    controller.clipboardClearSeconds = clipboardClear
    genLength = defaultLength
    genSymbols = defaultSymbols
    genMode = defaultMode
  }

  onOpenedChanged: {
    if (opened) {
      filter = ""
      searchField.text = ""
      cursor = 0
      revealPassword = false
      notice = ""
      noticeIsError = false
      formOpen = false
      generatorOpen = false
      settingsOpen = false
      deleteOpen = false
      pendingDelete = ""
      pendingEdit = false
      pendingSelectPath = ""

      controller.clipboardClearSeconds = clipboardClear
      genLength = defaultLength
      genSymbols = defaultSymbols
      genMode = defaultMode
      controller.activate(syncOnOpen)
      refocus()
      scheduleDetail()
    } else {
      formOpen = false
      generatorOpen = false
      settingsOpen = false
      deleteOpen = false
      pendingDelete = ""
      pendingEdit = false
      controller.clearDetail()
    }
  }

  onSettingsChanged: {
    controller.clipboardClearSeconds = clipboardClear
  }

  onVisibleEntriesChanged: clampCursor()
  onCursorChanged: if (listView) listView.positionViewAtIndex(cursor, ListView.Contain)
  onSelectedPathChanged: {
    revealPassword = false
    if (opened) scheduleDetail()
  }

  function clampLength(value) {
    var length = Number(value)
    if (!isFinite(length)) return 24
    return Math.max(8, Math.min(128, Math.round(length)))
  }

  function clampCursor() {
    if (visibleEntries.length === 0) {
      cursor = 0
      return
    }
    cursor = Math.max(0, Math.min(cursor, visibleEntries.length - 1))
  }

  function scheduleDetail() {
    detailTimer.restart()
  }

  function refocus() {
    Qt.callLater(function() {
      if (!root.opened) return
      if (root.formOpen) form.focusField(0)
      else if (root.generatorOpen) generator.forceActiveFocus()
      else if (root.settingsOpen) settingsView.forceActiveFocus()
      else searchField.forceActiveFocus()
    })
  }

  function showNotice(text, isError) {
    notice = String(text || "")
    noticeIsError = !!isError
    noticeTimer.interval = isError ? 6000 : 3500
    noticeTimer.restart()
  }

  function clearFilter() {
    searchField.text = ""
    filter = ""
    cursor = 0
  }

  function moveCursor(delta) {
    if (visibleEntries.length === 0) return
    cursor = Math.max(0, Math.min(visibleEntries.length - 1, cursor + delta))
  }

  function copySelectedPassword() {
    if (!selectedPath) return
    controller.copyPassword(selectedPath)
  }

  function copySelectedUsername() {
    if (!selectedPath) return
    controller.copyField(selectedPath, "username", "username")
  }

  function copySelectedUrl() {
    if (!selectedPath) return
    controller.copyField(selectedPath, "url", "url")
  }

  function copySelectedOtp() {
    if (!selectedPath) return
    controller.copyOtp(selectedPath)
  }

  function openSelectedUrl() {
    if (!detail || !detail.url) return
    Quickshell.execDetached(["xdg-open", detail.url])
  }

  function openNewForm() {
    form.open({
      mode: "new",
      path: "",
      username: "",
      password: "",
      url: "",
      notes: ""
    })
    formOpen = true
    refocus()

    controller.generate({ length: genLength, symbols: genSymbols, mode: genMode }, function(value, error) {
      if (!root.formOpen || form.mode !== "new" || form.hasPassword()) return
      if (value) form.setPassword(value)
    })
  }

  function openEditForm() {
    if (!selectedPath) return
    if (!detail) {
      pendingEdit = true
      controller.loadDetail(selectedPath, true)
      return
    }

    form.open({
      mode: "edit",
      path: detail.path,
      username: detail.username,
      password: detail.password,
      url: detail.url,
      notes: detail.formNotes
    })
    formOpen = true
    refocus()
  }

  function openGenerator(target) {
    var mode = target || "clipboard"
    if (mode === "entry" && !selectedPath) mode = "clipboard"
    if (mode === "form" && !formOpen) mode = "clipboard"

    genTarget = mode
    generator.open(mode, selectedPath, genLength, genSymbols, genMode)
    generatorOpen = true
    generator.loading = true
    generateCurrent()
    refocus()
  }

  function generateCurrent() {
    generator.loading = true
    controller.generate({ length: genLength, symbols: genSymbols, mode: genMode }, function(value, error) {
      if (!root.generatorOpen) return
      if (value) generator.setOutput(value)
      else generator.showError(error)
    })
  }

  function applyGenerated() {
    var value = generator.output
    if (!value) {
      showNotice("Generate a password first", true)
      return
    }

    if (genTarget === "form") {
      form.setPassword(value)
      generatorOpen = false
      refocus()
      return
    }

    if (genTarget === "entry") {
      controller.setPassword(selectedPath, { length: genLength, symbols: genSymbols, mode: genMode }, function(ok) {
        if (!ok) return
        generatorOpen = false
        refocus()
      })
      return
    }

    controller.copyValue(value, "password")
  }

  function copyGenerated() {
    if (!generator.output) {
      showNotice("Generate a password first", true)
      return
    }
    controller.copyValue(generator.output, "password")
  }

  function requestDelete() {
    if (!selectedPath) return
    pendingDelete = selectedPath
    deleteOpen = true
    deleteDialog.selectedIndex = 0
    Qt.callLater(function() { deleteDialog.forceActiveFocus() })
  }

  function confirmDelete() {
    var path = pendingDelete
    deleteOpen = false
    pendingDelete = ""
    if (!path) return
    controller.deleteEntry(path, function(ok) {
      if (ok) pendingSelectPath = ""
      refocus()
    })
  }

  function cancelDelete() {
    deleteOpen = false
    pendingDelete = ""
    refocus()
  }

  function selectPath(path) {
    pendingSelectPath = path
    applyPendingSelection()
  }

  function applyPendingSelection() {
    if (!pendingSelectPath) return
    for (var i = 0; i < visibleEntries.length; i++) {
      if (visibleEntries[i].path === pendingSelectPath) {
        cursor = i
        pendingSelectPath = ""
        return
      }
    }
  }

  function persist(values) {
    var entry = { id: root.moduleName }
    var current = root.settings || ({})
    for (var existing in current) {
      if (existing !== "id") entry[existing] = current[existing]
    }
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function cycleClipboard() {
    var options = [0, 15, 30, 45, 60, 120, 300]
    var index = options.indexOf(clipboardClear)
    var next = options[(index + 1) % options.length]
    persist({ clipboardClear: next })
    controller.clipboardClearSeconds = next
  }

  function cycleLength() {
    var options = [16, 20, 24, 32, 40, 48, 64, 96, 128]
    var index = options.indexOf(genLength)
    var next = options[(index + 1) % options.length]
    genLength = next
    persist({ genLength: next })
  }

  function toggleSyncOnOpen() {
    persist({ syncOnOpen: !syncOnOpen })
  }

  function openCredit() {
    Quickshell.execDetached(["xdg-open", "https://rezydev.com/"])
  }

  function gitLabel() {
    if (!controller.branch) return ""
    var text = controller.branch
    if (controller.ahead > 0) text += "  \u2191" + controller.ahead
    if (controller.behind > 0) text += "  \u2193" + controller.behind
    if (controller.dirty) text += "  \u2022"
    return text
  }

  // ---------------------------------------------------------------- keyboard

  function handleSearchKey(event) {
    if (formOpen || generatorOpen || settingsOpen || deleteOpen) return

    if (event.key === Qt.Key_Escape) {
      if (filter) clearFilter()
      else close()
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      switchPanel((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Down) { moveCursor(1); event.accepted = true; return }
    if (event.key === Qt.Key_Up) { moveCursor(-1); event.accepted = true; return }
    if (event.key === Qt.Key_PageDown) { moveCursor(10); event.accepted = true; return }
    if (event.key === Qt.Key_PageUp) { moveCursor(-10); event.accepted = true; return }
    if (event.key === Qt.Key_Home) { cursor = 0; event.accepted = true; return }
    if (event.key === Qt.Key_End) { cursor = Math.max(0, visibleEntries.length - 1); event.accepted = true; return }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      copySelectedPassword()
      event.accepted = true
      return
    }

    if (event.modifiers & Qt.ControlModifier) {
      if (event.key === Qt.Key_U) { copySelectedUsername(); event.accepted = true; return }
      if (event.key === Qt.Key_O) { copySelectedOtp(); event.accepted = true; return }
      if (event.key === Qt.Key_R) { revealPassword = !revealPassword; event.accepted = true; return }
      if (event.key === Qt.Key_N) { openNewForm(); event.accepted = true; return }
      if (event.key === Qt.Key_G) { openGenerator(selectedPath ? "entry" : "clipboard"); event.accepted = true; return }
      if (event.key === Qt.Key_S) { controller.sync(); event.accepted = true; return }
      if (event.key === Qt.Key_E) { openEditForm(); event.accepted = true; return }
      if (event.key === Qt.Key_D) { requestDelete(); event.accepted = true; return }
    }
  }

  // ---------------------------------------------------------------- processes

  GopassController {
    id: controller
  }

  IpcHandler {
    target: root.ipcTarget

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function refresh() { controller.refresh(); controller.refreshGit() }
    function sync() { controller.sync() }
    function copyPassword(path: string) { controller.copyPassword(path) }
  }

  Connections {
    target: controller

    function onNotice(text, isError) { root.showNotice(text, isError) }

    function onListChanged() {
      root.clampCursor()
      root.scheduleDetail()
      Qt.callLater(root.applyPendingSelection)
    }

    function onDetailLoaded() {
      if (root.pendingEdit && (root.detail || root.detailError)) {
        root.pendingEdit = false
        if (root.detail) Qt.callLater(root.openEditForm)
      }
    }
  }

  Timer {
    id: detailTimer
    interval: 220
    repeat: false
    onTriggered: if (root.opened) controller.loadDetail(root.selectedPath)
  }

  Timer {
    id: noticeTimer
    interval: 3500
    repeat: false
    onTriggered: root.notice = ""
  }

  // -------------------------------------------------------------------- bar

  BarSlot {
    id: barSlot
    anchors.fill: parent
    panel: root
  }

  KeyboardPanel {
    id: panel

    anchorItem: barSlot
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: searchField
    centerOnBar: false
    contentWidth: panel.fittedContentWidth(root.panelWidth)
    contentHeight: panel.fittedContentHeight(root.panelHeight)

    Item {
      id: content

      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (root.deleteOpen) {
          if (deleteDialog.handleKey(event)) event.accepted = true
          return
        }
        if (root.formOpen || root.generatorOpen || root.settingsOpen) return
        if (event.key === Qt.Key_Escape) {
          if (root.filter) root.clearFilter()
          else root.close()
          event.accepted = true
        } else if (event.key === Qt.Key_Down) {
          root.moveCursor(1)
          event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          root.moveCursor(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.copySelectedPassword()
          event.accepted = true
        }
      }

      ColumnLayout {
        anchors.fill: parent
        spacing: Style.spacing.md

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(headerTitle.implicitHeight, headerActions.implicitHeight) + Style.spacing.xs

          Row {
            id: headerTitle
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.sm

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf084"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Passwords"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.filter
                ? root.visibleEntries.length + "/" + controller.entries.length
                : String(controller.entries.length)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            id: headerActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xxs

            PanelActionButton {
              iconText: "\uf067"
              tooltipText: "New entry"
              foreground: root.foreground
              hoverColor: root.accent
              fontFamily: root.fontFamily
              onClicked: root.openNewForm()
            }

            PanelActionButton {
              iconText: "\uf0d0"
              tooltipText: "Generate"
              foreground: root.foreground
              hoverColor: root.accent
              fontFamily: root.fontFamily
              onClicked: root.openGenerator(root.selectedPath ? "entry" : "clipboard")
            }

            PanelActionButton {
              iconText: controller.syncing ? "\uf110" : "\uf021"
              tooltipText: controller.remote ? "Sync with " + controller.remote : "Sync with git"
              foreground: controller.syncing ? root.accent : root.foreground
              hoverColor: root.accent
              fontFamily: root.fontFamily
              onClicked: controller.sync()
            }

            PanelActionButton {
              iconText: "\uf013"
              tooltipText: "Settings"
              foreground: root.settingsOpen ? root.accent : root.foreground
              hoverColor: root.accent
              fontFamily: root.fontFamily
              onClicked: {
                root.settingsOpen = true
                settingsView.open()
                root.refocus()
              }
            }
          }
        }

        TextField {
          id: searchField

          Layout.fillWidth: true
          placeholderText: "Search"
          foreground: root.foreground
          accent: root.accent
          font.family: root.fontFamily
          onTextChanged: {
            if (root.filter !== text) {
              root.filter = text
              root.cursor = 0
            }
          }
          Keys.onPressed: function(event) { root.handleSearchKey(event) }
        }

        Text {
          Layout.fillWidth: true
          Layout.preferredHeight: visible ? implicitHeight : 0
          visible: root.notice !== ""
          text: root.notice
          color: root.noticeIsError ? root.urgent : root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.spacing.lg

          Rectangle {
            Layout.preferredWidth: root.listWidth
            Layout.minimumWidth: Style.space(180)
            Layout.fillHeight: true
            radius: Style.cornerRadius
            color: Util.alpha(root.foreground, 0.035)

            ListView {
              id: listView

              anchors.fill: parent
              anchors.margins: Style.spacing.xs
              clip: true
              spacing: Style.spacing.xxs
              boundsBehavior: Flickable.StopAtBounds
              model: root.visibleEntries

              delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                width: listView.width
                height: root.rowHeight
                radius: Style.cornerRadius
                color: index === root.selectedIndex
                  ? Util.alpha(root.accent, 0.14)
                  : (rowMouse.containsMouse ? Util.alpha(root.foreground, 0.06) : "transparent")

                Column {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.leftMargin: Style.spacing.md
                  anchors.rightMargin: Style.spacing.sm
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.spacing.xxs

                  Text {
                    width: parent.width
                    text: row.modelData.title
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: row.index === root.selectedIndex
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    visible: row.modelData.folder !== ""
                    text: row.modelData.folder
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.cursor = row.index
                    root.scheduleDetail()
                  }
                  onDoubleClicked: {
                    root.cursor = row.index
                    root.copySelectedPassword()
                  }
                }
              }
            }

            Text {
              anchors.centerIn: parent
              width: parent.width - Style.spacing.lg * 2
              visible: root.visibleEntries.length === 0
              text: controller.listLoading
                ? "\u2026"
                : (controller.listError !== ""
                  ? controller.listError
                  : (root.filter ? "No matches" : "No entries"))
              color: controller.listError !== "" ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }
          }

          Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Util.alpha(root.foreground, 0.1)
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0

            Flickable {
              id: detailFlick

              anchors.fill: parent
              contentWidth: width
              contentHeight: detailColumn.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              interactive: contentHeight > height

              Column {
                id: detailColumn

                width: detailFlick.width
                spacing: Style.spacing.sm

                Item {
                  width: parent.width
                  height: Math.max(pathText.implicitHeight, pathActions.implicitHeight)

                  Text {
                    id: pathText
                    anchors.left: parent.left
                    anchors.right: pathActions.left
                    anchors.rightMargin: Style.spacing.sm
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.selectedPath !== ""
                    text: root.selectedPath
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideMiddle
                  }

                  Row {
                    id: pathActions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacing.xxs

                    PanelActionButton {
                      visible: root.detail !== null
                      iconText: "\uf044"
                      tooltipText: "Edit"
                      foreground: root.foreground
                      hoverColor: root.accent
                      fontFamily: root.fontFamily
                      onClicked: root.openEditForm()
                    }

                    PanelActionButton {
                      visible: root.selectedPath !== ""
                      iconText: "\uf1f8"
                      tooltipText: "Delete"
                      foreground: root.foreground
                      hoverColor: root.urgent
                      fontFamily: root.fontFamily
                      onClicked: root.requestDelete()
                    }
                  }
                }

                Text {
                  width: parent.width
                  visible: root.selectedPath === ""
                  text: "Select an entry"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  topPadding: Style.spacing.huge
                }

                Text {
                  width: parent.width
                  visible: root.selectedPath !== "" && root.detailLoading
                  text: "\u2026"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  width: parent.width
                  visible: root.detailError !== ""
                  text: root.detailError
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }

                DetailRow {
                  visible: root.detail !== null && root.detail.password !== ""
                  icon: "\uf084"
                  value: root.revealPassword
                    ? root.detail.password
                    : Model.maskPassword(root.detail ? root.detail.password : "")
                  secret: true
                  revealed: root.revealPassword
                  revealable: true
                  foreground: root.foreground
                  accent: root.accent
                  dim: root.dim
                  fontFamily: root.fontFamily
                  onCopyRequested: root.copySelectedPassword()
                  onRevealRequested: root.revealPassword = !root.revealPassword
                }

                DetailRow {
                  visible: root.detail !== null && root.detail.username !== ""
                  icon: "\uf007"
                  value: root.detail ? root.detail.username : ""
                  foreground: root.foreground
                  accent: root.accent
                  dim: root.dim
                  fontFamily: root.fontFamily
                  onCopyRequested: root.copySelectedUsername()
                }

                DetailRow {
                  visible: root.detail !== null && root.detail.url !== ""
                  icon: "\uf0ac"
                  value: root.detail ? root.detail.url : ""
                  openable: true
                  foreground: root.foreground
                  accent: root.accent
                  dim: root.dim
                  fontFamily: root.fontFamily
                  onCopyRequested: root.copySelectedUrl()
                  onOpenRequested: root.openSelectedUrl()
                }

                Item {
                  width: parent.width
                  height: Math.max(otpIcon.implicitHeight, otpCode.implicitHeight, otpCopy.implicitHeight)
                  visible: root.detail !== null && root.detail.otpUrl !== ""

                  Text {
                    id: otpIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(18)
                    text: "\uf017"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }

                  Text {
                    id: otpCode
                    anchors.left: otpIcon.right
                    anchors.leftMargin: Style.spacing.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.otp && root.otp.code
                      ? Model.formatOtp(root.otp.code)
                      : (root.otp && root.otp.error ? "\u2014" : "\u2026")
                    color: root.otp && root.otp.error ? root.urgent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.letterSpacing: Style.space(1)
                  }

                  Text {
                    anchors.left: otpCode.right
                    anchors.leftMargin: Style.spacing.md
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.otp && root.otp.type === "totp"
                      ? controller.otpRemaining + "s"
                      : "HOTP"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  PanelActionButton {
                    id: otpCopy
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: root.otp !== null && root.otp.code !== ""
                    iconText: "\uf0c5"
                    tooltipText: "Copy code"
                    foreground: root.foreground
                    hoverColor: root.accent
                    fontFamily: root.fontFamily
                    onClicked: root.copySelectedOtp()
                  }
                }

                Item {
                  width: parent.width
                  height: notesText.implicitHeight
                  visible: root.detail !== null && root.detail.notes !== ""

                  Text {
                    id: notesIcon
                    anchors.left: parent.left
                    anchors.top: parent.top
                    width: Style.space(18)
                    text: "\uf15c"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }

                  Text {
                    id: notesText
                    anchors.left: notesIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: Style.spacing.sm
                    anchors.top: parent.top
                    text: root.detail ? root.detail.notes : ""
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    wrapMode: Text.WordWrap
                  }
                }

                Repeater {
                  model: root.detail ? root.detail.extras : []

                  DetailRow {
                    required property var modelData

                    icon: "\uf02b"
                    value: modelData.label + ": " + modelData.value
                    foreground: root.foreground
                    accent: root.accent
                    dim: root.dim
                    fontFamily: root.fontFamily
                    onCopyRequested: controller.copyValue(modelData.value, modelData.label)
                  }
                }
              }
            }
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(hintText.implicitHeight, gitText.implicitHeight, creditText.implicitHeight)

          Text {
            id: hintText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - creditText.width - (gitText.visible ? gitText.width : 0) - Style.spacing.xxl * 2)
            text: "\u21b5 copy   ^N new   ^G generate   ^S sync"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Text {
            id: gitText
            anchors.right: creditText.left
            anchors.rightMargin: Style.spacing.xxl
            anchors.verticalCenter: parent.verticalCenter
            visible: root.gitLabel() !== ""
            text: root.gitLabel()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            id: creditText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "rezydev.com"
            color: creditMouse.containsMouse ? root.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: creditMouse
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: creditText.width
            height: creditText.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openCredit()
          }
        }
      }

      EntryForm {
        id: form

        anchors.fill: parent
        opened: root.formOpen
        foreground: root.foreground
        accent: root.accent
        urgent: root.urgent
        dim: root.dim
        fontFamily: root.fontFamily

        onCanceled: {
          root.formOpen = false
          root.refocus()
        }
        onSaveRequested: function(payload) {
          form.saving = true
          controller.saveEntry(payload, function(ok, message) {
            if (!ok) {
              form.showError(message)
              return
            }
            root.formOpen = false
            root.clearFilter()
            root.selectPath(payload.path)
            root.refocus()
          })
        }
        onGenerateRequested: root.openGenerator("form")
      }

      Generator {
        id: generator

        anchors.fill: parent
        opened: root.generatorOpen
        foreground: root.foreground
        accent: root.accent
        urgent: root.urgent
        dim: root.dim
        fontFamily: root.fontFamily

        onClosed: {
          root.generatorOpen = false
          root.refocus()
        }
        onOptionsChanged: {
          root.genLength = generator.length
          root.genSymbols = generator.symbols
          root.genMode = generator.mode
          root.persist({ genLength: root.genLength, genSymbols: root.genSymbols, genMode: root.genMode })
          root.generateCurrent()
        }
        onCopyRequested: root.copyGenerated()
        onUseRequested: root.applyGenerated()
      }

      SettingsView {
        id: settingsView

        anchors.fill: parent
        opened: root.settingsOpen
        syncOnOpen: root.syncOnOpen
        clipboardClear: root.clipboardClear
        genLength: root.genLength
        storePath: controller.storePath
        remote: controller.remote
        branch: controller.branch
        ahead: controller.ahead
        behind: controller.behind
        dirty: controller.dirty
        lastCommit: controller.lastCommit
        foreground: root.foreground
        accent: root.accent
        dim: root.dim
        fontFamily: root.fontFamily

        onClosed: {
          root.settingsOpen = false
          root.refocus()
        }
        onToggleSync: root.toggleSyncOnOpen()
        onCycleClipboard: root.cycleClipboard()
        onCycleLength: root.cycleLength()
        onOpenStore: controller.openStore()
        onMaintenance: function(action) { controller.runMaintenance(action, root.selectedPath) }
        onOpenCredit: root.openCredit()
      }

      ConfirmDialog {
        id: deleteDialog

        anchors.fill: parent
        z: 20
        opened: root.deleteOpen
        message: root.pendingDelete
          ? "Delete " + (root.selectedRow ? root.selectedRow.title : root.pendingDelete)
            + "?\n" + root.pendingDelete
          : ""
        confirmText: "Delete"
        background: Color.popups.background
        foreground: root.foreground
        selectedText: root.urgent
        fontFamily: root.fontFamily
        cornerRadius: Style.cornerRadius
        onCanceled: root.cancelDelete()
        onConfirmed: root.confirmDelete()
      }
    }
  }
}
