/*
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *  SPDX-FileCopyrightText: 2025 Bruno Gonçalves <bigbruno@gmail.com>
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import "Migration.js" as Migration

/*
 * Plasmoid orchestration: representations, lazy WebView, pin, in-widget
 * settings, fullscreen guard and configuration migration.
 *
 * Note: compactRepresentation/fullRepresentation are components in Plasma 6,
 * so their inner ids are not visible here. Shared state lives on the root and
 * the inner items push their values up.
 */
PlasmoidItem {
    id: root

    ProviderModel {
        id: providerRegistry
    }

    // WebView.qml root while loaded (null after Close). Pushed by the Loader.
    property var webviewRoot: null
    readonly property bool fullScreenActive: webviewRoot ? webviewRoot.fullScreenActive : false
    property bool settingsOpen: false
    property string settingsCategory: "general"
    // True after Close until the next expansion: keeps the Loader inactive.
    property bool webviewClosed: false
    // Native dialogs (folder chooser, prompts) deactivate the popup window.
    property bool headerModalOpen: false
    property bool settingsModalOpen: false
    readonly property var currentProvider: providerRegistry.providerForUrl(plasmoid.configuration.url)

    // Pin is the single source of truth.
    hideOnWindowDeactivate: !(plasmoid.configuration.pin || headerModalOpen || settingsModalOpen || fullScreenActive)
    toolTipMainText: i18n("ChatAI")
    toolTipSubText: currentProvider ? currentProvider.name : providerRegistry.nameForUrl(plasmoid.configuration.url)

    Component.onCompleted: {
        if (Migration.run(plasmoid.configuration, providerRegistry.legacyUrlMap()))
            console.info("ChatAI: configuration migrated to schema", plasmoid.configuration.configVersion);
    }

    onExpandedChanged: {
        if (root.expanded)
            root.webviewClosed = false;
    }

    function openSettings(category) {
        settingsCategory = category || "general";
        settingsOpen = true;
    }

    function closeSettings() {
        settingsOpen = false;
    }

    function closeWebView() {
        settingsOpen = false;
        webviewClosed = true;
        root.expanded = false;
    }

    function recreateWebView() {
        webviewClosed = true;
        Qt.callLater(function () { root.webviewClosed = false; });
    }

    function goHome() {
        if (webviewRoot)
            webviewRoot.goHome();
    }

    compactRepresentation: CompactRepresentation {
        plasmoidItem: root
        providerModel: providerRegistry
    }

    fullRepresentation: ColumnLayout {
        id: mainLayout

        // AI web apps switch to their mobile layouts below ~768 CSS px, so the
        // popup opens at a desktop-friendly size by default. The user can still
        // drag it smaller (a hint appears if the page falls back to mobile).
        readonly property int minimumViewportWidth: 780
        readonly property int defaultWidth: Math.max(Kirigami.Units.gridUnit * 28, minimumViewportWidth + Kirigami.Units.gridUnit * 2)
        readonly property int defaultHeight: Kirigami.Units.gridUnit * 39

        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 18
        Layout.preferredWidth: plasmoid.configuration.dialogWidth > 0 ? plasmoid.configuration.dialogWidth : defaultWidth
        Layout.preferredHeight: plasmoid.configuration.dialogHeight > 0 ? plasmoid.configuration.dialogHeight : defaultHeight

        spacing: 0

        // Debounced persistence of the popup size.
        Timer {
            id: saveSizeTimer
            interval: 500
            repeat: false
            onTriggered: {
                const currentWidth = Math.round(mainLayout.width);
                const currentHeight = Math.round(mainLayout.height);
                if (currentWidth > 0 && currentHeight > 0
                    && (currentWidth !== plasmoid.configuration.dialogWidth || currentHeight !== plasmoid.configuration.dialogHeight)) {
                    plasmoid.configuration.dialogWidth = currentWidth;
                    plasmoid.configuration.dialogHeight = currentHeight;
                }
            }
        }

        onWidthChanged: saveSizeTimer.restart()
        onHeightChanged: saveSizeTimer.restart()

        Header {
            id: headerRoot

            property bool headerVisible: false
            readonly property bool shouldBeVisible: {
                if (plasmoid.configuration.hideHeader)
                    return false;
                if (!plasmoid.configuration.autoHideHeader || root.settingsOpen)
                    return true;
                return headerVisible || menuOpen || headerHover.hovered || revealStrip.hovered;
            }

            providerModel: providerRegistry
            webviewRoot: root.webviewRoot
            settingsOpen: root.settingsOpen
            Layout.fillWidth: true
            Layout.preferredHeight: shouldBeVisible ? implicitHeight : 0
            Layout.maximumHeight: Layout.preferredHeight
            Layout.minimumHeight: 0
            Layout.bottomMargin: shouldBeVisible ? Kirigami.Units.smallSpacing : 0
            z: 2
            visible: Layout.preferredHeight > 0
            opacity: shouldBeVisible ? 1 : 0
            clip: true

            onHomeRequested: root.goHome()
            onCloseRequested: root.closeWebView()
            onSettingsRequested: category => root.openSettings(category)
            onAboutRequested: root.openSettings("about")
            onShortcutsRequested: root.openSettings("about")
            onModalOpenChanged: root.headerModalOpen = modalOpen

            // A finished or failed download reveals the auto-hidden toolbar for
            // a moment so the indicator can be noticed (no modal popup).
            Connections {
                target: root.webviewRoot
                function onDownloadAttention() {
                    headerRoot.headerVisible = true;
                    hideTimer.restart();
                }
            }

            // Hover detection without participating in the layout.
            HoverHandler {
                id: headerHover
                onHoveredChanged: {
                    if (hovered) {
                        headerRoot.headerVisible = true;
                        hideTimer.stop();
                    } else if (!headerRoot.menuOpen) {
                        hideTimer.restart();
                    }
                }
            }

            onMenuOpenChanged: {
                if (!menuOpen && !headerHover.hovered)
                    hideTimer.restart();
            }

            Timer {
                id: hideTimer
                interval: 3000
                onTriggered: {
                    if (!headerRoot.menuOpen && !headerHover.hovered)
                        headerRoot.headerVisible = false;
                }
            }

            Behavior on Layout.preferredHeight {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.InOutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Thin strip that reveals the auto-hidden header.
        Item {
            id: revealStrip
            readonly property bool hovered: stripHover.hovered
            Layout.fillWidth: true
            Layout.preferredHeight: plasmoid.configuration.autoHideHeader && !headerRoot.shouldBeVisible ? 3 : 0
            z: 1

            HoverHandler {
                id: stripHover
                onHoveredChanged: {
                    if (hovered) {
                        headerRoot.headerVisible = true;
                        hideTimer.stop();
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Lazy WebEngine: created on first expansion (or when Plasma
            // preloads the representation and loadOnStartup is set),
            // destroyed by Close.
            Loader {
                id: webviewLoader
                anchors.fill: parent
                active: !root.webviewClosed && (root.expanded || item !== null || plasmoid.configuration.loadOnStartup)
                asynchronous: true
                visible: !root.settingsOpen
                sourceComponent: WebView {
                    providerModel: providerRegistry
                    hidden: !root.expanded || root.settingsOpen
                }
                onItemChanged: root.webviewRoot = item
                onStatusChanged: {
                    if (status === Loader.Error)
                        console.error("ChatAI: failed to load WebView.qml");
                }
            }

            Loader {
                id: settingsLoader
                anchors.fill: parent
                active: root.settingsOpen
                visible: active
                onActiveChanged: {
                    if (!active)
                        root.settingsModalOpen = false;
                }
                sourceComponent: SettingsPanel {
                    providerModel: providerRegistry
                    runtime: root.webviewRoot
                    category: root.settingsCategory
                    onCategoryChanged: root.settingsCategory = category
                    onCloseRequested: root.closeSettings()
                    onModalOpenChanged: root.settingsModalOpen = modalOpen
                    // Changing the storage name needs a fresh WebEngineView.
                    onProfileRecreationRequested: root.recreateWebView()
                }
            }
        }
    }
}
