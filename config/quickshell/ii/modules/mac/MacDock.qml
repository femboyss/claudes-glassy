// claudes-glassy (Look: Mac): Dock unten wie bei macOS
//   Launchpad, angeheftete + laufende Apps (Punkt darunter), Trenner, Papierkorb
//   Vergroesserung beim Drueberfahren, Name der App darueber
//   Klick: starten bzw. Fenster nach vorne holen; Rechtsklick: anheften / loesen
// (c) 2026 34 & Claude - GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root
    readonly property int iconSize: 50
    readonly property real maxScale: 1.55
    readonly property int reach: 140          // so weit (px) wirkt die Vergroesserung
    readonly property int padding: 6
    readonly property int bottomGap: 6

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dock
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked
            WlrLayershell.namespace: "quickshell:macdock"
            anchors { bottom: true; left: true; right: true }
            color: "transparent"
            readonly property int baseHeight: root.iconSize + root.padding * 2
            implicitHeight: Math.ceil(root.iconSize * root.maxScale) + root.padding * 2 + root.bottomGap + 28
            exclusiveZone: baseHeight + root.bottomGap
            mask: Region { item: dockArea }

            property real mouseX: -10000

            MouseArea {
                id: dockArea
                hoverEnabled: true
                anchors { bottom: parent.bottom; bottomMargin: root.bottomGap; horizontalCenter: parent.horizontalCenter }
                width: plate.width
                height: dock.implicitHeight - root.bottomGap
                acceptedButtons: Qt.NoButton
                onPositionChanged: mouse => dock.mouseX = mouse.x
                onExited: dock.mouseX = -10000

                Rectangle {
                    id: plate
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                    height: dock.baseHeight
                    width: row.implicitWidth + root.padding * 2
                    radius: 18
                    color: Qt.rgba(Appearance.colors.colLayer0.r, Appearance.colors.colLayer0.g, Appearance.colors.colLayer0.b, 0.45)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }

                Row {
                    id: row
                    anchors { bottom: plate.bottom; bottomMargin: root.padding; horizontalCenter: plate.horizontalCenter }
                    spacing: 4

                    MacDockIcon {
                        dockMouseX: dock.mouseX; dockArea: dockArea
                        name: Translation.tr("Launchpad")
                        iconName: "view-app-grid-symbolic"
                        fallbackSymbol: "apps"
                        onActivated: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                    }

                    Repeater {
                        model: ScriptModel { objectProp: "appId"; values: TaskbarApps.apps }
                        delegate: Item {
                            id: slot
                            required property var modelData
                            readonly property bool isSeparator: modelData.appId === "SEPARATOR"
                            width: isSeparator ? 13 : appIcon.width
                            height: appIcon.height
                            Rectangle {
                                visible: slot.isSeparator
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                                width: 1; height: root.iconSize - 10
                                color: Qt.rgba(1, 1, 1, 0.25)
                            }
                            MacDockIcon {
                                id: appIcon
                                visible: !slot.isSeparator
                                dockMouseX: dock.mouseX; dockArea: dockArea
                                readonly property var entry: DesktopEntries.heuristicLookup(slot.modelData.appId)
                                property int lastFocused: -1
                                name: entry?.name ?? slot.modelData.appId
                                iconName: AppSearch.guessIcon(slot.modelData.appId)
                                running: slot.modelData.toplevels.length > 0
                                onActivated: {
                                    const tl = slot.modelData.toplevels;
                                    if (tl.length === 0) { entry?.execute(); return; }
                                    lastFocused = (lastFocused + 1) % tl.length;
                                    tl[lastFocused].activate();
                                }
                                onSecondary: TaskbarApps.togglePin(slot.modelData.appId)
                            }
                        }
                    }

                    Item {
                        width: 13; height: root.iconSize
                        Rectangle {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                            width: 1; height: root.iconSize - 10
                            color: Qt.rgba(1, 1, 1, 0.25)
                        }
                    }

                    MacDockIcon {
                        dockMouseX: dock.mouseX; dockArea: dockArea
                        name: Translation.tr("Trash")
                        iconName: "user-trash"
                        fallbackSymbol: "delete"
                        onActivated: Quickshell.execDetached(["bash", "-c", "dolphin trash:/ || xdg-open trash:/"])
                    }
                }
            }
        }
    }

    component MacDockIcon: Item {
        id: icon
        property real dockMouseX: -10000
        property Item dockArea
        property string name: ""
        property string iconName: ""
        property string fallbackSymbol: ""
        property bool running: false
        signal activated()
        signal secondary()

        // Abstand der Maus zur Mitte dieses Icons -> Vergroesserung
        readonly property real centerX: dockArea ? icon.mapToItem(dockArea, width / 2, 0).x : 0
        readonly property real dist: Math.abs(dockMouseX - centerX)
        readonly property real zoom: 1 + (root.maxScale - 1) * Math.max(0, 1 - dist / root.reach)
        width: root.iconSize * zoom
        height: root.iconSize
        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        // Icon aus dem Icon-Theme; fehlt es, ein schlichtes Symbol statt "Bild fehlt"
        readonly property string iconFile: Quickshell.iconPath(icon.iconName, true)
        IconImage {
            id: img
            visible: icon.iconFile.length > 0
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            implicitSize: root.iconSize * icon.zoom
            source: icon.iconFile
            Behavior on implicitSize { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        }
        Rectangle {
            visible: icon.iconFile.length === 0
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            width: root.iconSize * icon.zoom * 0.92; height: width
            radius: width * 0.24
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(Appearance.colors.colPrimary, 1.25) }
                GradientStop { position: 1; color: Appearance.colors.colPrimary }
            }
            MaterialSymbol {
                visible: icon.fallbackSymbol.length > 0
                anchors.centerIn: parent
                text: icon.fallbackSymbol
                iconSize: parent.width * 0.55
                color: Appearance.colors.colOnPrimary
            }
            StyledText {   // App ohne Symbol: Anfangsbuchstabe
                visible: icon.fallbackSymbol.length === 0
                anchors.centerIn: parent
                text: icon.name.length ? icon.name[0].toUpperCase() : "?"
                font.pixelSize: parent.width * 0.5
                font.weight: Font.Bold
                color: Appearance.colors.colOnPrimary
            }
        }
        Rectangle {   // laufende App: Punkt darunter
            visible: icon.running
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 1 }
            width: 4; height: 4; radius: 2
            color: Appearance.colors.colOnLayer0
        }
        Rectangle {   // Name ueber dem Icon
            visible: area.containsMouse && icon.name.length > 0
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: root.iconSize * icon.zoom + 6 }
            width: label.implicitWidth + 16; height: 24; radius: 6
            color: Appearance.colors.colLayer0
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
            StyledText { id: label; anchors.centerIn: parent; text: icon.name; font.pixelSize: 12; color: Appearance.colors.colOnLayer0 }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? icon.secondary() : icon.activated()
        }
    }
}
