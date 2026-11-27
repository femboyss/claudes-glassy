import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

AppButton {
    id: root

    // claudes-glassy: wie Windows 11 immer Wetter (Symbol + Temperatur + Zustand) und
    // oeffnet das Widgets-Brett (nicht die Schnelleinstellungen)
    readonly property bool expandedForm: true
    readonly property string weatherSymbol: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
    readonly property string weatherText: ({
        "clear_day": Translation.tr("Sunny"),
        "partly_cloudy_day": Translation.tr("Partly cloudy"),
        "cloud": Translation.tr("Cloudy"),
        "foggy": Translation.tr("Fog"),
        "rainy": Translation.tr("Rain"),
        "thunderstorm": Translation.tr("Thunderstorm"),
        "snowing": Translation.tr("Snow"),
        "snowing_heavy": Translation.tr("Heavy snow"),
        "cloudy_snowing": Translation.tr("Snow showers"),
        "weather_hail": Translation.tr("Hail"),
    })[weatherSymbol] ?? ""
    leftInset: 4
    implicitWidth: 150
    iconName: "widgets"

    checked: GlobalStates.widgetsOpen
    onClicked: {
        GlobalStates.widgetsOpen = !GlobalStates.widgetsOpen
    }
    onDownChanged: {
        scaleAnim.duration = root.down ? 150 : 200
        scaleAnim.easing.bezierCurve = root.down ? Looks.transition.easing.bezierCurve.easeIn : Looks.transition.easing.bezierCurve.easeOut
        iconWidget.scale = root.down ? 5/6 : 1 // If/When we do dragging, the scale is 1.25
    }

    contentItem: Item {
        anchors {
            verticalCenter: parent.verticalCenter
            left: root.expandedForm ? parent.left : undefined
            horizontalCenter: root.expandedForm ? undefined : background.horizontalCenter
        }
        implicitHeight: row.implicitHeight
        implicitWidth: row.implicitWidth
        Row {
            id: row
            anchors {
                verticalCenter: parent.verticalCenter
                left: root.expandedForm ? parent.left : undefined
                horizontalCenter: root.expandedForm ? undefined : parent.horizontalCenter
                margins: 8
            }
            spacing: 6

            MaterialSymbol {
                id: iconWidget
                anchors.verticalCenter: parent.verticalCenter
                text: root.weatherSymbol
                iconSize: 26
                color: root.weatherSymbol === "clear_day" ? "#FFC83D" : Looks.colors.fg

                Behavior on scale {
                    NumberAnimation {
                        id: scaleAnim
                        easing.type: Easing.BezierSpline
                    }
                }
            }

            Column {
                visible: root.expandedForm
                anchors.verticalCenter: parent.verticalCenter
                WText {
                    text: Weather.data.temp || "--"
                }
                WText {
                    text: root.weatherText
                    color: Looks.colors.fg1
                }
            }
        }
    }

    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip
        text: Translation.tr("Widgets")
    }
}
