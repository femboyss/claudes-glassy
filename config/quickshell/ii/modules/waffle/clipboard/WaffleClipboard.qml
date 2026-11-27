// claudes-glassy (Windows-Look): Zwischenablage wie bei Windows 11
//   Win+V = Verlauf, Win+. = Emoji, eigenes Fenster (nicht im Startmenue)
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

    function openTab(tab) {
        if (GlobalStates.clipboardOpen && GlobalStates.clipboardTab === tab) {
            GlobalStates.clipboardOpen = false;
            return;
        }
        GlobalStates.clipboardTab = tab;
        GlobalStates.clipboardOpen = true;
    }

    Connections {
        target: GlobalStates
        function onClipboardOpenChanged() {
            if (GlobalStates.clipboardOpen) {
                Cliphist.refresh();
                panelLoader.active = true;
            }
        }
    }

    Loader {
        id: panelLoader
        active: GlobalStates.clipboardOpen
        sourceComponent: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wClipboard"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"
            anchors { bottom: true; right: true }
            margins { bottom: 48 + 12; right: 12 }
            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            HyprlandFocusGrab {
                active: true
                windows: [panelWindow]
                onCleared: content.close()
            }
            Connections {
                target: GlobalStates
                function onClipboardOpenChanged() {
                    if (!GlobalStates.clipboardOpen) content.close();
                }
            }

            ClipboardPanel {
                id: content
                anchors.fill: parent
                onClosed: {
                    GlobalStates.clipboardOpen = false;
                    panelLoader.active = false;
                }
            }
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.openTab("clipboard"); }
        function emoji(): void { root.openTab("emoji"); }
        function close(): void { GlobalStates.clipboardOpen = false; }
    }
    GlobalShortcut {
        name: "clipboardToggle"
        description: "Windows-Look: Zwischenablage-Verlauf (Win+V)"
        onPressed: root.openTab("clipboard")
    }
    GlobalShortcut {
        name: "emojiToggle"
        description: "Windows-Look: Emoji (Win+.)"
        onPressed: root.openTab("emoji")
    }
}
