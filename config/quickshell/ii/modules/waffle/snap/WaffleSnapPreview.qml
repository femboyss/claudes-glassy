// claudes-glassy (Windows-Look): durchsichtige Vorschau beim Andocken (gesteuert von hypr/glassy/snap.py)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.common
import qs.modules.waffle.looks

Scope {
    id: root
    property bool active: false
    property rect target: Qt.rect(0, 0, 0, 0)

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property bool here: root.active
                && root.target.x >= modelData.x && root.target.x < modelData.x + modelData.width
                && root.target.y >= modelData.y && root.target.y < modelData.y + modelData.height
            visible: here || box.opacity > 0
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wSnap"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region {}

            Rectangle {
                id: box
                x: root.target.x - win.modelData.x + 8
                y: root.target.y - win.modelData.y + 8
                width: Math.max(0, root.target.width - 16)
                height: Math.max(0, root.target.height - 16)
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.35)
                opacity: win.here ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }
    }

    IpcHandler {
        target: "snapPreview"
        function show(x: int, y: int, w: int, h: int): void {
            root.target = Qt.rect(x, y, w, h);
            root.active = true;
        }
        function hide(): void { root.active = false; }
    }
}
