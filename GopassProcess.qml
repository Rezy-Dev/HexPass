import QtQuick
import Quickshell.Io

// A Process that only reports once the exit code and both output streams are
// in. Quickshell does not guarantee exit and stream-finished ordering, and
// every gopass read here needs the complete stdout.
Item {
  id: root

  visible: false
  width: 0
  height: 0

  property string label: ""
  property string startedPath: ""
  property bool running: proc.running

  signal finished(int exitCode, string stdout, string stderr)

  property int _exitCode: -1
  property bool _outDone: false
  property bool _errDone: false
  property bool _exited: false
  property string _pendingStdin: ""

  function start(command, payload) {
    if (proc.running) return false
    _exitCode = -1
    _outDone = false
    _errDone = false
    _exited = false
    _pendingStdin = payload === undefined || payload === null ? "" : String(payload)

    proc.command = command
    proc.stdinEnabled = _pendingStdin !== ""
    proc.running = true
    return true
  }

  function stop() {
    proc.running = false
  }

  function _maybeFinish() {
    if (!_exited || !_outDone || !_errDone) return

    var code = _exitCode
    var output = out.text
    var errors = err.text
    _exitCode = -1
    _outDone = false
    _errDone = false
    _exited = false
    _pendingStdin = ""

    finished(code, output, errors)
  }

  Process {
    id: proc
    command: []
    stdinEnabled: false

    stdout: StdioCollector {
      id: out
      waitForEnd: true
      onStreamFinished: {
        root._outDone = true
        root._maybeFinish()
      }
    }

    stderr: StdioCollector {
      id: err
      waitForEnd: true
      onStreamFinished: {
        root._errDone = true
        root._maybeFinish()
      }
    }

    onStarted: {
      if (!root._pendingStdin) return
      write(root._pendingStdin)
      root._pendingStdin = ""
      Qt.callLater(function() { proc.stdinEnabled = false })
    }

    onExited: function(exitCode, exitStatus) {
      proc.running = false
      root._exitCode = exitCode
      root._exited = true
      root._maybeFinish()
    }
  }
}
