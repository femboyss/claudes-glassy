import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "weather"

    // claudes-glassy: mit Uhr-Stil "glassy" gibt es das Wetter als passende Glas-Karte
    readonly property bool glassy: Config.options.background.widgets.clock.style === "glassy"
        || Config.options.background.widgets.clock.styleLocked === "glassy"
    readonly property string tempText: (typeof Weather.data?.temp === "string" && Weather.data.temp.length > 0) ? Weather.data.temp : "--°"

    implicitHeight: glassy ? glassCard.implicitHeight : backgroundShape.implicitHeight
    implicitWidth: glassy ? glassCard.implicitWidth : backgroundShape.implicitWidth

    // ---------------------------------------------------------- Original (end-4)
    StyledDropShadow {
        target: backgroundShape
        visible: !root.glassy
    }

    MaterialShape {
        id: backgroundShape
        visible: !root.glassy
        anchors.fill: parent
        shape: MaterialShape.Shape.Pill
        color: Appearance.colors.colPrimaryContainer
        implicitSize: 200

        StyledText {
            font {
                pixelSize: 80
                family: Appearance.font.family.expressive
                weight: Font.Medium
            }
            color: Appearance.colors.colPrimary
            text: root.tempText.substring(0, root.tempText.length - 1)
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: 16
                topMargin: 20
            }
        }

        MaterialSymbol {
            iconSize: 80
            color: Appearance.colors.colOnPrimaryContainer
            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
            anchors {
                left: parent.left
                bottom: parent.bottom

                leftMargin: 16
                bottomMargin: 20
            }
        }
    }

    // ---------------------------------------------------------- Glassy
    StyledRectangularShadow {
        target: glassCard
        visible: root.glassy
    }

    Rectangle {
        id: glassCard
        visible: root.glassy
        anchors.fill: parent
        implicitWidth: glassRow.implicitWidth + 44
        implicitHeight: glassRow.implicitHeight + 32
        radius: 26
        color: ColorUtils.transparentize(Appearance.m3colors.m3background, 0.42)
        border.width: 1
        border.color: ColorUtils.transparentize(Appearance.m3colors.m3onBackground, 0.86)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: ColorUtils.transparentize("#ffffff", 0.92) }
                GradientStop { position: 0.5; color: "transparent" }
            }
        }

        Row {
            id: glassRow
            anchors.centerIn: parent
            spacing: 14

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                height: 56
                radius: 18
                color: ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.8)
                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    iconSize: 34
                    color: Appearance.m3colors.m3primary
                    text: Icons.getWeatherIcon(Weather.data?.wCode) ?? "cloud"
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2
                StyledText {
                    text: root.tempText
                    color: Appearance.m3colors.m3onBackground
                    font {
                        family: Config.options.background.widgets.clock.digital.font.family
                        pixelSize: 40
                        weight: 620
                    }
                }
                StyledText {
                    text: `${Weather.data?.city ?? ""}  -  ${Weather.data?.humidity ?? ""} Luftfeuchte`
                    color: ColorUtils.transparentize(Appearance.m3colors.m3onBackground, 0.3)
                    font {
                        family: Appearance.font.family.main
                        pixelSize: 14
                    }
                }
            }
        }
    }
}
