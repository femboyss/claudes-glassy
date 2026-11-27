// claudes-glassy (Look: Mac): Aufklapp-Menue unter einem Eintrag der Menueleiste
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common

PopupWindow {
    id: menu
    property Item anchorItem
    default property alias entries: column.data
    signal closeRequested()

    anchor.item: anchorItem
    anchor.rect.x: 0
    anchor.rect.y: anchorItem ? anchorItem.height + 3 : 0
    implicitWidth: Math.max(240, column.implicitWidth + 12)
    implicitHeight: column.implicitHeight + 12
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 6
            spacing: 0
        }
    }
}
