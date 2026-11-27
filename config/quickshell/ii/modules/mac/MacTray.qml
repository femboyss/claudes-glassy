// claudes-glassy (Look: Mac): Tray-Symbole in der Menueleiste
// Linksklick: App oeffnen, Rechtsklick (oder Apps nur mit Menue): Menue der App
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

RowLayout {
    id: tray
    spacing: 2
    Repeater {
        model: SystemTray.items
        delegate: Rectangle {
            id: trayItem
            required property SystemTrayItem modelData
            implicitWidth: 26; implicitHeight: 24
            radius: 6
            color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: trayItem.modelData.icon
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    const item = trayItem.modelData;
                    if (mouse.button === Qt.LeftButton && !item.onlyMenu) {
                        item.activate();
                        return;
                    }
                    if (item.hasMenu) {
                        const p = trayItem.mapToItem(null, 0, trayItem.height + 4);
                        item.display(trayItem.QsWindow.window, p.x, p.y);
                    }
                }
            }
        }
    }
}
