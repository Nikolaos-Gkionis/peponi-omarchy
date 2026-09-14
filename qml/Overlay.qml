import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Peponi One Day — fullscreen overlay (clipboard / reminders style).
// Beginner map:
//   Overlay.qml     = window + keys + day state
//   DayView.qml     = task list for selectedDate
//   BottomDrawer.qml = Not Yet slide-up (same window, not a 2nd layer-shell)
//   Service.qml     = peponi CLI auth + day / Not Yet fetch
Item {
  id: root

  // Injected by omarchy-shell when the overlay Loader starts.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var service: null

  property bool opened: false
  property bool drawerOpen: false
  property bool helpOpen: false

  // Selected calendar day (noon-normalized).
  property date selectedDate: Model.startOfToday()
  property date today: Model.startOfToday()
  property var dayTasks: []
  property var notYetItems: []
  property string authBanner: ""
  property bool signedIn: false

  readonly property bool demoMode: Quickshell.env("PEPONI_DEMO") === "1"

  // Theme tokens — same menu surface as clipboard/reminders.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property color dim: Qt.darker(Color.menu.text, 1.55)
  property color accent: Color.accent
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int cardWidth: Math.min(Style.space(720), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(640), panel.height - Style.gapsOut * 2)

  readonly property string heading: Model.dayHeading(selectedDate)
  readonly property string relative: Model.relativeLabel(selectedDate, today)
  readonly property bool isToday: Model.isSameDay(selectedDate, today)

  // ---- Lifecycle (shell summon / hide / toggle / call) --------------------

  function open(payloadJson) {
    root.today = Model.startOfToday()
    root.selectedDate = Model.parsePayloadDate(payloadJson)
    root.drawerOpen = false
    root.helpOpen = false
    root.reloadDay()
    root.opened = true
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    root.drawerOpen = false
    root.helpOpen = false
    root.opened = false
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "peponi.one-day")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  // IPC: omarchy-shell shell call peponi.one-day prevDay
  function prevDay() {
    root.ensureOpenForIpc()
    root.selectedDate = Model.stepDay(root.selectedDate, -1)
    root.reloadDay()
    return "ok"
  }

  function nextDay() {
    root.ensureOpenForIpc()
    root.selectedDate = Model.stepDay(root.selectedDate, 1)
    root.reloadDay()
    return "ok"
  }

  function goToToday() {
    root.today = Model.startOfToday()
    root.selectedDate = root.today
    root.reloadDay()
    return "ok"
  }

  function toggleDrawer() {
    root.ensureOpenForIpc()
    root.drawerOpen = !root.drawerOpen
    if (root.drawerOpen) {
      if (root.service && typeof root.service.loadNotYet === "function")
        root.service.loadNotYet()
      drawer.resetCursor()
    } else {
      dayView.resetCursor()
    }
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
    return root.drawerOpen ? "open" : "closed"
  }

  function ensureOpenForIpc() {
    if (root.opened) return
    root.today = Model.startOfToday()
    if (!root.selectedDate || isNaN(root.selectedDate.getTime()))
      root.selectedDate = root.today
    root.reloadDay()
    root.opened = true
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function peponiBin() {
    var home = Quickshell.env("HOME") || ""
    if (home !== "") return home + "/.local/bin/peponi"
    return "peponi"
  }

  // Overlay has exclusive keyboard focus, so close it first or the
  // terminal cannot receive the email/password keys.
  function openAuthLogin() {
    root.dismiss()
    Qt.callLater(function() {
      if (root.service && typeof root.service.openAuthLogin === "function") {
        root.service.openAuthLogin()
        return
      }
      Util.execArgv(["omarchy-launch-tui", peponiBin(), "auth", "login"])
    })
  }

  function startPeponi(proc, args) {
    var cmd = ["/usr/bin/bash", peponiBin()]
    for (var i = 0; i < args.length; i++) cmd.push(args[i])
    proc.running = false
    proc.command = cmd
    proc.running = true
  }

  function syncFromService() {
    if (!root.service) return false
    root.signedIn = root.service.authenticated === true || root.demoMode
    if (root.demoMode) {
      root.authBanner = ""
      root.dayTasks = root.service.dayTasks && root.service.dayTasks.length
        ? root.service.dayTasks
        : Model.tasksForDate(root.selectedDate)
      root.notYetItems = root.service.notYetItems && root.service.notYetItems.length
        ? root.service.notYetItems
        : Model.notYetItems()
      return true
    }
    root.authBanner = root.service.lastError || root.service.statusMessage || ""
    if (root.signedIn) {
      root.dayTasks = root.service.dayTasks || []
      root.notYetItems = root.service.notYetItems || []
    } else {
      root.dayTasks = []
      root.notYetItems = []
    }
    return true
  }

  function reloadDay() {
    if (root.demoMode && !root.service) {
      root.signedIn = true
      root.authBanner = "Demo mode (PEPONI_DEMO=1)"
      root.dayTasks = Model.tasksForDate(root.selectedDate)
      root.notYetItems = Model.notYetItems()
      dayView.resetCursor()
      return
    }

    if (root.service) {
      root.service.selectedDate = root.selectedDate
      if (!root.service.authenticated && typeof root.service.reloadAll === "function")
        root.service.reloadAll()
      if (typeof root.service.loadDay === "function")
        root.service.loadDay(root.selectedDate)
      if (typeof root.service.loadNotYet === "function")
        root.service.loadNotYet()
      root.syncFromService()
      dayView.resetCursor()
      return
    }

    // Fallback without service: call CLI directly
    root.signedIn = false
    root.authBanner = "Loading…"
    startPeponi(dayFallback, ["day", Model.keyForDate(root.selectedDate), "--json"])
    startPeponi(notYetFallback, ["not-yet", "--json"])
    dayView.resetCursor()
  }

  function handleEscape() {
    if (root.helpOpen) {
      root.helpOpen = false
      return
    }
    if (root.drawerOpen) {
      root.drawerOpen = false
      dayView.resetCursor()
      return
    }
    root.dismiss()
  }

  Connections {
    target: root.service
    function onDayTasksChanged() { root.syncFromService() }
    function onNotYetItemsChanged() { root.syncFromService() }
    function onAuthenticatedChanged() { root.syncFromService() }
    function onLastErrorChanged() { root.syncFromService() }
    function onStatusMessageChanged() { root.syncFromService() }
  }

  Component.onCompleted: {
    root.today = Model.startOfToday()
    root.selectedDate = root.today
    if (root.service && typeof root.service.reloadAll === "function")
      root.service.reloadAll()
    root.reloadDay()
  }

  Process {
    id: dayFallback
    command: []
    stdout: StdioCollector {
      id: dayFallbackStdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.signedIn = true
        root.authBanner = ""
        root.dayTasks = Model.tasksFromDayJson(dayFallbackStdout.text)
      } else {
        root.signedIn = false
        root.dayTasks = []
        root.authBanner = "Not signed in. Run peponi auth login (or scripts/install.sh)."
      }
    }
  }

  Process {
    id: notYetFallback
    command: []
    stdout: StdioCollector {
      id: notYetFallbackStdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0)
        root.notYetItems = Model.notYetFromJson(notYetFallbackStdout.text)
      else
        root.notYetItems = []
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "peponi-one-day"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // Dim the desktop behind the card.
    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      // Keep clicks on the card from dismissing via the scrim MouseArea.
      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        z: 30

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          // Esc: close help → drawer → overlay
          if (event.key === Qt.Key_Escape) {
            root.handleEscape()
            event.accepted = true
            return
          }

          // ← / → : previous / next day (only when drawer closed, like Peponi GUI)
          if (event.key === Qt.Key_Left) {
            if (!root.drawerOpen) root.prevDay()
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Right) {
            if (!root.drawerOpen) root.nextDay()
            event.accepted = true
            return
          }

          // ↑ / ↓ : move among tasks (or Not Yet items when drawer is open)
          if (event.key === Qt.Key_Up) {
            if (root.drawerOpen) drawer.select(-1)
            else dayView.select(-1)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Down) {
            if (root.drawerOpen) drawer.select(1)
            else dayView.select(1)
            event.accepted = true
            return
          }

          // Letter shortcuts (Peponi GUI cues)
          var t = event.text
          if (t === "y" || t === "Y") {
            root.toggleDrawer()
            event.accepted = true
            return
          }
          if (t === "t" || t === "T") {
            root.goToToday()
            event.accepted = true
            return
          }
          if ((t === "a" || t === "A") && !root.signedIn && !root.demoMode) {
            root.openAuthLogin()
            event.accepted = true
            return
          }
          if (t === "?") {
            root.helpOpen = !root.helpOpen
            event.accepted = true
            return
          }
        }
      }

      // Main content
      Item {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Column {
          id: mainColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.drawerOpen ? drawer.openHeight + Style.space(8) : 0
          spacing: Style.space(14)

          Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
          }

          // Hero: brand + day
          Column {
            width: parent.width
            spacing: Style.space(4)

            Text {
              text: "PEPONI"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Row {
              spacing: Style.space(14)

              Text {
                text: root.heading
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                font.bold: true
              }

              Text {
                anchors.baseline: parent.children[0].baseline
                text: root.relative.toUpperCase()
                color: root.isToday ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
            }

            Text {
              // Sign-in chord is only useful when logged out.
              text: (!root.signedIn && !root.demoMode)
                    ? "← → day  ·  y not yet  ·  t today  ·  a sign in  ·  esc close  ·  ?"
                    : "← → day  ·  y not yet  ·  t today  ·  esc close  ·  ?"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              visible: !root.signedIn && !root.demoMode && root.authBanner !== ""
              width: parent.width
              wrapMode: Text.Wrap
              text: root.authBanner
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              id: signInLink
              visible: !root.signedIn && !root.demoMode
              width: parent.width
              wrapMode: Text.Wrap
              text: "Sign in — opens your terminal and runs peponi auth login"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.underline: true

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                z: 40
                onClicked: root.openAuthLogin()
              }
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: root.border
            opacity: 0.45
          }

          DayView {
            id: dayView
            width: parent.width
            height: parent.height - Style.space(120)
            tasks: root.dayTasks
            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            selectedBackground: root.selectedBackground
            selectedText: root.selectedText
            fontFamily: root.fontFamily
          }
        }

        // Bottom drawer — child of the same overlay card (not a new layer-shell).
        BottomDrawer {
          id: drawer
          anchors.fill: parent
          open: root.drawerOpen
          items: root.notYetItems
          background: root.background
          foreground: root.foreground
          dim: root.dim
          accent: root.accent
          border: root.border
          borderSpec: root.borderSpec
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
        }

        // Lightweight shortcuts help overlay inside the card.
        Rectangle {
          visible: root.helpOpen
          anchors.fill: parent
          color: Qt.rgba(0, 0, 0, 0.55)
          z: 40

          MouseArea {
            anchors.fill: parent
            onClicked: root.helpOpen = false
          }

          BorderSurface {
            anchors.centerIn: parent
            width: Math.min(Style.space(420), parent.width - Style.space(40))
            height: helpCol.implicitHeight + Style.space(32)
            radius: root.cornerRadius
            color: root.background
            borderSpec: root.borderSpec
            padding: Style.spacing.panelPadding

            Column {
              id: helpCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text {
                text: "SHORTCUTS"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                width: parent.width
                text: (!root.signedIn && !root.demoMode)
                      ? "← / →   previous / next day\ny       toggle Not Yet drawer\nt       jump to today\na       sign in (opens terminal)\n↑ / ↓   move in list\nEsc     close drawer, then overlay\n?       this help"
                      : "← / →   previous / next day\ny       toggle Not Yet drawer\nt       jump to today\n↑ / ↓   move in list\nEsc     close drawer, then overlay\n?       this help"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.Wrap
              }
            }
          }
        }
      }
    }
  }
}
