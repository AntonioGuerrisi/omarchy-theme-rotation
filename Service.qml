import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  readonly property string pluginId: "antonio.theme-rotation"
  property var settings: ({})
  property bool settingsLoaded: false
  readonly property bool paused: settings.paused === true
  readonly property int intervalMinutes: {
    var value = Number(settings.intervalMinutes)
    return isFinite(value) && value > 0 ? Math.max(1, Math.min(10080, Math.round(value))) : 30
  }
  readonly property var includedThemes: Array.isArray(settings.includedThemes) ? settings.includedThemes : null
  property var availableThemes: []
  readonly property int themeCount: availableThemes.filter(function(theme) {
    return root.includedThemes === null || root.includedThemes.indexOf(theme) !== -1
  }).length
  readonly property bool busy: process.running
  property string currentTheme: ""
  property string lastError: ""

  function loadSettings(text) {
    try {
      var config = JSON.parse(text)
      var layout = config.bar ? config.bar.layout : null
      var sections = ["left", "center", "right"]
      for (var s = 0; layout && s < sections.length; s++) {
        var entries = layout[sections[s]] || []
        for (var i = 0; i < entries.length; i++) {
          if (entries[i].id !== pluginId) continue
          settings = entries[i]
          settingsLoaded = true
          return
        }
      }
    } catch (error) {
      console.warn("Theme Rotation settings: " + error)
    }
  }

  function run(action) {
    if (busy) return false
    lastError = ""
    var helperPath = decodeURIComponent(String(Qt.resolvedUrl("rotate.sh")).replace(/^file:\/\//, ""))
    process.command = ["bash", helperPath, action, JSON.stringify(includedThemes)]
    process.running = true
    return true
  }

  function next() {
    return run("next")
  }

  function setPaused(value) {
    if (!shell) return false
    var updated = JSON.parse(JSON.stringify(settings))
    updated.paused = value
    if (!shell.updateEntryInline(pluginId, updated)) return paused === value
    settings = updated
    return true
  }

  function toggle() {
    return setPaused(!paused)
  }

  function configure(minutes, themes) {
    minutes = Number(minutes)
    // QML method calls may wrap arrays as QVariantList instead of JS arrays.
    themes = JSON.parse(JSON.stringify(themes))
    if (!shell || !settingsLoaded) {
      lastError = "Impostazioni non ancora pronte."
      return false
    }
    if (!isFinite(minutes) || minutes < 1 || minutes > 10080 || Math.round(minutes) !== minutes) {
      lastError = "Inserisci un intervallo da 1 a 10080 minuti."
      return false
    }
    if (themes !== null && (!Array.isArray(themes) || themes.some(function(theme) {
      return typeof theme !== "string" || theme.trim() === ""
    }))) {
      lastError = "Selezione dei temi non valida."
      return false
    }
    var updated = JSON.parse(JSON.stringify(settings))
    updated.intervalMinutes = minutes
    updated.includedThemes = themes === null ? null : themes.filter(function(theme, index, list) {
      return list.indexOf(theme) === index
    })
    if (JSON.stringify(updated) !== JSON.stringify(settings)
        && !shell.updateEntryInline(pluginId, updated)) {
      lastError = "Impossibile salvare le impostazioni."
      return false
    }
    settings = updated
    lastError = ""
    return true
  }

  function status() {
    return JSON.stringify({
      currentTheme: currentTheme,
      themeCount: themeCount,
      availableThemes: availableThemes,
      includedThemes: includedThemes,
      intervalMinutes: intervalMinutes,
      paused: paused,
      busy: busy,
      lastError: lastError,
      timerRunning: rotationTimer.running
    })
  }

  Component.onCompleted: Qt.callLater(function() { root.run("status") })

  Timer {
    id: rotationTimer
    interval: root.intervalMinutes * 60000
    running: root.shell !== null && root.settingsLoaded && root.themeCount > 0 && !root.paused && !root.busy
    repeat: true
    onTriggered: root.next()
  }

  // Read the persisted entry directly: host bar snapshots can lag one update.
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onLoaded: root.loadSettings(text())
    onFileChanged: reload()
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    onFileChanged: {
      reload()
      root.run("status")
    }
  }

  Process {
    id: process
    stdout: StdioCollector { id: output }
    stderr: StdioCollector { id: errors }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = errors.text.trim() || "Theme rotation failed (exit " + exitCode + ")"
        console.warn("Theme Rotation: " + root.lastError)
        return
      }
      try {
        var result = JSON.parse(output.text)
        root.currentTheme = result.current
        root.availableThemes = result.themes
      } catch (error) {
        root.lastError = String(error)
        console.warn("Theme Rotation: " + root.lastError)
      }
    }
  }

  IpcHandler {
    target: "theme-rotation"

    function status(): string { return root.status() }
    function next(): string { return root.next() ? "ok" : "busy" }
    function pause(): string { return root.setPaused(true) ? "ok" : "error" }
    function resume(): string { return root.setPaused(false) ? "ok" : "error" }
    function configure(configJson: string): string {
      try {
        var config = JSON.parse(configJson)
        return root.configure(config.intervalMinutes, config.includedThemes) ? "ok" : "error"
      } catch (error) {
        console.warn("Theme Rotation settings: " + error)
        return "error"
      }
    }
  }
}
