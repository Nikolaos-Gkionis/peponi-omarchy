import QtQuick
import qs.Commons
import qs.Ui

// Not Yet bottom drawer — lives INSIDE the overlay window.
// Beginner note: this is UI state (drawerOpen), not a second Wayland layer.
Item {
  id: root

  property bool open: false
  property var items: []
  property int selectedIndex: 0
  property bool cursorActive: false
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color dim: Qt.darker(Color.menu.text, 1.55)
  property color accent: Color.accent
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property string fontFamily: Style.font.menuFamily

  // Drawer height when open (fraction of parent). Closed height is 0.
  readonly property real openHeight: Math.min(Style.space(280), parent ? parent.height * 0.42 : Style.space(280))

  function select(delta) {
    if (items.length === 0) {
      selectedIndex = 0
      cursorActive = false
      return
    }
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? items.length - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + items.length) % items.length
    }
  }

  signal requestFocus()

  function resetCursor() {
    selectedIndex = 0
    cursorActive = false
  }

  // Highlight a row so Delete / typing has a target. Used when the drawer opens.
  function ensureCursor() {
    if (!items || items.length === 0) {
      selectedIndex = 0
      cursorActive = false
      return
    }
    if (selectedIndex >= items.length)
      selectedIndex = items.length - 1
    if (selectedIndex < 0)
      selectedIndex = 0
    cursorActive = true
  }

  function selectIndex(index) {
    if (!items || items.length === 0) return
    if (index < 0 || index >= items.length) return
    selectedIndex = index
    cursorActive = true
    requestFocus()
  }

  onItemsChanged: {
    if (!items || items.length === 0) {
      selectedIndex = 0
      cursorActive = false
      return
    }
    if (selectedIndex >= items.length)
      selectedIndex = items.length - 1
    if (root.open && !cursorActive)
      ensureCursor()
  }

  // Slide-up panel anchored to the bottom of the overlay content.
  BorderSurface {
    id: sheet
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: root.open ? root.openHeight : 0
    visible: height > 0.5
    radius: Style.cornerRadius
    color: root.background
    borderSpec: root.borderSpec
    padding: Style.spacing.panelPadding
    clip: true

    Behavior on height {
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    Column {
      anchors.fill: parent
      anchors.topMargin: sheet.contentTopInset
      anchors.rightMargin: sheet.contentRightInset
      anchors.bottomMargin: sheet.contentBottomInset
      anchors.leftMargin: sheet.contentLeftInset
      spacing: Style.space(10)

      Row {
        id: headerRow
        width: parent.width
        spacing: Style.space(10)

        Text {
          text: "NOT YET"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.items.length + " undated"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Item { width: 1; height: 1 }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "n add · a today · del remove · ↑ ↓ · y/esc close"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Rectangle {
        id: rule
        width: parent.width
        height: 1
        color: root.border
        opacity: 0.45
      }

      Flickable {
        width: parent.width
        height: Math.max(Style.space(64), parent.height - headerRow.height - rule.height - parent.spacing * 2)
        contentWidth: width
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Clicks here would steal overlay keys — hand them back immediately.
        onActiveFocusChanged: {
          if (activeFocus)
            root.requestFocus()
        }

        Column {
          id: listColumn
          width: parent.width
          spacing: Style.space(4)

          Text {
            visible: !root.items || root.items.length === 0
            width: parent.width
            text: "Inbox is empty. Press n to add."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            topPadding: Style.space(16)
          }

          Repeater {
            // Integer model: JS object arrays often fail to show rows in Quickshell.
            model: root.items ? root.items.length : 0

            Rectangle {
              required property int index
              readonly property var row: (root.items && root.items[index]) ? root.items[index] : ({})
              width: listColumn.width
              height: itemRow.implicitHeight + Style.space(12)
              radius: Style.cornerRadius
              color: root.cursorActive && root.selectedIndex === index
                ? root.selectedBackground
                : "transparent"

              MouseArea {
                anchors.fill: parent
                z: 2
                onClicked: root.selectIndex(index)
              }

              Row {
                id: itemRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(10)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰘓"
                  color: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                Column {
                  width: parent.width - Style.space(36)
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    text: row.title || ""
                    textFormat: Text.PlainText
                    color: root.cursorActive && root.selectedIndex === index
                      ? root.selectedText
                      : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: row.list && row.list !== ""
                    width: parent.width
                    text: row.list || ""
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
}
