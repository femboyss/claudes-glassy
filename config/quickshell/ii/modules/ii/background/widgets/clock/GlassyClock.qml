pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// claudes-glassy: Musik-Uhr (Stil "glassy")
//  Desktop:  grosse Uhrzeit, darunter Live-Audiobalken (cava) und "Jetzt laeuft" bzw. Datum
//  Gesperrt: Split-Layout - links riesige Zeit, rechts Wetter, Musik (Cover, Fortschritt,
//            Balken) und Mitteilungen
Item {
    id: root

    // von ClockWidget
    property color colText: Appearance.m3colors.m3onBackground
    property bool darkBackground: true
    property real screenWidth: 1920
    property real screenHeight: 1080

    readonly property bool locked: GlobalStates.screenLocked

    // Akzentfarben, lesbar auf hellem wie dunklem Hintergrund
    readonly property color colAccent: ColorUtils.colorWithLightness(Appearance.m3colors.m3primary, darkBackground ? 0.68 : 0.36)
    readonly property color colAccent2: ColorUtils.colorWithLightness(Appearance.m3colors.m3tertiary, darkBackground ? 0.72 : 0.34)
    readonly property color colSoft: ColorUtils.transparentize(colText, 0.32)
    readonly property color colFaint: ColorUtils.transparentize(colText, 0.8)
    readonly property color colShadow: darkBackground ? "#66000000" : "#55ffffff"

    readonly property string timeFont: Config.options.background.widgets.clock.digital.font.family
    readonly property string timeString: DateTime.time
    readonly property int sep: timeString.indexOf(":")
    readonly property string hoursText: sep > 0 ? timeString.substring(0, sep) : timeString
    readonly property string minutesText: sep > 0 ? timeString.substring(sep + 1).split(" ")[0] : ""

    readonly property string greeting: {
        const h = DateTime.clock.date.getHours();
        if (h < 5) return "Gute Nacht";
        if (h < 11) return "Guten Morgen";
        if (h < 17) return "Guten Tag";
        if (h < 22) return "Guten Abend";
        return "Gute Nacht";
    }

    readonly property bool hasWeather: (Config.options.bar.weather.enable || Config.options.background.widgets.weather.enable)
        && typeof Weather.data?.temp === "string" && Weather.data.temp.length > 0

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool hasPlayer: player !== null && (player?.trackTitle ?? "").length > 0
    readonly property bool playing: MprisController.isPlaying
    readonly property string artUrl: player?.trackArtUrl ?? ""

    function fmt(sec) {
        if (!(sec > 0)) return "0:00";
        const s = Math.floor(sec);
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    // Fortschritt nur aktualisieren, wenn gesperrt und Musik laeuft
    Timer {
        running: root.locked && root.playing
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    implicitWidth: locked ? lockView.implicitWidth : desktopView.implicitWidth
    implicitHeight: locked ? lockView.implicitHeight : desktopView.implicitHeight

    // ================================================================ Desktop
    ColumnLayout {
        id: desktopView
        anchors.centerIn: parent
        visible: opacity > 0
        opacity: root.locked ? 0 : 1
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        spacing: 0

        Label {
            text: root.greeting
            color: root.colAccent2
            font.pixelSize: 16
            font.weight: Font.Bold
            font.letterSpacing: 4
            font.capitalization: Font.AllUppercase
        }

        Row {
            id: desktopTime
            Layout.topMargin: -10
            TimeText { text: root.hoursText; size: 132 }
            TimeText { text: ":"; size: 132; color: root.colAccent; visible: root.minutesText.length > 0 }
            TimeText { text: root.minutesText; size: 132; visible: root.minutesText.length > 0 }
        }

        VisualizerBars {
            Layout.preferredWidth: desktopTime.width
            Layout.preferredHeight: 40
            Layout.topMargin: -4
            colA: root.colAccent
            colB: root.colAccent2
            count: 32
            idleOpacity: 0.35
        }

        Label {
            Layout.topMargin: 10
            Layout.maximumWidth: Math.max(desktopTime.width, 320)
            elide: Text.ElideRight
            text: root.hasPlayer ? `${root.playing ? "▶" : "❙❙"}  ${root.player.trackTitle}  -  ${root.player.trackArtist}` : DateTime.longDate
            color: root.colSoft
            font.pixelSize: 18
            font.weight: Font.Medium
        }
    }

    // ================================================================ Sperrbildschirm: Split
    Row {
        id: lockView
        anchors.centerIn: parent
        visible: opacity > 0
        opacity: root.locked ? 1 : 0
        Behavior on opacity {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        spacing: Math.round(root.screenWidth * 0.045)

        readonly property real bigSize: Math.min(300, root.screenHeight * 0.27)

        // ---------------------------------------- links: Zeit
        Column {
            id: leftCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            TimeText {
                text: root.hoursText
                size: lockView.bigSize
                weightValue: 760
                lineHeight: 0.82
            }
            TimeText {
                visible: root.minutesText.length > 0
                text: root.minutesText
                size: lockView.bigSize
                weightValue: 760
                lineHeight: 0.82
                color: root.colAccent
            }
            Item { width: 1; height: 18 }
            Label {
                text: `${root.greeting}, ${SystemInfo.username}`
                color: root.colAccent2
                font.pixelSize: 17
                font.weight: Font.Bold
                font.letterSpacing: 4
                font.capitalization: Font.AllUppercase
            }
            Label {
                text: DateTime.longDate
                color: root.colSoft
                font.pixelSize: 26
                font.weight: Font.Medium
            }
        }

        // ---------------------------------------- Trennlinie
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: leftCol.height * 0.9
            radius: 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: root.colAccent }
                GradientStop { position: 0.7; color: root.colAccent2 }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ---------------------------------------- rechts: Infos
        Column {
            id: rightCol
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(460, root.screenWidth * 0.3)
            spacing: 34

            // Wetter
            Column {
                visible: root.hasWeather
                width: parent.width
                spacing: 6
                SectionLabel { text: "Wetter" }
                Row {
                    spacing: 14
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        fill: 1
                        text: Icons.getWeatherIcon(Weather.data?.wCode) ?? "cloud"
                        iconSize: 44
                        color: root.colAccent
                    }
                    TimeText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.data?.temp ?? ""
                        size: 48
                        weightValue: 650
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Label { text: Weather.data?.city ?? ""; color: root.colText; font.pixelSize: 17; font.weight: Font.DemiBold }
                        Label { text: `gefuehlt ${Weather.data?.tempFeelsLike ?? ""}  -  ${Weather.data?.humidity ?? ""}`; color: root.colSoft; font.pixelSize: 15 }
                    }
                }
            }

            // Musik
            Column {
                visible: root.hasPlayer
                width: parent.width
                spacing: 10
                SectionLabel { text: root.playing ? "Jetzt laeuft" : "Pausiert" }
                Row {
                    width: parent.width
                    spacing: 16

                    Item {
                        width: 104
                        height: 104
                        Rectangle {
                            anchors.fill: parent
                            radius: 20
                            color: root.colFaint
                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: cover.status !== Image.Ready
                                text: "music_note"
                                iconSize: 44
                                fill: 1
                                color: root.colAccent
                            }
                        }
                        Image {
                            id: cover
                            anchors.fill: parent
                            source: root.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 208
                            sourceSize.height: 208
                            visible: false
                        }
                        OpacityMask {
                            anchors.fill: parent
                            visible: cover.status === Image.Ready
                            source: cover
                            maskSource: Rectangle {
                                width: 104
                                height: 104
                                radius: 20
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 104 - 16
                        spacing: 2
                        Label {
                            width: parent.width
                            elide: Text.ElideRight
                            text: root.player?.trackTitle ?? ""
                            color: root.colText
                            font.pixelSize: 24
                            font.weight: Font.Bold
                        }
                        Label {
                            width: parent.width
                            elide: Text.ElideRight
                            text: root.player?.trackArtist ?? ""
                            color: root.colSoft
                            font.pixelSize: 17
                        }
                        Item { width: 1; height: 8 }
                        // Fortschritt
                        Item {
                            width: parent.width
                            height: 6
                            visible: (root.player?.length ?? 0) > 0
                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: root.colFaint
                            }
                            Rectangle {
                                height: parent.height
                                radius: 3
                                width: parent.width * Math.max(0, Math.min(1, (root.player?.position ?? 0) / Math.max(1, root.player?.length ?? 1)))
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.colAccent }
                                    GradientStop { position: 1.0; color: root.colAccent2 }
                                }
                            }
                        }
                        Row {
                            width: parent.width
                            visible: (root.player?.length ?? 0) > 0
                            Label {
                                width: parent.width / 2
                                text: root.fmt(root.player?.position ?? 0)
                                color: root.colSoft
                                font.pixelSize: 13
                            }
                            Label {
                                width: parent.width / 2
                                horizontalAlignment: Text.AlignRight
                                text: root.fmt(root.player?.length ?? 0)
                                color: root.colSoft
                                font.pixelSize: 13
                            }
                        }
                    }
                }
                VisualizerBars {
                    width: parent.width
                    height: 46
                    colA: root.colAccent
                    colB: root.colAccent2
                    count: 36
                }
            }

            // Mitteilungen (nur Anzahl und App-Namen, keine Inhalte auf dem Sperrbildschirm)
            Column {
                width: parent.width
                spacing: 6
                SectionLabel { text: "Mitteilungen" }
                Row {
                    spacing: 10
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        fill: 1
                        text: Notifications.list.length > 0 ? "notifications_unread" : "notifications"
                        iconSize: 26
                        color: Notifications.list.length > 0 ? root.colAccent2 : root.colSoft
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: rightCol.width - 40
                        elide: Text.ElideRight
                        text: {
                            const n = Notifications.list.length;
                            if (n === 0) return "Keine neuen";
                            const apps = [...new Set(Notifications.list.map(x => x.appName).filter(a => a && a.length > 0))].slice(0, 3);
                            return `${n} neue${apps.length ? "  -  " + apps.join(", ") : ""}`;
                        }
                        color: root.colText
                        font.pixelSize: 18
                    }
                }
            }
        }
    }

    // ================================================================ Bausteine
    component Label: StyledText {
        color: root.colText
        style: Text.Raised
        styleColor: root.colShadow
        font.family: Appearance.font.family.main
        animateChange: false
    }

    component SectionLabel: Label {
        color: root.colAccent
        font.pixelSize: 13
        font.weight: Font.Bold
        font.letterSpacing: 3
        font.capitalization: Font.AllUppercase
    }

    component TimeText: StyledText {
        id: tt
        property real size: 120
        property int weightValue: 650
        color: root.colText
        style: Text.Raised
        styleColor: root.colShadow
        animateChange: Config.options.background.widgets.clock.digital.animateChange
        font {
            family: root.timeFont
            pixelSize: tt.size
            weight: tt.weightValue
            styleName: ""
            variableAxes: ({
                    "wdth": 110,
                    "ROND": 100
                })
        }
    }
}
