import QtQuick
import Quickshell
import qs.Commons
import "Model.js" as Model

// Owns every gopass process. The panel asks for data and actions; this file
// keeps the reads coalesced and the writes serialized so a quick arrow-key
// run cannot leave a stale decryption on screen.
Item {
  id: root

  visible: false
  width: 0
  height: 0

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string gopass: Quickshell.env("GOPASS_BIN") || "gopass"
  readonly property string storeFallback: home + "/.local/share/gopass/stores/root"

  property int clipboardClearSeconds: 45

  property var entries: []
  property bool listLoading: false
  property string listError: ""

  property var detail: null
  property string detailPath: ""
  property bool detailLoading: false
  property string detailError: ""

  property var otp: null
  property string otpPath: ""
  property bool otpLoading: false
  property int otpRemaining: 0
  property int otpFetchedWindow: -1

  property string generated: ""
  property bool generateLoading: false

  property bool syncing: false
  property bool saving: false
  property bool deleting: false

  property string storePath: ""
  property int gitRunningCount: 0
  property bool gitQueued: false
  property string remote: ""
  property string branch: ""
  property int ahead: 0
  property int behind: 0
  property bool dirty: false
  property string lastCommit: ""

  readonly property bool busy: listLoading || detailLoading || otpLoading
    || generateLoading || syncing || saving || deleting

  signal notice(string text, bool isError)
  signal listChanged()
  signal detailLoaded()
  signal otpLoaded()
  signal gitChanged()

  // ---------------------------------------------------------------- public

  function activate(syncOnOpen) {
    refreshGit()
    if (syncOnOpen) sync()
    else refresh()
  }

  function refresh() {
    if (listProc.running) {
      listQueued = true
      return
    }

    listLoading = true
    listError = ""
    listProc.start([gopass, "ls", "--json", "--nosync"])
  }

  function loadDetail(path, force) {
    if (!path) {
      clearDetail()
      return
    }
    if (!force && path === detailPath && detail && !detailError) return

    detailPath = path
    detailLoading = true
    detailError = ""
    detail = null
    detailLoaded()

    if (detailProc.running) return
    startDetail(path)
  }

  function clearDetail() {
    detailPath = ""
    detail = null
    detailLoading = false
    detailError = ""
    clearOtp()
    detailLoaded()
  }

  function copyPassword(path) {
    withEntry(path, function(entry, error) {
      if (!entry) {
        root.notice(error || "Could not read entry", true)
        return
      }
      root.copyValue(entry.password, "password")
    })
  }

  function copyField(path, field, label) {
    withEntry(path, function(entry, error) {
      if (!entry) {
        root.notice(error || "Could not read entry", true)
        return
      }
      var value = entry[field] || ""
      if (!value) {
        root.notice("No " + (label || field), true)
        return
      }
      root.copyValue(value, label || field)
    })
  }

  function copyOtp(path) {
    if (otp && otp.path === path && otp.code) {
      var fresh = otp.type !== "totp" || Model.otpWindow(otp.period) === otpFetchedWindow
      if (fresh) {
        copyValue(otp.code, "code")
        return
      }
    }
    loadOtp(path, function(code, error) {
      if (!code) {
        root.notice(error || "No code for this entry", true)
        return
      }
      root.copyValue(code, "code")
    })
  }

  function saveEntry(payload, callback) {
    var path = Model.normalizePath(payload.path)
    var error = Model.validatePath(path)
    if (error) {
      if (callback) callback(false, error)
      return
    }
    if (insertProc.running) return

    var content = Model.buildSecret(payload.password, payload.username, payload.url, payload.notes)
    saving = true
    insertStartedPath = path
    insertCallback = function(code, output, stderr) {
      root.saving = false
      if (code === 0) {
        root.notice("Saved " + path, false)
        root.refresh()
        root.refreshGit()
        root.loadDetail(path, true)
        if (callback) callback(true, "")
        return
      }
      var message = Model.cleanError(stderr) || "Could not save entry"
      root.notice(message, true)
      if (callback) callback(false, message)
    }

    insertProc.start([gopass, "--yes", "insert", "--force", path], content)
  }

  function deleteEntry(path, callback) {
    if (!path) return
    deleting = true
    enqueue([gopass, "--yes", "delete", "--force", path], function(code, output, stderr) {
      root.deleting = false
      if (code === 0) {
        root.notice("Deleted " + path, false)
        if (root.detailPath === path) root.clearDetail()
        root.refresh()
        root.refreshGit()
        if (callback) callback(true)
        return
      }
      root.notice(Model.cleanError(stderr) || "Could not delete entry", true)
      if (callback) callback(false)
    })
  }

  function sync(callback) {
    if (syncing) return
    syncing = true
    enqueue([gopass, "sync"], function(code, output, stderr) {
      root.syncing = false
      if (code === 0) {
        root.notice("Synced", false)
        root.refresh()
        root.refreshGit()
        if (root.detailPath) root.loadDetail(root.detailPath, true)
        if (callback) callback(true)
        return
      }
      root.notice(Model.cleanError(stderr) || "Sync failed", true)
      if (callback) callback(false)
    })
  }

  function generate(options, callback) {
    var request = {
      length: clampLength(options.length),
      symbols: options.symbols === true,
      mode: options.mode || "cryptic"
    }
    if (genProc.running) {
      genPending = { options: request, callback: callback }
      return
    }
    startGenerate(request, callback)
  }

  function setPassword(path, options, callback) {
    if (!path) return
    var request = {
      length: clampLength(options.length),
      symbols: options.symbols === true,
      mode: options.mode || "cryptic"
    }

    var command = [gopass, "--yes", "generate", "--print", "--force"]
    if (request.symbols) command.push("--symbols")
    if (request.mode !== "cryptic") command.push("--generator", request.mode)
    command.push(path, String(request.length))

    enqueue(command, function(code, output, stderr) {
      if (code === 0) {
        root.notice("Password updated", false)
        root.loadDetail(path, true)
        root.refreshGit()
        if (callback) callback(true)
        return
      }
      root.notice(Model.cleanError(stderr) || "Could not generate password", true)
      if (callback) callback(false)
    })
  }

  function copyValue(value, label) {
    var text = String(value || "")
    if (!text) {
      notice("Nothing to copy", true)
      return false
    }

    Quickshell.execDetached(["bash", "-lc", "printf %s " + Util.shellQuote(text) + " | wl-copy --sensitive"])
    lastClipboard = text

    var seconds = Model.clipboardSeconds(clipboardClearSeconds)
    if (seconds > 0) {
      clipboardTimer.interval = seconds * 1000
      clipboardTimer.restart()
    } else {
      clipboardTimer.stop()
    }

    notice("Copied " + (label || "value"), false)
    return true
  }

  function openEditor(path) {
    if (!path) return
    Quickshell.execDetached(["omarchy-launch-terminal", "gopass", "edit", path])
  }

  function openStore() {
    if (!storePath) return
    Quickshell.execDetached(["xdg-open", storePath])
  }

  function runMaintenance(action, path) {
    var args = ["omarchy-launch-terminal", "gopass"]
    if (action === "history" && path) args.push("history", path)
    else args.push(action)
    Quickshell.execDetached(args)
  }

  function refreshGit() {
    if (storeProc.running) return
    storeProc.start([gopass, "config", "mounts.path"])
  }

  // -------------------------------------------------------------- internals

  property bool listQueued: false
  property var actionQueue: []
  property bool actionRunning: false
  property var actionCallback: null

  property var readQueue: []
  property bool readRunning: false
  property var readCallback: null
  property string readStartedPath: ""

  property var genPending: null
  property var genCallback: null
  property var insertCallback: null
  property string insertStartedPath: ""
  property string lastClipboard: ""

  property string detailStartedPath: ""
  property string otpStartedPath: ""
  property string otpPendingPath: ""
  property var otpCurrentCallback: null
  property var otpNextCallback: null

  function clampLength(value) {
    var length = Number(value)
    if (!isFinite(length)) return 24
    return Math.max(8, Math.min(128, Math.round(length)))
  }

  function startDetail(path) {
    detailStartedPath = path
    detailProc.start([gopass, "show", "--nosync", "--noparsing", "--unsafe", path])
  }

  function clearOtp() {
    otp = null
    otpPath = ""
    otpLoading = false
    otpRemaining = 0
    otpFetchedWindow = -1
    otpTimer.stop()
    otpLoaded()
  }

  function loadOtp(path, callback) {
    if (!path) {
      if (callback) callback("", "No entry selected")
      return
    }
    if (otpProc.running) {
      otpPendingPath = path
      otpNextCallback = callback
      return
    }
    startOtp(path, callback)
  }

  function startOtp(path, callback) {
    otpPath = path
    otpLoading = true
    otpCurrentCallback = callback
    otpStartedPath = path
    otpProc.start([gopass, "otp", "--nosync", "--password", path])
  }

  function withEntry(path, callback) {
    if (detail && detail.path === path && !detailError) {
      callback(detail, "")
      return
    }
    readQueue.push({ path: path, callback: callback })
    pumpRead()
  }

  function pumpRead() {
    if (readRunning || readQueue.length === 0) return
    var job = readQueue.shift()
    readRunning = true
    readCallback = job.callback
    readStartedPath = job.path
    readProc.start([gopass, "show", "--nosync", "--noparsing", "--unsafe", job.path])
  }

  function enqueue(command, callback) {
    actionQueue.push({ command: command, callback: callback })
    pumpAction()
  }

  function pumpAction() {
    if (actionRunning || actionQueue.length === 0) return
    var job = actionQueue.shift()
    actionRunning = true
    actionCallback = job.callback
    actionProc.start(job.command)
  }

  function startGenerate(request, callback) {
    var command = [gopass, "pwgen"]
    if (request.symbols) command.push("-y")
    if (request.mode === "xkcd") command.push("-x")
    else if (request.mode === "memorable") command.push("-m")
    command.push(String(request.length), "1")

    generateLoading = true
    genCallback = callback
    genProc.start(command)
  }

  function finishGenerate(code, output, stderr) {
    generateLoading = false
    var callback = genCallback
    genCallback = null

    if (code === 0) {
      var value = String(output || "").trim().split("\n")[0].trim()
      generated = value
      if (callback) callback(value, "")
    } else {
      var message = Model.cleanError(stderr) || "Generator failed"
      notice(message, true)
      if (callback) callback("", message)
    }

    if (genPending) {
      var pending = genPending
      genPending = null
      startGenerate(pending.options, pending.callback)
    }
  }

  function startGit() {
    if (!storePath) return
    if (gitRunningCount > 0) {
      gitQueued = true
      return
    }

    gitRunningCount = 3
    gitProc.start(["git", "-C", storePath, "status", "--porcelain=v1", "--branch"])
    remoteProc.start(["git", "-C", storePath, "remote", "get-url", "origin"])
    logProc.start(["git", "-C", storePath, "log", "-1", "--format=%cr"])
  }

  function finishGit() {
    gitRunningCount = Math.max(0, gitRunningCount - 1)
    if (gitRunningCount === 0 && gitQueued) {
      gitQueued = false
      startGit()
    }
  }

  // --------------------------------------------------------------- processes

  GopassProcess {
    id: listProc

    onFinished: function(code, output, stderr) {
      root.listLoading = false
      if (code !== 0) {
        root.listError = Model.cleanError(stderr) || "Could not list entries"
        root.notice(root.listError, true)
      } else {
        root.entries = Model.parseList(output)
        root.listError = ""
        root.listChanged()
      }

      if (root.listQueued) {
        root.listQueued = false
        root.refresh()
      }
    }
  }

  GopassProcess {
    id: detailProc

    onFinished: function(code, output, stderr) {
      root.detailLoading = false

      if (root.detailStartedPath !== root.detailPath) {
        if (root.detailPath) {
          root.detailLoading = true
          root.startDetail(root.detailPath)
        }
        return
      }
      if (!root.detailPath) return

      if (code !== 0) {
        root.detail = null
        root.detailError = Model.cleanError(stderr) || "Could not read entry"
        root.clearOtp()
        root.detailLoaded()
        return
      }

      var entry = Model.parseEntry(output, root.detailPath)
      root.detail = entry
      root.detailError = ""
      root.detailLoaded()

      if (entry.otpUrl) root.loadOtp(entry.path)
      else root.clearOtp()
    }
  }

  GopassProcess {
    id: readProc

    onFinished: function(code, output, stderr) {
      var callback = root.readCallback
      root.readCallback = null
      root.readRunning = false

      if (callback) {
        if (code === 0) callback(Model.parseEntry(output, root.readStartedPath), "")
        else callback(null, Model.cleanError(stderr) || "Could not read entry")
      }
      root.pumpRead()
    }
  }

  GopassProcess {
    id: otpProc

    onFinished: function(code, output, stderr) {
      root.otpLoading = false

      if (root.otpStartedPath === root.otpPath) {
        var callback = root.otpCurrentCallback
        root.otpCurrentCallback = null

        if (code !== 0) {
          root.otp = { path: root.otpPath, code: "", error: Model.cleanError(stderr) || "Could not read code" }
          root.otpLoaded()
          if (callback) callback("", root.otp.error)
        } else {
          var codeValue = String(output || "").trim().split("\n")[0].trim()
          var url = root.detail && root.detail.otpUrl ? root.detail.otpUrl : ""
          var period = Model.otpPeriod(url)
          var type = Model.otpType(url)
          root.otp = {
            path: root.otpPath,
            code: codeValue,
            period: period,
            type: type,
            digits: Model.otpDigits(url),
            error: ""
          }
          root.otpRemaining = Model.otpRemaining(period)
          root.otpFetchedWindow = Model.otpWindow(period)
          root.otpLoaded()
          if (type === "totp") root.otpTimer.restart()
          if (callback) callback(codeValue, "")
        }
      }

      if (root.otpPendingPath) {
        var nextPath = root.otpPendingPath
        var nextCallback = root.otpNextCallback
        root.otpPendingPath = ""
        root.otpNextCallback = null
        root.startOtp(nextPath, nextCallback)
      }
    }
  }

  GopassProcess {
    id: actionProc

    onFinished: function(code, output, stderr) {
      var callback = root.actionCallback
      root.actionCallback = null
      root.actionRunning = false

      if (callback) callback(code, output, stderr)
      root.pumpAction()
    }
  }

  GopassProcess {
    id: insertProc

    onFinished: function(code, output, stderr) {
      var callback = root.insertCallback
      root.insertCallback = null
      if (callback) callback(code, output, stderr)
    }
  }

  GopassProcess {
    id: genProc

    onFinished: function(code, output, stderr) {
      root.finishGenerate(code, output, stderr)
    }
  }

  GopassProcess {
    id: storeProc

    onFinished: function(code, output, stderr) {
      var path = code === 0 ? String(output || "").trim() : ""
      if (!path) path = root.storeFallback
      if (path.indexOf("~/") === 0) path = root.home + path.slice(1)
      root.storePath = path
      root.startGit()
    }
  }

  GopassProcess {
    id: gitProc

    onFinished: function(code, output, stderr) {
      if (code === 0) {
        var parsed = Model.parseGitStatus(output)
        root.branch = parsed.branch
        root.ahead = parsed.ahead
        root.behind = parsed.behind
        root.dirty = parsed.dirty
      }
      root.gitChanged()
      root.finishGit()
    }
  }

  GopassProcess {
    id: remoteProc

    onFinished: function(code, output, stderr) {
      root.remote = code === 0 ? Model.prettyRemote(output) : ""
      root.gitChanged()
      root.finishGit()
    }
  }

  GopassProcess {
    id: logProc

    onFinished: function(code, output, stderr) {
      root.lastCommit = code === 0 ? String(output || "").trim() : ""
      root.gitChanged()
      root.finishGit()
    }
  }

  Timer {
    id: otpTimer
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      if (!root.otp || !root.detail || !root.detail.otpUrl) {
        stop()
        return
      }
      var period = Model.otpPeriod(root.detail.otpUrl)
      root.otpRemaining = Model.otpRemaining(period)
      if (Model.otpType(root.detail.otpUrl) !== "totp") return
      if (Model.otpWindow(period) !== root.otpFetchedWindow && !root.otpLoading) {
        root.loadOtp(root.detail.path)
      }
    }
  }

  Timer {
    id: clipboardTimer
    interval: 45000
    repeat: false
    onTriggered: {
      if (!root.lastClipboard) return
      Quickshell.execDetached(["bash", "-lc", "test \"$(wl-paste -n 2>/dev/null)\" = "
        + Util.shellQuote(root.lastClipboard) + " && wl-copy --clear"])
      root.lastClipboard = ""
    }
  }
}
