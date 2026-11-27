// claudes-glassy (Windows-Look): Inhalt der Zwischenablage (Verlauf / Emoji / Symbole)
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

Item {
    id: root
    signal closed
    implicitWidth: 380
    implicitHeight: 500
    property real lift: 30
    opacity: 0

    function close() { closeAnim.start(); }

    // Etwas in die zuletzt aktive App einfuegen (wie bei Windows: auswaehlen = einfuegen)
    // Nicht mit wtype tippen: Electron/Chromium-Apps (Discord, Claude ...) machen daraus
    // Emoji + "OBJ"-Kaestchen (U+FFFC). Stattdessen kopieren und Strg+V druecken.
    function pasteText(text) {
        Quickshell.execDetached(["bash", "-c",
            `printf '%s' '${StringUtils.shellSingleQuoteEscape(text)}' | wl-copy; sleep 0.3; wtype -M ctrl -k v -m ctrl`]);
        root.close();
    }
    function pasteEntry(entry) {
        if (Cliphist.entryIsImage(entry)) {
            Cliphist.copy(entry);
            Quickshell.execDetached(["bash", "-c", "sleep 0.3; wtype -M ctrl -k v -m ctrl"]);
        } else {
            // Text ohne Discords "OBJ"-Platzhalter (U+FFFC) einfuegen
            Quickshell.execDetached(["bash", "-c",
                `printf '%s' '${StringUtils.shellSingleQuoteEscape(entry)}' | cliphist decode | sed 's/\xEF\xBF\xBC//g' | wl-copy; sleep 0.3; wtype -M ctrl -k v -m ctrl`]);
        }
        root.close();
    }

    Component.onCompleted: openAnim.start()
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "lift"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 150 }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "lift"; to: 20; duration: 140; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "opacity"; to: 0; duration: 140 }
        }
        ScriptAction { script: root.closed() }
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; }
    }

    WPane {
        id: pane
        y: root.lift
        width: root.width
        height: root.height
        contentItem: Item {
            implicitWidth: root.implicitWidth
            implicitHeight: root.implicitHeight

            ColumnLayout {
                anchors { fill: parent; margins: 12 }
                spacing: 10

                // ---------------------------------------------------- Reiter oben
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    TabBtn { tab: "emoji"; symbol: "mood"; tip: Translation.tr("Emoji") }
                    TabBtn { tab: "symbols"; symbol: "special_character"; tip: Translation.tr("Symbols") }
                    TabBtn { tab: "clipboard"; symbol: "content_paste"; tip: Translation.tr("Clipboard history") }
                    Item { Layout.fillWidth: true }
                    TabBtn { symbol: "close"; tip: Translation.tr("Close"); onClicked: root.close() }
                }

                // ---------------------------------------------------- Suchfeld (Emoji/Symbole)
                Rectangle {
                    visible: GlobalStates.clipboardTab !== "clipboard"
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 4
                    color: Looks.colors.inputBg
                    border.width: 1
                    border.color: Looks.colors.bg2Border
                    TextInput {
                        id: searchInput
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Looks.colors.fg
                        font.family: Looks.font.family.ui
                        font.pixelSize: Looks.font.pixelSize.large
                        focus: GlobalStates.clipboardTab !== "clipboard"
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !searchInput.text.length
                            text: Translation.tr("Search")
                            color: Looks.colors.fg1
                            font: searchInput.font
                        }
                    }
                }

                // ---------------------------------------------------- Verlauf
                ColumnLayout {
                    visible: GlobalStates.clipboardTab === "clipboard"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        WText {
                            text: Translation.tr("Clipboard history")
                            font.pixelSize: Looks.font.pixelSize.large
                            font.weight: Looks.font.weight.strong
                        }
                        Item { Layout.fillWidth: true }
                        WTextButton {
                            text: Translation.tr("Clear all")
                            onClicked: Cliphist.wipe()
                        }
                    }
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: Cliphist.entries.slice(0, 60)
                        keyNavigationEnabled: true
                        focus: GlobalStates.clipboardTab === "clipboard"
                        Keys.onReturnPressed: if (currentIndex >= 0) root.pasteEntry(model[currentIndex])
                        ScrollBar.vertical: WScrollBar {}
                        delegate: Rectangle {
                            id: item
                            required property string modelData
                            required property int index
                            readonly property bool isImage: Cliphist.entryIsImage(modelData)
                            width: list.width - 8
                            implicitHeight: Math.max(52, (isImage ? img.implicitHeight : txt.implicitHeight) + 24)
                            radius: Looks.radius.large
                            color: area.containsMouse || list.currentIndex === index ? Looks.colors.bg2Hover : Looks.colors.bg1
                            border.width: list.currentIndex === index ? 2 : 1
                            border.color: list.currentIndex === index ? Looks.colors.accent : Looks.colors.bg2Border
                            WText {
                                id: txt
                                visible: !item.isImage
                                anchors { left: parent.left; right: delBtn.left; top: parent.top; margins: 12 }
                                // Discord kopiert Emojis mit einem Platzhalter (U+FFFC = "OBJ"-Kaestchen) -> ausblenden
                                text: (StringUtils.cleanCliphistEntry ? StringUtils.cleanCliphistEntry(item.modelData) : item.modelData.replace(/^\d+\t/, "")).replace(/\uFFFC/g, "")
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                            Loader {
                                id: img
                                active: item.isImage
                                anchors { left: parent.left; top: parent.top; margins: 12 }
                                sourceComponent: CliphistImage {
                                    entry: item.modelData
                                    maxWidth: list.width - 80
                                    maxHeight: 140
                                }
                            }
                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.pasteEntry(item.modelData)
                            }
                            TabBtn {
                                id: delBtn
                                anchors { right: parent.right; top: parent.top; margins: 6 }
                                symbol: "delete"
                                tip: Translation.tr("Delete")
                                onClicked: Cliphist.deleteEntry(item.modelData)
                            }
                        }
                        WText {
                            anchors.centerIn: parent
                            visible: list.count === 0
                            horizontalAlignment: Text.AlignHCenter
                            color: Looks.colors.fg1
                            text: Translation.tr("You haven't copied anything yet.")
                        }
                    }
                }

                // ---------------------------------------------------- Emoji + Symbole
                GridView {
                    id: grid
                    visible: GlobalStates.clipboardTab !== "clipboard"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: Math.floor(width / 8)
                    cellHeight: cellWidth
                    ScrollBar.vertical: WScrollBar {}
                    readonly property var symbols: "© ® ™ ° ± × ÷ ≠ ≈ ≤ ≥ ∞ √ ∑ π µ € £ ¥ ¢ § ¶ † • … ‰ ← → ↑ ↓ ↔ ⇒ ⇔ ★ ☆ ♥ ♦ ♣ ♠ ✓ ✗ ½ ¼ ¾ ² ³ ¹ α β γ δ λ Ω « » „ “ ” ‚ ‘ ’ – — ¿ ¡".split(" ")
                    model: {
                        const q = searchInput.text.trim();
                        if (GlobalStates.clipboardTab === "symbols")
                            return symbols;
                        const src = q.length ? Emojis.fuzzyQuery(q) : Emojis.list;
                        return src.slice(0, 400).map(e => String(e).split(" ")[0]);
                    }
                    delegate: Rectangle {
                        id: cell
                        required property string modelData
                        width: grid.cellWidth - 2
                        height: grid.cellHeight - 2
                        radius: 4
                        color: cellArea.containsMouse ? Looks.colors.bg2Hover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData
                            font.pixelSize: GlobalStates.clipboardTab === "emoji" ? 24 : 18
                            color: Looks.colors.fg
                        }
                        MouseArea {
                            id: cellArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.pasteText(cell.modelData)
                        }
                    }
                }
            }
        }
    }

    component TabBtn: Rectangle {
        id: tb
        property string tab: ""
        property string symbol: ""
        property string tip: ""
        signal clicked
        readonly property bool active: tab.length > 0 && GlobalStates.clipboardTab === tab
        implicitWidth: 36; implicitHeight: 32
        radius: 4
        color: active ? Looks.colors.bg2Active : (tbArea.containsMouse ? Looks.colors.bg2Hover : "transparent")
        MaterialSymbol {
            anchors.centerIn: parent
            text: tb.symbol
            iconSize: 18
            color: Looks.colors.fg
        }
        Rectangle {
            visible: tb.active
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: 16; height: 3; radius: 2
            color: Looks.colors.accent
        }
        MouseArea {
            id: tbArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (tb.tab.length) GlobalStates.clipboardTab = tb.tab;
                tb.clicked();
            }
        }
        WToolTip { text: tb.tip; extraVisibleCondition: tbArea.containsMouse }
    }
}
