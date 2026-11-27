// claudes-glassy (Look: Mac): ein Eintrag in einem Menue der Menueleiste
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: item
    property string text: ""
    property string shortcut: ""
    property bool separator: false
    signal triggered()

    Layout.fillWidth: true
    implicitWidth: separator ? 10 : row.implicitWidth + 24
    implicitHeight: separator ? 9 : 24
    radius: 5
    color: (!separator && area.containsMouse) ? Appearance.colors.colPrimary : "transparent"

    Rectangle {
        visible: item.separator
        anchors.centerIn: parent
        width: parent.width - 16; height: 1
        color: Appearance.colors.colOutlineVariant
    }
    RowLayout {
        id: row
        visible: !item.separator
        anchors.fill: parent
        anchors.leftMargin: 12; anchors.rightMargin: 12
        spacing: 24
        StyledText {
            text: item.text
            font.pixelSize: 13
            color: area.containsMouse ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
        }
        Item { Layout.fillWidth: true }
        StyledText {
            visible: item.shortcut.length > 0
            text: item.shortcut
            font.pixelSize: 13
            color: area.containsMouse ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: !item.separator
        hoverEnabled: true
        onClicked: item.triggered()
    }
}
