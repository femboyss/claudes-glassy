// claudes-glassy (Windows-Look): Inhalt vom Widgets-Brett
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root
    signal closed
    property real slide: -implicitWidth
    readonly property int barHeight: 48
    implicitWidth: 800

    function close() { closeAnim.start(); }

    focus: true
    Keys.onPressed: event => { if (event.key === Qt.Key_Escape) root.close(); }

    Component.onCompleted: openAnim.start()
    NumberAnimation { id: openAnim; target: root; property: "slide"; to: 12; duration: 260; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "slide"; to: -root.implicitWidth; duration: 180; easing.type: Easing.InCubic }
        ScriptAction { script: root.closed() }
    }

    WPane {
        id: pane
        x: root.slide
        y: 12
        width: root.implicitWidth - 24
        height: root.height - root.barHeight - 24
        contentItem: Item {
            implicitWidth: root.implicitWidth - 24
            implicitHeight: root.height - root.barHeight - 24

            Flickable {
                anchors.fill: parent
                anchors.margins: 20
                contentHeight: column.implicitHeight
                clip: true

                ColumnLayout {
                    id: column
                    width: parent.width
                    spacing: 16

                    // ---------------------------------------------------------- Kopf: Uhrzeit
                    RowLayout {
                        Layout.fillWidth: true
                        WText {
                            text: DateTime.time
                            font.pixelSize: 28
                            font.weight: Looks.font.weight.strong
                        }
                        Item { Layout.fillWidth: true }
                        WText {
                            text: Qt.locale().toString(DateTime.clock.date, "dddd, d. MMMM")
                            font.pixelSize: Looks.font.pixelSize.larger
                            color: Looks.colors.fg1
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 12

                        // ------------------------------------------------------ Wetter
                        Card {
                            title: Translation.tr("Weather")
                            icon: "weather-sunny"
                            ColumnLayout {
                                spacing: 4
                                RowLayout {
                                    spacing: 12
                                    MaterialSymbol {
                                        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                                        iconSize: 52
                                        color: Looks.colors.fg
                                    }
                                    WText {
                                        text: Weather.data.temp || "--"
                                        font.pixelSize: 40
                                        font.weight: Looks.font.weight.strong
                                    }
                                }
                                WText { text: String(Weather.data.city || ""); font.pixelSize: Looks.font.pixelSize.large }
                                WText {
                                    color: Looks.colors.fg1
                                    text: Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike || "--")
                                        + "   " + Translation.tr("Humidity %1").arg(Weather.data.humidity || "--")
                                }
                            }
                        }

                        // ------------------------------------------------------ Musik
                        Card {
                            title: Translation.tr("Now playing")
                            icon: "music-note-2"
                            readonly property MprisPlayer player: MprisController.activePlayer
                            RowLayout {
                                spacing: 12
                                Rectangle {
                                    implicitWidth: 72; implicitHeight: 72
                                    radius: 6
                                    color: Looks.colors.bg2
                                    clip: true
                                    Image {
                                        anchors.fill: parent
                                        source: MprisController.activePlayer?.trackArtUrl ?? ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    WText {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: MprisController.activePlayer?.trackTitle || Translation.tr("Nothing is playing")
                                        font.weight: Looks.font.weight.strong
                                    }
                                    WText {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        color: Looks.colors.fg1
                                        text: MprisController.activePlayer?.trackArtist ?? ""
                                    }
                                    RowLayout {
                                        spacing: 4
                                        MediaBtn { icon: "previous"; onClicked: MprisController.previous() }
                                        MediaBtn { icon: MprisController.isPlaying ? "pause" : "play"; onClicked: MprisController.togglePlaying() }
                                        MediaBtn { icon: "next"; onClicked: MprisController.next() }
                                    }
                                }
                            }
                        }

                        // ------------------------------------------------------ System
                        Card {
                            title: Translation.tr("System")
                            icon: "server"
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Meter { label: "CPU"; value: ResourceUsage.cpuUsage }
                                Meter { label: Translation.tr("Memory"); value: ResourceUsage.memoryUsedPercentage }
                                Meter { label: "Swap"; value: ResourceUsage.swapUsedPercentage }
                            }
                        }

                        // ------------------------------------------------------ Aufgaben
                        Card {
                            title: Translation.tr("To Do")
                            icon: "checkmark"
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Repeater {
                                    model: Todo.list.slice(0, 5)
                                    delegate: RowLayout {
                                        required property var modelData
                                        required property int index
                                        spacing: 8
                                        FluentIcon {
                                            icon: modelData.done ? "checkmark" : "subtract"
                                            implicitSize: 14
                                            color: modelData.done ? Looks.colors.accent : Looks.colors.fg1
                                        }
                                        WText {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: modelData.content
                                            font.strikeout: modelData.done
                                            color: modelData.done ? Looks.colors.fg1 : Looks.colors.fg
                                        }
                                    }
                                }
                                WText {
                                    visible: Todo.list.length === 0
                                    color: Looks.colors.fg1
                                    text: Translation.tr("No tasks")
                                }
                            }
                        }

                        // ------------------------------------------------------ Kalender (ganze Breite)
                        Card {
                            Layout.columnSpan: 2
                            title: Qt.locale().toString(DateTime.clock.date, "MMMM yyyy")
                            icon: "calendar-add"
                            MonthGrid { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ Bausteine
    component Card: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        default property alias cardData: cardBody.data
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: cardCol.implicitHeight + 28
        radius: Looks.radius.large
        color: Looks.colors.bg1
        border.width: 1
        border.color: Looks.colors.bg2Border
        ColumnLayout {
            id: cardCol
            anchors { fill: parent; margins: 14 }
            spacing: 10
            RowLayout {
                spacing: 8
                FluentIcon { icon: card.icon; implicitSize: 16; color: Looks.colors.fg1 }
                WText { text: card.title; color: Looks.colors.fg1; font.weight: Looks.font.weight.strong }
            }
            ColumnLayout { id: cardBody; Layout.fillWidth: true }
        }
    }

    component MediaBtn: Rectangle {
        id: mb
        property string icon: ""
        signal clicked
        implicitWidth: 32; implicitHeight: 32
        radius: 4
        color: mbArea.containsMouse ? Looks.colors.bg2Hover : "transparent"
        FluentIcon { anchors.centerIn: parent; icon: mb.icon; implicitSize: 16 }
        MouseArea { id: mbArea; anchors.fill: parent; hoverEnabled: true; onClicked: mb.clicked() }
    }

    component Meter: ColumnLayout {
        id: meter
        property string label: ""
        property real value: 0
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            WText { text: meter.label }
            Item { Layout.fillWidth: true }
            WText { text: Math.round(meter.value * 100) + " %"; color: Looks.colors.fg1 }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: Looks.colors.bg2
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.value))
                height: parent.height
                radius: 2
                color: Looks.colors.accent
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }
    }

    component MonthGrid: GridLayout {
        id: grid
        columns: 7
        rowSpacing: 2
        columnSpacing: 2
        readonly property date today: DateTime.clock.date
        readonly property var cells: {
            const first = new Date(today.getFullYear(), today.getMonth(), 1);
            const offset = (first.getDay() + 6) % 7;   // Montag zuerst
            const days = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
            const out = [];
            for (let i = 0; i < offset; i++) out.push(0);
            for (let d = 1; d <= days; d++) out.push(d);
            return out;
        }
        Repeater {
            model: 7
            delegate: WText {
                required property int index
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                color: Looks.colors.fg1
                text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat)
            }
        }
        Repeater {
            model: grid.cells
            delegate: Rectangle {
                required property int modelData
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 15
                readonly property bool isToday: modelData === grid.today.getDate()
                color: isToday ? Looks.colors.accent : "transparent"
                WText {
                    anchors.centerIn: parent
                    visible: parent.modelData > 0
                    text: parent.modelData
                    color: parent.isToday ? Looks.colors.accentFg : Looks.colors.fg
                }
            }
        }
    }
}
