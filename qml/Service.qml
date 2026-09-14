import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// Shared engine for every bar / overlay instance.
// Talks to the peponi CLI (credentials in ~/.config/peponi/).
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
  property string appTitle: "Peponi"
  property string notYetTitle: "Not Yet"
  property int openTaskCount: 0
  property int authWatchTicks: 0
  property bool mutating: false

  property date selectedDate: Model.startOfToday()
  property var dayTasks: []
  property var notYetItems: []

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
      dayTasks = Model.tasksForDate(selectedDate)
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
    if (!authenticated) {
      notYetItems = []
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
    lastError = ""
    startPeponi(mutateProcess, ["add", Model.keyForDate(when), title, "--json"])
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
      lastError = ""
      return
    }
    if (!authenticated) return
    mutating = true
    lastError = ""
    startPeponi(mutateProcess, ["rm", String(id), "--json"])
  }

  function applyMutate(stdoutText, exitCode, stderrText) {
    mutating = false
    if (exitCode !== 0) {
      var detail = String(stderrText || stdoutText || "").trim().split("\n")[0]
      lastError = detail !== "" ? detail : "Could not save task"
      statusMessage = lastError
      return
    }
    lastError = ""
    loadDay(selectedDate)
  }

  // Open the user's default terminal and run `peponi auth login`.
  // omarchy-launch-tui → xdg-terminal-exec (Ghostty/Alacritty/Kitty/Foot).
  function openAuthLogin() {
    Util.execArgv(["omarchy-launch-tui", peponiBin(), "auth", "login"])
    authWatchTicks = 0
    authWatch.restart()
  }

  function applyAuth(stdoutText, exitCode, stderrText) {
    probing = false
    if (exitCode !== 0) {
      authenticated = false
      userEmail = ""
      var detail = String(stderrText || "").trim().split("\n")[0]
      lastError = detail !== ""
        ? detail
        : ("Not signed in. Run: peponi auth login (exit " + exitCode + ")")
      statusMessage = lastError
      dayTasks = []
      notYetItems = []
      openTaskCount = 0
      return
    }
    try {
      var data = JSON.parse(stdoutText || "{}")
      authenticated = data.authenticated === true
      if (data.user) {
        userEmail = data.user.email || ""
        appTitle = data.user.app_title || "Peponi"
        notYetTitle = data.user.not_yet_panel_title || "Not Yet"
      }
      statusMessage = authenticated ? ("Signed in as " + userEmail) : "Not signed in"
      lastError = authenticated ? "" : statusMessage
    } catch (e) {
      authenticated = false
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
      lastError = "Failed to load day (is peponi signed in?)"
      dayTasks = []
      openTaskCount = 0
      return
    }
    dayTasks = Model.tasksFromDayJson(stdoutText)
    openTaskCount = Model.openCount(dayTasks)
    lastError = ""
  }

  function applyNotYet(stdoutText, exitCode) {
    loadingNotYet = false
    if (exitCode !== 0) {
      notYetItems = []
      return
    }
    try {
      var data = JSON.parse(stdoutText || "{}")
      if (data.title) notYetTitle = data.title
    } catch (e) {}
    notYetItems = Model.notYetFromJson(stdoutText)
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
