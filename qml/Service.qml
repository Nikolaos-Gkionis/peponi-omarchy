import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// Shared engine for every bar / overlay instance.
// Talks to the peponi CLI. Two modes:
//   local — tasks in ~/.local/share/peponi/ (no account)
//   cloud — any Peponi instance (~/.config/peponi/credentials.json)
Item {
  id: root

  property var shell: null
  property var settings: ({})
  property bool active: true

  property bool authenticated: false
  property bool probing: false
  property bool loadingDay: false
  property bool loadingNotYet: false
  property string lastError: ""
  property string statusMessage: ""
  property string userEmail: ""
  property string dataMode: ""   // "local" | "cloud" | "demo" | ""
  property string appTitle: "Peponi"
  property string notYetTitle: "Not Yet"
  property int openTaskCount: 0
  property int authWatchTicks: 0
  property bool mutating: false
  property bool pendingNotYetAdd: false
  property bool pendingNotYetToday: false

  property date selectedDate: Model.startOfToday()
  property var dayTasks: []
  property var notYetItems: []
  property bool rollOver: true
  property string keepSelectedId: ""

  readonly property bool demoMode: Quickshell.env("PEPONI_DEMO") === "1"
  readonly property bool busy: probing || loadingDay || loadingNotYet || mutating

  function peponiBin() {
    // Absolute path first so Quickshell Process finds it without a login shell PATH.
    var home = Quickshell.env("HOME") || ""
    if (home !== "") return home + "/.local/bin/peponi"
    return "peponi"
  }

  // bash + the script path: /usr/bin/env in the shebang needs PATH, and
  // Process must be flipped off then on or a second fetch is a no-op.
  function startPeponi(proc, args) {
    var cmd = ["/usr/bin/bash", peponiBin()]
    for (var i = 0; i < args.length; i++) cmd.push(args[i])
    proc.running = false
    proc.command = cmd
    proc.running = true
  }

  function refreshAuth() {
    if (demoMode) {
      authenticated = true
      dataMode = "demo"
      statusMessage = "Demo mode (PEPONI_DEMO=1)"
      lastError = ""
      return
    }
    probing = true
    lastError = ""
    startPeponi(authProcess, ["auth", "status", "--json"])
  }

  function loadDay(dateObj) {
    selectedDate = dateObj instanceof Date ? dateObj : Model.startOfToday()
    if (demoMode) {
      dayTasks = Model.sortUnfinishedFirst(Model.tasksForDate(selectedDate))
      openTaskCount = Model.openCount(dayTasks)
      return
    }
    if (!authenticated) {
      dayTasks = []
      openTaskCount = 0
      return
    }
    loadingDay = true
    startPeponi(dayProcess, ["day", Model.keyForDate(selectedDate), "--json"])
  }

  function loadNotYet() {
    if (demoMode) {
      notYetItems = Model.notYetItems()
      return
    }
    loadingNotYet = true
    startPeponi(notYetProcess, ["not-yet", "--json"])
  }

  function reloadAll() {
    refreshAuth()
  }

  // Add a Focus-column task on selectedDate (or dateObj).
  function addTask(dateObj, title) {
    title = String(title || "").trim()
    if (title === "") return
    var when = dateObj instanceof Date ? dateObj : selectedDate
    if (demoMode) {
      var copy = []
      for (var i = 0; i < dayTasks.length; i++) copy.push(dayTasks[i])
      copy.push({
        id: "demo-" + Date.now(),
        title: title,
        done: false,
        list: "",
        is_visual_break: false
      })
      dayTasks = copy
      openTaskCount = Model.openCount(dayTasks)
      lastError = ""
      return
    }
    if (!authenticated) return
    mutating = true
    pendingNotYetAdd = false
    pendingNotYetToday = false
    lastError = ""
    startPeponi(mutateProcess, ["add", Model.keyForDate(when), title, "--json"])
  }

  // Tick / untick. Unfinished rows stay at the top after the save.
  function toggleTask(id) {
    if (id === undefined || id === null || String(id) === "") return
    keepSelectedId = String(id)
    if (demoMode) {
      dayTasks = Model.toggleRowCopy(dayTasks, id)
      notYetItems = Model.toggleRowCopy(notYetItems, id)
      openTaskCount = Model.openCount(dayTasks)
      lastError = ""
      return
    }
    if (!authenticated) return
    dayTasks = Model.toggleRowCopy(dayTasks, id)
    notYetItems = Model.toggleRowCopy(notYetItems, id)
    openTaskCount = Model.openCount(dayTasks)
    var idx = Model.findIndexById(dayTasks, id)
    if (idx < 0) idx = Model.findIndexById(notYetItems, id)
    var nowDone = false
    if (idx >= 0) {
      var src = Model.findIndexById(dayTasks, id) >= 0 ? dayTasks : notYetItems
      nowDone = Model.isDone(src[Model.findIndexById(src, id)])
    }
    mutating = true
    pendingNotYetAdd = false
    pendingNotYetToday = false
    lastError = ""
    startPeponi(mutateProcess, ["tick", String(id), nowDone ? "on" : "off", "--json"])
  }

  // delta -1 = up, +1 = down. Stays inside unfinished or ticked group.
  function moveTask(id, delta) {
    if (id === undefined || id === null || String(id) === "") return
    keepSelectedId = String(id)
    var dir = delta < 0 ? "up" : "down"
    if (demoMode) {
      dayTasks = Model.moveRowCopy(dayTasks, id, delta)
      notYetItems = Model.moveRowCopy(notYetItems, id, delta)
      lastError = ""
      return
    }
    if (!authenticated) return
    dayTasks = Model.moveRowCopy(dayTasks, id, delta)
    notYetItems = Model.moveRowCopy(notYetItems, id, delta)
    mutating = true
    pendingNotYetAdd = false
    pendingNotYetToday = false
    lastError = ""
    startPeponi(mutateProcess, ["move", String(id), dir, Model.keyForDate(selectedDate), "--json"])
  }

  // Keyboard-only local users toggle this with `r`. Matches instance roll_over.
  function setRollOver(enabled) {
    rollOver = enabled === true
    if (demoMode) return
    if (!authenticated) return
    mutating = true
    pendingNotYetAdd = false
    pendingNotYetToday = false
    lastError = ""
    startPeponi(mutateProcess, ["pref", "roll_over", rollOver ? "on" : "off", "--json"])
  }

  function toggleRollOver() {
    setRollOver(!rollOver)
  }

  // Delete by API id (from the day JSON). Demo ids are local-only strings.
  function removeTask(id) {
    if (id === undefined || id === null || String(id) === "") return
    if (demoMode) {
      var kept = []
      for (var i = 0; i < dayTasks.length; i++) {
        if (String(dayTasks[i].id) !== String(id)) kept.push(dayTasks[i])
      }
      dayTasks = kept
      openTaskCount = Model.openCount(dayTasks)
      var keptNy = []
      for (var j = 0; j < notYetItems.length; j++) {
        if (String(notYetItems[j].id) !== String(id)) keptNy.push(notYetItems[j])
      }
      notYetItems = keptNy
      lastError = ""
      return
    }
    if (!authenticated) return
    mutating = true
    pendingNotYetAdd = false
    pendingNotYetToday = false
    lastError = ""
    startPeponi(mutateProcess, ["rm", String(id), "--json"])
  }

  function applyMutate(stdoutText, exitCode, stderrText) {
    mutating = false
    var wasNotYet = pendingNotYetAdd
    var wasToday = pendingNotYetToday
    pendingNotYetAdd = false
    pendingNotYetToday = false
    if (exitCode !== 0) {
      var detail = String(stderrText || stdoutText || "").trim().split("\n")[0]
      lastError = detail !== "" ? detail : "Could not save task"
      statusMessage = lastError
      if (wasToday) {
        loadDay(selectedDate)
        loadNotYet()
      }
      return
    }
    lastError = ""
    if (wasNotYet) {
      var data = ({})
      try { data = JSON.parse(stdoutText || "{}") } catch (e) { data = ({}) }
      replacePendingNotYet(data.task || {})
      return
    }
    loadDay(selectedDate)
    loadNotYet()
  }

  function dropPendingNotYet() {
    var kept = []
    for (var i = 0; i < notYetItems.length; i++) {
      if (String(notYetItems[i].id).indexOf("pending-") !== 0)
        kept.push(notYetItems[i])
    }
    notYetItems = kept
  }

  function replacePendingNotYet(task) {
    var row = Model.notYetRow(task, "Inbox")
    var next = []
    var replaced = false
    for (var i = 0; i < notYetItems.length; i++) {
      if (!replaced && String(notYetItems[i].id).indexOf("pending-") === 0) {
        if (row.title !== "")
          next.push(row)
        replaced = true
      } else {
        next.push(notYetItems[i])
      }
    }
    if (!replaced && row.title !== "")
      next.push(row)
    notYetItems = next
  }

  // Undated Inbox task (Not Yet drawer). Same composer as the day, different CLI.
  function addNotYet(title) {
    title = String(title || "").trim()
    if (title === "") return
    // Show the row immediately so the drawer never looks empty after n.
    var copy = Model.copyRows(notYetItems)
    copy.push({
      id: "pending-" + Date.now(),
      title: title,
      list: "Inbox",
      done: false
    })
    notYetItems = copy
    lastError = ""
    if (demoMode) return
    mutating = true
    pendingNotYetAdd = true
    pendingNotYetToday = false
    startPeponi(mutateProcess, ["not-yet", "add", title, "--json"])
  }

  // Move a Not Yet row onto today (key: a while the drawer is open).
  function scheduleNotYetToToday(id) {
    if (id === undefined || id === null || String(id) === "") return
    var moved = null
    var kept = []
    for (var i = 0; i < notYetItems.length; i++) {
      if (String(notYetItems[i].id) === String(id))
        moved = notYetItems[i]
      else
        kept.push(notYetItems[i])
    }
    if (!moved) return
    notYetItems = kept
    lastError = ""
    selectedDate = Model.startOfToday()
    if (demoMode) {
      var copy = Model.copyRows(Model.tasksForDate(selectedDate))
      copy.push({
        id: moved.id,
        title: moved.title,
        done: false,
        list: "",
        is_visual_break: false
      })
      dayTasks = copy
      openTaskCount = Model.openCount(dayTasks)
      return
    }
    mutating = true
    pendingNotYetAdd = false
    pendingNotYetToday = true
    startPeponi(mutateProcess, ["not-yet", "today", String(id), "--json"])
  }

  // Open the user's default terminal and run `peponi auth login`.
  // omarchy-launch-tui → xdg-terminal-exec (Ghostty/Alacritty/Kitty/Foot).
  function openAuthLogin() {
    Util.execArgv(["omarchy-launch-tui", peponiBin(), "auth", "login"])
    authWatchTicks = 0
    authWatch.restart()
  }

  // Local mode is one CLI call — no terminal, no password.
  function enableLocalMode() {
    probing = true
    lastError = ""
    statusMessage = "Starting local mode…"
    startPeponi(authProcess, ["auth", "local", "--json"])
  }

  function applyAuth(stdoutText, exitCode, stderrText) {
    probing = false
    if (exitCode !== 0) {
      authenticated = false
      dataMode = ""
      userEmail = ""
      var detail = String(stderrText || "").trim().split("\n")[0]
      lastError = detail !== ""
        ? detail
        : ("Not set up. Press l for local, or a to sign in (exit " + exitCode + ")")
      statusMessage = lastError
      dayTasks = []
      notYetItems = []
      openTaskCount = 0
      return
    }
    try {
      var data = JSON.parse(stdoutText || "{}")
      authenticated = data.authenticated === true
      if (data.mode === "local" || data.mode === "cloud" || data.mode === "demo")
        dataMode = data.mode
      else
        dataMode = authenticated ? "cloud" : ""
      if (data.user) {
        userEmail = data.user.email || ""
        appTitle = data.user.app_title || "Peponi"
        notYetTitle = data.user.not_yet_panel_title || "Not Yet"
        if (data.user.roll_over !== undefined)
          rollOver = data.user.roll_over !== false
      }
      if (data.prefs && data.prefs.roll_over !== undefined)
        rollOver = data.prefs.roll_over !== false
      if (!authenticated) {
        statusMessage = ""
        lastError = ""
      } else if (dataMode === "local") {
        statusMessage = "Using local data on this machine"
        lastError = ""
      } else {
        statusMessage = userEmail !== "" ? ("Signed in as " + userEmail) : "Signed in"
        lastError = ""
      }
    } catch (e) {
      authenticated = false
      dataMode = ""
      lastError = "Could not read peponi auth status"
      statusMessage = lastError
    }
    if (authenticated) {
      authWatch.stop()
      loadDay(selectedDate)
      loadNotYet()
    }
  }

  function applyDay(stdoutText, exitCode) {
    loadingDay = false
    if (exitCode !== 0) {
      lastError = "Failed to load this day"
      dayTasks = []
      openTaskCount = 0
      return
    }
    dayTasks = Model.tasksFromDayJson(stdoutText)
    openTaskCount = Model.openCount(dayTasks)
    try {
      var data = JSON.parse(stdoutText || "{}")
      if (data.prefs && data.prefs.roll_over !== undefined)
        rollOver = data.prefs.roll_over !== false
    } catch (e) {}
    lastError = ""
  }

  function applyNotYet(stdoutText, exitCode) {
    loadingNotYet = false
    if (exitCode !== 0) {
      // Keep whatever is already on screen (including a just-added row).
      return
    }
    try {
      var data = JSON.parse(stdoutText || "{}")
      if (data.title) notYetTitle = data.title
    } catch (e) {}
    var parsed = Model.notYetFromJson(stdoutText)
    // An empty parse after a successful fetch can wipe a just-added row.
    if (parsed.length > 0)
      notYetItems = parsed
  }

  Component.onCompleted: reloadAll()

  // Read stdout/stderr to the end, then apply in onExited.
  // onStreamFinished can run before Process.exitCode is set, which made
  // a successful `peponi auth status` look like a sign-in failure.
  Process {
    id: authProcess
    command: []
    stdout: StdioCollector {
      id: authStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: authStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.applyAuth(authStdout.text, exitCode, authStderr.text)
    }
  }

  Process {
    id: dayProcess
    command: []
    stdout: StdioCollector {
      id: dayStdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.applyDay(dayStdout.text, exitCode)
    }
  }

  Process {
    id: notYetProcess
    command: []
    stdout: StdioCollector {
      id: notYetStdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.applyNotYet(notYetStdout.text, exitCode)
    }
  }

  Process {
    id: mutateProcess
    command: []
    stdout: StdioCollector {
      id: mutateStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: mutateStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.applyMutate(mutateStdout.text, exitCode, mutateStderr.text)
    }
  }

  // After Sign in opens a terminal, poll until credentials exist (or give up).
  Timer {
    id: authWatch
    interval: 2000
    repeat: true
    onTriggered: {
      root.authWatchTicks += 1
      root.refreshAuth()
      if (root.authenticated || root.authWatchTicks >= 45)
        stop()
    }
  }
}
