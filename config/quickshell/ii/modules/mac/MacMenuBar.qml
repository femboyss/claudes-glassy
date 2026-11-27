// claudes-glassy (Look: Mac): Menueleiste oben wie bei macOS
//   links:  Logo-Menue, Name der aktiven App, Fenster-Menue
//   rechts: Tray, Akku, WLAN/LAN, Bluetooth, Ton, Spotlight, Kontrollzentrum, Datum + Uhrzeit
// (c) 2026 34 & Claude - GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root
    readonly property int barHeight: 30

    function hypr(lua) { Quickshell.execDetached(["hyprctl", "dispatch", lua]); }
    function sh(cmd) { Quickshell.execDetached(["bash", "-c", cmd]); }
    // Erst das Menue zumachen, dann (kurz danach) das naechste Panel oeffnen.
    // Sonst kaempfen Menue und Uebersicht/Sitzungsbildschirm um den Fokus und es flackert.
    function later(fn) { deferTimer.fn = fn; deferTimer.restart(); }
    Timer {
        id: deferTimer
        property var fn: null
        interval: 200
        onTriggered: if (fn) { const f = fn; fn = null; f(); }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked
            WlrLayershell.namespace: "quickshell:macbar"
            anchors { top: true; left: true; right: true }
            implicitHeight: root.barHeight
            exclusiveZone: root.barHeight
            color: "transparent"

            property string openMenu: ""
            readonly property var activeApp: ToplevelManager.activeToplevel
            readonly property string appName: {
                const id = activeApp?.appId ?? "";
                if (!id.length) return Translation.tr("Desktop");
                const entry = DesktopEntries.heuristicLookup(id);
                return entry?.name ?? id;
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Appearance.colors.colLayer0.r, Appearance.colors.colLayer0.g, Appearance.colors.colLayer0.b, 0.55)
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }
            }

            // ---------------------------------------------------------------- links
            RowLayout {
                id: leftRow
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 4

                MacBarButton {
                    id: logoButton
                    implicitWidth: 34
                    active: bar.openMenu === "logo"
                    onClicked: bar.openMenu = bar.openMenu === "logo" ? "" : "logo"
                    Image {
                        anchors.centerIn: parent
                        source: `${Directories.assetsPath}/icons/vitra-logo.svg`
                        sourceSize.width: 18; sourceSize.height: 18
                        width: 18; height: 18
                        smooth: true
                    }
                }
                MacBarButton {
                    id: appButton
                    label: bar.appName
                    bold: true
                    active: bar.openMenu === "app"
                    onClicked: bar.openMenu = bar.openMenu === "app" ? "" : "app"
                }
                MacBarButton {
                    id: windowButton
                    label: Translation.tr("Window")
                    active: bar.openMenu === "window"
                    onClicked: bar.openMenu = bar.openMenu === "window" ? "" : "window"
                }
            }

            // Tray links neben den Status-Symbolen; auf kleinen Bildschirmen ausgeblendet,
            // bevor es die Menues links ueberdeckt
            MacTray {
                id: macTray
                anchors { right: rightRow.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                visible: leftRow.x + leftRow.width + 24 < rightRow.x - implicitWidth - 8
            }

            // ---------------------------------------------------------------- rechts
            RowLayout {
                id: rightRow
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 2

                MacBarButton {
                    visible: Battery.available
                    label: `${Math.round(Battery.percentage * 100)}%`
                    icon: Battery.isCharging ? "battery_charging_full" : "battery_full"
                    onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }
                MacBarButton {
                    icon: Network.ethernet ? "lan" : (Network.wifiStatus === "connected" ? "wifi" : "wifi_off")
                    onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }
                MacBarButton {
                    visible: BluetoothStatus.available && BluetoothStatus.enabled
                    icon: BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
                    onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }
                MacBarButton {
                    icon: (Audio.sink?.audio.muted ?? false) ? "volume_off" : (Audio.value > 0.5 ? "volume_up" : "volume_down")
                    onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }
                MacBarButton {
                    icon: "search"
                    onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                }
                MacBarButton {
                    icon: "toggle_on"
                    active: GlobalStates.sidebarRightOpen
                    onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }
                MacBarButton {
                    label: Qt.locale().toString(DateTime.clock.date, "ddd d. MMM  HH:mm")
                    onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }
            }

            // ---------------------------------------------------------------- Menues
            MacMenu {
                anchorItem: logoButton
                visible: bar.openMenu === "logo"
                MacMenuItem { text: Translation.tr("About this computer"); onTriggered: { bar.openMenu = ""; root.sh(`${Config.options.apps.terminal} --hold fastfetch`) } }
                MacMenuItem { separator: true }
                MacMenuItem { text: Translation.tr("System settings..."); shortcut: "⌘ I"; onTriggered: { bar.openMenu = ""; root.sh(`XDG_CURRENT_DESKTOP=gnome qs -p ${FileUtils.trimFileProtocol(Directories.config)}/quickshell/ii/settings.qml`) } }
                MacMenuItem { separator: true }
                MacMenuItem { text: Translation.tr("Sleep"); onTriggered: { bar.openMenu = ""; root.sh("systemctl suspend || loginctl suspend") } }
                MacMenuItem { text: Translation.tr("Restart..."); onTriggered: { bar.openMenu = ""; root.later(() => GlobalStates.sessionOpen = true) } }
                MacMenuItem { text: Translation.tr("Shut down..."); onTriggered: { bar.openMenu = ""; root.later(() => GlobalStates.sessionOpen = true) } }
                MacMenuItem { separator: true }
                MacMenuItem { text: Translation.tr("Lock screen"); shortcut: "⌘ L"; onTriggered: { bar.openMenu = ""; root.sh("loginctl lock-session") } }
                MacMenuItem { text: Translation.tr("Log out..."); onTriggered: { bar.openMenu = ""; root.later(() => GlobalStates.sessionOpen = true) } }
            }
            MacMenu {
                anchorItem: appButton
                visible: bar.openMenu === "app"
                MacMenuItem { text: Translation.tr("Hide"); onTriggered: { bar.openMenu = ""; root.hypr('hl.dsp.window.move({ workspace = "special:minimized", follow = false })') } }
                MacMenuItem { separator: true }
                MacMenuItem { text: Translation.tr("Quit %1").arg(bar.appName); shortcut: "⌘ Q"; onTriggered: { bar.openMenu = ""; root.hypr("hl.dsp.window.close()") } }
            }
            MacMenu {
                anchorItem: windowButton
                visible: bar.openMenu === "window"
                MacMenuItem { text: Translation.tr("Minimize"); onTriggered: { bar.openMenu = ""; root.hypr('hl.dsp.window.move({ workspace = "special:minimized", follow = false })') } }
                MacMenuItem { text: Translation.tr("Zoom"); onTriggered: { bar.openMenu = ""; root.hypr('hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })') } }
                MacMenuItem { text: Translation.tr("Full screen"); onTriggered: { bar.openMenu = ""; root.hypr('hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })') } }
                MacMenuItem { separator: true }
                MacMenuItem { text: Translation.tr("Show all windows"); shortcut: "⌃ ↑"; onTriggered: { bar.openMenu = ""; root.later(() => GlobalStates.overviewOpen = true) } }
                MacMenuItem { text: Translation.tr("Close window"); onTriggered: { bar.openMenu = ""; root.hypr("hl.dsp.window.close()") } }
            }
        }
    }
}
