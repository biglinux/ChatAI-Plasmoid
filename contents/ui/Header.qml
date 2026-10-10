/*
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *  SPDX-FileCopyrightText: 2025 Bruno Gonçalves <bigbruno@gmail.com>
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtCore
import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

/*
 * Toolbar:  📌  ←  →  ↻  ⌂  [ AI ▼ ]  🔍  (↓ while downloads need attention)  ⋮  ✕
 * Auto-hide and Downloads live in the ⋮ menu; the download indicator is
 * temporary. Home and Find move into the kebab when the bar gets narrow.
 */
RowLayout {
    id: header

    required property QtObject providerModel
    // WebView.qml root while loaded, otherwise null.
    property var webviewRoot: null
    property bool settingsOpen: false

    signal homeRequested()
    signal closeRequested()
    signal settingsRequested(string category)
    signal aboutRequested()
    signal shortcutsRequested()
    // True while a native dialog owned by the header is open.
    property bool modalOpen: folderDialog.visible

    readonly property bool hasWebView: webviewRoot !== null
    readonly property bool menuOpen: kebabMenu.visible || downloadPopup.visible || selector.popup.visible || customUrlField.visible
    readonly property var emptyDownloadSummary: ({ active: 0, paused: 0, completedUnseen: 0, failedUnseen: 0, progress: 0, hasUnknownSize: false, showIndicator: false, attention: 0 })
    readonly property var downloadSummary: hasWebView && webviewRoot.downloadSummary ? webviewRoot.downloadSummary : emptyDownloadSummary

    // Progressive overflow: only Home and Find are optional now.
    readonly property int overflowLevel: width < Kirigami.Units.gridUnit * 26 ? 2 : width < Kirigami.Units.gridUnit * 30 ? 1 : 0
    readonly property bool searchInBar: overflowLevel < 2
    readonly property bool homeInBar: !plasmoid.configuration.hideHomeButton && overflowLevel < 1

    spacing: Kirigami.Units.smallSpacing

    function configuredDownloadPath() {
        const configured = String(plasmoid.configuration.downloadPath || "");
        return configured || StandardPaths.writableLocation(StandardPaths.DownloadLocation);
    }

    function openDownloadFolder() {
        const path = String(configuredDownloadPath());
        Qt.openUrlExternally(path.indexOf("file://") === 0 ? path : "file://" + path);
    }

    function openDownloads(anchorItem) {
        const anchor = anchorItem || kebabButton;
        downloadPopup.parent = anchor;
        // Right-align with the anchor; Popup.margins keeps it inside the window.
        downloadPopup.x = anchor.width - downloadPopup.width;
        downloadPopup.y = anchor.height + Kirigami.Units.smallSpacing;
        downloadPopup.open();
    }

    function showCustomAddress() {
        customUrlField.text = plasmoid.configuration.url;
        customUrlField.visible = true;
        customUrlField.forceActiveFocus();
        customUrlField.selectAll();
    }

    function acceptCustomAddress() {
        const url = providerModel.normalizeUrl(customUrlField.text);
        customUrlField.visible = false;
        if (!url)
            return;
        if (plasmoid.configuration.url !== url)
            plasmoid.configuration.url = url;
        homeRequested();
    }

    component ToolbarButton: PlasmaComponents3.ToolButton {
        display: PlasmaComponents3.AbstractButton.IconOnly
        Accessible.name: text
        PlasmaComponents3.ToolTip.text: text
        PlasmaComponents3.ToolTip.visible: hovered
        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    // 1. Pin
    ToolbarButton {
        id: pinButton
        visible: !plasmoid.configuration.hideKeepOpen
        icon.name: "window-pin"
        checkable: true
        checked: Boolean(plasmoid.configuration.pin)
        text: checked ? i18n("Pinned: stays open when clicking outside") : i18n("Pin: keep open when clicking outside")
        onToggled: plasmoid.configuration.pin = checked
    }

    // 2–3. Back / Forward
    ToolbarButton {
        id: backButton
        visible: !plasmoid.configuration.hideNavigationButtons
        text: i18n("Back")
        enabled: header.hasWebView && header.webviewRoot.canGoBack
        onClicked: header.webviewRoot.goBack()
        contentItem: Kirigami.Icon {
            source: "go-previous"
            isMask: true
            color: Kirigami.Theme.textColor
            // Clearly greyed (not invisible) when there is no history yet.
            opacity: backButton.enabled ? 1 : 0.45
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
        }
    }

    ToolbarButton {
        id: forwardButton
        visible: !plasmoid.configuration.hideNavigationButtons
        text: i18n("Forward")
        enabled: header.hasWebView && header.webviewRoot.canGoForward
        onClicked: header.webviewRoot.goForward()
        contentItem: Kirigami.Icon {
            source: "go-next"
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: forwardButton.enabled ? 1 : 0.45
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
        }
    }

    // 4. Reload / Stop
    ToolbarButton {
        visible: !plasmoid.configuration.hideRefreshButton
        readonly property bool loadingPage: header.hasWebView && header.webviewRoot.loading
        icon.name: loadingPage ? "process-stop" : "view-refresh"
        text: loadingPage ? i18n("Stop loading") : i18n("Reload")
        enabled: header.hasWebView && !header.webviewRoot.clearingCache
        onClicked: loadingPage ? header.webviewRoot.stop() : header.webviewRoot.reload()
    }

    // 5. Home
    ToolbarButton {
        visible: header.homeInBar
        icon.name: "go-home"
        text: i18n("Home page of the current assistant")
        enabled: header.hasWebView
        onClicked: header.homeRequested()
    }

    // 6. Select AI (or the custom address field)
    AiSelector {
        id: selector
        visible: !customUrlField.visible
        providerModel: header.providerModel
        onSelected: header.homeRequested()
        onCustomAddressRequested: header.showCustomAddress()
    }

    PlasmaComponents3.TextField {
        id: customUrlField
        visible: false
        Layout.fillWidth: true
        placeholderText: "https://…"
        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
        Accessible.name: i18n("Custom address")
        onAccepted: header.acceptCustomAddress()
        Keys.onEscapePressed: visible = false
        onActiveFocusChanged: {
            if (!activeFocus)
                visible = false;
        }
    }

    // 7. Search
    ToolbarButton {
        visible: header.searchInBar
        icon.name: "edit-find"
        text: i18n("Find in page (Ctrl+F)")
        enabled: header.hasWebView
        checkable: true
        checked: header.hasWebView && header.webviewRoot.findBarVisible
        onClicked: header.webviewRoot.toggleFind()
    }

    // 8. Temporary download indicator (only while downloads need attention)
    DownloadIndicator {
        id: downloadIndicator
        visible: header.downloadSummary.showIndicator
        summary: header.downloadSummary
        onClicked: header.openDownloads(downloadIndicator)
    }

    // 9. Kebab
    ToolbarButton {
        id: kebabButton
        text: i18n("More actions")
        onClicked: kebabMenu.popup()
        // Drawn as a monochrome mask in the theme text colour. Some icon themes
        // (e.g. kora) ship a multicolour, light "overflow-menu" that the button
        // could not recolour; masking forces it to match the other icons.
        contentItem: Kirigami.Icon {
            source: "overflow-menu"
            isMask: true
            color: Kirigami.Theme.textColor
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
        }

        ChatAIMenu {
            id: kebabMenu
            webviewRoot: header.webviewRoot
            showFindItem: !header.searchInBar
            showHomeItem: !header.homeInBar && !plasmoid.configuration.hideHomeButton
            onSettingsRequested: category => header.settingsRequested(category)
            onAboutRequested: header.aboutRequested()
            onShortcutsRequested: header.shortcutsRequested()
            onHomeRequested: header.homeRequested()
            onDownloadsRequested: header.openDownloads(kebabButton)
        }
    }

    // 10. Close
    ToolbarButton {
        visible: !plasmoid.configuration.hideCloseButton
        icon.name: "window-close"
        text: i18n("Close and release memory")
        onClicked: header.closeRequested()
    }

    // Downloads list, anchored to the indicator or to the kebab button.
    DownloadPopup {
        id: downloadPopup
        runtime: header.webviewRoot
        onOpenDownloadFolderRequested: header.openDownloadFolder()
        onChooseDownloadFolderRequested: folderDialog.open()
    }

    FolderDialog {
        id: folderDialog
        title: i18n("Choose Download Folder")
        currentFolder: header.configuredDownloadPath()
        onAccepted: plasmoid.configuration.downloadPath = selectedFolder
    }
}
