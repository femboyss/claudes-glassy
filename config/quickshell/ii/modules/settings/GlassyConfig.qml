import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// claudes-glassy: eigene Einstellungsseite (Theme, Performance, Updates)
ContentPage {
    id: page
    forceWidth: true

    readonly property string themeScript: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/glassy_theme.py`)
    readonly property string glassyBin: `${FileUtils.trimFileProtocol(Directories.home)}/.local/bin/glassy`
    property string status: ""

    function runTheme(args) {
        themeProc.command = ["python3", page.themeScript].concat(args);
        themeProc.running = true;
    }

    function inTerminal(cmd) {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.terminal} bash -c '${cmd}; echo; read -r -p "Enter zum Schliessen "'`]);
    }

    Process {
        id: themeProc
        stdout: SplitParser {
            onRead: data => page.status = data.trim()
        }
    }

    Timer {
        // Kurz warten, bis die Config auf der Platte ist, dann Hyprland-Werte schreiben
        id: syncTimer
        interval: 400
        onTriggered: page.runTheme(["sync"])
    }

    ContentSection {
        icon: "palette"
        title: "Theme"

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: "Faerbt Leiste, Seitenleisten, Overview, Benachrichtigungen, Sperrbildschirm, Terminal, GTK-Apps und die Fensterrahmen auf einmal. \"Material You\" nimmt die Farben automatisch aus dem Wallpaper."
        }

        ConfigSelectionArray {
            currentValue: Config.options.glassy.theme
            onSelected: newValue => {
                Config.options.glassy.theme = newValue;
                page.status = "Wende Theme an ...";
                page.runTheme(["apply", newValue]);
            }
            options: [
                { value: "tokyo", displayName: "Tokyo Night", icon: "nightlight" },
                { value: "catppuccin", displayName: "Catppuccin", icon: "pets" },
                { value: "glass", displayName: "Komplett Glas", icon: "blur_on" },
                { value: "clear", displayName: "Durchsicht", icon: "visibility" },
                { value: "nord", displayName: "Nord", icon: "ac_unit" },
                { value: "gruvbox", displayName: "Gruvbox", icon: "local_fire_department" },
                { value: "rosepine", displayName: "Rose Pine", icon: "local_florist" },
                { value: "dracula", displayName: "Dracula", icon: "bedtime" },
                { value: "mono", displayName: "Schwarz/Weiss", icon: "contrast" },
                { value: "material", displayName: "Material You", icon: "wallpaper" }
            ]
        }

        ConfigSwitch {
            buttonIcon: "ev_shadow"
            text: "Glas (Transparenz + Blur)"
            checked: Config.options.appearance.transparency.enable
            onCheckedChanged: Config.options.appearance.transparency.enable = checked
        }

        ConfigSlider {
            text: "Durchsicht Hintergrund"
            buttonIcon: "opacity"
            value: Config.options.appearance.transparency.backgroundTransparency
            from: 0
            to: 0.9
            usePercentTooltip: true
            textWidth: 200
            onValueChanged: Config.options.appearance.transparency.backgroundTransparency = value
        }

        ConfigSlider {
            text: "Durchsicht Inhalte"
            buttonIcon: "layers"
            value: Config.options.appearance.transparency.contentTransparency
            from: 0
            to: 0.9
            usePercentTooltip: true
            textWidth: 200
            onValueChanged: Config.options.appearance.transparency.contentTransparency = value
        }

        ContentSubsection {
            title: "Stil der Leiste"
            ConfigSelectionArray {
                currentValue: Config.options.panelFamily
                onSelected: newValue => Config.options.panelFamily = newValue
                options: [
                    { value: "ii", displayName: "Glassy (illogical-impulse)", icon: "auto_awesome" },
                    { value: "waffle", displayName: "Windows 11 (Startmenue unten)", icon: "grid_view" }
                ]
            }
        }

        StyledText {
            visible: page.status.length > 0
            Layout.fillWidth: true
            color: Appearance.colors.colSubtext
            text: page.status
        }
    }

    ContentSection {
        icon: "speed"
        title: "Performance"

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: "Bei mehreren Monitoren mit hoher Hz-Zahl lohnt sich das. Der rotierende Rahmen zwingt Hyprland, jeden Frame neu zu zeichnen."
        }

        ConfigSwitch {
            buttonIcon: "animation"
            text: "Rotierender Rahmen-Verlauf"
            checked: Config.options.glassy.borderAnimation
            onCheckedChanged: {
                if (Config.options.glassy.borderAnimation === checked) return;
                Config.options.glassy.borderAnimation = checked;
                syncTimer.restart();
            }
        }

        ConfigSwitch {
            buttonIcon: "bolt"
            text: "Performance-Modus (weniger Blur, keine Schatten, schnellere Animationen)"
            checked: Config.options.glassy.performanceMode
            onCheckedChanged: {
                if (Config.options.glassy.performanceMode === checked) return;
                Config.options.glassy.performanceMode = checked;
                syncTimer.restart();
            }
        }

        ConfigSwitch {
            buttonIcon: "live_tv"
            text: "Live-Vorschau in der Uebersicht (SUPER+Tab)"
            checked: Config.options.overview.livePreviews
            onCheckedChanged: Config.options.overview.livePreviews = checked
            StyledToolTip {
                text: "Aus = Standbild, live nur fuer das Fenster unter der Maus (spart viel GPU)"
            }
        }

        ConfigSpinBox {
            icon: "notifications"
            text: "Gespeicherte Benachrichtigungen (max.)"
            value: Config.options.notifications.maxStored
            from: 10
            to: 500
            stepSize: 10
            onValueChanged: Config.options.notifications.maxStored = value
        }
    }

    ContentSection {
        icon: "system_update_alt"
        title: "claudes-glassy"

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "update"
                mainText: "Nach Updates suchen"
                onClicked: Quickshell.execDetached([page.glassyBin, "--check", "--notify", "--force"])
            }
            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "new_releases"
                mainText: "Was ist neu"
                onClicked: page.inTerminal(`${page.glassyBin} --whatsnew`)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "medical_services"
                mainText: "Doktor"
                onClicked: page.inTerminal(`${page.glassyBin} --doctor`)
            }
            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "restart_alt"
                mainText: "Shell neu starten"
                onClicked: Quickshell.execDetached([page.glassyBin, "--reload"])
            }
        }
    }
}
