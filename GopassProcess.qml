import QtQuick
import Quickshell.Io

// A Process that reports after the exit code and a short drain window. The
// drain matters because Quickshell does not guarantee that stream-finished
// lands before exited, and every gopass read here needs the complete stdout.
Item {
  id: root

  visible: false
  width: 0
  height: 0

  property string label: ""
  property string startedPath: ""
  property bool discardStdout: false
  property bool running: proc.running

  signal finished(int exitCode, string stdout, string stderr)

  property int _exitCode: -1
  property bool _exited: false
  property string _pendingStdin: ""

  function start(command, payload) {
    if (proc.running) return false
    drainTimer.stop()
    _exitCode = -1
    _exited = false
    _pendingStdin = payload === undefined || payload === null ? "" : String(payload)

    proc.command = discardStdout
      ? ["sh", "-c", 'exec "$@" >/dev/null', "sh"].concat(command)
      : command
    proc.stdinEnabled = _pendingStdin !== ""
    proc.running = true
    return true
  }

  function stop() {
    proc.running = false
  }

  Process {
    id: proc
    command: []
    stdinEnabled: false

    stdout: StdioCollector {
      id: out
      waitForEnd: true
    }

    stderr: StdioCollector {
      id: err
      waitForEnd: true
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
      drainTimer.restart()
    }
  }

  Timer {
    id: drainTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (!root._exited) return
      var code = root._exitCode
      var output = out.text
      var errors = err.text
      root._exitCode = -1
      root._exited = false
      root.finished(code, output, errors)
    }
  }
}
