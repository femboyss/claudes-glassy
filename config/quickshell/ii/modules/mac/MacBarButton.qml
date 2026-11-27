// claudes-glassy (Look: Mac): Knopf in der Menueleiste (Text und/oder Symbol)
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: btn
    property string label: ""
    property string icon: ""
    property bool bold: false
    property bool active: false
    signal clicked()
    default property alias content: holder.data

    Layout.fillHeight: false
    implicitHeight: 24
    implicitWidth: Math.max(28, row.implicitWidth + 16)
    radius: 6
    color: (active || area.containsMouse) ? Qt.rgba(1, 1, 1, 0.14) : "transparent"

    Item { id: holder; anchors.fill: parent }
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5
        MaterialSymbol {
            visible: btn.icon.length > 0
            text: btn.icon
            iconSize: 17
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            visible: btn.label.length > 0
            text: btn.label
            font.pixelSize: 13
            font.weight: btn.bold ? Font.Bold : Font.Medium
            color: Appearance.colors.colOnLayer0
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}
