import QtQuick
import qs.Ui

// The bar icon. Left click opens the panel; right click syncs.
Item {
  id: root

  property QtObject panel: null

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button

    anchors.fill: parent
    bar: root.panel ? root.panel.bar : null
    text: "\uf084"
    active: root.panel ? root.panel.opened : false
    useActiveColor: false
    tooltipText: root.panel && root.panel.syncing ? "Syncing\u2026" : "HexPass"

    onPressed: function(button) {
      if (!root.panel) return
      if (button === Qt.RightButton) root.panel.syncNow()
      else root.panel.toggle()
    }
  }
}
