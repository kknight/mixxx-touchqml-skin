import "../Theme"
import Mixxx 1.0 as Mixxx
import Mixxx.Controls 1.0 as MixxxControls
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    required property color accentColor
    required property string group
    required property bool skinControlsReady
    readonly property var vinylModeControl: vinylModeControlLoader.item
    required property string vinylModeKey
    readonly property string zoomGroup: Mixxx.Config.waveformZoomSynchronization ? "[Channel1]" : root.group

    clip: true
    color: TouchTheme.overviewBackground

    Loader {
        id: vinylModeControlLoader

        active: root.skinControlsReady
        sourceComponent: Mixxx.ControlProxy {
            group: "[Skin]"
            key: root.vinylModeKey
        }
    }
    Mixxx.ControlProxy {
        id: zoomControl

        group: root.zoomGroup
        key: "waveform_zoom"

        Component.onCompleted: {
            if (zoomControl.group === root.group) {
                zoomControl.value = Mixxx.Config.waveformDefaultZoom;
            }
        }
    }
    Connections {
        target: Mixxx.Config

        function onWaveformDefaultZoomChanged() {
            if (zoomControl.group === root.group) {
                zoomControl.value = Mixxx.Config.waveformDefaultZoom;
            }
        }
    }
    MixxxControls.WaveformDisplay {
        id: scrollingWaveform

        anchors.fill: parent
        backgroundColor: "transparent"
        group: root.group
        zoom: zoomControl.value

        Mixxx.WaveformRendererEndOfTrack {
            color: TouchTheme.recording
            endOfTrackWarningTime: 30
        }
        Mixxx.WaveformRendererPreroll {
            color: TouchTheme.recording
        }
        Mixxx.WaveformRendererMarkRange {
            Mixxx.WaveformMarkRange {
                color: TouchTheme.activeLoop
                disabledColor: TouchTheme.primaryText
                disabledOpacity: 0.2
                enabledControl: "loop_enabled"
                endControl: "loop_end_position"
                opacity: 0.45
                startControl: "loop_start_position"
            }
            Mixxx.WaveformMarkRange {
                color: root.accentColor
                durationTextColor: TouchTheme.primaryText
                durationTextLocation: "after"
                endControl: "intro_end_position"
                opacity: 0.35
                startControl: "intro_start_position"
                visibilityControl: "[Skin],show_intro_outro_cues"
            }
            Mixxx.WaveformMarkRange {
                color: root.accentColor
                durationTextColor: TouchTheme.primaryText
                durationTextLocation: "before"
                endControl: "outro_end_position"
                opacity: 0.35
                startControl: "outro_start_position"
                visibilityControl: "[Skin],show_intro_outro_cues"
            }
        }
        Mixxx.WaveformRendererRGB {
            axesColor: TouchTheme.border
            gainAll: 1.0
            gainHigh: 1.0
            gainLow: 1.0
            gainMid: 1.0
            highColor: TouchTheme.waveformHigh
            lowColor: TouchTheme.waveformLow
            midColor: TouchTheme.waveformMid
        }
        Mixxx.WaveformRendererBeat {
            color: TouchTheme.border
        }
        Mixxx.WaveformRendererMark {
            playMarkerBackground: "transparent"
            playMarkerColor: "transparent"
            playMarkerPosition: TouchTheme.mainWaveformPlayMarkerPosition
            untilMark.showBeats: false
            untilMark.showTime: false

            Mixxx.WaveformMark {
                align: "top|right"
                color: TouchTheme.recording.toString()
                control: "cue_point"
                text: "CUE"
                textColor: TouchTheme.primaryText.toString()
            }
            Mixxx.WaveformMark {
                align: "top|right"
                color: TouchTheme.activeLoop.toString()
                control: "loop_start_position"
                text: "LOOP"
                textColor: TouchTheme.background.toString()
            }
            Mixxx.WaveformMark {
                align: "bottom|right"
                color: TouchTheme.activeLoop.toString()
                control: "loop_end_position"
                textColor: TouchTheme.background.toString()
            }
            Mixxx.WaveformMark {
                align: "top|right"
                color: root.accentColor.toString()
                control: "intro_start_position"
                text: "IN"
                textColor: TouchTheme.primaryText.toString()
                visibilityControl: "[Skin],show_intro_outro_cues"
            }
            Mixxx.WaveformMark {
                align: "top|left"
                color: root.accentColor.toString()
                control: "intro_end_position"
                textColor: TouchTheme.primaryText.toString()
                visibilityControl: "[Skin],show_intro_outro_cues"
            }
            Mixxx.WaveformMark {
                align: "top|right"
                color: root.accentColor.toString()
                control: "outro_start_position"
                text: "OUT"
                textColor: TouchTheme.primaryText.toString()
                visibilityControl: "[Skin],show_intro_outro_cues"
            }
            Mixxx.WaveformMark {
                align: "top|left"
                color: root.accentColor.toString()
                control: "outro_end_position"
                textColor: TouchTheme.primaryText.toString()
                visibilityControl: "[Skin],show_intro_outro_cues"
            }
        }
        Mixxx.WaveformRendererMark {
            playMarkerBackground: "transparent"
            playMarkerColor: TouchTheme.primaryText
            playMarkerPosition: TouchTheme.mainWaveformPlayMarkerPosition
            untilMark.align: Qt.AlignBottom
            untilMark.showBeats: true
            untilMark.showTime: true
            untilMark.textSize: 11

            defaultMark: Mixxx.WaveformMark {
                align: "bottom|center"
                color: TouchTheme.border.toString()
                text: " %1 "
                textColor: TouchTheme.primaryText.toString()
            }
        }
    }
    WaveformTouchArea {
        anchors.fill: parent
        accentColor: root.accentColor
        excludedArea: Qt.rect(vinylButton.x, vinylButton.y, vinylButton.width, vinylButton.height)
        group: root.group
        vinylMode: (root.vinylModeControl?.value ?? 0) > 0
        waveformDisplay: scrollingWaveform
        z: 1
    }
    Button {
        id: vinylButton

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: 8
        enabled: root.vinylModeControl?.initialized ?? false
        height: TouchTheme.minimumTouchSize
        padding: 0
        width: TouchTheme.deckStatusActionWidth
        z: 3

        Accessible.name: qsTr("Vinyl scratch mode")
        Accessible.checkable: true
        Accessible.checked: (root.vinylModeControl?.value ?? 0) > 0

        onClicked: root.vinylModeControl.toggle()

        background: Rectangle {
            color: vinylButton.down ? TouchTheme.controlPressedBackground : TouchTheme.controlBackground
            border.color: vinylButton.visualFocus ? TouchTheme.secondaryText : TouchTheme.border
            border.width: 1

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                color: root.accentColor
                height: 2
                visible: (root.vinylModeControl?.value ?? 0) > 0
            }
        }
        contentItem: Text {
            color: (root.vinylModeControl?.value ?? 0) > 0 ? root.accentColor : TouchTheme.secondaryText
            font.family: TouchTheme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("VINYL")
            verticalAlignment: Text.AlignVCenter
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        color: root.accentColor
        width: TouchTheme.mainWaveformAccentWidth
        z: 2
    }
}
