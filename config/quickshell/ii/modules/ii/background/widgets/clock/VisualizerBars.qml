import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions

// claudes-glassy: Audio-Balken (cava ueber GlassyCava). Ohne Musik: ruhige, statische Welle.
Item {
    id: root

    property int count: 36
    property real spacing: 4
    property color colA: Appearance.m3colors.m3primary
    property color colB: Appearance.m3colors.m3tertiary
    property real idleOpacity: 0.45
    readonly property var points: GlassyCava.points
    readonly property bool live: points.length > 0

    implicitHeight: 44

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            model: root.count
            delegate: Item {
                id: slot
                required property int index
                readonly property real t: root.count > 1 ? index / (root.count - 1) : 0
                readonly property real value: {
                    if (root.live) {
                        const i = Math.floor(index * root.points.length / root.count);
                        return root.points[i] ?? 0;
                    }
                    // statische Ruhe-Welle
                    return 0.12 + 0.1 * Math.abs(Math.sin(index * 0.55)) + 0.06 * Math.abs(Math.sin(index * 1.7));
                }
                width: (root.width - root.spacing * (root.count - 1)) / root.count
                height: root.height

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: Math.max(width, parent.height * slot.value)
                    radius: width / 2
                    color: ColorUtils.mix(root.colB, root.colA, slot.t)
                    opacity: root.live ? 1 : root.idleOpacity
                }
            }
        }
    }
}
