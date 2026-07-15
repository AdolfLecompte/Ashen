import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/services" as Services

Scope {
    id: root

    IpcHandler {
        target: "emojis"
        function toggle() {
            Services.AppState.toggleOverlay("emojisVisible")
            if (Services.AppState.emojisVisible) {
                searchField.text = ""
                searchField.forceActiveFocus()
            }
        }
    }

    PanelWindow {
        id: win
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // stays mapped through the close animation, so the exit plays in reverse
        readonly property bool shown: Services.AppState.emojisVisible
        visible: shown || closeDelay.running
        onShownChanged: if (!shown) closeDelay.restart()
        Timer { id: closeDelay; interval: 300 }

        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property string searchText: ""
        property string activeCategory: "All"
        property int selectedIndex: 0
        property bool copied: false

        property var allEmojis: [
                { char: "😀", cat: "Smileys" },
                { char: "😃", cat: "Smileys" },
                { char: "😄", cat: "Smileys" },
                { char: "😁", cat: "Smileys" },
                { char: "😆", cat: "Smileys" },
                { char: "😅", cat: "Smileys" },
                { char: "🤣", cat: "Smileys" },
                { char: "😂", cat: "Smileys" },
                { char: "🙂", cat: "Smileys" },
                { char: "🙃", cat: "Smileys" },
                { char: "😉", cat: "Smileys" },
                { char: "😊", cat: "Smileys" },
                { char: "😇", cat: "Smileys" },
                { char: "🥰", cat: "Smileys" },
                { char: "😍", cat: "Smileys" },
                { char: "🤩", cat: "Smileys" },
                { char: "😘", cat: "Smileys" },
                { char: "😗", cat: "Smileys" },
                { char: "😚", cat: "Smileys" },
                { char: "😙", cat: "Smileys" },
                { char: "😋", cat: "Smileys" },
                { char: "😛", cat: "Smileys" },
                { char: "😜", cat: "Smileys" },
                { char: "🤪", cat: "Smileys" },
                { char: "😝", cat: "Smileys" },
                { char: "🤑", cat: "Smileys" },
                { char: "🤗", cat: "Smileys" },
                { char: "🤭", cat: "Smileys" },
                { char: "🤫", cat: "Smileys" },
                { char: "🤔", cat: "Smileys" },
                { char: "😐", cat: "Smileys" },
                { char: "😑", cat: "Smileys" },
                { char: "😶", cat: "Smileys" },
                { char: "🙄", cat: "Smileys" },
                { char: "😏", cat: "Smileys" },
                { char: "😣", cat: "Smileys" },
                { char: "😥", cat: "Smileys" },
                { char: "😮", cat: "Smileys" },
                { char: "🤐", cat: "Smileys" },
                { char: "😯", cat: "Smileys" },
                { char: "😪", cat: "Smileys" },
                { char: "😫", cat: "Smileys" },
                { char: "🥱", cat: "Smileys" },
                { char: "😴", cat: "Smileys" },
                { char: "😌", cat: "Smileys" },
                { char: "😷", cat: "Smileys" },
                { char: "🤒", cat: "Smileys" },
                { char: "🤕", cat: "Smileys" },
                { char: "🤢", cat: "Smileys" },
                { char: "🤮", cat: "Smileys" },
                { char: "🤧", cat: "Smileys" },
                { char: "🥵", cat: "Smileys" },
                { char: "🥶", cat: "Smileys" },
                { char: "🥴", cat: "Smileys" },
                { char: "😵", cat: "Smileys" },
                { char: "🤯", cat: "Smileys" },
                { char: "🤠", cat: "Smileys" },
                { char: "🥳", cat: "Smileys" },
                { char: "🥸", cat: "Smileys" },
                { char: "😎", cat: "Smileys" },
                { char: "🤓", cat: "Smileys" },
                { char: "🧐", cat: "Smileys" },
                { char: "😕", cat: "Smileys" },
                { char: "🙁", cat: "Smileys" },
                { char: "😖", cat: "Smileys" },
                { char: "😞", cat: "Smileys" },
                { char: "😟", cat: "Smileys" },
                { char: "😤", cat: "Smileys" },
                { char: "😢", cat: "Smileys" },
                { char: "😭", cat: "Smileys" },
                { char: "😦", cat: "Smileys" },
                { char: "😧", cat: "Smileys" },
                { char: "😨", cat: "Smileys" },
                { char: "😩", cat: "Smileys" },
                { char: "🤬", cat: "Smileys" },
                { char: "😠", cat: "Smileys" },
                { char: "😡", cat: "Smileys" },
                { char: "🥺", cat: "Smileys" },
                { char: "👋", cat: "People" },
                { char: "🤚", cat: "People" },
                { char: "🖐️", cat: "People" },
                { char: "✋", cat: "People" },
                { char: "🖖", cat: "People" },
                { char: "👌", cat: "People" },
                { char: "🤌", cat: "People" },
                { char: "🤏", cat: "People" },
                { char: "✌️", cat: "People" },
                { char: "🤞", cat: "People" },
                { char: "🤟", cat: "People" },
                { char: "🤘", cat: "People" },
                { char: "🤙", cat: "People" },
                { char: "👈", cat: "People" },
                { char: "👉", cat: "People" },
                { char: "👆", cat: "People" },
                { char: "🖕", cat: "People" },
                { char: "👇", cat: "People" },
                { char: "☝️", cat: "People" },
                { char: "👍", cat: "People" },
                { char: "👎", cat: "People" },
                { char: "✊", cat: "People" },
                { char: "👊", cat: "People" },
                { char: "🤛", cat: "People" },
                { char: "🤜", cat: "People" },
                { char: "👏", cat: "People" },
                { char: "🙌", cat: "People" },
                { char: "👐", cat: "People" },
                { char: "🤲", cat: "People" },
                { char: "🙏", cat: "People" },
                { char: "✍️", cat: "People" },
                { char: "💪", cat: "People" },
                { char: "🦾", cat: "People" },
                { char: "🦿", cat: "People" },
                { char: "🦵", cat: "People" },
                { char: "🦶", cat: "People" },
                { char: "👂", cat: "People" },
                { char: "🦻", cat: "People" },
                { char: "👃", cat: "People" },
                { char: "🧠", cat: "People" },
                { char: "🦷", cat: "People" },
                { char: "🦴", cat: "People" },
                { char: "👀", cat: "People" },
                { char: "👁️", cat: "People" },
                { char: "👅", cat: "People" },
                { char: "👄", cat: "People" },
                { char: "👶", cat: "People" },
                { char: "🧒", cat: "People" },
                { char: "👦", cat: "People" },
                { char: "👧", cat: "People" },
                { char: "🧑", cat: "People" },
                { char: "👱", cat: "People" },
                { char: "👨", cat: "People" },
                { char: "👩", cat: "People" },
                { char: "🧓", cat: "People" },
                { char: "👴", cat: "People" },
                { char: "👵", cat: "People" },
                { char: "🐶", cat: "Animals" },
                { char: "🐱", cat: "Animals" },
                { char: "🐭", cat: "Animals" },
                { char: "🐹", cat: "Animals" },
                { char: "🐰", cat: "Animals" },
                { char: "🦊", cat: "Animals" },
                { char: "🐻", cat: "Animals" },
                { char: "🐼", cat: "Animals" },
                { char: "🐨", cat: "Animals" },
                { char: "🐯", cat: "Animals" },
                { char: "🦁", cat: "Animals" },
                { char: "🐮", cat: "Animals" },
                { char: "🐷", cat: "Animals" },
                { char: "🐸", cat: "Animals" },
                { char: "🐵", cat: "Animals" },
                { char: "🙈", cat: "Animals" },
                { char: "🙉", cat: "Animals" },
                { char: "🙊", cat: "Animals" },
                { char: "🐒", cat: "Animals" },
                { char: "🐔", cat: "Animals" },
                { char: "🐧", cat: "Animals" },
                { char: "🐦", cat: "Animals" },
                { char: "🐤", cat: "Animals" },
                { char: "🦆", cat: "Animals" },
                { char: "🦅", cat: "Animals" },
                { char: "🦉", cat: "Animals" },
                { char: "🦇", cat: "Animals" },
                { char: "🐺", cat: "Animals" },
                { char: "🐗", cat: "Animals" },
                { char: "🐴", cat: "Animals" },
                { char: "🦄", cat: "Animals" },
                { char: "🐝", cat: "Animals" },
                { char: "🐛", cat: "Animals" },
                { char: "🦋", cat: "Animals" },
                { char: "🐌", cat: "Animals" },
                { char: "🐞", cat: "Animals" },
                { char: "🐜", cat: "Animals" },
                { char: "🕷️", cat: "Animals" },
                { char: "🦂", cat: "Animals" },
                { char: "🐢", cat: "Animals" },
                { char: "🐍", cat: "Animals" },
                { char: "🦎", cat: "Animals" },
                { char: "🐙", cat: "Animals" },
                { char: "🦑", cat: "Animals" },
                { char: "🦀", cat: "Animals" },
                { char: "🐡", cat: "Animals" },
                { char: "🐠", cat: "Animals" },
                { char: "🐟", cat: "Animals" },
                { char: "🐬", cat: "Animals" },
                { char: "🐳", cat: "Animals" },
                { char: "🐋", cat: "Animals" },
                { char: "🦈", cat: "Animals" },
                { char: "🐊", cat: "Animals" },
                { char: "🐅", cat: "Animals" },
                { char: "🦓", cat: "Animals" },
                { char: "🦍", cat: "Animals" },
                { char: "🐘", cat: "Animals" },
                { char: "🦛", cat: "Animals" },
                { char: "🐪", cat: "Animals" },
                { char: "🐫", cat: "Animals" },
                { char: "🦒", cat: "Animals" },
                { char: "🦘", cat: "Animals" },
                { char: "🐕", cat: "Animals" },
                { char: "🐈", cat: "Animals" },
                { char: "🦃", cat: "Animals" },
                { char: "🦚", cat: "Animals" },
                { char: "🦜", cat: "Animals" },
                { char: "🦢", cat: "Animals" },
                { char: "🐇", cat: "Animals" },
                { char: "🦔", cat: "Animals" },
                { char: "🍏", cat: "Food" },
                { char: "🍎", cat: "Food" },
                { char: "🍐", cat: "Food" },
                { char: "🍊", cat: "Food" },
                { char: "🍋", cat: "Food" },
                { char: "🍌", cat: "Food" },
                { char: "🍉", cat: "Food" },
                { char: "🍇", cat: "Food" },
                { char: "🍓", cat: "Food" },
                { char: "🫐", cat: "Food" },
                { char: "🍒", cat: "Food" },
                { char: "🍑", cat: "Food" },
                { char: "🥭", cat: "Food" },
                { char: "🍍", cat: "Food" },
                { char: "🥥", cat: "Food" },
                { char: "🥝", cat: "Food" },
                { char: "🍅", cat: "Food" },
                { char: "🍆", cat: "Food" },
                { char: "🥑", cat: "Food" },
                { char: "🥦", cat: "Food" },
                { char: "🥒", cat: "Food" },
                { char: "🌶️", cat: "Food" },
                { char: "🌽", cat: "Food" },
                { char: "🥕", cat: "Food" },
                { char: "🧄", cat: "Food" },
                { char: "🧅", cat: "Food" },
                { char: "🥔", cat: "Food" },
                { char: "🍠", cat: "Food" },
                { char: "🥐", cat: "Food" },
                { char: "🍞", cat: "Food" },
                { char: "🥖", cat: "Food" },
                { char: "🧀", cat: "Food" },
                { char: "🥚", cat: "Food" },
                { char: "🍳", cat: "Food" },
                { char: "🥞", cat: "Food" },
                { char: "🧇", cat: "Food" },
                { char: "🥓", cat: "Food" },
                { char: "🥩", cat: "Food" },
                { char: "🍗", cat: "Food" },
                { char: "🍖", cat: "Food" },
                { char: "🌭", cat: "Food" },
                { char: "🍔", cat: "Food" },
                { char: "🍟", cat: "Food" },
                { char: "🍕", cat: "Food" },
                { char: "🥪", cat: "Food" },
                { char: "🌮", cat: "Food" },
                { char: "🌯", cat: "Food" },
                { char: "🥗", cat: "Food" },
                { char: "🍝", cat: "Food" },
                { char: "🍜", cat: "Food" },
                { char: "🍲", cat: "Food" },
                { char: "🍣", cat: "Food" },
                { char: "🍱", cat: "Food" },
                { char: "🍤", cat: "Food" },
                { char: "🍙", cat: "Food" },
                { char: "🍚", cat: "Food" },
                { char: "🍘", cat: "Food" },
                { char: "🍥", cat: "Food" },
                { char: "🍧", cat: "Food" },
                { char: "🍨", cat: "Food" },
                { char: "🍦", cat: "Food" },
                { char: "🥧", cat: "Food" },
                { char: "🧁", cat: "Food" },
                { char: "🍰", cat: "Food" },
                { char: "🎂", cat: "Food" },
                { char: "🍮", cat: "Food" },
                { char: "🍭", cat: "Food" },
                { char: "🍬", cat: "Food" },
                { char: "🍫", cat: "Food" },
                { char: "🍿", cat: "Food" },
                { char: "🍩", cat: "Food" },
                { char: "🍪", cat: "Food" },
                { char: "☕", cat: "Food" },
                { char: "🍵", cat: "Food" },
                { char: "🧃", cat: "Food" },
                { char: "🥤", cat: "Food" },
                { char: "🍺", cat: "Food" },
                { char: "🍷", cat: "Food" },
                { char: "🥂", cat: "Food" },
                { char: "🍹", cat: "Food" },
                { char: "🚗", cat: "Travel" },
                { char: "🚕", cat: "Travel" },
                { char: "🚙", cat: "Travel" },
                { char: "🚌", cat: "Travel" },
                { char: "🏎️", cat: "Travel" },
                { char: "🚓", cat: "Travel" },
                { char: "🚑", cat: "Travel" },
                { char: "🚒", cat: "Travel" },
                { char: "🚐", cat: "Travel" },
                { char: "🚚", cat: "Travel" },
                { char: "🚛", cat: "Travel" },
                { char: "🚜", cat: "Travel" },
                { char: "🛵", cat: "Travel" },
                { char: "🏍️", cat: "Travel" },
                { char: "🚨", cat: "Travel" },
                { char: "🚔", cat: "Travel" },
                { char: "🛞", cat: "Travel" },
                { char: "🚁", cat: "Travel" },
                { char: "✈️", cat: "Travel" },
                { char: "🛫", cat: "Travel" },
                { char: "🛬", cat: "Travel" },
                { char: "🚀", cat: "Travel" },
                { char: "🛸", cat: "Travel" },
                { char: "🚢", cat: "Travel" },
                { char: "⚓", cat: "Travel" },
                { char: "🚦", cat: "Travel" },
                { char: "🚧", cat: "Travel" },
                { char: "🗺️", cat: "Travel" },
                { char: "🗽", cat: "Travel" },
                { char: "🗼", cat: "Travel" },
                { char: "🏰", cat: "Travel" },
                { char: "🎡", cat: "Travel" },
                { char: "🎢", cat: "Travel" },
                { char: "⛲", cat: "Travel" },
                { char: "🏖️", cat: "Travel" },
                { char: "🏝️", cat: "Travel" },
                { char: "🏜️", cat: "Travel" },
                { char: "🌋", cat: "Travel" },
                { char: "⛰️", cat: "Travel" },
                { char: "🏔️", cat: "Travel" },
                { char: "🏕️", cat: "Travel" },
                { char: "⛺", cat: "Travel" },
                { char: "🏠", cat: "Travel" },
                { char: "🏢", cat: "Travel" },
                { char: "🏬", cat: "Travel" },
                { char: "🏥", cat: "Travel" },
                { char: "🏦", cat: "Travel" },
                { char: "🏨", cat: "Travel" },
                { char: "🏫", cat: "Travel" },
                { char: "⛪", cat: "Travel" },
                { char: "🕌", cat: "Travel" },
                { char: "🕍", cat: "Travel" },
                { char: "🛕", cat: "Travel" },
                { char: "⛩️", cat: "Travel" },
                { char: "🌉", cat: "Travel" },
                { char: "🌇", cat: "Travel" },
                { char: "🌆", cat: "Travel" },
                { char: "🌃", cat: "Travel" },
                { char: "🌌", cat: "Travel" },
                { char: "⚽", cat: "Activities" },
                { char: "🏀", cat: "Activities" },
                { char: "🏈", cat: "Activities" },
                { char: "⚾", cat: "Activities" },
                { char: "🎾", cat: "Activities" },
                { char: "🏐", cat: "Activities" },
                { char: "🏉", cat: "Activities" },
                { char: "🎱", cat: "Activities" },
                { char: "🏓", cat: "Activities" },
                { char: "🏸", cat: "Activities" },
                { char: "🏒", cat: "Activities" },
                { char: "🏑", cat: "Activities" },
                { char: "🥍", cat: "Activities" },
                { char: "⛳", cat: "Activities" },
                { char: "🏹", cat: "Activities" },
                { char: "🎣", cat: "Activities" },
                { char: "🥊", cat: "Activities" },
                { char: "🥋", cat: "Activities" },
                { char: "🎽", cat: "Activities" },
                { char: "🛹", cat: "Activities" },
                { char: "🛷", cat: "Activities" },
                { char: "⛸️", cat: "Activities" },
                { char: "🎿", cat: "Activities" },
                { char: "🏋️", cat: "Activities" },
                { char: "🤼", cat: "Activities" },
                { char: "🤸", cat: "Activities" },
                { char: "⛹️", cat: "Activities" },
                { char: "🤺", cat: "Activities" },
                { char: "🏌️", cat: "Activities" },
                { char: "🏇", cat: "Activities" },
                { char: "🧘", cat: "Activities" },
                { char: "🏄", cat: "Activities" },
                { char: "🏊", cat: "Activities" },
                { char: "🚣", cat: "Activities" },
                { char: "🚵", cat: "Activities" },
                { char: "🚴", cat: "Activities" },
                { char: "🏆", cat: "Activities" },
                { char: "🥇", cat: "Activities" },
                { char: "🥈", cat: "Activities" },
                { char: "🥉", cat: "Activities" },
                { char: "🏅", cat: "Activities" },
                { char: "🎖️", cat: "Activities" },
                { char: "🎫", cat: "Activities" },
                { char: "🎪", cat: "Activities" },
                { char: "🤹", cat: "Activities" },
                { char: "🎭", cat: "Activities" },
                { char: "🎨", cat: "Activities" },
                { char: "🎬", cat: "Activities" },
                { char: "🎤", cat: "Activities" },
                { char: "🎧", cat: "Activities" },
                { char: "🎼", cat: "Activities" },
                { char: "🎹", cat: "Activities" },
                { char: "🥁", cat: "Activities" },
                { char: "🎷", cat: "Activities" },
                { char: "🎺", cat: "Activities" },
                { char: "🎸", cat: "Activities" },
                { char: "🎻", cat: "Activities" },
                { char: "🎲", cat: "Activities" },
                { char: "🎯", cat: "Activities" },
                { char: "🎳", cat: "Activities" },
                { char: "🎮", cat: "Activities" },
                { char: "🎰", cat: "Activities" },
                { char: "⌚", cat: "Objects" },
                { char: "📱", cat: "Objects" },
                { char: "💻", cat: "Objects" },
                { char: "⌨️", cat: "Objects" },
                { char: "🖥️", cat: "Objects" },
                { char: "🖨️", cat: "Objects" },
                { char: "🖱️", cat: "Objects" },
                { char: "🕹️", cat: "Objects" },
                { char: "💽", cat: "Objects" },
                { char: "💾", cat: "Objects" },
                { char: "💿", cat: "Objects" },
                { char: "📀", cat: "Objects" },
                { char: "📷", cat: "Objects" },
                { char: "📸", cat: "Objects" },
                { char: "📹", cat: "Objects" },
                { char: "🎥", cat: "Objects" },
                { char: "📽️", cat: "Objects" },
                { char: "📞", cat: "Objects" },
                { char: "☎️", cat: "Objects" },
                { char: "📟", cat: "Objects" },
                { char: "📠", cat: "Objects" },
                { char: "📺", cat: "Objects" },
                { char: "📻", cat: "Objects" },
                { char: "🎙️", cat: "Objects" },
                { char: "🕯️", cat: "Objects" },
                { char: "💡", cat: "Objects" },
                { char: "🔦", cat: "Objects" },
                { char: "🔋", cat: "Objects" },
                { char: "🔌", cat: "Objects" },
                { char: "💸", cat: "Objects" },
                { char: "💵", cat: "Objects" },
                { char: "💰", cat: "Objects" },
                { char: "💳", cat: "Objects" },
                { char: "💎", cat: "Objects" },
                { char: "⚖️", cat: "Objects" },
                { char: "🔧", cat: "Objects" },
                { char: "🔨", cat: "Objects" },
                { char: "⚒️", cat: "Objects" },
                { char: "🛠️", cat: "Objects" },
                { char: "⛏️", cat: "Objects" },
                { char: "🔩", cat: "Objects" },
                { char: "⚙️", cat: "Objects" },
                { char: "🔫", cat: "Objects" },
                { char: "🧨", cat: "Objects" },
                { char: "🔪", cat: "Objects" },
                { char: "🗡️", cat: "Objects" },
                { char: "⚔️", cat: "Objects" },
                { char: "🛡️", cat: "Objects" },
                { char: "🚬", cat: "Objects" },
                { char: "🔮", cat: "Objects" },
                { char: "💈", cat: "Objects" },
                { char: "🔭", cat: "Objects" },
                { char: "🔬", cat: "Objects" },
                { char: "💊", cat: "Objects" },
                { char: "💉", cat: "Objects" },
                { char: "🧪", cat: "Objects" },
                { char: "🧹", cat: "Objects" },
                { char: "🧻", cat: "Objects" },
                { char: "🚽", cat: "Objects" },
                { char: "🚿", cat: "Objects" },
                { char: "🛁", cat: "Objects" },
                { char: "🧼", cat: "Objects" },
                { char: "🪒", cat: "Objects" },
                { char: "🧴", cat: "Objects" },
                { char: "🔑", cat: "Objects" },
                { char: "🗝️", cat: "Objects" },
                { char: "🔒", cat: "Objects" },
                { char: "🔓", cat: "Objects" },
                { char: "✂️", cat: "Objects" },
                { char: "📌", cat: "Objects" },
                { char: "📎", cat: "Objects" },
                { char: "📏", cat: "Objects" },
                { char: "📐", cat: "Objects" },
                { char: "🗑️", cat: "Objects" },
                { char: "❤️", cat: "Symbols" },
                { char: "🧡", cat: "Symbols" },
                { char: "💛", cat: "Symbols" },
                { char: "💚", cat: "Symbols" },
                { char: "💙", cat: "Symbols" },
                { char: "💜", cat: "Symbols" },
                { char: "🖤", cat: "Symbols" },
                { char: "🤍", cat: "Symbols" },
                { char: "🤎", cat: "Symbols" },
                { char: "💔", cat: "Symbols" },
                { char: "❣️", cat: "Symbols" },
                { char: "💕", cat: "Symbols" },
                { char: "💞", cat: "Symbols" },
                { char: "💓", cat: "Symbols" },
                { char: "💗", cat: "Symbols" },
                { char: "💖", cat: "Symbols" },
                { char: "💘", cat: "Symbols" },
                { char: "💝", cat: "Symbols" },
                { char: "☮️", cat: "Symbols" },
                { char: "✝️", cat: "Symbols" },
                { char: "☪️", cat: "Symbols" },
                { char: "🕉️", cat: "Symbols" },
                { char: "☸️", cat: "Symbols" },
                { char: "✡️", cat: "Symbols" },
                { char: "🔯", cat: "Symbols" },
                { char: "☯️", cat: "Symbols" },
                { char: "⛎", cat: "Symbols" },
                { char: "♈", cat: "Symbols" },
                { char: "♉", cat: "Symbols" },
                { char: "♊", cat: "Symbols" },
                { char: "♋", cat: "Symbols" },
                { char: "♌", cat: "Symbols" },
                { char: "♍", cat: "Symbols" },
                { char: "♎", cat: "Symbols" },
                { char: "♏", cat: "Symbols" },
                { char: "♐", cat: "Symbols" },
                { char: "♑", cat: "Symbols" },
                { char: "♒", cat: "Symbols" },
                { char: "♓", cat: "Symbols" },
                { char: "❌", cat: "Symbols" },
                { char: "⭕", cat: "Symbols" },
                { char: "🛑", cat: "Symbols" },
                { char: "⛔", cat: "Symbols" },
                { char: "📛", cat: "Symbols" },
                { char: "🚫", cat: "Symbols" },
                { char: "💯", cat: "Symbols" },
                { char: "❗", cat: "Symbols" },
                { char: "❓", cat: "Symbols" },
                { char: "‼️", cat: "Symbols" },
                { char: "⁉️", cat: "Symbols" },
                { char: "⚠️", cat: "Symbols" },
                { char: "🔱", cat: "Symbols" },
                { char: "♻️", cat: "Symbols" },
                { char: "✅", cat: "Symbols" },
                { char: "❎", cat: "Symbols" },
                { char: "🔃", cat: "Symbols" },
                { char: "🔄", cat: "Symbols" },
                { char: "🔀", cat: "Symbols" },
                { char: "🔁", cat: "Symbols" },
                { char: "🔂", cat: "Symbols" },
                { char: "🎵", cat: "Symbols" },
                { char: "🎶", cat: "Symbols" },
                { char: "➕", cat: "Symbols" },
                { char: "➖", cat: "Symbols" },
                { char: "➗", cat: "Symbols" },
                { char: "✖️", cat: "Symbols" },
                { char: "♾️", cat: "Symbols" },
                { char: "💲", cat: "Symbols" },
                { char: "™️", cat: "Symbols" },
                { char: "©️", cat: "Symbols" },
                { char: "®️", cat: "Symbols" },
                { char: "🔚", cat: "Symbols" },
                { char: "🔙", cat: "Symbols" },
                { char: "🔛", cat: "Symbols" },
                { char: "🔝", cat: "Symbols" },
                { char: "🔜", cat: "Symbols" },
                { char: "✔️", cat: "Symbols" },
                { char: "☑️", cat: "Symbols" },
                { char: "🔘", cat: "Symbols" },
                { char: "🔴", cat: "Symbols" },
                { char: "🟠", cat: "Symbols" },
                { char: "🟡", cat: "Symbols" },
                { char: "🟢", cat: "Symbols" },
                { char: "🔵", cat: "Symbols" },
                { char: "🟣", cat: "Symbols" },
                { char: "⚫", cat: "Symbols" },
                { char: "⚪", cat: "Symbols" },
                { char: "🔺", cat: "Symbols" },
                { char: "🔻", cat: "Symbols" },
                { char: "🔶", cat: "Symbols" },
                { char: "🔷", cat: "Symbols" },
                { char: "⬛", cat: "Symbols" },
                { char: "⬜", cat: "Symbols" },
                { char: "🔈", cat: "Symbols" },
                { char: "🔇", cat: "Symbols" },
                { char: "🔉", cat: "Symbols" },
                { char: "🔊", cat: "Symbols" },
                { char: "🔔", cat: "Symbols" },
                { char: "🔕", cat: "Symbols" },
                { char: "💬", cat: "Symbols" },
                { char: "💭", cat: "Symbols" },
                { char: "♠️", cat: "Symbols" },
                { char: "♣️", cat: "Symbols" },
                { char: "♥️", cat: "Symbols" },
                { char: "♦️", cat: "Symbols" },
                { char: "🃏", cat: "Symbols" },
                { char: "🕐", cat: "Symbols" },
                { char: "🕑", cat: "Symbols" },
                { char: "🕒", cat: "Symbols" },
                { char: "🕓", cat: "Symbols" },
                { char: "🕔", cat: "Symbols" },
                { char: "🕕", cat: "Symbols" },
                { char: "🏳️", cat: "Flags" },
                { char: "🏴", cat: "Flags" },
                { char: "🚩", cat: "Flags" },
                { char: "🏁", cat: "Flags" },
                { char: "🏳️‍🌈", cat: "Flags" },
                { char: "🏳️‍⚧️", cat: "Flags" },
                { char: "🇺🇸", cat: "Flags" },
                { char: "🇬🇧", cat: "Flags" },
                { char: "🇨🇦", cat: "Flags" },
                { char: "🇲🇽", cat: "Flags" },
                { char: "🇧🇷", cat: "Flags" },
                { char: "🇦🇷", cat: "Flags" },
                { char: "🇨🇴", cat: "Flags" },
                { char: "🇻🇪", cat: "Flags" },
                { char: "🇵🇪", cat: "Flags" },
                { char: "🇨🇱", cat: "Flags" },
                { char: "🇪🇨", cat: "Flags" },
                { char: "🇺🇾", cat: "Flags" },
                { char: "🇵🇾", cat: "Flags" },
                { char: "🇧🇴", cat: "Flags" },
                { char: "🇪🇸", cat: "Flags" },
                { char: "🇫🇷", cat: "Flags" },
                { char: "🇩🇪", cat: "Flags" },
                { char: "🇮🇹", cat: "Flags" },
                { char: "🇵🇹", cat: "Flags" },
                { char: "🇳🇱", cat: "Flags" },
                { char: "🇧🇪", cat: "Flags" },
                { char: "🇨🇭", cat: "Flags" },
                { char: "🇸🇪", cat: "Flags" },
                { char: "🇳🇴", cat: "Flags" },
                { char: "🇩🇰", cat: "Flags" },
                { char: "🇫🇮", cat: "Flags" },
                { char: "🇮🇸", cat: "Flags" },
                { char: "🇷🇺", cat: "Flags" },
                { char: "🇺🇦", cat: "Flags" },
                { char: "🇵🇱", cat: "Flags" },
                { char: "🇬🇷", cat: "Flags" },
                { char: "🇹🇷", cat: "Flags" },
                { char: "🇮🇱", cat: "Flags" },
                { char: "🇸🇦", cat: "Flags" },
                { char: "🇦🇪", cat: "Flags" },
                { char: "🇮🇳", cat: "Flags" },
                { char: "🇨🇳", cat: "Flags" },
                { char: "🇯🇵", cat: "Flags" },
                { char: "🇰🇷", cat: "Flags" },
                { char: "🇮🇩", cat: "Flags" },
                { char: "🇹🇭", cat: "Flags" },
                { char: "🇻🇳", cat: "Flags" },
                { char: "🇵🇭", cat: "Flags" },
                { char: "🇦🇺", cat: "Flags" },
                { char: "🇳🇿", cat: "Flags" },
                { char: "🇿🇦", cat: "Flags" },
                { char: "🇪🇬", cat: "Flags" },
                { char: "🇳🇬", cat: "Flags" },
                { char: "🇰🇪", cat: "Flags" },
        ]

        property var categories: ["All", "Smileys", "People", "Animals", "Food", "Travel", "Activities", "Objects", "Symbols", "Flags"]

        property var filtered: {
            let list = allEmojis
            if (activeCategory !== "All") list = list.filter(e => e.cat === activeCategory)
            if (searchText.length > 0) {
                let q = searchText.toLowerCase()
                list = list.filter(e => e.cat.toLowerCase().includes(q))
            }
            return list
        }

        function moveCategory(dir) {
            let idx = categories.indexOf(activeCategory)
            idx = (idx + dir + categories.length) % categories.length
            activeCategory = categories[idx]
            selectedIndex = 0
        }
        function moveSelection(dir) {
            if (filtered.length === 0) return
            selectedIndex = Math.max(0, Math.min(filtered.length - 1, selectedIndex + dir))
            grid.positionViewAtIndex(selectedIndex, GridView.Contain)
        }
        function copySelected() {
            if (filtered.length === 0) return
            let e = filtered[Math.min(selectedIndex, filtered.length - 1)]
            copyProc.command = ["sh", "-c", "printf '%s' '" + e.char + "' | wl-copy"]
            copyProc.running = true
            win.copied = true
            copiedTimer.restart()
        }

        Process { id: copyProc; running: false }
        Timer { id: copiedTimer; interval: 900; onTriggered: win.copied = false }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.AppState.emojisVisible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 560
            height: 460
            radius: 16
            color: Services.Colors.surfaceAlpha(0.96)
            border.color: Services.Colors.ghostAlpha(0.2)
            border.width: 0
            clip: true

            opacity: Services.AppState.emojisVisible ? 1.0 : 0.0
            scale: Services.AppState.emojisVisible ? 1.0 : 0.96
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                id: contentCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    width: parent.width
                    Rectangle {
                        Layout.fillWidth: true
                        height: 48
                        radius: 10
                        color: Services.Colors.ghostAlpha(0.1)
                        border.color: searchField.activeFocus ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10
                            Text { text: "\ue8b6"; color: Services.Colors.ghost; font.pixelSize: 18; font.family: "Material Symbols Rounded" }
                            Item {
                                Layout.fillWidth: true
                                height: 28
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Search category..."
                                    color: Services.Colors.ash
                                    font.pixelSize: 14
                                    font.family: "JetBrainsMono NF"
                                    visible: searchField.text.length === 0
                                }
                                TextInput {
                                    id: searchField
                                    anchors.fill: parent
                                    color: Services.Colors.snow
                                    font.pixelSize: 14
                                    font.family: "JetBrainsMono NF"
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: { win.searchText = text; win.selectedIndex = 0 }
                                    Keys.onEscapePressed: Services.AppState.emojisVisible = false
                                    Keys.onReturnPressed: win.copySelected()
                                    Keys.onUpPressed: win.moveSelection(-8)
                                    Keys.onDownPressed: win.moveSelection(8)
                                    Keys.onLeftPressed: win.moveSelection(-1)
                                    Keys.onRightPressed: win.moveSelection(1)
                                }
                            }
                        }
                    }
                    Text {
                        text: win.copied ? "Copied!" : ""
                        color: Services.Colors.ghost
                        font.pixelSize: 12
                        font.family: "JetBrainsMono NF"
                        Layout.leftMargin: 8
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: win.categories
                        delegate: Rectangle {
                            required property string modelData
                            height: 28
                            width: catLabel.implicitWidth + 16
                            radius: 8
                            color: win.activeCategory === modelData ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                id: catLabel
                                anchors.centerIn: parent
                                text: modelData
                                color: win.activeCategory === modelData ? Services.Colors.abyss : Services.Colors.mist
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { win.activeCategory = modelData; win.selectedIndex = 0 }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 300
                    color: "transparent"
                    clip: true

                    GridView {
                        id: grid
                        anchors.fill: parent
                        model: win.filtered
                        cellWidth: (parent.width) / 8
                        cellHeight: 48

                        ScrollBar.vertical: ScrollBar {
                            policy: grid.contentHeight > grid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            width: 4
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: grid.cellWidth - 4
                            height: grid.cellHeight - 4
                            radius: 8
                            color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.25) : "transparent"
                            border.color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.4) : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.char
                                font.pixelSize: 24
                                font.family: "Noto Color Emoji"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: win.selectedIndex = index
                                onClicked: win.copySelected()
                            }
                        }
                    }
                }
            }
        }
    }
}
