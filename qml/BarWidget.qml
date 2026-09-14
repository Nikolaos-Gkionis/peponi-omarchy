import QtQuick
import qs.Ui

// Bar toggle — click opens/closes the Peponi one-day overlay.
BarWidget {
  id: root
  moduleName: "peponi.one-day"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property var peponiService: {
    if (!root.bar || !root.bar.shell) return null
    try {
      return root.bar.shell.service && root.bar.shell.service("peponi.one-day")
    } catch (e) {
      return null
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Simple "P" mark — Omarchy theme colors the control.
    text: "P"
    horizontalMargin: 8
    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.RightButton) {
        // Right-click refreshes auth + day data via service if available
        if (root.peponiService && typeof root.peponiService.reloadAll === "function")
          root.peponiService.reloadAll()
        return
      }
      root.bar.run("omarchy-shell shell toggle peponi.one-day '{}'")
    }
  }
}
