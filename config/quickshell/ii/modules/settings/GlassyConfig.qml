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
                { value: "miku", displayName: "Hatsune Miku", icon: "music_note" },
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

        ConfigSwitch {
            buttonIcon: "bedtime"
            text: "Automatisch sperren (10 min) + Bildschirm aus (12 min)"
            checked: Config.options.glassy.autoIdle
            onCheckedChanged: {
                if (Config.options.glassy.autoIdle === checked) return;
                Config.options.glassy.autoIdle = checked;
                Quickshell.execDetached([page.glassyBin, "--idle", checked ? "on" : "off"]);
            }
        }

        ConfigSwitch {
            buttonIcon: "folder_open"
            text: "Qt-Apps (Dolphin, Kate, Ark) im Glas-Look + Theme-Farben"
            checked: Config.options.glassy.qtApps
            onCheckedChanged: {
                if (Config.options.glassy.qtApps === checked) return;
                Config.options.glassy.qtApps = checked;
                if (checked) page.runTheme(["apply", Config.options.glassy.theme]);
            }
            StyledToolTip {
                text: "Braucht den Qt-Stil Darkly (installiert glassy --update automatisch). Dolphin einmal neu starten."
            }
        }

        ContentSubsection {
            title: "Miku-Wallpaper"

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: "Holt bei jedem Start ein zufaelliges Hatsune-Miku-Wallpaper von wallhaven.cc (nur SFW), exakt in deiner Bildschirm-Aufloesung - kein Hoch- oder Runterskalieren. Wird beim Miku-Theme automatisch eingeschaltet."
            }

            ConfigSwitch {
                buttonIcon: "wallpaper_slideshow"
                text: "Bei jedem Start neues Miku-Wallpaper"
                checked: Config.options.glassy.mikuWallpaperOnStart
                onCheckedChanged: Config.options.glassy.mikuWallpaperOnStart = checked
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: "Aufloesung: auto oder z.B. 1920x1080"
                text: Config.options.glassy.mikuResolution
                wrapMode: TextEdit.NoWrap
                onTextChanged: Config.options.glassy.mikuResolution = text.trim().length > 0 ? text.trim() : "auto"
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "shuffle"
                mainText: "Jetzt neues Miku-Wallpaper"
                onClicked: Quickshell.execDetached([page.glassyBin, "--miku-wall"])
            }
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
        icon: "neurology"
        title: "KI (SUPER+K): LM Studio und LU"

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: "In LM Studio unter Developer den Server starten (Port 1234) und \"Just-in-Time Model Loading\" einschalten. Dann tauchen deine Modelle in der KI-Seitenleiste auf, oben ueber das Modell-Symbol oder /model. \"LU (Uncensored)\" nimmt dasselbe Modell mit dem System-Prompt aus deiner LU-Datei. Nach Aenderungen hier: Shell neu starten."
        }

        ConfigSwitch {
            buttonIcon: "dns"
            text: "Modelle aus LM Studio anzeigen"
            checked: Config.options.ai.lmstudioModels
            onCheckedChanged: Config.options.ai.lmstudioModels = checked
        }

        ConfigSwitch {
            buttonIcon: "lock_open"
            text: "LU (Locally Uncensored) anzeigen"
            checked: Config.options.ai.luEnable
            onCheckedChanged: Config.options.ai.luEnable = checked
        }

        ContentSubsection {
            title: "LU: Datei mit dem System-Prompt"
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: "~/uncensored/system_prompt.txt"
                text: Config.options.ai.luPromptFile
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.options.ai.luPromptFile = text
            }
        }

        ContentSubsection {
            title: "LU: Modell (leer = erstes Modell in LM Studio)"
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: "z. B. qwen3-coder-30b-a3b-instruct-abliterated"
                text: Config.options.ai.luModel
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.options.ai.luModel = text
            }
        }

        ContentSubsection {
            title: "LM Studio Adresse"
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: "http://localhost:1234/v1"
                text: Config.options.ai.lmstudioUrl
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.options.ai.lmstudioUrl = text
            }
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
