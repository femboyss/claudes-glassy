pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// claudes-glassy: Uhr im Glas-Look (Stil "glassy")
// Glas-Karte mit grosser Uhrzeit, Doppelpunkt in Akzentfarbe, Datum, Begruessung und Wetter.
// Auf dem Sperrbildschirm groesser.
Item {
    id: root

    readonly property bool locked: GlobalStates.screenLocked
    readonly property real sizeFactor: locked ? 1.3 : 1.0
    Behavior on sizeFactor {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    readonly property string timeString: DateTime.time
    readonly property int sep: timeString.indexOf(":")
    readonly property string hoursText: sep > 0 ? timeString.substring(0, sep) : timeString
    readonly property string minutesText: sep > 0 ? timeString.substring(sep + 1) : ""

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

    readonly property color colCard: ColorUtils.transparentize(Appearance.m3colors.m3background, 0.42)
    readonly property color colBorder: ColorUtils.transparentize(Appearance.m3colors.m3onBackground, 0.86)
    readonly property color colText: Appearance.m3colors.m3onBackground
    readonly property color colSoft: ColorUtils.transparentize(Appearance.m3colors.m3onBackground, 0.3)
    readonly property color colAccent: Appearance.m3colors.m3primary
    readonly property color colAccent2: Appearance.m3colors.m3tertiary

    readonly property string timeFont: Config.options.background.widgets.clock.digital.font.family

    implicitWidth: Math.max(card.implicitWidth, 1)
    implicitHeight: Math.max(card.implicitHeight, 1)

    StyledRectangularShadow {
        target: card
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        implicitWidth: Math.max(content.implicitWidth + 64 * root.sizeFactor, 360 * root.sizeFactor)
        implicitHeight: content.implicitHeight + 48 * root.sizeFactor
        radius: 32 * root.sizeFactor
        color: root.colCard
        border.width: 1
        border.color: root.colBorder

        // Lichtkante oben (Glas-Reflex)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: ColorUtils.transparentize("#ffffff", 0.92) }
                GradientStop { position: 0.45; color: "transparent" }
            }
        }

        // Akzent-Streifen links (Primary -> Tertiary)
        Rectangle {
            anchors {
                left: parent.left
                leftMargin: 18 * root.sizeFactor
                verticalCenter: parent.verticalCenter
            }
            width: 4
            height: parent.height * 0.55
            radius: 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.colAccent }
                GradientStop { position: 1.0; color: root.colAccent2 }
            }
        }

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 8 * root.sizeFactor
            spacing: 2

            // Begruessung
            StyledText {
                Layout.alignment: Qt.AlignLeft
                text: root.locked ? `${root.greeting}, ${SystemInfo.username}` : root.greeting
                color: root.colAccent
                font {
                    family: Appearance.font.family.main
                    pixelSize: 15 * root.sizeFactor
                    weight: Font.DemiBold
                    letterSpacing: 2
                    capitalization: Font.AllUppercase
                }
            }

            // Uhrzeit
            Row {
                Layout.alignment: Qt.AlignLeft
                Layout.topMargin: -6 * root.sizeFactor
                spacing: 0

                TimePart { text: root.hoursText }
                TimePart {
                    visible: root.minutesText.length > 0
                    text: ":"
                    color: root.colAccent
                    animateChange: false
                }
                TimePart {
                    visible: root.minutesText.length > 0
                    text: root.minutesText
                }
            }

            // Datum
            StyledText {
                Layout.alignment: Qt.AlignLeft
                Layout.topMargin: -8 * root.sizeFactor
                text: DateTime.longDate
                color: root.colSoft
                font {
                    family: Appearance.font.family.main
                    pixelSize: 20 * root.sizeFactor
                    weight: Font.Medium
                }
            }

            // Wetter
            Rectangle {
                visible: root.hasWeather
                Layout.fillWidth: true
                Layout.topMargin: 12 * root.sizeFactor
                Layout.bottomMargin: 6 * root.sizeFactor
                implicitHeight: 1
                color: root.colBorder
            }
            Row {
                visible: root.hasWeather
                Layout.alignment: Qt.AlignLeft
                spacing: 10 * root.sizeFactor

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    fill: 1
                    text: Icons.getWeatherIcon(Weather.data?.wCode) ?? "cloud"
                    iconSize: 26 * root.sizeFactor
                    color: root.colAccent
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.data?.temp ?? ""
                    color: root.colText
                    font {
                        family: root.timeFont
                        pixelSize: 20 * root.sizeFactor
                        weight: Font.DemiBold
                    }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Weather.data?.city ?? ""}  -  gefuehlt ${Weather.data?.tempFeelsLike ?? ""}`
                    color: root.colSoft
                    font {
                        family: Appearance.font.family.main
                        pixelSize: 15 * root.sizeFactor
                    }
                }
            }
        }
    }

    component TimePart: StyledText {
        color: root.colText
        animateChange: Config.options.background.widgets.clock.digital.animateChange
        font {
            family: root.timeFont
            pixelSize: 112 * root.sizeFactor
            weight: 620
            styleName: ""
            variableAxes: ({
                    "wdth": 108,
                    "ROND": 100
                })
        }
    }
}
