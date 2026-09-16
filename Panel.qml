import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "cjkaufman.runescape"
  ipcTarget: "cjkaufman.runescape"
  manageIpc: false

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function togglePopup(): void { root.togglePopup() }
    function dismissPopup(): void { root.dismissPopup() }
  }

  // Glyphs & Icons (JetBrainsMono Nerd Font)
  readonly property string glyphCrossSwords: String.fromCodePoint(0xF0787) // Iconic OSRS crossed swords
  readonly property string glyphSword: String.fromCodePoint(0xF04E5)       // Sword
  readonly property string glyphShieldSword: String.fromCodePoint(0xF18BE) // Shield with sword
  readonly property string glyphGamepad: String.fromCodePoint(0xF02B4)     // Gamepad controller
  readonly property string glyphAlert: String.fromCodePoint(0xF0026)       // Alert
  readonly property string glyphPlay: String.fromCodePoint(0xF040A)        // Play icon
  readonly property string glyphRefresh: String.fromCodePoint(0xF0450)     // Refresh
  readonly property string glyphClose: String.fromCodePoint(0xF0156)       // Close
  readonly property string glyphExpand: String.fromCodePoint(0xF037C)      // Window expand
  readonly property string glyphDock: String.fromCodePoint(0xF037D)        // Window dock

  readonly property string helper: Qt.resolvedUrl("bin/runescape-helper").toString().replace("file://", "")
  readonly property string iconPath: Qt.resolvedUrl("icon.png").toString()

  // Theme Styling
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color successColor: "#4EBA6F"
  readonly property color dim: Qt.darker(foreground, 1.6)
  readonly property color subtleBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.07)
  readonly property color cardBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.04)
  readonly property color borderCol: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Plugin Settings
  readonly property int popupWidth: Math.max(600, Number(setting("popupWidth", 840)))
  readonly property int popupHeight: Math.max(400, Number(setting("popupHeight", 600)))
  readonly property bool autoHideOnBlur: Boolean(setting("autoHideOnBlur", true))
  readonly property bool flashOnAlert: Boolean(setting("flashOnAlert", true))

  // Live State
  property bool running: false
  property bool launcherRunning: false
  property string character: ""
  property bool popupOpen: false
  property string mode: "popup"
  property bool alert: false
  property string alertMessage: ""
  property bool flashPhase: false
  property bool showCharacterName: Boolean(setting("showCharacterName", true))

  // Reactive State File Watcher
  FileView {
    id: stateWatcher
    path: Quickshell.env("HOME") + "/.local/state/omarchy/cjkaufman.runescape/state.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.parseState(text())
    onFileChanged: reload()
    Component.onCompleted: reload()
  }

  function parseState(raw) {
    try {
      if (!raw || raw.trim() === "") return
      var s = JSON.parse(raw)
      root.running = s.running === true
      root.launcherRunning = s.launcherRunning === true
      root.character = String(s.character || "")
      root.popupOpen = s.popupOpen === true
      root.mode = String(s.mode || "popup")
      root.alert = s.alert === true
      root.alertMessage = String(s.alertMessage || "")
      if (s.showCharacterName !== undefined) {
        root.showCharacterName = s.showCharacterName === true
      }
    } catch (e) {
      console.warn("runescape state parse error", e)
    }
  }

  // Flashing animation on alert
  Timer {
    id: flashTimer
    interval: 400
    repeat: true
    running: root.alert && root.flashOnAlert
    onTriggered: root.flashPhase = !root.flashPhase
    onRunningChanged: if (!running) root.flashPhase = false
  }

  // Periodic Status Poller
  Timer {
    interval: 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.requestStatus()
  }

  // Process Handler for CLI commands
  Process {
    id: helperProc
    command: [root.helper]
    stdinEnabled: true
    property string payload: ""
    onStarted: {
      if (payload) write(payload + "\n")
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var res = JSON.parse(String(text || "{}"))
          if (res.running !== undefined) root.running = res.running === true
          if (res.character) root.character = res.character
          if (res.popupOpen !== undefined) root.popupOpen = res.popupOpen === true
          if (res.alert !== undefined) root.alert = res.alert === true
          if (res.alertMessage !== undefined) root.alertMessage = res.alertMessage
          if (res.showCharacterName !== undefined) root.showCharacterName = res.showCharacterName === true
        } catch (e) {}
      }
    }
  }

  function sendAction(actionName, extra) {
    var data = Object.assign({ action: actionName }, extra || {})
    helperProc.running = false
    helperProc.payload = JSON.stringify(data)
    helperProc.running = true
  }

  function requestStatus() {
    sendAction("status")
  }

  function togglePopup() {
    sendAction("toggle", {
      width: root.popupWidth,
      height: root.popupHeight
    })
  }

  function dismissPopup() {
    sendAction("dismiss")
  }

  function detachWindow() {
    sendAction("detach", { workspace: "5" })
  }

  function dockWindow() {
    sendAction("dock")
  }

  function launchJagex() {
    sendAction("launch")
  }

  function launchRuneLite() {
    sendAction("launch_runelite")
  }

  function clearAlert() {
    sendAction("clear_alert")
  }

  function toggleLauncher() {
    sendAction("toggle_launcher")
  }

  function quitGame() {
    sendAction("quit")
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
  }

  function toggleCharacterNameDisplay() {
    var nextVal = !root.showCharacterName
    root.showCharacterName = nextVal
    persistSettings({ showCharacterName: nextVal })
    sendAction("set_config", { showCharacterName: nextVal })
  }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight
  width: implicitWidth
  height: implicitHeight

  // Top Bar Button
  WidgetButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    dimmed: root.alert ? !root.flashPhase : false
    active: root.alert ? root.flashPhase : (root.mode === "popup" && root.popupOpen)
    activeColor: root.alert ? root.urgent : root.accent
    useActiveColor: true
    labelVisible: true
    fontSize: Style.font.body
    text: {
      var showName = root.showCharacterName
      if (root.alert) {
        if (showName && root.character) {
          return root.glyphCrossSwords + " " + root.character + " (AFK!)"
        }
        return root.glyphCrossSwords
      }
      if (showName && root.running && root.character) {
        return root.glyphCrossSwords + " " + root.character
      }
      return root.glyphCrossSwords
    }

    tooltipText: {
      if (root.alert) {
        return "⚠️ RuneScape Alert: " + (root.alertMessage || "Idle / Stopped mining!") + " (Click to focus)"
      }
      if (root.running) {
        var charStr = root.character ? (" (" + root.character + ")") : ""
        if (root.mode === "normal") {
          return "RuneScape: Active" + charStr + " (Normal Mode) · Left-click: Focus · Right-click: Menu"
        }
        return "RuneScape: Active" + charStr + " · Left-click: Toggle Quick-Screen · Right-click: Menu"
      }
      return "RuneScape / RuneLite: Offline (Click to launch & login)"
    }

    onPressed: function (btn) {
      if (btn === Qt.RightButton) {
        root.toggle()
      } else {
        if (!root.running) {
          root.toggle()
        } else {
          if (root.alert) {
            root.clearAlert()
            if (!root.popupOpen) {
              root.togglePopup()
            }
          } else {
            if (root.mode === "normal") {
              root.togglePopup()
            } else {
              if (root.popupOpen) {
                root.dismissPopup()
              } else {
                root.togglePopup()
              }
            }
          }
        }
      }
    }
  }

  // Dropdown Menu & Login Panel
  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(menuCol.implicitHeight + Style.space(24), Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: menuCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: menuCol
          width: parent.width
          spacing: Style.space(12)

          // Header
          RowLayout {
            width: parent.width
            spacing: Style.space(10)

            Image {
              source: root.iconPath
              sourceSize.width: 48
              sourceSize.height: 48
              Layout.preferredWidth: 28
              Layout.preferredHeight: 28
              fillMode: Image.PreserveAspectFit
              smooth: true
              visible: status === Image.Ready
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(2)

              Text {
                text: "Old School RuneScape"
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                text: root.running ? ("Online: " + (root.character || "DarkOmenZA")) : "Jagex Account & RuneLite"
                textFormat: Text.PlainText
                color: root.running ? root.successColor : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              Layout.preferredWidth: 10
              Layout.preferredHeight: 10
              radius: 5
              color: root.running ? root.successColor : root.urgent
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: root.borderCol
          }

          // Active Alert Banner
          Rectangle {
            width: parent.width
            implicitHeight: alertRow.implicitHeight + Style.space(16)
            radius: 8
            color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.15)
            border.color: root.urgent
            border.width: 1
            visible: root.alert

            RowLayout {
              id: alertRow
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text {
                text: "⚠️"
                textFormat: Text.PlainText
                font.pixelSize: Style.font.body
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(2)

                Text {
                  text: "AFK / Idle Alert Triggered"
                  textFormat: Text.PlainText
                  color: root.urgent
                  font.bold: true
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: root.alertMessage || "You have stopped mining or gone idle!"
                  textFormat: Text.PlainText
                  color: root.foreground
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }

              Button {
                text: "Clear"
                onClicked: root.clearAlert()
              }
            }
          }

          // Bar Appearance Settings
          Rectangle {
            width: parent.width
            height: Style.space(48)
            radius: 8
            color: root.cardBg
            border.color: root.borderCol
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(10)

              Text {
                text: root.glyphCrossSwords
                textFormat: Text.PlainText
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                color: root.accent
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  text: "Bar Display"
                  textFormat: Text.PlainText
                  font.bold: true
                  color: root.foreground
                  font.pixelSize: Style.font.caption
                }

                Text {
                  text: root.showCharacterName
                    ? ("Name & Icon (" + (root.character || "DarkOmenZA") + ")")
                    : "Icon Only"
                  textFormat: Text.PlainText
                  color: root.dim
                  font.pixelSize: Style.font.caption - 1
                }
              }

              // Interactive Toggle Pill
              Rectangle {
                Layout.preferredWidth: Style.space(92)
                Layout.preferredHeight: Style.space(26)
                radius: 13
                color: root.showCharacterName ? root.accent : root.subtleBg
                border.color: root.showCharacterName ? root.accent : root.borderCol
                border.width: 1

                MouseArea {
                  id: modeToggleMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleCharacterNameDisplay()
                }

                Text {
                  anchors.centerIn: parent
                  text: root.showCharacterName ? "Name & Icon" : "Icon Only"
                  textFormat: Text.PlainText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                  color: root.showCharacterName ? Color.background : root.foreground
                }
              }
            }
          }

          // In-Game Options (When RuneLite is running)
          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.running

            Text {
              text: "Quick Controls"
              textFormat: Text.PlainText
              color: root.dim
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            // Primary Toggle Quick Screen
            Rectangle {
              width: parent.width
              height: Style.space(42)
              radius: 6
              color: root.accent
              opacity: toggleMouse.containsMouse ? 0.9 : 1.0

              MouseArea {
                id: toggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  panel.open = false
                  if (root.popupOpen) {
                    root.dismissPopup()
                  } else {
                    root.togglePopup()
                  }
                }
              }

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: root.popupOpen ? "🗔" : "🗖"
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.body
                  color: Color.background
                }

                Text {
                  text: root.popupOpen ? "Hide Quick-Screen" : "Show Quick-Screen (840×600)"
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.body
                  font.bold: true
                  color: Color.background
                }
              }
            }

            // Detach to Workspace 5
            Rectangle {
              width: parent.width
              height: Style.space(36)
              radius: 6
              color: root.subtleBg
              border.color: root.borderCol
              border.width: 1

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  panel.open = false
                  root.detachWindow()
                }
              }

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: root.glyphExpand
                  textFormat: Text.PlainText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.foreground
                }

                Text {
                  text: "Move to Workspace 5 (Fullscreen Session)"
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.caption
                  color: root.foreground
                }
              }
            }

            // Dock back to Scratchpad
            Rectangle {
              width: parent.width
              height: Style.space(36)
              radius: 6
              color: root.subtleBg
              border.color: root.borderCol
              border.width: 1
              visible: root.mode === "normal"

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.dockWindow()
                }
              }

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: root.glyphDock
                  textFormat: Text.PlainText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.accent
                }

                Text {
                  text: "Dock Back to Quick-Screen Scratchpad"
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.caption
                  color: root.accent
                }
              }
            }
            // Toggle Jagex Launcher in Background
            Rectangle {
              width: parent.width
              height: Style.space(36)
              radius: 6
              color: root.subtleBg
              border.color: root.borderCol
              border.width: 1

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.close()
                  root.toggleLauncher()
                }
              }

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: root.glyphGamepad
                  textFormat: Text.PlainText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.foreground
                }

                Text {
                  text: "Show / Hide Jagex Launcher"
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.caption
                  color: root.foreground
                }
              }
            }

            // Clean Quit (Both Game & Launcher)
            Rectangle {
              width: parent.width
              height: Style.space(36)
              radius: 6
              color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.1)
              border.color: root.urgent
              border.width: 1

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.close()
                  root.quitGame()
                }
              }

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: root.glyphClose
                  textFormat: Text.PlainText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.urgent
                }

                Text {
                  text: "Quit Game & Launcher Session"
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.caption
                  color: root.urgent
                  font.bold: true
                }
              }
            }
          }

          // Offline / Launch Controls (When RuneLite is not running)
          Column {
            width: parent.width
            spacing: Style.space(10)
            visible: !root.running

            Rectangle {
              width: parent.width
              implicitHeight: infoCol.implicitHeight + Style.space(16)
              radius: 8
              color: root.cardBg
              border.color: root.borderCol
              border.width: 1

              ColumnLayout {
                id: infoCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(6)

                Text {
                  text: "Connect to Jagex Account"
                  textFormat: Text.PlainText
                  font.bold: true
                  color: root.foreground
                  font.pixelSize: Style.font.body
                }

                Text {
                  text: "Launch the official Jagex Launcher to authenticate your character and start RuneLite. Once in game, the popup scratchpad will activate automatically."
                  textFormat: Text.PlainText
                  color: root.dim
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                  font.pixelSize: Style.font.caption
                }
              }
            }

            // Launch Jagex Launcher Button
            Rectangle {
              width: parent.width
              height: Style.space(42)
              radius: 6
              color: root.accent
              opacity: jagexMouse.containsMouse ? 0.9 : 1.0

              MouseArea {
                id: jagexMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.launchJagex()
                }
              }

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: "⚔️"
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.body
                  color: Color.background
                }

                Text {
                  text: "Launch Jagex Launcher & Login"
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.body
                  font.bold: true
                  color: Color.background
                }
              }
            }

            // Launch RuneLite Directly Button
            Rectangle {
              width: parent.width
              height: Style.space(36)
              radius: 6
              color: root.subtleBg
              border.color: root.borderCol
              border.width: 1

              MouseArea {
                id: runeliteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.launchRuneLite()
                }
              }

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: "⚡"
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.caption
                  color: root.foreground
                }

                Text {
                  text: "Start RuneLite Directly"
                  textFormat: Text.PlainText
                  font.pixelSize: Style.font.caption
                  color: root.foreground
                }
              }
            }
          }

          // Footer
          Item {
            width: parent.width
            height: Style.space(8)
          }
        }
      }
    }
  }
}
