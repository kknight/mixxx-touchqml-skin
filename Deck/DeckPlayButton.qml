import "../Theme"
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

Button {
    id: root

    required property color accentColor
    required property bool deckLoaded
    required property string group
    readonly property bool playing: playControl.value > 0

    Accessible.name: root.playing ? qsTr("Pause") : qsTr("Play")
    enabled: root.deckLoaded && playControl.initialized
    implicitHeight: TouchTheme.deckStatusRowHeight
    implicitWidth: TouchTheme.deckStatusActionMinimumWidth
    padding: 0

    onPressed: playControl.value = root.playing ? 0 : 1

    Mixxx.ControlProxy {
        id: playControl

        group: root.group
        key: "play"
    }
    background: Rectangle {
        color: root.down ? TouchTheme.controlPressedBackground : "transparent"

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            color: TouchTheme.secondaryText
            height: 2
            visible: root.visualFocus
            width: 12
        }
    }
    contentItem: Item {
        id: content

        readonly property color iconColor: !root.enabled ? TouchTheme.mutedText :
            root.playing ? root.accentColor : TouchTheme.primaryText

        Shape {
            anchors.centerIn: parent
            antialiasing: true
            height: TouchTheme.deckStatusIconSize
            visible: !root.playing
            width: TouchTheme.deckStatusIconSize

            ShapePath {
                fillColor: content.iconColor
                startX: 3
                startY: 0
                strokeColor: "transparent"

                PathLine {
                    x: TouchTheme.deckStatusIconSize
                    y: TouchTheme.deckStatusIconSize / 2
                }
                PathLine {
                    x: 3
                    y: TouchTheme.deckStatusIconSize
                }
                PathLine {
                    x: 3
                    y: 0
                }
            }
        }
        Row {
            anchors.centerIn: parent
            spacing: 4
            visible: root.playing

            Rectangle {
                color: content.iconColor
                height: TouchTheme.deckStatusIconSize
                width: 5
            }
            Rectangle {
                color: content.iconColor
                height: TouchTheme.deckStatusIconSize
                width: 5
            }
        }
    }
}
