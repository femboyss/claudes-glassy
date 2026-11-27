// claudes-glassy (Windows-Look): Widgets-Brett wie bei Windows 11 (Win+W oder Wetter-Knopf links)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common

Scope {
    id: root

    Connections {
        target: GlobalStates
        function onWidgetsOpenChanged() {
            if (GlobalStates.widgetsOpen) panelLoader.active = true;
        }
    }

    Loader {
        id: panelLoader
        active: GlobalStates.widgetsOpen
        sourceComponent: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wWidgets"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"
            anchors {
                left: true
                top: true
                bottom: true
            }
            implicitWidth: content.implicitWidth

            HyprlandFocusGrab {
                active: true
                windows: [panelWindow]
                onCleared: content.close()
            }
            Connections {
                target: GlobalStates
                function onWidgetsOpenChanged() {
                    if (!GlobalStates.widgetsOpen) content.close();
                }
            }

            WidgetsBoard {
                id: content
                anchors.fill: parent
                onClosed: {
                    GlobalStates.widgetsOpen = false;
                    panelLoader.active = false;
                }
            }
        }
    }

    IpcHandler {
        target: "widgets"
        function toggle(): void { GlobalStates.widgetsOpen = !GlobalStates.widgetsOpen; }
        function open(): void { GlobalStates.widgetsOpen = true; }
        function close(): void { GlobalStates.widgetsOpen = false; }
    }
    GlobalShortcut {
        name: "widgetsToggle"
        description: "Windows-Look: Widgets-Brett"
        onPressed: GlobalStates.widgetsOpen = !GlobalStates.widgetsOpen
    }
}
