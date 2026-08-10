import Quickshell
import Quickshell.Io
import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import "root:/services" as Services
import "root:/modules/settings/components"

Item {
    anchors.fill: parent

    Flickable {
        anchors.fill: parent
        anchors.margins: 28
        contentHeight: tab.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: tab
            width: parent.width
            spacing: 18

            // kitty appends "-<pid>" to the listen_on socket, so we have to walk
            // whichever ones exist instead of assuming the exact path.
            readonly property string kittySockets: "/tmp/kitty-ashen.sock-*"

    property var schemes: {
        "classic": { abyss: "#080809", void_: "#0f0f11", crypt: "#16161a", surface: "#1c1c21", raised: "#242428", elevated: "#2e2e34", snow: "#e8e8ec", mist: "#9090a0", ash: "#4a4a54", ghost: "#6e6e7a", shade: "#4e4e5a", error_: "#c87a7a", neutral: "#8a8a96", papirusColor: "grey" },
        // Strictly greyscale -- no hue anywhere, error_ included (it stays
        // readable through brightness, not colour).
        "monochrome": { abyss: "#050505", void_: "#0d0d0d", crypt: "#131313", surface: "#1a1a1a", raised: "#242424", elevated: "#2e2e2e", snow: "#f2f2f2", mist: "#9e9e9e", ash: "#4d4d4d", ghost: "#d4d4d4", shade: "#8c8c8c", error_: "#b3b3b3", neutral: "#c4c4c4", papirusColor: "grey" },
        "cyberpunk": { abyss: "#0d0221", void_: "#150829", crypt: "#1a0b2e", surface: "#241b3d", raised: "#2d2347", elevated: "#3a2d5c", snow: "#f0f0ff", mist: "#b8a9d9", ash: "#5e4b8b", ghost: "#ff2e97", shade: "#cc1f7a", error_: "#ff3860", neutral: "#00fff2", papirusColor: "magenta" },
        "edgerunners": { abyss: "#05070a", void_: "#080c12", crypt: "#0c1119", surface: "#111827", raised: "#172032", elevated: "#1e2a3f", snow: "#eaf6ff", mist: "#5ef2a4", ash: "#3d5166", ghost: "#fcee0a", shade: "#c9be00", error_: "#ff003c", neutral: "#00e5ff", papirusColor: "yellow" },
        "tokyonight": { abyss: "#16161e", void_: "#1a1b26", crypt: "#1f2335", surface: "#24283b", raised: "#292e42", elevated: "#364a82", snow: "#c0caf5", mist: "#a9b1d6", ash: "#565f89", ghost: "#7aa2f7", shade: "#3d59a1", error_: "#f7768e", neutral: "#bb9af7", papirusColor: "blue" },
        "dracula": { abyss: "#21222c", void_: "#282a36", crypt: "#2d2f3f", surface: "#343746", raised: "#44475a", elevated: "#4d5066", snow: "#f8f8f2", mist: "#9ba0c4", ash: "#6272a4", ghost: "#bd93f9", shade: "#9580c9", error_: "#ff5555", neutral: "#ff79c6", papirusColor: "violet" },
        "nord": { abyss: "#2e3440", void_: "#3b4252", crypt: "#434c5e", surface: "#434c5e", raised: "#4c566a", elevated: "#4c566a", snow: "#eceff4", mist: "#d8dee9", ash: "#4c566a", ghost: "#88c0d0", shade: "#5e81ac", error_: "#bf616a", neutral: "#b48ead", papirusColor: "cyan" },
    }


    // The same seven, in light. Not an inversion: a palette that is merely
    // flipped comes out muddy, and an accent that reads on black is usually
    // too pale to read on white. The surface ladder still runs base -> raised,
    // it just runs upward in brightness instead of downward.
    property var lightSchemes: {
        "classic": { abyss: "#f4f4f6", void_: "#eeeef1", crypt: "#e7e7ec", surface: "#e0e0e6", raised: "#d6d6de", elevated: "#c9c9d3", snow: "#15151a", mist: "#45454f", ash: "#6e6e7a", ghost: "#4a4a58", shade: "#6a6a78", error_: "#b04a4a", neutral: "#6a6a78", papirusColor: "grey" },
        "monochrome": { abyss: "#fafafa", void_: "#f2f2f2", crypt: "#ebebeb", surface: "#e3e3e3", raised: "#d6d6d6", elevated: "#c7c7c7", snow: "#0b0b0b", mist: "#3d3d3d", ash: "#6b6b6b", ghost: "#242424", shade: "#565656", error_: "#5c5c5c", neutral: "#3d3d3d", papirusColor: "grey" },
        "cyberpunk": { abyss: "#f7f2ff", void_: "#f1e9fb", crypt: "#e9dff7", surface: "#e0d4f2", raised: "#d3c3ea", elevated: "#c2ade0", snow: "#1b0a2e", mist: "#4a2f70", ash: "#7a63a0", ghost: "#c1005f", shade: "#a8005699", error_: "#d10030", neutral: "#00877f", papirusColor: "magenta" },
        "edgerunners": { abyss: "#f6f9fc", void_: "#eef3f9", crypt: "#e4ebf4", surface: "#d9e3ef", raised: "#c9d6e6", elevated: "#b5c6db", snow: "#06121f", mist: "#0f5c3a", ash: "#5b6f85", ghost: "#6f5d00", shade: "#8f7a00", error_: "#c40030", neutral: "#0077a8", papirusColor: "yellow" },
        "tokyonight": { abyss: "#e9e9ed", void_: "#e1e2e7", crypt: "#d8dae2", surface: "#cfd2dc", raised: "#c3c7d4", elevated: "#b4bac9", snow: "#1f2335", mist: "#41508a", ash: "#5b6693", ghost: "#2557c9", shade: "#3f6bd6", error_: "#c64343", neutral: "#7847bd", papirusColor: "blue" },
        "dracula": { abyss: "#fbfbf6", void_: "#f4f4ee", crypt: "#ecece4", surface: "#e3e3da", raised: "#d7d7cc", elevated: "#c7c7ba", snow: "#1a1a1f", mist: "#4a4a63", ash: "#6b6b84", ghost: "#5236b8", shade: "#6e51cf", error_: "#cb3a3a", neutral: "#c2318f", papirusColor: "violet" },
        "nord": { abyss: "#eceff4", void_: "#e5e9f0", crypt: "#dde3ec", surface: "#d8dee9", raised: "#ccd4e0", elevated: "#bcc6d6", snow: "#2e3440", mist: "#3f4a5c", ash: "#5d6a7d", ghost: "#4a6d97", shade: "#5e81ac", error_: "#a8434c", neutral: "#9d6d92", papirusColor: "cyan" },
    }

    // The palette a scheme id resolves to right now.
    function paletteFor(id) {
        const set = Services.Prefs.themeMode === "light" ? tab.lightSchemes : tab.schemes
        return set[id] || tab.schemes[id]
    }

    function applyScheme(schemeId) {
        let c = tab.paletteFor(schemeId)
        if (!c) return
        let json = JSON.stringify({
            abyss: c.abyss, void_: c.void_, crypt: c.crypt, surface: c.surface,
            raised: c.raised, elevated: c.elevated, snow: c.snow, mist: c.mist,
            ash: c.ash, ghost: c.ghost, shade: c.shade, error_: c.error_, neutral: c.neutral
        })
        let borderHex = c.ghost.replace("#", "") + "ff"
        // Payload as argv ($1), never inlined into the script: Qt.btoa is
        // deprecated and base64 was only ever a way past the shell's parser.
        Quickshell.execDetached(["sh", "-c",
            "printf %s \"$1\" > \"$HOME/.cache/ashen_scheme.json\" && " +
            "echo '" + schemeId + "' > \"$HOME/.cache/ashen_scheme_mode.txt\" && " +
            "hyprctl eval \"hl.config({ general = { col = { active_border = { colors = {'rgba(" + borderHex + ")'} } } } })\" && " +
            "sed -i 's/active_border = { colors = {\"rgba([^)]*)\"} }/active_border = { colors = {\"rgba(" + borderHex + ")\"} }/' \"$HOME/.config/hypr/conf/general.lua\"",
            "sh", json
        ])
        tab.applyGtkTheme(c)
        tab.applyKittyTheme(c)
        tab.applyP10kTheme(c)
        tab.applyCavaTheme(c)
    }

    // The standalone terminal cava. It reads a THEME file, named once in a
    // static ~/.config/cava/config that nothing regenerates -- the split cava
    // is built for. Rewriting the config under a running cava is what used to
    // break the bars: it reloads on change and read a half-written file.
    function applyCavaTheme(c) {
        // Bottom to top: the accent's dark end climbing to the lightest tone.
        const dim = tab.darken(c.ghost, 0.45)
        const lines = [
            "# Generated by Ashen from the active scheme -- do NOT edit by hand",
            "[color]",
            "foreground = '" + c.ghost + "'",
            "gradient = 1",
            "gradient_color_1 = '" + dim + "'",
            "gradient_color_2 = '" + c.shade + "'",
            "gradient_color_3 = '" + c.ghost + "'",
            "gradient_color_4 = '" + c.neutral + "'",
            "gradient_color_5 = '" + c.snow + "'"
        ]
        const body = lines.map(l => '"' + l + '"').join(" ")
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$HOME/.config/cava/themes\" && " +
            "printf '%s\\n' " + body + " > \"$HOME/.config/cava/themes/ashen\""
        ])
    }

    // The accent taken most of the way down, on the string: Qt.darker hands
    // back a colour object and cava wants six hex digits.
    function darken(hex, k) {
        const n = parseInt(hex.replace("#", ""), 16)
        const two = v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")
        return "#" + two(((n >> 16) & 255) * k) + two(((n >> 8) & 255) * k) + two((n & 255) * k)
    }

    function applyKittyTheme(c) {
        let conf = '# Generated by Ashen -- do NOT edit by hand, regenerated when the scheme changes\n' +
            'foreground            ' + c.snow + '\n' +
            'background            ' + c.abyss + '\n' +
            'selection_foreground  ' + c.abyss + '\n' +
            'selection_background  ' + c.ghost + '\n' +
            'cursor                ' + c.ghost + '\n' +
            'color0  ' + c.abyss + '\n' +
            'color1  ' + c.error_ + '\n' +
            'color2  #5a7a6a\n' +
            'color3  #8a7a5a\n' +
            // ANSI blue is the scheme accent (same as in p10k), so whatever the
            // terminal paints as "blue" follows the theme: fastfetch,
            // prompt, etc.
            'color4  ' + c.ghost + '\n' +
            'color5  #a89bc8\n' +
            'color6  #5a7a8a\n' +
            'color7  ' + c.mist + '\n' +
            'color8  ' + c.ash + '\n' +
            'color9  ' + c.error_ + '\n' +
            'color10 #7a9e7e\n' +
            'color11 #c4a882\n' +
            'color12 ' + c.neutral + '\n' +
            'color13 #c8b8e8\n' +
            'color14 #7aaabb\n' +
            'color15 ' + c.snow + '\n'
        Quickshell.execDetached(["sh", "-c",
            "printf %s \"$1\" > \"$HOME/.config/kitty/ashen-colors.conf\" && " +
            "for s in " + tab.kittySockets + "; do kitten @ --to \"unix:$s\" set-colors --all " +
            "foreground=" + c.snow + " background=" + c.abyss + " " +
            "selection_foreground=" + c.abyss + " selection_background=" + c.ghost + " " +
            "cursor=" + c.ghost + " color0=" + c.abyss + " color1=" + c.error_ + " " +
            "color7=" + c.mist + " color8=" + c.ash + " color9=" + c.error_ + " color15=" + c.snow + " " +
            "2>/dev/null; done",
            "sh", conf
        ])
    }

    // The prompt follows the scheme through ONE file, sourced by .zshrc after
    // ~/.p10k.zsh so it wins. This used to sed `local grey=` and six friends
    // into that file -- lines no real p10k config has, so nothing ever changed.
    // Same path matugen's template writes; the last one wins.
    function applyP10kTheme(c) {
        const line = (name, hex) => "typeset -g POWERLEVEL9K_" + name + "='" + hex + "'"
        const lines = [
            "# Generated by Ashen from the active scheme -- do NOT edit by hand",
            line("DIR_FOREGROUND", c.ghost),
            line("DIR_ANCHOR_FOREGROUND", c.ghost),
            line("DIR_SHORTENED_FOREGROUND", c.ash),
            line("PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND", c.ghost),
            line("PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND", c.error_),
            line("VCS_CLEAN_FOREGROUND", c.mist),
            line("VCS_MODIFIED_FOREGROUND", c.neutral),
            line("VCS_UNTRACKED_FOREGROUND", c.shade),
            line("VCS_LOADING_FOREGROUND", c.ash),
            line("TIME_FOREGROUND", c.ash),
            line("RULER_FOREGROUND", c.ash),
            line("MULTILINE_FIRST_PROMPT_GAP_FOREGROUND", c.ash),
            line("OS_ICON_FOREGROUND", c.ghost),
            line("STATUS_OK_FOREGROUND", c.mist),
            line("STATUS_ERROR_FOREGROUND", c.error_),
            "typeset -g POWERLEVEL9K_BACKGROUND="
        ]
        const body = lines.map(l => '"' + l + '"').join(" ")
        Quickshell.execDetached(["sh", "-c",
            "printf '%s\\n' " + body + " > \"$HOME/.cache/ashen_p10k.zsh\" && " +
            "for s in " + tab.kittySockets + "; do kitten @ --to \"unix:$s\" send-text --match all $'source ~/.cache/ashen_p10k.zsh\\r' 2>/dev/null; done"
        ])
    }

    function applyGtkTheme(c) {
        let css = '/* ══════════════════════════════════════\n' +
            '   Ashen Ghost -- GTK3 overrides for Nemo\n' +
            '   ══════════════════════════════════════ */\n' +
            '@define-color theme_bg_color ' + c.void_ + ';\n' +
            '@define-color theme_fg_color ' + c.snow + ';\n' +
            '@define-color theme_base_color ' + c.void_ + ';\n' +
            '@define-color theme_text_color ' + c.snow + ';\n' +
            '@define-color theme_selected_bg_color ' + c.ghost + ';\n' +
            '@define-color theme_selected_fg_color ' + c.abyss + ';\n' +
            '@define-color insensitive_bg_color ' + c.surface + ';\n' +
            '@define-color insensitive_fg_color ' + c.ash + ';\n' +
            '@define-color borders ' + c.raised + ';\n' +
            '@define-color sidebar_bg_color ' + c.crypt + ';\n' +
            'toolbar, GtkToolbar {\n' +
            '    background-color: transparent;\n' +
            '    background-image: none;\n' +
            '    box-shadow: none;\n' +
            '    border: none;\n' +
            '}\n' +
            '.sidebar row:selected,\n' +
            '.sidebar row:selected:focus {\n' +
            '    background-color: ' + c.ghost + ';\n' +
            '    color: ' + c.abyss + ';\n' +
            '}\n' +
            'iconview.view:selected,\n' +
            'iconview.view:selected:focus,\n' +
            '.view:selected,\n' +
            '.view:selected:focus {\n' +
            '    background-color: alpha(' + c.ghost + ', 0.35);\n' +
            '    color: ' + c.snow + ';\n' +
            '    border-radius: 6px;\n' +
            '}\n' +
            'window, .background {\n' +
            '    background-color: ' + c.void_ + ';\n' +
            '    color: ' + c.snow + ';\n' +
            '}\n' +
            '.sidebar {\n' +
            '    background-color: ' + c.crypt + ';\n' +
            '}\n' +
            '.view,\n' +
            'iconview.view,\n' +
            'iconview {\n' +
            '    background-color: transparent;\n' +
            '    color: ' + c.snow + ';\n' +
            '}\n' +
            '.sidebar,\n' +
            '.sidebar .view,\n' +
            'placessidebar {\n' +
            '    background-color: ' + c.crypt + ';\n' +
            '    color: ' + c.snow + ';\n' +
            '}\n' +
            'button {\n' +
            '    border-radius: 8px;\n' +
            '}\n' +
            'dialog,\n' +
            'window.dialog,\n' +
            '.background.csd {\n' +
            '    border-radius: 12px;\n' +
            '}\n' +
            'button.suggested-action {\n' +
            '    background-color: ' + c.ghost + ';\n' +
            '    background-image: none;\n' +
            '    color: ' + c.abyss + ';\n' +
            '    border-color: ' + c.ghost + ';\n' +
            '}\n' +
            'button.suggested-action:hover {\n' +
            '    background-color: ' + c.neutral + ';\n' +
            '}\n' +
            'button.suggested-action:active {\n' +
            '    background-color: ' + c.shade + ';\n' +
            '}\n' +
            'list row:selected,\n' +
            'list row:selected:focus,\n' +
            'treeview:selected,\n' +
            'treeview:selected:focus {\n' +
            '    background-color: ' + c.ghost + ';\n' +
            '    color: ' + c.abyss + ';\n' +
            '}\n' +
            'check:checked,\n' +
            'radio:checked,\n' +
            'switch:checked {\n' +
            '    background-color: ' + c.ghost + ';\n' +
            '    border-color: ' + c.ghost + ';\n' +
            '}\n' +
            'selection,\n' +
            'entry selection,\n' +
            'textview text selection,\n' +
            'label selection {\n' +
            '    background-color: ' + c.ghost + ';\n' +
            '    color: ' + c.abyss + ';\n' +
            '}\n' +
            '.floating-bar {\n' +
            '    background-color: ' + c.surface + ';\n' +
            '    color: ' + c.snow + ';\n' +
            '    border: 1px solid alpha(' + c.ghost + ', 0.3);\n' +
            '    border-radius: 10px;\n' +
            '    padding: 4px 10px;\n' +
            '    box-shadow: none;\n' +
            '}\n' +
            '.floating-bar:backdrop {\n' +
            '    background-color: ' + c.surface + ';\n' +
            '}\n'
        // GTK4/libadwaita reads its own names, and every one it does not find
        // falls back to libadwaita's DARK default -- which is what left the
        // portal's file chooser half dark on a light scheme.
        const def = (name, hex) => '@define-color ' + name + ' ' + hex + ';\n'
        let css4 = '/* Ashen -- GTK4 / libadwaita overrides */\n' +
            def('accent_color', c.ghost) +
            def('accent_bg_color', c.ghost) +
            def('accent_fg_color', c.abyss) +
            def('destructive_color', c.error_) +
            def('destructive_bg_color', c.error_) +
            def('destructive_fg_color', c.abyss) +
            def('success_color', c.neutral) +
            def('warning_color', c.shade) +
            def('error_color', c.error_) +
            def('window_bg_color', c.void_) +
            def('window_fg_color', c.snow) +
            def('view_bg_color', c.void_) +
            def('view_fg_color', c.snow) +
            def('headerbar_bg_color', c.surface) +
            def('headerbar_fg_color', c.snow) +
            def('headerbar_backdrop_color', c.crypt) +
            def('card_bg_color', c.surface) +
            def('card_fg_color', c.snow) +
            def('card_shade_color', c.abyss) +
            def('dialog_bg_color', c.crypt) +
            def('dialog_fg_color', c.snow) +
            def('popover_bg_color', c.crypt) +
            def('popover_fg_color', c.snow) +
            def('sidebar_bg_color', c.crypt) +
            def('sidebar_fg_color', c.snow) +
            def('sidebar_backdrop_color', c.void_) +
            def('sidebar_shade_color', c.abyss) +
            def('secondary_sidebar_bg_color', c.surface) +
            def('secondary_sidebar_fg_color', c.snow) +
            def('thumbnail_bg_color', c.surface) +
            def('thumbnail_fg_color', c.snow) +
            def('shade_color', c.abyss) +
            'window, .background {\n' +
            '    background-color: ' + c.void_ + ';\n' +
            '    color: ' + c.snow + ';\n' +
            '}\n' +
            'headerbar {\n' +
            '    background-color: ' + c.surface + ';\n' +
            '    color: ' + c.snow + ';\n' +
            '}\n' +
            '.sidebar {\n' +
            '    background-color: ' + c.crypt + ';\n' +
            '    color: ' + c.snow + ';\n' +
            '}\n'

        // papirus-folders repoints the Papirus symlinks; with the accent
        // folders on, Ashen-Papirus is its own theme and this would only fight
        // it (and the folders already follow the accent).
        let papirusCmd = (c.papirusColor && !Services.Prefs.accentFolders)
            ? ("papirus-folders -C " + c.papirusColor + " 2>/dev/null; ") : ""
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$HOME/.config/gtk-3.0\" \"$HOME/.config/gtk-4.0\" && " +
            "printf %s \"$1\" > \"$HOME/.config/gtk-3.0/gtk.css\" && " +
            "printf %s \"$2\" > \"$HOME/.config/gtk-4.0/gtk.css\"; " +
            papirusCmd,
            "sh", css, css4
        ])
        // Theme name, colour-scheme and the portal restart, all in one place.
        Quickshell.execDetached([Services.Paths.script("ashen-gtk-mode.sh")])
    }
    Text {
        visible: false   // the drawer header carries the section name
        text: "Theme"
        color: Services.Colors.snow
        font.pixelSize: Services.Sizes.fsPanelTitle
        font.bold: true
        font.family: "JetBrainsMono NF"
    }

    PreviewCard {
        // Shows the wallpaper actually on screen; video/gif resolve to the
        // frame ashen-wallpaper.sh extracts, and the glyph covers "none yet".
        // Wide tile + fit: shows the whole wallpaper, whatever its ratio
        previewWidth: 142
        previewFill: Image.PreserveAspectFit
        source: Services.Wallpaper.stillUrl
        fallbackGlyph: "\ue1bc"
        title: "Wallpaper"
        // The picker only lists what is already in the folder -- it has no
        // import, so promising "add" here would be a lie.
        subtitle: Services.Wallpaper.path !== ""
            ? Services.Wallpaper.path.split("/").pop()
            : "Pick one from " + (Services.Prefs.wallpaperDir !== ""
                ? Services.Prefs.wallpaperDir : Services.Paths.wallpapers)
        action: "Open"
        onTriggered: {
            Services.AppState.settingsVisible = false
            Services.AppState.wallpaperVisible = true
        }
    }

    // Where the picker looks. Same shape as the recording folder row in Sound.
    DirField {
        glyph: "\ue2c7"
        title: "Wallpapers folder"
        value: Services.Prefs.wallpaperDir !== ""
            ? Services.Prefs.wallpaperDir : Services.Paths.wallpapers
        placeholder: Services.Paths.wallpapers
        Layout.topMargin: 4
        onCommitted: path => Services.Prefs.wallpaperDir = path
    }

    // A box, not a rule.
    Card {
        title: "Color Scheme"
        ColumnLayout {
            id: schemeSection
            Layout.fillWidth: true
            spacing: 8

            property string activeScheme: "classic"
            readonly property bool dynamicActive: activeScheme === "dynamic"

            Process {
                id: schemeModeReadProc
                command: ["sh", "-c", "cat \"$HOME/.cache/ashen_scheme_mode.txt\" 2>/dev/null"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        let s = text.trim()
                        if (s.length > 0) schemeSection.activeScheme = s
                    }
                }
            }

            property string dynamicType: "scheme-tonal-spot"
            // Single source for the pills below and the validity check on load
            readonly property var dynamicTypes: [
                { id: "scheme-neutral", label: "Neutral" },
                { id: "scheme-tonal-spot", label: "Tonal Spot" },
                { id: "scheme-vibrant", label: "Vibrant" },
                { id: "scheme-expressive", label: "Expressive" },
                { id: "scheme-fidelity", label: "Fidelity" },
                { id: "scheme-content", label: "Content" },
                { id: "scheme-rainbow", label: "Rainbow" },
                { id: "scheme-fruit-salad", label: "Fruit Salad" },
            ]

            Component.onCompleted: {
                schemeModeReadProc.running = true
                dynTypeProc.running = true
            }
            Process {
                id: dynTypeProc
                command: ["sh", "-c", "cat \"$HOME/.cache/ashen_dynamic_type.txt\" 2>/dev/null"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        let t = text.trim()
                        // A cache written before monochrome moved out of Dynamic
                        // would name a type that no longer exists: no pill would
                        // light up and matugen would still be handed it.
                        if (t.length > 0 && schemeSection.dynamicTypes.some(d => d.id === t)) {
                            schemeSection.dynamicType = t
                        } else if (t.length > 0) {
                            schemeSection.setDynamicType("scheme-tonal-spot")
                        }
                    }
                }
            }
            // Light/dark is not a scheme, it is a variant of the one you are on:
            // switching it re-applies the same selection through the other palette,
            // or asks matugen for the other mode when the colours come from the
            // wallpaper.
            function setMode(m) {
                if (Services.Prefs.themeMode === m) return
                Services.Prefs.themeMode = m
                // The scripts run outside the shell, so the mode has to be on disk
                // before they are asked to recolour.
                Quickshell.execDetached(["sh", "-c",
                    'printf %s "$1" > "$HOME/.cache/ashen_theme_mode.txt"', "sh", m])
                // Both roads wait for that write: the fixed schemes now also
                // run a script (ashen-gtk-mode.sh) that reads the file, and it
                // used to read the mode it was replacing.
                modeRecolor.restart()
            }
            // matugen reads the file, so give the write a moment to land.
            Timer {
                id: modeRecolor
                interval: 60
                onTriggered: {
                    if (schemeSection.dynamicActive) schemeSection.recolor()
                    else tab.applyScheme(schemeSection.activeScheme)
                }
            }

            function setDynamicType(t) {
                schemeSection.dynamicType = t
                Quickshell.execDetached(["sh", "-c", "echo '" + t + "' > \"$HOME/.cache/ashen_dynamic_type.txt\""])
            }

            // Re-run matugen from the current wallpaper (frame for gif/video) with
            // the saved style. No-ops unless in dynamic mode. Called when a style
            // pill or the Dynamic tile is clicked so the change lands immediately.
            function recolor() {
                Quickshell.execDetached([Services.Paths.script("ashen-recolor.sh")])
            }

            // Above the schemes, because it is not one of them: every scheme below
            // has a light and a dark face, and this picks which one you get.
            Segmented {
                Layout.fillWidth: true
                options: [
                    { id: "dark", icon: "\ue51c", label: "Dark" },
                    { id: "light", icon: "\ue518", label: "Light" },
                ]
                current: Services.Prefs.themeMode
                onPicked: id => schemeSection.setMode(id)
            }

            // The colours a scheme will actually paint the shell in, taken from
            // `tab.schemes` itself. The model used to carry its own hand-written
            // swatch list, which is one more thing to keep in step with the
            // palette and was already out of step with it.
            function swatchesOf(id) {
                const c = tab.paletteFor(id)
                if (!c) return []
                return [c.abyss, c.surface, c.ghost, c.neutral, c.snow]
            }

            // ── Dynamic, alone and across the full width ────────────────────
            // Not one more palette: it is the one with no fixed colours, so it gets a
            // bar rather than a cell. Its swatches are read live off Colors.
            Rectangle {
                id: dynRowCard
                readonly property bool active: schemeSection.dynamicActive
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: Services.Sizes.cardR
                color: active ? Services.Colors.fillSunken : Services.Colors.fillRest
                scale: Services.Sizes.hoverScaleFor(width, dynHover.containsMouse, dynHover.pressed)
                Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }
                border.color: active ? Services.Colors.ghost : "transparent"
                border.width: active ? 2 : 0
                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Text {
                        text: ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Services.Colors.ghost
                    }
                    ColumnLayout {
                        spacing: 1
                        Text { text: "Dynamic"; color: Services.Colors.snow; font.pixelSize: Services.Sizes.fsInput; font.bold: true; font.family: "JetBrainsMono NF" }
                        Text { text: "From wallpaper"; color: Services.Colors.mist; font.pixelSize: Services.Sizes.fsMeta; font.family: "JetBrainsMono NF" }
                    }
                    Item { Layout.fillWidth: true }

                    Row {
                        spacing: 6
                        Repeater {
                            model: [Services.Colors.abyss, Services.Colors.surface,
                                    Services.Colors.ghost, Services.Colors.neutral,
                                    Services.Colors.snow]
                            delegate: Rectangle {
                                required property color modelData
                                width: 18; height: 18
                                radius: Services.Sizes.innerR
                                color: modelData
                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1
                            }
                        }
                    }

                    // Holds its place whether or not it is showing, so the
                    // swatches do not shift sideways when the scheme changes.
                    Item {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        Rectangle {
                            anchors.fill: parent
                            visible: dynRowCard.active
                            radius: Services.Sizes.innerR
                            color: Services.Colors.ghost
                            gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 11
                                color: Services.Colors.accentText
                            }
                        }
                    }
                }

                MouseArea {
                    id: dynHover
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        schemeSection.activeScheme = "dynamic"
                        // Switch into dynamic mode, then recolour from the
                        // wallpaper's frame -- awww query fails on video
                        // (mpvpaper, not awww, is running).
                        Quickshell.execDetached(["sh", "-c",
                            "echo 'dynamic' > " + Quickshell.env("HOME") + "/.cache/ashen_scheme_mode.txt && " +
                            Services.Paths.script("ashen-recolor.sh")
                        ])
                    }
                }
            }

            // ── The fixed palettes ──────────────────────────────────────────
            // Name on the left, its colours on the right, one scheme per line.
            // Two columns, because a single column of full-width rows in a 1240 px
            // drawer is mostly empty space between the two things you read.
            Flow {
                id: schemeFlow
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8

                Repeater {
                    model: [
                        { id: "classic", label: "Classic" },
                        { id: "monochrome", label: "Monochrome" },
                        { id: "cyberpunk", label: "Cyberpunk" },
                        { id: "edgerunners", label: "Edgerunners" },
                        { id: "tokyonight", label: "Tokyo Night" },
                        { id: "dracula", label: "Dracula" },
                        { id: "nord", label: "Nord" },
                    ]
                    delegate: Rectangle {
                        id: schemeRow
                        required property var modelData
                        readonly property bool active: schemeSection.activeScheme === modelData.id
                        width: (schemeFlow.width - schemeFlow.spacing) / 2
                        height: 44
                        radius: Services.Sizes.pillR
                        color: active ? Services.Colors.fillSunken : Services.Colors.fillRest
                        scale: Services.Sizes.hoverScaleFor(width, schemeHover.containsMouse, schemeHover.pressed)
                        Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }
                        border.color: active ? Services.Colors.ghost : "transparent"
                        border.width: active ? 2 : 0
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Text {
                                text: schemeRow.modelData.label
                                color: Services.Colors.snow
                                font.pixelSize: Services.Sizes.fsBody
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Row {
                                spacing: 5
                                Repeater {
                                    model: schemeSection.swatchesOf(schemeRow.modelData.id)
                                    delegate: Rectangle {
                                        required property color modelData
                                        width: 16; height: 16
                                        radius: Services.Sizes.innerR
                                        color: modelData
                                        border.color: Qt.rgba(1, 1, 1, 0.15)
                                        border.width: 1
                                    }
                                }
                            }

                            Item {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                Rectangle {
                                    anchors.fill: parent
                                    visible: schemeRow.active
                                    radius: Services.Sizes.innerR
                                    color: Services.Colors.ghost
                                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 10
                                        color: Services.Colors.accentText
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: schemeHover
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                schemeSection.activeScheme = schemeRow.modelData.id
                                tab.applyScheme(schemeRow.modelData.id)
                            }
                        }
                    }
                }
            }

            // ── Dynamic Style: only has any effect while Dynamic is the active
            //    scheme, so it is visibly subordinate to it and dims when it is not.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                radius: Services.Sizes.cardR
                color: Services.Colors.fillInset
                implicitHeight: dynCol.implicitHeight + 24
                opacity: schemeSection.dynamicActive ? 1.0 : 0.45
                Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard } }

                ColumnLayout {
                    id: dynCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 6

                    RowLayout {
                        spacing: 8
                        Text { text: "\ue65f"; font.family: "Material Symbols Rounded"; font.pixelSize: 15; color: Services.Colors.ghost }
                        Text { text: "Dynamic Style"; color: Services.Colors.snow; font.pixelSize: Services.Sizes.fsBody; font.bold: true; font.family: "JetBrainsMono NF" }
                    }
                    Text {
                        // Clicking Dynamic re-runs matugen against the *current*
                        // wallpaper -- it does not open the picker.
                        text: schemeSection.dynamicActive
                            ? "How aggressively matugen pulls color from the wallpaper"
                            : "Select the Dynamic scheme above to use these"
                        color: Services.Colors.ash
                        font.pixelSize: Services.Sizes.fsMeta
                        font.family: "JetBrainsMono NF"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 8
                        Repeater {
                            model: schemeSection.dynamicTypes
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: schemeSection.dynamicType === modelData.id
                                width: dynRow.implicitWidth + 20
                                height: 32
                                radius: Services.Sizes.innerR
                                color: active ? Services.Colors.ghost : Services.Colors.fillLine
                                gradient: Services.Prefs.useGradients && (active) ? Services.Colors.accentGradient : null
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                RowLayout {
                                    id: dynRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        visible: parent.parent.active
                                        text: ""
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 11
                                        color: Services.Colors.accentText
                                    }
                                    Text {
                                        text: modelData.label
                                        font.pixelSize: Services.Sizes.fsBody
                                        font.family: "JetBrainsMono NF"
                                        color: parent.parent.active ? Services.Colors.accentText : Services.Colors.snow
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { schemeSection.setDynamicType(modelData.id); schemeSection.recolor() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

        // ── Gradient Accents ────────────────────────────────────────────
        // How an active fill is painted, so it lives with the palette that decides
        // its colour.
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 6
            radius: Services.Sizes.cardR
            color: Services.Colors.fillInset
            implicitHeight: gradCol.implicitHeight + 24

            ColumnLayout {
                id: gradCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: ""; font.family: "Material Symbols Rounded"; font.pixelSize: 15; color: Services.Colors.ghost }
                    Text { text: "Gradient Accents"; color: Services.Colors.snow; font.pixelSize: Services.Sizes.fsBody; font.bold: true; font.family: "JetBrainsMono NF" }
                    Item { Layout.fillWidth: true }
                    Toggle {
                        checked: Services.Prefs.useGradients
                        onToggled: Services.Prefs.useGradients = !Services.Prefs.useGradients
                    }
                }
                Text {
                    text: "One accent tone lit from the left: lighter at one end, darker at the other, on active buttons and pills"
                    color: Services.Colors.ash
                    font.pixelSize: Services.Sizes.fsMeta
                    font.family: "JetBrainsMono NF"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // The switch showing what it does, rather than a sentence
                // describing it: the same fill every active pill will wear.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.preferredHeight: 22
                    radius: Services.Sizes.innerR
                    color: Services.Colors.ghost
                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                }
            }
        }


    // The one piece of the palette that lives outside the shell: the file
    // manager's folders. papirus-folders can only offer the colours Papirus
    // ships, so the script builds a theme that inherits Papirus and repaints
    // just the folders with the accent of the moment.
    Card {
        title: "Folders"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "\ue2c7"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 15
                color: Services.Colors.ghost
            }
            Text {
                text: "Accent folders"
                color: Services.Colors.snow
                font.pixelSize: Services.Sizes.fsBody
                font.bold: true
                font.family: "JetBrainsMono NF"
            }
            Item { Layout.fillWidth: true }
            Toggle {
                checked: Services.Prefs.accentFolders
                onToggled: {
                    Services.Prefs.accentFolders = !Services.Prefs.accentFolders
                    Quickshell.execDetached([Services.Paths.script("ashen-folders.sh"),
                                             Services.Prefs.accentFolders ? "--apply" : "--off"])
                }
            }
        }
        Text {
            text: "Papirus folders repainted in the accent, and repainted again whenever the wallpaper moves it"
            color: Services.Colors.ash
            font.pixelSize: Services.Sizes.fsMeta
            font.family: "JetBrainsMono NF"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    Card {
        title: "Panels"

        SectionLabel { text: "How they open" }

        Segmented {
            options: [
                { id: "morph", label: "Transform" },
                { id: "plain", label: "Window" },
            ]
            current: Services.Prefs.panelStyle
            onPicked: id => Services.Prefs.panelStyle = id
        }

        Text {
            text: Services.Prefs.panelStyle === "morph"
                ? "A panel comes out of the capsule you pressed and grows into place."
                : "A panel simply appears where it lives, at its full size."
            color: Services.Colors.ash
            font.pixelSize: Services.Sizes.fsMeta
            font.family: "JetBrainsMono NF"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    Item { Layout.preferredHeight: 8 }
        }
    }
}
