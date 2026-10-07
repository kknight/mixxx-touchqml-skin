pragma ComponentBehavior: Bound

import "Deck" as Deck
import Mixxx 1.0 as Mixxx
import QtCore
import QtQuick

Item {
    id: root

    required property var browseView
    property bool readyToSave: false
    readonly property url settingsLocation: Mixxx.Application.settingsDirectoryUrl.toString().replace(/\/$/, "") + "/TouchQML-session.ini"

    function save() {
        if (!root.readyToSave) {
            return;
        }
        deck1.save();
        deck2.save();
        previewLoader.item?.save();
        const page = libraryControl.value > 0 ? 1 : effectsControl.value > 0 ? 2 :
            samplesControl.value > 0 ? 3 : settingsControl.value > 0 ? 4 : 0;
        const snapshot = JSON.stringify({version: 1, page: page, browse: root.browseView.sessionState()});
        if (storage.snapshot !== snapshot) {
            storage.snapshot = snapshot;
            storage.sync();
        }
    }
    function restore() {
        let state = null;
        try {
            state = JSON.parse(storage.snapshot);
        } catch (error) {
            console.warn("TouchQML: invalid saved UI session");
        }
        if (state?.version === 1) {
            root.browseView.restoreSessionState(state.browse);
            libraryControl.value = state.page === 1 ? 1 : 0;
            effectsControl.value = state.page === 2 ? 1 : 0;
            samplesControl.value = state.page === 3 ? 1 : 0;
            settingsControl.value = state.page === 4 ? 1 : 0;
        }
        root.readyToSave = true;
    }

    Component.onCompleted: Qt.callLater(root.restore)

    Settings {
        id: storage

        property string snapshot: "{}"

        category: "UI"
        location: root.settingsLocation
    }
    Deck.DeckSession {
        id: deck1

        group: "[Channel1]"
        settingsLocation: root.settingsLocation
    }
    Deck.DeckSession {
        id: deck2

        group: "[Channel2]"
        settingsLocation: root.settingsLocation
    }
    Loader {
        id: previewLoader

        active: previewCountControl.value > 0
        sourceComponent: Deck.DeckSession {
            group: "[PreviewDeck1]"
            settingsLocation: root.settingsLocation
        }
    }
    Mixxx.ControlProxy {
        id: previewCountControl

        group: "[Master]"
        key: "num_preview_decks"
    }
    Mixxx.ControlProxy {
        id: libraryControl

        group: "[Skin]"
        key: "show_maximized_library"
    }
    Mixxx.ControlProxy {
        id: effectsControl

        group: "[Skin]"
        key: "show_effectrack"
    }
    Mixxx.ControlProxy {
        id: samplesControl

        group: "[Skin]"
        key: "show_samplers"
    }
    Mixxx.ControlProxy {
        id: settingsControl

        group: "[Skin]"
        key: "show_settings"
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.readyToSave

        onTriggered: root.save()
    }
}
