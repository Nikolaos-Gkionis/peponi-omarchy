// Peponi One Day — date helpers + task shaping.
// Live JSON comes from the peponi CLI (local store or peponi.to).
// Demo data only when PEPONI_DEMO=1 (offline smoke).

var WEEKDAYS_LONG = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
var WEEKDAYS_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var MONTHS_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function pad2(n) {
  return (n < 10 ? "0" : "") + n
}

function keyForDate(date) {
  var d = date instanceof Date ? date : new Date(date)
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

function stepDay(date, delta) {
  var d = date instanceof Date ? new Date(date.getTime()) : new Date(date)
  d.setHours(12, 0, 0, 0)
  d.setDate(d.getDate() + (delta || 0))
  return d
}

function startOfToday() {
  var d = new Date()
  d.setHours(12, 0, 0, 0)
  return d
}

function isSameDay(a, b) {
  return keyForDate(a) === keyForDate(b)
}

function dayHeading(date) {
  var d = date instanceof Date ? date : new Date(date)
  return WEEKDAYS_LONG[d.getDay()] + " · " + MONTHS_SHORT[d.getMonth()] + " " + d.getDate()
}

function relativeLabel(selected, today) {
  if (keyForDate(selected) === keyForDate(today)) return "Today"
  var a = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate(), 12)
  var b = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 12)
  var diff = Math.round((a - b) / 86400000)
  if (diff === 1) return "Tomorrow"
  if (diff === -1) return "Yesterday"
  if (diff > 1) return "In " + diff + " days"
  return Math.abs(diff) + " days ago"
}

function openCount(tasks) {
  var n = 0
  for (var i = 0; i < tasks.length; i++) if (!tasks[i].done) n++
  return n
}

function parsePayloadDate(payloadJson) {
  var payload = ({})
  try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
  if (payload.date) {
    var parts = String(payload.date).split("-")
    if (parts.length === 3) {
      var y = parseInt(parts[0], 10)
      var m = parseInt(parts[1], 10) - 1
      var day = parseInt(parts[2], 10)
      if (isFinite(y) && isFinite(m) && isFinite(day)) {
        var d = new Date(y, m, day, 12, 0, 0, 0)
        if (!isNaN(d.getTime())) return d
      }
    }
  }
  return startOfToday()
}

function demoEnabled() {
  return false
}

// Shape API / CLI day JSON → DayView rows ({ id, title, done, list })
function tasksFromDayJson(raw) {
  var data = ({})
  try { data = JSON.parse(raw || "{}") } catch (e) { return [] }
  var rows = data.tasks || []
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var t = rows[i] || {}
    out.push({
      id: t.id,
      title: String(t.title || ""),
      done: t.completed === true || t.done === true,
      list: String(t.list || ""),
      is_visual_break: t.is_visual_break === true
    })
  }
  return out
}

// Flatten Not Yet pages → drawer rows ({ id, title, list, done })
function notYetFromJson(raw) {
  var data = ({})
  try { data = JSON.parse(raw || "{}") } catch (e) { return [] }
  var pages = data.pages || []
  var out = []
  for (var p = 0; p < pages.length; p++) {
    var page = pages[p] || {}
    var listName = String(page.name || "")
    var todos = page.todos || []
    for (var i = 0; i < todos.length; i++) {
      var t = todos[i] || {}
      if (t.is_visual_break === true) continue
      out.push(notYetRow(t, listName))
    }
  }
  return out
}

// One drawer row. listName is the page/inbox name from the API.
function notYetRow(task, listName) {
  task = task || {}
  return {
    id: task.id,
    title: String(task.title || ""),
    list: String(task.list || listName || ""),
    done: task.completed === true || task.done === true
  }
}

function copyRows(rows) {
  var out = []
  if (!rows) return out
  for (var i = 0; i < rows.length; i++) out.push(rows[i])
  return out
}

function peponiCommand() {
  // Prefer PATH; install.sh also drops a copy in ~/.local/bin
  return "peponi"
}

function dayCommand(dateKey) {
  return [peponiCommand(), "day", dateKey, "--json"]
}

function notYetCommand() {
  return [peponiCommand(), "not-yet", "--json"]
}

function authStatusCommand() {
  return [peponiCommand(), "auth", "status", "--json"]
}

// ---------------------------------------------------------------------------
// DEMO stubs (PEPONI_DEMO=1 only)
// ---------------------------------------------------------------------------
var demoByWeekday = {
  0: [{ title: "Weekly review", done: false, list: "Planning" }],
  1: [
    { title: "Ship Omarchy overlay", done: false, list: "Work" },
    { title: "Write the plugin README", done: false, list: "Work" },
    { title: "Gym", done: true, list: "Health" }
  ],
  2: [{ title: "Write docs", done: false, list: "Work" }],
  3: [{ title: "Mid-week check-in", done: false, list: "Work" }],
  4: [{ title: "Friday demo", done: false, list: "Work" }],
  5: [{ title: "Ship the week", done: false, list: "Work" }],
  6: [{ title: "Long walk", done: false, list: "Health" }]
}

var demoNotYet = [
  { title: "Book dentist", list: "Personal" },
  { title: "Rewrite onboarding", list: "Work" },
  { title: "Reply to design notes", list: "Work" }
]

function tasksForDate(date) {
  var d = date instanceof Date ? date : new Date(date)
  var rows = demoByWeekday[d.getDay()] || []
  var out = []
  for (var i = 0; i < rows.length; i++) {
    out.push({
      id: "demo-" + d.getDay() + "-" + i,
      title: rows[i].title,
      done: rows[i].done === true,
      list: rows[i].list || ""
    })
  }
  return out
}

function notYetItems() {
  var out = []
  for (var i = 0; i < demoNotYet.length; i++) {
    out.push({ title: demoNotYet[i].title, list: demoNotYet[i].list || "" })
  }
  return out
}
