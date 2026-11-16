import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

// Icon + title + value pill, with a themed slider underneath.
ColumnLayout {
    id: root

    property string icon: ""
    property color iconColor: Theme.accent
    property string title: ""
    property string valueText: ""
    property real value: 0
    property real minimumValue: 0
    // Greys the track out (e.g. muted audio) while staying usable.
    property bool dimmed: false

    signal moved(real value)
    signal iconClicked

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        IconButton {
            icon: root.icon
            iconColor: root.iconColor
            iconSize: 16
            onClicked: root.iconClicked()
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.text
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight
        }

        Rectangle {
            implicitWidth: Math.max(38, valueLabel.implicitWidth + 14)
            implicitHeight: 20
            radius: 7
            color: Theme.surface

            Text {
                id: valueLabel
                anchors.centerIn: parent
                text: root.valueText
                color: root.dimmed ? Theme.muted : Theme.text
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    Slider {
        id: slider

        Layout.fillWidth: true
        Layout.preferredHeight: 26

        from: root.minimumValue
        to: 1
        stepSize: 0.01
        enabled: root.enabled

        // Follow the real value except while the user is dragging.
        Binding {
            target: slider
            property: "value"
            value: root.value
            when: !slider.pressed
        }

        onMoved: root.moved(value)

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 5
            radius: 2.5
            color: slider.hovered ? Theme.border : Theme.surface

            Rectangle {
                width: parent.width * slider.visualPosition
                height: parent.height
                radius: parent.radius
                color: slider.enabled && !root.dimmed ? Theme.accent : Theme.muted
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.hovered || slider.pressed ? 16 : 14
            height: width
            radius: width / 2
            color: Theme.text
            border.width: 3
            border.color: root.dimmed ? Theme.muted : Theme.accent

            Behavior on width { NumberAnimation { duration: 100 } }
        }
    }
}
