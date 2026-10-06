import "../Theme"
import Mixxx 1.0 as Mixxx
import QtQuick

Item {
    id: root

    required property color accentColor
    readonly property var currentTrack: player?.currentTrack
    required property rect excludedArea
    required property string group
    property bool gestureAccepted: false
    property bool ownsBend: false
    property bool ownsScratch: false
    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)
    property real scratchStartX: 0
    property real scratchSamplesPerPixel: 0
    required property bool vinylMode
    required property var waveformDisplay

    function startsOnButton(point) {
        return point.x >= root.excludedArea.x && point.x <= root.excludedArea.x + root.excludedArea.width &&
            point.y >= root.excludedArea.y && point.y <= root.excludedArea.y + root.excludedArea.height;
    }
    function releaseGesture() {
        root.gestureAccepted = false;
        if (root.ownsBend && wheelControl.initialized) {
            wheelControl.value = 0;
        }
        root.ownsBend = false;
        if (root.ownsScratch) {
            if (scratchEnableControl.initialized) {
                scratchEnableControl.value = 0;
            }
            if (scratchPositionControl.initialized) {
                scratchPositionControl.value = 0;
            }
        }
        root.ownsScratch = false;
    }
    function beginScratch() {
        if (!root.enabled || !root.visible || !root.vinylMode || root.startsOnButton(scratchTouch.point.pressPosition)) {
            return;
        }
        root.scratchSamplesPerPixel = root.waveformDisplay.audioSamplePerPixel * 2;
        if (!Number.isFinite(root.scratchSamplesPerPixel) || root.scratchSamplesPerPixel <= 0) {
            return;
        }
        root.scratchStartX = scratchTouch.point.position.x;
        root.ownsScratch = true;
        scratchPositionControl.value = 0;
        scratchEnableControl.value = 1;
    }
    function updateScratch() {
        if (root.ownsScratch && scratchTouch.active && root.enabled && root.visible) {
            // Match upstream waveform scratching: pull the audio under the finger.
            scratchPositionControl.value = -(scratchTouch.point.position.x - root.scratchStartX) * root.scratchSamplesPerPixel;
        }
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

    enabled: (player?.isLoaded ?? false) && (root.vinylMode ?
        scratchEnableControl.initialized && scratchPositionControl.initialized :
        playControl.value > 0 && wheelControl.initialized)

    Component.onDestruction: root.releaseGesture()
    onCurrentTrackChanged: root.releaseGesture()
    onVinylModeChanged: root.releaseGesture()
    onEnabledChanged: {
        if (!enabled) {
            root.releaseGesture();
        }
    }
    onVisibleChanged: {
        if (!visible) {
            root.releaseGesture();
        }
    }

    Mixxx.ControlProxy {
        id: playControl

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: scratchEnableControl

        group: root.group
        key: "scratch_position_enable"
    }
    Mixxx.ControlProxy {
        id: scratchPositionControl

        group: root.group
        key: "scratch_position"
    }
    PointHandler {
        id: scratchTouch

        acceptedButtons: Qt.LeftButton
        enabled: root.enabled && root.visible && root.vinylMode
        target: null

        onActiveChanged: {
            if (active) {
                root.beginScratch();
            } else {
                root.releaseGesture();
            }
        }
        onPointChanged: root.updateScratch()
    }
    Mixxx.ControlProxy {
        id: wheelControl

        group: root.group
        key: "wheel"
    }
    DragHandler {
        id: nudgeDrag

        acceptedButtons: Qt.LeftButton
        enabled: root.enabled && root.visible && !root.vinylMode
        maximumPointCount: 1
        minimumPointCount: 1
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (active) {
                root.gestureAccepted = !root.startsOnButton(nudgeDrag.centroid.pressPosition);
                root.updateBend();
            } else {
                root.releaseGesture();
            }
        }
        onCentroidChanged: root.updateBend()
    }
    Rectangle {
        anchors.fill: parent
        border.color: root.accentColor
        border.width: 1
        color: "transparent"
        visible: (nudgeDrag.active && root.gestureAccepted) || root.ownsScratch
    }
}
