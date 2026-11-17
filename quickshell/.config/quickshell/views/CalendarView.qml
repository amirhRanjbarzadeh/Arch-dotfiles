pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../components"
import "../styles"

// Month calendar, opened by clicking the clock. Opens on the current month.
// Keys: ←/→ (or PageUp/PageDown) change month, Home or T jumps back to today.
// Scrolling over it changes month too.
Item {
    id: root

    signal closeRequested

    readonly property int cellSize: 38

    // Refreshed every minute so "today" moves on at midnight.
    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property bool showingToday: viewYear === today.getFullYear() && viewMonth === today.getMonth()
    readonly property int firstDayOfWeek: Qt.locale().firstDayOfWeek

    // Always 6 weeks, so the island keeps one height from month to month.
    readonly property var days: {
        const first = new Date(viewYear, viewMonth, 1);
        const offset = (first.getDay() - firstDayOfWeek + 7) % 7;
        const result = [];
        for (let i = 0; i < 42; i++)
            result.push(new Date(viewYear, viewMonth, 1 - offset + i));
        return result;
    }

    function shiftMonth(delta) {
        const date = new Date(viewYear, viewMonth + delta, 1);
        viewYear = date.getFullYear();
        viewMonth = date.getMonth();
        monthSwitch.direction = delta;
        monthSwitch.restart();
    }

    function goToToday() {
        if (showingToday)
            return;
        const forward = today > new Date(viewYear, viewMonth, 1);
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
        monthSwitch.direction = forward ? 1 : -1;
        monthSwitch.restart();
    }

    function isToday(date) {
        return date.getDate() === today.getDate() && date.getMonth() === today.getMonth() && date.getFullYear() === today.getFullYear();
    }

    implicitWidth: 7 * cellSize + 2 * card.padding
    implicitHeight: column.implicitHeight + 2 * card.padding

    onVisibleChanged: {
        if (visible) {
            today = new Date();
            viewYear = today.getFullYear();
            viewMonth = today.getMonth();
            forceActiveFocus();
        }
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: root.today = new Date()
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_PageUp:
            shiftMonth(-1);
            break;
        case Qt.Key_Right:
        case Qt.Key_PageDown:
            shiftMonth(1);
            break;
        case Qt.Key_Home:
        case Qt.Key_T:
            goToToday();
            break;
        case Qt.Key_Escape:
            root.closeRequested();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
            if (delta !== 0)
                root.shiftMonth(delta < 0 ? 1 : -1);
        }
    }

    Card {
        id: card

        anchors.fill: parent
        padding: 16

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 10

            // Header: today's date, the shown month and navigation.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                ColumnLayout {
                    spacing: 1

                    Text {
                        text: Qt.locale().standaloneMonthName(root.viewMonth, Locale.LongFormat) + " " + root.viewYear
                        color: Theme.text
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Text {
                        text: Qt.formatDate(root.today, "dddd, d MMMM")
                        color: Theme.muted
                        font.pixelSize: 11
                    }
                }

                // Pushes the buttons to the right edge.
                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    icon: Icons.calendar
                    iconColor: Theme.accent
                    tooltip: "Today"
                    visible: !root.showingToday
                    onClicked: root.goToToday()
                }

                IconButton {
                    icon: Icons.chevronLeft
                    iconSize: 16
                    tooltip: "Previous month"
                    onClicked: root.shiftMonth(-1)
                }

                IconButton {
                    icon: Icons.chevronRight
                    iconSize: 16
                    tooltip: "Next month"
                    onClicked: root.shiftMonth(1)
                }
            }

            // Weekday names, starting from the locale's first day of the week.
            Row {
                Repeater {
                    model: 7

                    delegate: Text {
                        required property int index
                        readonly property int day: (root.firstDayOfWeek + index) % 7

                        width: root.cellSize
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName(day, Locale.ShortFormat).slice(0, 2)
                        color: day === 0 || day === 6 ? Theme.muted : Theme.subtle
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Grid {
                id: grid

                columns: 7

                Repeater {
                    model: root.days

                    delegate: Item {
                        id: cell

                        required property var modelData
                        readonly property bool inMonth: modelData.getMonth() === root.viewMonth
                        readonly property bool current: root.isToday(modelData)
                        readonly property bool weekend: modelData.getDay() === 0 || modelData.getDay() === 6

                        width: root.cellSize
                        height: root.cellSize - 6

                        Rectangle {
                            anchors.centerIn: parent
                            width: root.cellSize - 8
                            height: width - 4
                            radius: Theme.itemRadius
                            color: cell.current ? Theme.accent : cellHover.hovered && cell.inMonth ? Theme.surface : "transparent"

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.getDate()
                            color: cell.current ? Theme.accentText : !cell.inMonth ? Theme.border : cell.weekend ? Theme.subtle : Theme.text
                            font.pixelSize: 12
                            font.bold: cell.current
                        }

                        HoverHandler {
                            id: cellHover
                        }

                        // Clicking a day from a neighbouring month flips to that month.
                        TapHandler {
                            enabled: !cell.inMonth
                            onTapped: root.shiftMonth(cell.modelData < new Date(root.viewYear, root.viewMonth, 1) ? -1 : 1)
                        }
                    }
                }

                // Slide-and-fade when the month changes.
                transform: Translate { id: gridShift }
            }
        }
    }

    ParallelAnimation {
        id: monthSwitch

        property int direction: 1

        NumberAnimation { target: gridShift; property: "x"; from: 14 * monthSwitch.direction; to: 0; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: grid; property: "opacity"; from: 0.3; to: 1; duration: 180 }
    }
}
