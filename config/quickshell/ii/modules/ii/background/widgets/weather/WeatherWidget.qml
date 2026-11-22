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

    // ---------------------------------------------------------- Glassy (ohne Karte, passend zur Musik-Uhr)
    needsColText: root.glassy
    readonly property bool darkBg: root.dominantColorIsDark
    readonly property color colAccent: ColorUtils.colorWithLightness(Appearance.m3colors.m3primary, darkBg ? 0.68 : 0.32)
    readonly property color colShadowText: darkBg ? "#66000000" : "#55ffffff"

    Row {
        id: glassCard
        visible: root.glassy
        anchors.centerIn: parent
        spacing: 12

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 1
            iconSize: 54
            color: root.colAccent
            text: Icons.getWeatherIcon(Weather.data?.wCode) ?? "cloud"
            style: Text.Raised
            styleColor: root.colShadowText
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -4
            StyledText {
                text: root.tempText
                color: root.colText
                style: Text.Raised
                styleColor: root.colShadowText
                font {
                    family: Config.options.background.widgets.clock.digital.font.family
                    pixelSize: 52
                    weight: 680
                    styleName: ""
                    variableAxes: ({ "wdth": 110, "ROND": 100 })
                }
            }
            StyledText {
                text: (Weather.data?.city ?? "").toUpperCase()
                color: ColorUtils.transparentize(root.colText, 0.3)
                style: Text.Raised
                styleColor: root.colShadowText
                font {
                    family: Appearance.font.family.main
                    pixelSize: 13
                    weight: Font.Bold
                    letterSpacing: 3
                }
            }
        }
    }
}
