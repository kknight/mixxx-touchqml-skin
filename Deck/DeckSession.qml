pragma ComponentBehavior: Bound

import Mixxx 1.0 as Mixxx
import QtCore
import QtQuick

Item {
    id: root

    required property string group
    required property url settingsLocation
    readonly property var player: Mixxx.PlayerManager.getPlayer(root.group)
    property var savedState: null
    property bool readyToSave: false
    property bool waitingForTrack: false
    property bool preserveMissingTrack: false
    readonly property var controlKeys: ["rateRange", "rate", "keylock", "quantize",
        "beatloop_size", "beatjump_size", "waveform_zoom"]

    function currentUrl() {
        return root.player?.currentTrack?.trackLocationUrl.toString() ?? "";
    }
    function save() {
        if (!root.readyToSave || root.waitingForTrack || !root.player ||
                (root.player.isLoaded && !root.player.trackLoaded) ||
                (root.preserveMissingTrack && !root.player.isLoaded)) {
            return;
        }
        const values = {};
        for (let i = 0; i < controls.count; ++i) {
            const control = controls.itemAt(i)?.control;
            if (control?.initialized) {
                values[root.controlKeys[i]] = control.value;
            }
        }
        const snapshot = JSON.stringify({version: 1, url: root.currentUrl(),
            position: positionControl.value, controls: values});
        if (storage.snapshot !== snapshot) {
            storage.snapshot = snapshot;
            storage.sync();
        }
    }
    function finishRestore() {
        if (!root.waitingForTrack || !root.player?.trackLoaded) {
            return;
        }
        // A user/controller load takes precedence over the startup request.
        if (root.currentUrl() === root.savedState.url) {
            root.restoreControls();
            if (Number.isFinite(root.savedState.position)) {
                positionControl.value = Math.max(0, Math.min(1, root.savedState.position));
            }
        }
        root.waitingForTrack = false;
        restoreTimeout.stop();
        root.save();
    }
    function restoreControls() {
        const values = root.savedState?.controls ?? {};
        for (let i = 0; i < controls.count; ++i) {
            const control = controls.itemAt(i)?.control;
            const value = values[root.controlKeys[i]];
            if (control?.initialized && typeof value === "number" && Number.isFinite(value)) {
                control.value = value;
            } else if (control?.initialized && root.controlKeys[i] === "waveform_zoom") {
                control.value = Mixxx.Config.waveformDefaultZoom;
            }
        }
    }
    function restore() {
        try {
            root.savedState = JSON.parse(storage.snapshot);
        } catch (error) {
            console.warn("TouchQML: invalid saved deck session", root.group);
        }
        root.readyToSave = true;
        // Auto-reload must leave an already loaded engine deck alone.
        if (!root.player || root.player.isLoaded) {
            return;
        }
        if (root.savedState?.version !== 1 || typeof root.savedState.url !== "string") {
            root.savedState = null;
            root.restoreControls();
            return;
        }
        if (root.savedState.url === "") {
            root.restoreControls();
            return;
        }
        if (!root.savedState.url.startsWith("file:")) {
            return;
        }
        root.waitingForTrack = true;
        restoreTimeout.start();
        root.player.loadTrackFromLocationUrl(root.savedState.url, false);
    }

    Component.onCompleted: Qt.callLater(root.restore)

    Settings {
        id: storage

        property string snapshot: "{}"

        category: root.group
        location: root.settingsLocation
    }
    Mixxx.ControlProxy {
        id: positionControl

        group: root.group
        key: "playposition"
    }
    Repeater {
        id: controls

        model: root.controlKeys
        delegate: Item {
            id: savedControl

            required property string modelData
            readonly property alias control: proxy

            Mixxx.ControlProxy {
                id: proxy

                group: root.group
                key: savedControl.modelData
            }
        }
    }
    Connections {
        target: root.player

        function onTrackLoaded() {
            root.preserveMissingTrack = false;
            Qt.callLater(root.finishRestore);
        }
        function onTrackUnloaded() {
            if (!root.waitingForTrack) {
                root.preserveMissingTrack = false;
                root.save();
            }
        }
    }
    Timer {
        id: restoreTimeout

        interval: 15000

        onTriggered: {
            root.waitingForTrack = false;
            root.preserveMissingTrack = true;
            console.warn("TouchQML: saved track could not be restored", root.group);
        }
    }
}
