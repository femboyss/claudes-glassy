pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = HyprlandData.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    // Internals
    //
    // claudes-glassy: Lag-Fix. Vorher hat JEDES Hyprland-Event (auch "windowtitle",
    // das Browser/Terminals dauernd feuern, oder jede Mausbewegung beim Fenster-Ziehen)
    // sofort 5 hyprctl-Prozesse gestartet und alles neu geparst. Jetzt:
    //  - pro Event nur das neu holen, was sich wirklich aendern kann
    //  - Events werden gesammelt (coalesceDelay ms) -> max. ein Durchlauf pro Frame-Gruppe
    //  - laeuft ein hyprctl noch, wird danach genau einmal nachgeholt statt verworfen
    readonly property int dirtyClients: 1
    readonly property int dirtyMonitors: 2
    readonly property int dirtyLayers: 4
    readonly property int dirtyWorkspaces: 8
    readonly property int dirtyAll: 15
    property int dirty: 0
    property int coalesceDelay: 33

    function markDirty(flags) {
        root.dirty |= flags;
        if (!flushTimer.running)
            flushTimer.start();
    }

    function flush() {
        const d = root.dirty;
        root.dirty = 0;
        if (d & root.dirtyClients) root.runOrQueue(getClients, root.dirtyClients);
        if (d & root.dirtyMonitors) root.runOrQueue(getMonitors, root.dirtyMonitors);
        if (d & root.dirtyLayers) root.runOrQueue(getLayers, root.dirtyLayers);
        if (d & root.dirtyWorkspaces) {
            root.runOrQueue(getWorkspaces, root.dirtyWorkspaces);
            root.runOrQueue(getActiveWorkspace, root.dirtyWorkspaces);
        }
    }

    function runOrQueue(proc, flag) {
        if (proc.running) {
            // Noch beschaeftigt: nach dem Ende nochmal holen
            proc.pendingRerun = true;
        } else {
            proc.running = true;
        }
    }

    // Welche Daten aendern sich bei welchem Event?
    function flagsForEvent(name) {
        switch (name) {
        case "openlayer":
        case "closelayer":
            // Wie upstream ignoriert: feuert bei jedem Tooltip/Popup der Shell selbst.
            // Die Layer-Liste braucht nur die Bereichsauswahl, die holt sie beim Oeffnen.
            return 0;
        case "screencast":
        case "bell":
        case "submap":
        case "activelayout":
        case "ignoregrouplock":
        case "lockgroups":
            return 0;
        case "windowtitle":
        case "windowtitlev2":
        case "activewindow":
        case "activewindowv2":
        case "urgent":
        case "pin":
        case "minimized":
        case "togglegroup":
        case "moveintogroup":
        case "moveoutofgroup":
        case "changefloatingmode":
            return root.dirtyClients;
        case "fullscreen":
            return root.dirtyClients | root.dirtyWorkspaces;
        case "openwindow":
        case "closewindow":
        case "movewindow":
        case "movewindowv2":
            return root.dirtyClients | root.dirtyWorkspaces;
        case "workspace":
        case "workspacev2":
        case "focusedmon":
        case "focusedmonv2":
        case "activespecial":
        case "activespecialv2":
        case "createworkspace":
        case "createworkspacev2":
        case "destroyworkspace":
        case "destroyworkspacev2":
        case "renameworkspace":
        case "moveworkspace":
        case "moveworkspacev2":
            return root.dirtyWorkspaces | root.dirtyMonitors;
        case "monitoradded":
        case "monitoraddedv2":
        case "monitorremoved":
        case "monitorremovedv2":
        case "configreloaded":
            return root.dirtyAll;
        default:
            return root.dirtyAll;
        }
    }

    function updateWindowList() {
        root.markDirty(root.dirtyClients);
    }

    function updateLayers() {
        root.markDirty(root.dirtyLayers);
    }

    function updateMonitors() {
        root.markDirty(root.dirtyMonitors);
    }

    function updateWorkspaces() {
        root.markDirty(root.dirtyWorkspaces);
    }

    function updateAll() {
        root.markDirty(root.dirtyAll);
    }

    Timer {
        id: flushTimer
        interval: root.coalesceDelay
        repeat: false
        onTriggered: root.flush()
    }

    component CoalescedProcess: Process {
        property bool pendingRerun: false
        onRunningChanged: {
            if (!running && pendingRerun) {
                pendingRerun = false;
                Qt.callLater(() => { running = true; });
            }
        }
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        updateAll();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const flags = root.flagsForEvent(event.name);
            if (flags !== 0)
                root.markDirty(flags);
        }
    }

    CoalescedProcess {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                root.windowList = JSON.parse(clientsCollector.text)
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
            }
        }
    }

    CoalescedProcess {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                root.monitors = JSON.parse(monitorsCollector.text);
            }
        }
    }

    CoalescedProcess {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                root.layers = JSON.parse(layersCollector.text);
            }
        }
    }

    CoalescedProcess {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                var rawWorkspaces = JSON.parse(workspacesCollector.text);
                // Filter out invalid workspace ids (e.g. lock-screen temp workspace 2147483647 - N)
                root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                let tempWorkspaceById = {};
                for (var i = 0; i < root.workspaces.length; ++i) {
                    var ws = root.workspaces[i];
                    tempWorkspaceById[ws.id] = ws;
                }
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
            }
        }
    }

    CoalescedProcess {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
            }
        }
    }
}
