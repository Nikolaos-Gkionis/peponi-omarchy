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
//   Service.qml     = peponi CLI (local store, or any Peponi instance)
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
  property bool composing: false
  property string composerText: ""

  // Selected calendar day (noon-normalized).
  property date selectedDate: Model.startOfToday()
  property date today: Model.startOfToday()
  property var dayTasks: []
  property var notYetItems: []
  property string authBanner: ""
  property bool signedIn: false
  property string dataMode: ""   // "local" | "cloud" | "demo" | ""
  property bool rollOver: true

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
    root.cancelComposer()
    root.reloadDay()
    root.opened = true
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    root.drawerOpen = false
    root.helpOpen = false
    root.cancelComposer()
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
      drawer.ensureCursor()
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

  // Local mode does not need a terminal — the CLI writes a JSON file and
  // the overlay can keep focus.
  function enableLocalMode() {
    if (root.service && typeof root.service.enableLocalMode === "function") {
      root.service.enableLocalMode()
      return
    }
    startPeponi(authLocalFallback, ["auth", "local", "--json"])
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
    root.dataMode = root.demoMode ? "demo" : (root.service.dataMode || "")
    root.rollOver = root.service.rollOver !== false
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
      root.dayTasks = Model.copyRows(root.service.dayTasks)
      root.notYetItems = Model.copyRows(root.service.notYetItems)
    } else {
      root.dayTasks = []
      root.notYetItems = []
    }
    Qt.callLater(function() {
      var keep = root.service && root.service.keepSelectedId
      if (keep) {
        if (root.drawerOpen) drawer.selectById(keep)
        else dayView.selectById(keep)
      }
    })
    return true
  }

  function reloadDay() {
    if (root.demoMode && !root.service) {
      root.signedIn = true
      root.dataMode = "demo"
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
    if (root.composing) {
      root.cancelComposer()
      return
    }
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

  // One-line "new task" field. Same key (n) on the day or in Not Yet.
  function openComposer() {
    if ((!root.signedIn && !root.demoMode) || root.helpOpen)
      return
    root.composing = true
    root.composerText = ""
    Qt.callLater(function() {
      if (composerInput) composerInput.forceActiveFocus()
    })
  }

  function cancelComposer() {
    root.composing = false
    root.composerText = ""
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function submitComposer() {
    var title = String(root.composerText || "").trim()
    var toNotYet = root.drawerOpen
    root.cancelComposer()
    if (title === "") return
    if (!root.service) return
    // Drawer open → always Not Yet. Never fall through to the day list.
    if (toNotYet) {
      if (typeof root.service.addNotYet === "function")
        root.service.addNotYet(title)
      return
    }
    if (typeof root.service.addTask === "function")
      root.service.addTask(root.selectedDate, title)
  }

  // Delete the highlighted row (↑ / ↓ first). Day list, or Not Yet if the drawer is open.
  function removeSelectedTask() {
    if ((!root.signedIn && !root.demoMode) || root.composing || root.helpOpen)
      return
    if (root.drawerOpen) {
      if (!drawer.cursorActive || !drawer.items || drawer.items.length === 0) {
        root.authBanner = "Highlight a Not Yet task with ↑ / ↓, then Delete"
        return
      }
      var ny = drawer.items[drawer.selectedIndex]
      if (!ny || ny.id === undefined || ny.id === null || String(ny.id) === "") {
        root.authBanner = "This task has no id — reload and try again"
        return
      }
      if (root.service && typeof root.service.removeTask === "function")
        root.service.removeTask(ny.id)
      return
    }
    if (!dayView.cursorActive || !dayView.tasks || dayView.tasks.length === 0) {
      root.authBanner = "Highlight a task with ↑ / ↓, then Delete"
      return
    }
    var task = dayView.tasks[dayView.selectedIndex]
    if (!task || task.id === undefined || task.id === null || String(task.id) === "") {
      root.authBanner = "This task has no id — reload the day and try again"
      return
    }
    if (root.service && typeof root.service.removeTask === "function")
      root.service.removeTask(task.id)
  }

  function selectedRow() {
    if (root.drawerOpen) {
      if (!drawer.cursorActive || !drawer.items || drawer.items.length === 0)
        return null
      return drawer.items[drawer.selectedIndex]
    }
    if (!dayView.cursorActive || !dayView.tasks || dayView.tasks.length === 0)
      return null
    return dayView.tasks[dayView.selectedIndex]
  }

  // Space (keyboard) or checkbox click (mouse).
  function toggleSelectedTask() {
    if ((!root.signedIn && !root.demoMode) || root.composing || root.helpOpen)
      return
    var row = root.selectedRow()
    if (!row || row.id === undefined || row.id === null || String(row.id) === "") {
      root.authBanner = "Highlight a task with j / k, then Space to tick"
      return
    }
    root.toggleTaskById(row.id)
  }

  function toggleTaskById(id) {
    if (root.service && typeof root.service.toggleTask === "function")
      root.service.toggleTask(id)
  }

  // K / ↑ button = up, J / ↓ button = down.
  function moveSelectedTask(delta) {
    if ((!root.signedIn && !root.demoMode) || root.composing || root.helpOpen)
      return
    var row = root.selectedRow()
    if (!row || row.id === undefined || row.id === null || String(row.id) === "") {
      root.authBanner = "Highlight a task with j / k, then K / J to move"
      return
    }
    root.moveTaskById(row.id, delta)
  }

  function moveTaskById(id, delta) {
    if (root.service && typeof root.service.moveTask === "function")
      root.service.moveTask(id, delta)
  }

  function toggleRollOver() {
    if ((!root.signedIn && !root.demoMode) || root.composing || root.helpOpen)
      return
    if (root.service && typeof root.service.toggleRollOver === "function")
      root.service.toggleRollOver()
    else
      root.rollOver = !root.rollOver
  }

  // IPC for keyboard-only Omarchy users (optional Hyprland chords).
  function toggleSelected() {
    root.ensureOpenForIpc()
    root.toggleSelectedTask()
    return "ok"
  }

  function moveSelectedUp() {
    root.ensureOpenForIpc()
    root.moveSelectedTask(-1)
    return "ok"
  }

  function moveSelectedDown() {
    root.ensureOpenForIpc()
    root.moveSelectedTask(1)
    return "ok"
  }

  function toggleRoll() {
    root.ensureOpenForIpc()
    root.toggleRollOver()
    return root.rollOver ? "on" : "off"
  }

  // a in the Not Yet drawer: put the highlighted inbox task on today.
  function sendNotYetToToday() {
    if (!root.drawerOpen || root.composing || root.helpOpen)
      return
    if (!drawer.cursorActive || !drawer.items || drawer.items.length === 0) {
      root.authBanner = "Highlight a Not Yet task with ↑ / ↓, then a"
      return
    }
    var ny = drawer.items[drawer.selectedIndex]
    if (!ny || ny.id === undefined || ny.id === null || String(ny.id) === "") {
      root.authBanner = "This task has no id — reload and try again"
      return
    }
    // Jump the day view to today so the moved task is visible when it lands.
    root.today = Model.startOfToday()
    root.selectedDate = root.today
    if (root.service)
      root.service.selectedDate = root.today
    if (root.service && typeof root.service.scheduleNotYetToToday === "function")
      root.service.scheduleNotYetToToday(ny.id)
  }

  Connections {
    target: root.service
    function onDayTasksChanged() { root.syncFromService() }
    function onNotYetItemsChanged() { root.syncFromService() }
    function onAuthenticatedChanged() { root.syncFromService() }
    function onLastErrorChanged() { root.syncFromService() }
    function onStatusMessageChanged() { root.syncFromService() }
    function onDataModeChanged() { root.syncFromService() }
    function onRollOverChanged() { root.syncFromService() }
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
        root.authBanner = "Not set up. Press l to use locally, or a to sign in."
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

  Process {
    id: authLocalFallback
    command: []
    stdout: StdioCollector {
      id: authLocalFallbackStdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.signedIn = true
        root.dataMode = "local"
        root.authBanner = "Using local data on this machine"
        root.reloadDay()
      } else {
        root.authBanner = "Could not start local mode"
      }
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
      MouseArea {
        anchors.fill: parent
        onClicked: {
          if (keyCatcher) keyCatcher.forceActiveFocus()
        }
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        z: 30

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          // Composer: Esc cancel, Enter save; other keys go to TextInput.
          if (root.composing) {
            if (event.key === Qt.Key_Escape) {
              root.cancelComposer()
              event.accepted = true
              return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.submitComposer()
              event.accepted = true
              return
            }
            return
          }

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

          // ↑ / ↓ / j / k : move among tasks (or Not Yet items when drawer is open)
          if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && !(event.modifiers & Qt.ShiftModifier))) {
            if (root.drawerOpen) drawer.select(-1)
            else dayView.select(-1)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && !(event.modifiers & Qt.ShiftModifier))) {
            if (root.drawerOpen) drawer.select(1)
            else dayView.select(1)
            event.accepted = true
            return
          }

          // Shift+K / Shift+J — move the highlighted task (neovim-style)
          if (event.key === Qt.Key_K && (event.modifiers & Qt.ShiftModifier)) {
            root.moveSelectedTask(-1)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_J && (event.modifiers & Qt.ShiftModifier)) {
            root.moveSelectedTask(1)
            event.accepted = true
            return
          }

          // h / l — same as ← / → when signed in (neovim). Unsigned `l` stays "use locally".
          if (event.key === Qt.Key_H || ((event.key === Qt.Key_L) && (root.signedIn || root.demoMode))) {
            if (event.key === Qt.Key_H) {
              if (!root.drawerOpen) root.prevDay()
            } else if (!root.drawerOpen) {
              root.nextDay()
            }
            event.accepted = true
            return
          }

          if (event.key === Qt.Key_Space) {
            root.toggleSelectedTask()
            event.accepted = true
            return
          }

          if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.removeSelectedTask()
            event.accepted = true
            return
          }

          // Letter shortcuts — same keys on the day and in the Y drawer
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
          if ((t === "n" || t === "N") && (root.signedIn || root.demoMode)) {
            root.openComposer()
            event.accepted = true
            return
          }
          if ((t === "a" || t === "A") && root.drawerOpen) {
            root.sendNotYetToToday()
            event.accepted = true
            return
          }
          if ((t === "r" || t === "R") && (root.signedIn || root.demoMode)) {
            root.toggleRollOver()
            event.accepted = true
            return
          }
          if ((t === "l" || t === "L") && !root.signedIn && !root.demoMode) {
            root.enableLocalMode()
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

            Text {
              visible: root.signedIn && root.dataMode === "local"
              text: "Local · this machine"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
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
              // Drawer open: a = send to today. Drawer closed + not set up: a = sign in.
              text: root.composing
                    ? "enter save  ·  esc cancel"
                    : (root.drawerOpen
                      ? "n add  ·  a today  ·  j/k  ·  K/J move  ·  y/esc close  ·  ?"
                      : ((!root.signedIn && !root.demoMode)
                        ? "← → day  ·  l local  ·  a sign in  ·  y not yet  ·  t today  ·  esc close  ·  ?"
                        : "h/l day  ·  j/k list  ·  space tick  ·  K/J move  ·  n add  ·  r roll  ·  y  ·  ?"))
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              visible: (root.signedIn || root.demoMode) && !root.drawerOpen
              width: parent.width
              text: root.rollOver
                    ? "Roll unfinished to today · on  (r)"
                    : "Roll unfinished to today · off  (r)"
              color: root.rollOver ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.underline: true

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                z: 40
                onClicked: root.toggleRollOver()
              }
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

            Column {
              visible: !root.signedIn && !root.demoMode
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Use locally (l) — tasks stay on this Omarchy machine, no account needed"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.underline: true

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  z: 40
                  onClicked: root.enableLocalMode()
                }
              }

              Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Sign in (a) — peponi.to hosted week, or your own instance"
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
            height: parent.height - Style.space(120) - (root.composing ? Style.space(56) : 0)
            tasks: root.dayTasks
            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            selectedBackground: root.selectedBackground
            selectedText: root.selectedText
            fontFamily: root.fontFamily
            onToggleRequested: root.toggleTaskById(taskId)
            onMoveRequested: root.moveTaskById(taskId, delta)
            onRowClicked: {
              if (keyCatcher) keyCatcher.forceActiveFocus()
            }
          }

          // New-task composer — n on the day or in the Not Yet drawer.
          Rectangle {
            visible: root.composing
            width: parent.width
            height: Style.space(48)
            radius: Style.cornerRadius
            color: root.selectedBackground
            border.width: 1
            border.color: root.accent
            z: 50

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(10)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Item {
                width: parent.width - Style.space(28)
                height: parent.height

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  visible: composerInput.text === ""
                  text: root.drawerOpen ? "New task in Not Yet" : "New task on this day"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                TextInput {
                  id: composerInput
                  anchors.fill: parent
                  verticalAlignment: TextInput.AlignVCenter
                  text: root.composerText
                  color: root.selectedText
                  selectedTextColor: root.background
                  selectionColor: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  clip: true
                  onTextChanged: root.composerText = text
                  onAccepted: root.submitComposer()
                  Keys.onEscapePressed: root.cancelComposer()
                }
              }
            }
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
          onRequestFocus: {
            if (keyCatcher) keyCatcher.forceActiveFocus()
          }
          onMoveRequested: root.moveTaskById(taskId, delta)
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
                text: root.drawerOpen
                      ? "n       add a Not Yet task\na       move highlighted task to today\nj / k   move in Not Yet (or ↑ / ↓)\nK / J   move highlighted task up / down\nDelete  remove highlighted Not Yet task\ny / Esc close the drawer\n?       this help"
                      : ((!root.signedIn && !root.demoMode)
                        ? "← / →   previous / next day\nl       use locally on this machine\na       sign in to an instance\ny       toggle Not Yet drawer\nt       jump to today\nj / k   move in list\nEsc     close drawer, then overlay\n?       this help"
                        : "h / l   previous / next day (also ← / →)\nj / k   move in list (also ↑ / ↓)\nSpace   tick / untick highlighted task\nK / J   move highlighted task up / down\nn       add a task on this day\nr       roll unfinished tasks to today\nDelete  remove highlighted task\ny       toggle Not Yet drawer\nt       jump to today\nEsc     close drawer, then overlay\n?       this help")
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
