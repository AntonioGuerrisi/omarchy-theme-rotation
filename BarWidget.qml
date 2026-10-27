import QtQuick
import QtQuick.Controls as QQC
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "antonio.theme-rotation"

  readonly property var rotator: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  property bool popupOpen: false
  property bool useAllThemes: true
  property var draftThemes: []
  property string settingsError: ""

  function close() {
    popupOpen = false
  }

  function openSettings() {
    if (!rotator) return
    useAllThemes = rotator.includedThemes === null
    draftThemes = useAllThemes ? rotator.availableThemes.slice() : rotator.includedThemes.slice()
    intervalField.value = rotator.intervalMinutes
    intervalField.field.value = rotator.intervalMinutes
    settingsError = ""
    rotator.run("status")
    popupOpen = true
  }

  function toggleTheme(theme) {
    var selected = draftThemes.slice()
    var index = selected.indexOf(theme)
    if (index === -1) selected.push(theme)
    else selected.splice(index, 1)
    draftThemes = selected
  }

  function saveSettings() {
    var field = intervalField.field
    var minutes = field.valueFromText(field.contentItem.text, field.locale)
    if (!rotator || !rotator.configure(minutes, useAllThemes ? null : draftThemes)) {
      settingsError = rotator ? rotator.lastError : "Rotazione temi non disponibile."
      return
    }
    close()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: !root.rotator ? "..." : (root.rotator.paused ? "II" : "TR")
    dimmed: !root.rotator || root.rotator.paused
    interactive: root.rotator !== null
    tooltipText: {
      var service = root.rotator
      if (!service) return "Rotazione temi non disponibile"
      return "Tema: " + service.currentTheme
        + "\nRotazione casuale: " + (service.paused ? "in pausa" : "ogni " + service.intervalMinutes + " min")
        + "\nTemi inclusi: " + service.themeCount + "/" + service.availableThemes.length
        + "\nClic sinistro: pausa/riprendi"
        + "\nClic destro: cambia tema"
        + "\nClic centrale: impostazioni"
        + (service.lastError ? "\nErrore: " + service.lastError : "")
    }
    onPressed: function(button) {
      if (!root.rotator) return
      if (button === Qt.LeftButton) root.rotator.toggle()
      else if (button === Qt.MiddleButton) {
        if (root.popupOpen) root.close()
        else root.openSettings()
      }
      else root.rotator.next()
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      width: parent.width
      spacing: Style.space(10)

      Text {
        text: "Rotazione temi"
        color: Commons.Color.popups.text
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      NumberField {
        id: intervalField
        label: "Intervallo (minuti)"
        from: 1
        to: 10080
        value: 30
        foreground: Commons.Color.popups.text
        onModified: function(value) { intervalField.value = value }
      }

      Toggle {
        width: parent.width
        label: "Tutti i temi installati"
        description: "Includi automaticamente anche i nuovi temi."
        checked: root.useAllThemes
        foreground: Commons.Color.popups.text
        onClicked: root.useAllThemes = !root.useAllThemes
      }

      Flickable {
        id: themeList
        width: parent.width
        height: visible ? Math.min(Style.space(240), themeRows.implicitHeight) : 0
        visible: !root.useAllThemes
        contentHeight: themeRows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar {}

        Column {
          id: themeRows
          width: themeList.width - Style.space(12)
          spacing: Style.space(4)

          Repeater {
            model: root.rotator ? root.rotator.availableThemes : []

            Toggle {
              required property string modelData
              width: themeRows.width
              label: modelData
              checked: root.draftThemes.indexOf(modelData) !== -1
              foreground: Commons.Color.popups.text
              onClicked: root.toggleTheme(modelData)
            }
          }
        }
      }

      Text {
        width: parent.width
        visible: !root.useAllThemes && root.draftThemes.length === 0
        text: "Nessun tema selezionato: la rotazione resta ferma."
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Text {
        width: parent.width
        visible: root.settingsError !== ""
        text: root.settingsError
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Row {
        spacing: Style.space(8)

        Button {
          text: "Salva"
          foreground: Commons.Color.popups.text
          onClicked: root.saveSettings()
        }

        Button {
          text: "Annulla"
          foreground: Commons.Color.popups.text
          onClicked: root.close()
        }
      }
    }
  }
}
