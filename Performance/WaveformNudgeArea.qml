import "../Theme"
import Mixxx 1.0 as Mixxx
import QtQuick

Item {
    id: root

    required property color accentColor
    readonly property var currentTrack: player?.currentTrack
    required property string group
    property bool gestureAccepted: false
    property bool ownsBend: false
    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)

    function releaseBend() {
        root.gestureAccepted = false;
        if (root.ownsBend && wheelControl.initialized) {
            wheelControl.value = 0;
        }
        root.ownsBend = false;
    }
    function updateBend() {
        if (!root.gestureAccepted || !nudgeDrag.active || !root.enabled || !root.visible) {
            return;
        }
        const distance = nudgeDrag.centroid.position.x - nudgeDrag.centroid.pressPosition.x;
        const fullBendDistance = Math.max(1, root.width * TouchTheme.mainWaveformNudgeDistanceFraction);
        const amount = Math.max(-1, Math.min(1, distance / fullBendDistance));
        root.ownsBend = true;
        wheelControl.value = amount * TouchTheme.mainWaveformNudgeMaximumRate;
    }

    enabled: (player?.isLoaded ?? false) && playControl.value > 0 && wheelControl.initialized

    Component.onDestruction: root.releaseBend()
    onCurrentTrackChanged: root.releaseBend()
    onEnabledChanged: {
        if (!enabled) {
            root.releaseBend();
        }
    }
    onVisibleChanged: {
        if (!visible) {
            root.releaseBend();
        }
    }

    Mixxx.ControlProxy {
        id: playControl

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: wheelControl

        group: root.group
        key: "wheel"
    }
    DragHandler {
        id: nudgeDrag

        acceptedButtons: Qt.LeftButton
        enabled: root.enabled && root.visible
        maximumPointCount: 1
        minimumPointCount: 1
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (active) {
                root.gestureAccepted = true;
                root.updateBend();
            } else {
                root.releaseBend();
            }
        }
        onCentroidChanged: root.updateBend()
    }
    Rectangle {
        anchors.fill: parent
        border.color: root.accentColor
        border.width: 1
        color: "transparent"
        visible: nudgeDrag.active && root.gestureAccepted
    }
}
