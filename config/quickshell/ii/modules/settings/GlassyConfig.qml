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

    // Look: shortcuts (Hyprland, via glassy-generated.lua) + key symbols in the cheatsheet
    function setPlatform(p) {
        if (["linux", "windows", "mac"].indexOf(p) < 0) return;
        Config.options.glassy.platform = p;
        Config.options.cheatsheet.superKey = p === "windows" ? String.fromCodePoint(0xF05B3)
                                           : p === "mac" ? String.fromCodePoint(0x2318)
                                           : String.fromCodePoint(0xE8E5);
        Config.options.cheatsheet.useMacSymbol = p === "mac";
        Config.options.panelFamily = p === "windows" ? "waffle" : "ii";
        syncTimer.restart();
    }

    function inTerminal(cmd) {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.terminal} bash -c '${cmd}; echo; read -r -p "${Translation.tr("Press Enter to close")} "'`]);
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
        title: Translation.tr("Theme")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("Colors the bar, sidebars, overview, notifications, lock screen, terminal, GTK apps and the window borders all at once. \"Material You\" takes the colors from your wallpaper.")
        }

        ConfigSelectionArray {
            currentValue: Config.options.glassy.theme
            onSelected: newValue => {
                Config.options.glassy.theme = newValue;
                page.status = Translation.tr("Applying theme ...");
                page.runTheme(["apply", newValue]);
            }
            options: [
                { value: "tokyo", displayName: "Tokyo Night", icon: "nightlight" },
                { value: "catppuccin", displayName: "Catppuccin", icon: "pets" },
                { value: "glass", displayName: Translation.tr("Full glass"), icon: "blur_on" },
                { value: "clear", displayName: Translation.tr("See-through"), icon: "visibility" },
                { value: "nord", displayName: "Nord", icon: "ac_unit" },
                { value: "gruvbox", displayName: "Gruvbox", icon: "local_fire_department" },
                { value: "rosepine", displayName: "Rose Pine", icon: "local_florist" },
                { value: "dracula", displayName: "Dracula", icon: "bedtime" },
                { value: "miku", displayName: "Hatsune Miku", icon: "music_note" },
                { value: "alya", displayName: "Alya", icon: "diamond" },
                { value: "mono", displayName: Translation.tr("Black/White"), icon: "contrast" },
                { value: "material", displayName: "Material You", icon: "wallpaper" }
            ]
        }

        ConfigSwitch {
            buttonIcon: "ev_shadow"
            text: Translation.tr("Glass (transparency + blur)")
            checked: Config.options.appearance.transparency.enable
            onCheckedChanged: Config.options.appearance.transparency.enable = checked
        }

        ConfigSlider {
            text: Translation.tr("Background see-through")
            buttonIcon: "opacity"
            value: Config.options.appearance.transparency.backgroundTransparency
            from: 0
            to: 0.9
            usePercentTooltip: true
            textWidth: 200
            onValueChanged: Config.options.appearance.transparency.backgroundTransparency = value
        }

        ConfigSlider {
            text: Translation.tr("Content see-through")
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
            text: Translation.tr("Lock automatically (10 min) + screen off (12 min)")
            checked: Config.options.glassy.autoIdle
            onCheckedChanged: {
                if (Config.options.glassy.autoIdle === checked) return;
                Config.options.glassy.autoIdle = checked;
                Quickshell.execDetached([page.glassyBin, "--idle", checked ? "on" : "off"]);
            }
        }

        ConfigSwitch {
            buttonIcon: "folder_open"
            text: Translation.tr("Qt apps (Dolphin, Kate, Ark) in the glass look + theme colors")
            checked: Config.options.glassy.qtApps
            onCheckedChanged: {
                if (Config.options.glassy.qtApps === checked) return;
                Config.options.glassy.qtApps = checked;
                if (checked) page.runTheme(["apply", Config.options.glassy.theme]);
            }
            StyledToolTip {
                text: Translation.tr("Needs the Qt style Darkly (glassy --update installs it). Restart Dolphin once.")
            }
        }

        ContentSubsection {
            visible: Config.options.glassy.theme === "miku"
            title: Translation.tr("Miku wallpaper")

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("Fetches a random Hatsune Miku wallpaper from wallhaven.cc (SFW only) on every start, in exactly your screen resolution - no up- or downscaling. Turned on automatically with the Miku theme.")
            }

            ConfigSwitch {
                buttonIcon: "wallpaper_slideshow"
                text: Translation.tr("New Miku wallpaper on every start")
                checked: Config.options.glassy.mikuWallpaperOnStart
                onCheckedChanged: Config.options.glassy.mikuWallpaperOnStart = checked
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Resolution: auto or e.g. 1920x1080")
                text: Config.options.glassy.mikuResolution
                wrapMode: TextEdit.NoWrap
                onTextChanged: Config.options.glassy.mikuResolution = text.trim().length > 0 ? text.trim() : "auto"
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "shuffle"
                mainText: Translation.tr("New Miku wallpaper now")
                onClicked: Quickshell.execDetached([page.glassyBin, "--miku-wall"])
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
        icon: "keyboard"
        title: Translation.tr("Look: Linux, Windows or Mac")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("Decides the whole desktop: panel, shortcuts and key symbols. Windows: Windows taskbar and start menu. Linux: the glassy bar (end-4). Mac: Mac dock (coming soon). Linux: tap Super for the start menu. Windows: Ctrl+Esc for the start menu, Ctrl+Super for the overview, Super alone does nothing. Mac: Super is Cmd, Cmd+Space for search, Ctrl+Up for the overview, Cmd+Shift+3 / 4 for screenshots.")
        }

        ConfigSelectionArray {
            currentValue: Config.options.glassy.platform
            onSelected: newValue => page.setPlatform(newValue)
            options: [
                { value: "linux", displayName: "Linux", icon: "terminal" },
                { value: "windows", displayName: "Windows", icon: "window" },
                { value: "mac", displayName: "Mac", icon: "laptop_mac" }
            ]
        }
    }

    ContentSection {
        icon: "speed"
        title: Translation.tr("Performance")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("Worth it with several high refresh rate monitors. The rotating border makes Hyprland redraw every frame.")
        }

        ConfigSwitch {
            buttonIcon: "animation"
            text: Translation.tr("Rotating border gradient")
            checked: Config.options.glassy.borderAnimation
            onCheckedChanged: {
                if (Config.options.glassy.borderAnimation === checked) return;
                Config.options.glassy.borderAnimation = checked;
                syncTimer.restart();
            }
        }

        ConfigSwitch {
            buttonIcon: "bolt"
            text: Translation.tr("Performance mode (less blur, no shadows, faster animations)")
            checked: Config.options.glassy.performanceMode
            onCheckedChanged: {
                if (Config.options.glassy.performanceMode === checked) return;
                Config.options.glassy.performanceMode = checked;
                syncTimer.restart();
            }
        }

        ConfigSwitch {
            buttonIcon: "live_tv"
            text: Translation.tr("Live previews in the overview (SUPER+Tab)")
            checked: Config.options.overview.livePreviews
            onCheckedChanged: Config.options.overview.livePreviews = checked
            StyledToolTip {
                text: Translation.tr("Off = still image, live only for the window under the mouse (saves a lot of GPU)")
            }
        }

        ConfigSpinBox {
            icon: "notifications"
            text: Translation.tr("Stored notifications (max.)")
            value: Config.options.notifications.maxStored
            from: 10
            to: 500
            stepSize: 10
            onValueChanged: Config.options.notifications.maxStored = value
        }
    }

    ContentSection {
        icon: "neurology"
        title: Translation.tr("AI (SUPER+K): LM Studio and LU")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("In LM Studio, start the server under Developer (port 1234) and turn on \"Just-in-Time Model Loading\". Your models then show up in the AI sidebar, at the top via the model icon or /model. \"LU (Uncensored)\" uses the same model with the system prompt from your LU file. After changes here: restart the shell.")
        }

        ConfigSwitch {
            buttonIcon: "dns"
            text: Translation.tr("Show models from LM Studio")
            checked: Config.options.ai.lmstudioModels
            onCheckedChanged: Config.options.ai.lmstudioModels = checked
        }

        ConfigSwitch {
            buttonIcon: "lock_open"
            text: Translation.tr("Show LU (Locally Uncensored)")
            checked: Config.options.ai.luEnable
            onCheckedChanged: Config.options.ai.luEnable = checked
        }

        ContentSubsection {
            title: Translation.tr("LU: file with the system prompt")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: "~/uncensored/system_prompt.txt"
                text: Config.options.ai.luPromptFile
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.options.ai.luPromptFile = text
            }
        }

        ContentSubsection {
            title: Translation.tr("LU: model (empty = first model in LM Studio)")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("e.g. qwen3-coder-30b-a3b-instruct-abliterated")
                text: Config.options.ai.luModel
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.options.ai.luModel = text
            }
        }

        ContentSubsection {
            title: Translation.tr("LM Studio address")
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
                mainText: Translation.tr("Check for updates")
                onClicked: Quickshell.execDetached([page.glassyBin, "--check", "--notify", "--force"])
            }
            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "new_releases"
                mainText: Translation.tr("What's new")
                onClicked: page.inTerminal(`${page.glassyBin} --whatsnew`)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "medical_services"
                mainText: Translation.tr("Doctor")
                onClicked: page.inTerminal(`${page.glassyBin} --doctor`)
            }
            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "restart_alt"
                mainText: Translation.tr("Restart the shell")
                onClicked: Quickshell.execDetached([page.glassyBin, "--reload"])
            }
        }
    }
}
