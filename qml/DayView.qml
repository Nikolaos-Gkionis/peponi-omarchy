import QtQuick
import qs.Commons
import qs.Ui

// One day's task list for the selected date.
// Parent (Overlay) owns selectedDate + task model; this is presentation only.
// Mouse: click checkbox to tick, arrows to move, row to highlight.
// Keyboard lives on Overlay (j/k, Space, J/K).
Item {
  id: root

  property var tasks: []
  property int selectedIndex: 0
  property bool cursorActive: false
  property color foreground: Color.menu.text
  property color dim: Qt.darker(Color.menu.text, 1.55)
  property color accent: Color.accent
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property string fontFamily: Style.font.menuFamily

  signal toggleRequested(var taskId)
  signal moveRequested(var taskId, int delta)
  signal rowClicked(int index)

  readonly property int openCount: {
    var n = 0
    for (var i = 0; i < tasks.length; i++) if (!tasks[i].done) n++
    return n
  }

  function select(delta) {
    if (tasks.length === 0) {
      selectedIndex = 0
      cursorActive = false
      return
    }
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? tasks.length - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + tasks.length) % tasks.length
    }
  }

  function selectIndex(index) {
    if (!tasks || tasks.length === 0) return
    if (index < 0 || index >= tasks.length) return
    selectedIndex = index
    cursorActive = true
  }

  // After tick/move the list reorders — keep the same task highlighted.
  function selectById(id) {
    if (!tasks || id === undefined || id === null) return false
    var want = String(id)
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i] && String(tasks[i].id) === want) {
        selectedIndex = i
        cursorActive = true
        return true
      }
    }
    return false
  }

  function resetCursor() {
    selectedIndex = 0
    cursorActive = false
  }

  function rowId(index) {
    if (!tasks || index < 0 || index >= tasks.length) return ""
    var row = tasks[index]
    return row && row.id !== undefined && row.id !== null ? row.id : ""
  }

  // After add/remove the list length changes — keep the highlight valid.
  onTasksChanged: {
    if (!tasks || tasks.length === 0) {
      selectedIndex = 0
      cursorActive = false
      return
    }
    if (selectedIndex >= tasks.length)
      selectedIndex = tasks.length - 1
  }

  Column {
    anchors.fill: parent
    spacing: Style.space(10)

    Text {
      width: parent.width
      text: root.tasks.length === 0
        ? "No tasks for this day"
        : (root.openCount + " open · " + root.tasks.length + " total")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Flickable {
      width: parent.width
      height: parent.height - Style.space(28)
      contentWidth: width
      contentHeight: taskColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick

      Column {
        id: taskColumn
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: root.tasks

          Rectangle {
            required property var modelData
            required property int index
            width: taskColumn.width
            height: row.implicitHeight + Style.space(14)
            radius: Style.cornerRadius
            color: (hover.containsMouse || (root.cursorActive && root.selectedIndex === index))
              ? root.selectedBackground
              : "transparent"

            MouseArea {
              id: hover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton
              onClicked: {
                root.selectIndex(index)
                root.rowClicked(index)
              }
            }

            Row {
              id: row
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(10)

              // Checkbox — mouse tick. Keyboard uses Space on the highlighted row.
              Text {
                id: checkGlyph
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.done ? "󰄲" : "󰄱"
                color: modelData.done ? root.dim : root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -Style.space(6)
                  cursorShape: Qt.PointingHandCursor
                  preventStealing: true
                  z: 5
                  onClicked: {
                    root.selectIndex(index)
                    root.toggleRequested(modelData.id)
                  }
                }
              }

              Column {
                width: parent.width - Style.space(88)
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: modelData.title
                  textFormat: Text.PlainText
                  color: (hover.containsMouse || (root.cursorActive && root.selectedIndex === index))
                    ? root.selectedText
                    : (modelData.done ? root.dim : root.foreground)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.strikeout: modelData.done === true
                  elide: Text.ElideRight
                }

                Text {
                  visible: modelData.list && modelData.list !== ""
                  width: parent.width
                  text: modelData.list
                  textFormat: Text.PlainText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              // Mouse move — same as keyboard J / K. Shown on hover or highlight.
              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)
                visible: hover.containsMouse || (root.cursorActive && root.selectedIndex === index)
                opacity: visible ? 1 : 0

                Text {
                  text: "↑"
                  color: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Style.space(6)
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    z: 5
                    onClicked: {
                      root.selectIndex(index)
                      root.moveRequested(modelData.id, -1)
                    }
                  }
                }

                Text {
                  text: "↓"
                  color: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Style.space(6)
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    z: 5
                    onClicked: {
                      root.selectIndex(index)
                      root.moveRequested(modelData.id, 1)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
