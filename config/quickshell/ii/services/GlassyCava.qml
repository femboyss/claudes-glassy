pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions

/**
 * claudes-glassy: eine einzige cava-Instanz fuer die Musik-Uhr.
 * Laeuft nur, wenn wirklich Musik spielt und die Uhr gerade sichtbar ist.
 */
Singleton {
    id: root

    property list<real> points: [] // 0..1
    readonly property var clockCfg: Config.options.background.widgets.clock
    readonly property bool clockShown: clockCfg.enable && (GlobalStates.screenLocked
        ? clockCfg.styleLocked === "glassy"
        : (clockCfg.style === "glassy" && !clockCfg.showOnlyWhenLocked))
    readonly property bool wanted: MprisController.isPlaying && clockShown

    Process {
        id: cava
        running: root.wanted
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/glassy_raw.txt`]
        onRunningChanged: {
            if (!running)
                root.points = [];
        }
        stdout: SplitParser {
            onRead: data => {
                root.points = data.split(";").map(p => parseFloat(p)).filter(p => !isNaN(p)).map(p => Math.min(1, p / 1000));
            }
        }
    }
}
