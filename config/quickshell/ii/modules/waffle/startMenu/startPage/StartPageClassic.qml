// claudes-glassy (Windows-Look): Startmenue wie Windows 11 (Angeheftet / Alle Apps / Empfohlen)
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

WPanelPageColumn {
    id: root
    property bool allApps: false
    property int pinnedPage: 0

    // Angeheftet: deine Liste, aufgefuellt mit gaengigen installierten Apps (wie ein frisches Windows)
    readonly property var fallbackIds: ["firefox", "org.kde.dolphin", "kitty", "code", "code-oss", "visual-studio-code", "com.visualstudio.code", "spotify",
        "discord", "vesktop", "steam", "org.kde.gwenview", "org.kde.kate", "org.kde.okular", "obs", "com.obsproject.Studio",
        "org.kde.ark", "org.kde.spectacle", "pavucontrol", "org.kde.kcalc", "org.gnome.Calculator", "btop"]
    readonly property var pinnedEntries: {
        const ids = [];
        for (const id of Config.options.launcher.pinnedApps) if (!ids.includes(id) && id !== "cmake-gui") ids.push(id);   // cmake-gui = alter end-4-Standard
        for (const id of fallbackIds) if (ids.length < 18 && !ids.includes(id)) ids.push(id);
        return ids.map(id => DesktopEntries.byId(id)).filter(e => e && !e.noDisplay);
    }
    readonly property int pageCount: Math.max(1, Math.ceil(pinnedEntries.length / 18))

    readonly property var allEntries: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name))
    // Mit Buchstaben-Ueberschriften (A, B, C ...) wie bei Windows
    readonly property var allRows: {
        const rows = [];
        let last = "";
        for (const e of allEntries) {
            const c = (e.name[0] ?? "#").toUpperCase();
            const letter = /[A-Z\u00C0-\u017F]/.test(c) ? c : "#";
            if (letter !== last) { rows.push({ header: letter }); last = letter; }
            rows.push({ entry: e });
        }
        return rows;
    }

    WPanelSeparator {}

    BodyRectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: 560

        // ============================================================ Startseite
        ColumnLayout {
            visible: !root.allApps
            anchors { fill: parent; leftMargin: 32; rightMargin: 32; topMargin: 22; bottomMargin: 16 }
            spacing: 14

            SectionHeader {
                title: Translation.tr("Pinned")
                buttonText: Translation.tr("All apps")
                onButtonClicked: root.allApps = true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                GridLayout {
                    Layout.fillWidth: true
                    columns: 6
                    columnSpacing: 0
                    rowSpacing: 2
                    Repeater {
                        model: root.pinnedEntries.slice(root.pinnedPage * 18, root.pinnedPage * 18 + 18)
                        delegate: StartAppButton {
                            required property var modelData
                            Layout.fillWidth: true
                            desktopEntry: modelData
                            onClicked: {
                                GlobalStates.searchOpen = false;
                                desktopEntry.execute();
                            }
                        }
                    }
                }
                // Seitenpunkte rechts (wie bei Windows)
                ColumnLayout {
                    visible: root.pageCount > 1
                    spacing: 6
                    Repeater {
                        model: root.pageCount
                        delegate: Rectangle {
                            required property int index
                            implicitWidth: 6; implicitHeight: 6; radius: 3
                            color: index === root.pinnedPage ? Looks.colors.fg : Looks.colors.fg1
                            opacity: index === root.pinnedPage ? 1 : 0.5
                            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.pinnedPage = parent.index }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true; implicitHeight: 4 }

            SectionHeader {
                title: Translation.tr("Recommended")
                buttonText: ""
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 4
                Repeater {
                    model: recent.items.slice(0, 6)
                    delegate: RecentButton {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        file: modelData
                    }
                }
            }
            WText {
                visible: recent.items.length === 0
                color: Looks.colors.fg1
                text: Translation.tr("The more you use your PC, the more of your recent files and new apps will show up here.")
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
        }

        // ============================================================ Alle Apps (A-Z)
        ColumnLayout {
            visible: root.allApps
            anchors { fill: parent; leftMargin: 32; rightMargin: 24; topMargin: 22; bottomMargin: 12 }
            spacing: 10
            SectionHeader {
                title: Translation.tr("All apps")
                buttonText: Translation.tr("Back")
                backArrow: true
                onButtonClicked: root.allApps = false
            }
            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.allRows
                ScrollBar.vertical: WScrollBar {}
                delegate: Item {
                    id: row
                    required property var modelData
                    width: appList.width - 12
                    implicitHeight: modelData.header ? 34 : 40
                    WText {
                        visible: !!row.modelData.header
                        anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 4 }
                        text: row.modelData.header ?? ""
                        font.weight: Looks.font.weight.strong
                    }
                    WButton {
                        id: appRow
                        visible: !row.modelData.header
                        anchors.fill: parent
                        color: hovered ? Looks.colors.bg2Hover : "transparent"
                        onClicked: {
                            GlobalStates.searchOpen = false;
                            row.modelData.entry.execute();
                        }
                        contentItem: RowLayout {
                            spacing: 12
                            WAppIcon {
                                Layout.leftMargin: 12
                                iconName: row.modelData.entry?.icon ?? ""
                                implicitSize: 24
                                tryCustomIcon: false
                            }
                            WText {
                                Layout.fillWidth: true
                                text: row.modelData.entry?.name ?? ""
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    WPanelSeparator {}

    FooterRectangle {
        Layout.fillWidth: true
        implicitHeight: 63
        StartUserButton {
            anchors { left: parent.left; leftMargin: 52; bottom: parent.bottom; bottomMargin: 12 }
        }
        WBorderlessButton {
            id: powerButton
            anchors { right: parent.right; rightMargin: 52; bottom: parent.bottom; bottomMargin: 12 }
            implicitWidth: 40
            implicitHeight: 40
            contentItem: Item {
                FluentIcon { anchors.centerIn: parent; icon: "power"; implicitSize: 20 }
            }
            onClicked: powerMenu.open()
            WMenu {
                id: powerMenu
                x: -powerMenu.implicitWidth / 2 + powerButton.implicitWidth / 2
                y: -powerMenu.implicitHeight - 4
                Action { icon.name: "lock-closed"; text: Translation.tr("Lock"); onTriggered: Session.lock() }
                Action { icon.name: "weather-moon"; text: Translation.tr("Sleep"); onTriggered: Session.suspend() }
                Action { icon.name: "power"; text: Translation.tr("Shut down"); onTriggered: Session.poweroff() }
                Action { icon.name: "arrow-counterclockwise"; text: Translation.tr("Restart"); onTriggered: Session.reboot() }
            }
        }
    }

    // Zuletzt benutzte Dateien (wie "Empfohlen")
    Process {
        id: recent
        property var items: []
        running: true
        command: ["python3", "-c", `
import json, os, urllib.parse, xml.etree.ElementTree as ET
p = os.path.expanduser("~/.local/share/recently-used.xbel")
out = []
try:
    for b in ET.parse(p).getroot().findall("bookmark"):
        href = b.get("href", "")
        if not href.startswith("file://"): continue
        path = urllib.parse.unquote(href[7:])
        if not os.path.exists(path) or os.path.isdir(path): continue
        out.append({"path": path, "name": os.path.basename(path), "time": b.get("visited") or b.get("modified") or ""})
except Exception:
    pass
out.sort(key=lambda x: x["time"], reverse=True)
print(json.dumps(out[:12]))
`]
        stdout: StdioCollector {
            onStreamFinished: {
                try { recent.items = JSON.parse(this.text); } catch (e) { recent.items = []; }
            }
        }
    }

    component SectionHeader: RowLayout {
        id: header
        property string title: ""
        property string buttonText: ""
        property bool backArrow: false
        signal buttonClicked
        Layout.fillWidth: true
        WText {
            Layout.leftMargin: 4
            text: header.title
            font.pixelSize: Looks.font.pixelSize.large
            font.weight: Looks.font.weight.stronger
        }
        Item { Layout.fillWidth: true }
        WButton {
            visible: header.buttonText.length > 0
            implicitHeight: 26
            implicitWidth: btnRow.implicitWidth + 20
            onClicked: header.buttonClicked()
            contentItem: Item {
                RowLayout {
                    id: btnRow
                    anchors.centerIn: parent
                    spacing: 6
                    FluentIcon { visible: header.backArrow; icon: "chevron-left"; implicitSize: 12 }
                    WText { text: header.buttonText }
                    FluentIcon { visible: !header.backArrow; icon: "chevron-right"; implicitSize: 12 }
                }
            }
        }
    }

    component RecentButton: WButton {
        id: rb
        property var file
        implicitHeight: 52
        color: hovered ? Looks.colors.bg2Hover : "transparent"
        onClicked: {
            GlobalStates.searchOpen = false;
            Quickshell.execDetached(["xdg-open", rb.file.path]);
        }
        contentItem: RowLayout {
            spacing: 12
            WAppIcon {
                Layout.leftMargin: 10
                iconName: {
                    const ext = (rb.file?.name ?? "").split(".").pop().toLowerCase();
                    if (["png", "jpg", "jpeg", "webp", "gif", "svg"].includes(ext)) return "image-x-generic";
                    if (["mp4", "mkv", "webm", "mov"].includes(ext)) return "video-x-generic";
                    if (["mp3", "flac", "ogg", "wav"].includes(ext)) return "audio-x-generic";
                    if (["pdf"].includes(ext)) return "application-pdf";
                    if (["zip", "tar", "gz", "zst", "7z", "rar"].includes(ext)) return "package-x-generic";
                    return "text-x-generic";
                }
                implicitSize: 28
                tryCustomIcon: false
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                WText {
                    Layout.fillWidth: true
                    text: rb.file?.name ?? ""
                    elide: Text.ElideMiddle
                }
                WText {
                    Layout.fillWidth: true
                    color: Looks.colors.fg1
                    text: {
                        const t = Date.parse(rb.file?.time ?? "");
                        if (isNaN(t)) return "";
                        const min = Math.round((Date.now() - t) / 60000);
                        if (min < 60) return Translation.tr("%1 min ago").arg(Math.max(1, min));
                        if (min < 60 * 24) return Translation.tr("%1 h ago").arg(Math.round(min / 60));
                        return Qt.locale().toString(new Date(t), "d. MMM");
                    }
                }
            }
        }
    }
}
