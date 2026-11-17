import QtQuick
import "../styles"

// Pill-shaped search box for list views in the island (launcher, clipboard).
// Typing goes to `text`; list navigation keys are turned into signals so the
// owner keeps its own selection. Right-hand content (a count, buttons) goes in `trailing`.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: "Search"
    property string icon: Icons.search
    default property alias trailing: trailingRow.data
    // Rows per PageUp/PageDown.
    property int pageSize: 7

    signal moved(int step)
    signal accepted
    signal closeRequested
    // Shift+Delete: remove the selected item (views that support it).
    signal removeRequested

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitHeight: 44
    radius: height / 2
    color: Theme.surface
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.border

    Behavior on border.color { ColorAnimation { duration: 160 } }

    Text {
        id: searchIcon
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: Theme.accent
        font.pixelSize: 18
    }

    TextInput {
        id: input

        anchors.left: searchIcon.right
        anchors.leftMargin: 12
        anchors.right: trailingRow.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter

        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.pixelSize: 15
        clip: true
        focus: true

        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            const shift = event.modifiers & Qt.ShiftModifier;
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)))
                root.moved(1);
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)))
                root.moved(-1);
            else if (event.key === Qt.Key_PageDown)
                root.moved(root.pageSize);
            else if (event.key === Qt.Key_PageUp)
                root.moved(-root.pageSize);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.accepted();
            else if (shift && event.key === Qt.Key_Delete)
                root.removeRequested();
            else if (event.key === Qt.Key_Escape) {
                // First Escape clears the query, the second closes.
                if (text !== "")
                    text = "";
                else
                    root.closeRequested();
            } else
                return;
            event.accepted = true;
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Theme.muted
            font.pixelSize: 15
        }
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
