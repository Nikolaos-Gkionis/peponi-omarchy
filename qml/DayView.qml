import QtQuick
import qs.Commons
import qs.Ui

// One day's task list for the selected date.
// Parent (Overlay) owns selectedDate + task model; this is presentation only.
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

  function resetCursor() {
    selectedIndex = 0
    cursorActive = false
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
            color: root.cursorActive && root.selectedIndex === index
              ? root.selectedBackground
              : "transparent"

            Row {
              id: row
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(12)

              // Checkbox glyph (done vs open)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.done ? "󰄲" : "󰄱"
                color: modelData.done ? root.dim : root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              Column {
                width: parent.width - Style.space(40)
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: modelData.title
                  textFormat: Text.PlainText
                  color: root.cursorActive && root.selectedIndex === index
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
            }
          }
        }
      }
    }
  }
}
