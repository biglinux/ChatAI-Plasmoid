/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

// Kebab (⋮) menu of the header.
PlasmaComponents3.Menu {
    id: chatAiMenu

    // WebView.qml root, or null while the view is not loaded.
    property var webviewRoot: null
    // Items whose toolbar button is currently hidden by the overflow logic.
    property bool showFindItem: false
    property bool showHomeItem: false

    signal settingsRequested(string category)
    signal aboutRequested()
    signal shortcutsRequested()
    signal homeRequested()
    signal downloadsRequested()

    readonly property bool hasPage: webviewRoot !== null && webviewRoot.currentUrl !== ""
    readonly property int downloadAttention: webviewRoot ? webviewRoot.downloadSummary.attention + webviewRoot.downloadSummary.active : 0

    // Same as the PlasmaComponents3 default delegate, but null-safe: the stock
    // one reads parent.width before sub-menu items are parented. Note: inside
    // a MenuItem the unqualified name "menu" is MenuItem.menu, hence the id
    // chatAiMenu for this component.
    delegate: PlasmaComponents3.MenuItem {
        width: parent ? parent.width : implicitWidth
        onImplicitWidthChanged: {
            if (chatAiMenu.contentItem && chatAiMenu.contentItem.contentItem)
                chatAiMenu.contentItem.contentItem.childrenChanged();
        }
    }

    // MenuItem whose icon is drawn as a monochrome mask in the theme text
    // colour. Some icon themes (e.g. kora) ship multicolour icons for a few
    // entries (web browser, downloads, keyboard); masking keeps every menu icon
    // consistent. The layout mirrors the stock PlasmaComponents3 MenuItem.
    component MonoMenuItem: PlasmaComponents3.MenuItem {
        id: monoItem
        contentItem: RowLayout {
            Item {
                Layout.preferredWidth: (monoItem.ListView.view && monoItem.ListView.view.hasCheckables) || monoItem.checkable ? monoItem.indicator.width : Kirigami.Units.smallSpacing
            }
            Kirigami.Icon {
                Layout.alignment: Qt.AlignVCenter
                visible: (monoItem.ListView.view && monoItem.ListView.view.hasIcons) || (monoItem.icon != undefined && (monoItem.icon.name.length > 0 || monoItem.icon.source.length > 0))
                source: monoItem.icon ? (monoItem.icon.name || monoItem.icon.source) : ""
                isMask: true
                color: Kirigami.Theme.textColor
                Layout.preferredHeight: Math.max(monoLabel.height, Kirigami.Units.iconSizes.small)
                Layout.preferredWidth: Layout.preferredHeight
            }
            PlasmaComponents3.Label {
                id: monoLabel
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                text: monoItem.Kirigami.MnemonicData.richTextLabel
                font: monoItem.font
                elide: Text.ElideRight
                visible: monoItem.text
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    MonoMenuItem {
        text: i18n("Open in Browser")
        icon.name: "internet-web-browser"
        enabled: chatAiMenu.hasPage
        onTriggered: chatAiMenu.webviewRoot.openExternally()
    }

    PlasmaComponents3.MenuItem {
        text: i18n("Copy Address")
        icon.name: "edit-copy"
        enabled: chatAiMenu.hasPage
        onTriggered: chatAiMenu.webviewRoot.copyUrl()
    }

    PlasmaComponents3.MenuItem {
        text: i18n("Reload Ignoring Cache")
        icon.name: "view-refresh"
        enabled: chatAiMenu.webviewRoot !== null && !chatAiMenu.webviewRoot.clearingCache
        onTriggered: chatAiMenu.webviewRoot.reloadBypassCache()
    }

    PlasmaComponents3.MenuSeparator {}

    PlasmaComponents3.Menu {
        id: zoomMenu
        title: i18n("Zoom (%1%)", chatAiMenu.webviewRoot ? chatAiMenu.webviewRoot.zoomPercent : 100)
        icon.name: "zoom"
        enabled: chatAiMenu.webviewRoot !== null

        PlasmaComponents3.MenuItem {
            text: i18n("Zoom In")
            icon.name: "zoom-in"
            onTriggered: chatAiMenu.webviewRoot.zoomIn()
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Zoom Out")
            icon.name: "zoom-out"
            onTriggered: chatAiMenu.webviewRoot.zoomOut()
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Reset Zoom (100%)")
            icon.name: "zoom-original"
            enabled: chatAiMenu.webviewRoot !== null && chatAiMenu.webviewRoot.zoomPercent !== 100
            onTriggered: chatAiMenu.webviewRoot.zoomReset()
        }
    }

    PlasmaComponents3.MenuItem {
        text: chatAiMenu.webviewRoot && chatAiMenu.webviewRoot.fullScreenActive ? i18n("Exit Full Screen") : i18n("Full Screen")
        icon.name: chatAiMenu.webviewRoot && chatAiMenu.webviewRoot.fullScreenActive ? "view-restore" : "view-fullscreen"
        enabled: chatAiMenu.webviewRoot !== null
        onTriggered: chatAiMenu.webviewRoot.toggleFullScreen()
    }

    PlasmaComponents3.MenuSeparator {}

    // Toolbar auto-hide lives only here (no permanent toolbar button).
    PlasmaComponents3.MenuItem {
        text: i18n("Hide Toolbar Automatically")
        icon.name: "view-hidden"
        checkable: true
        checked: plasmoid.configuration.autoHideHeader
        enabled: !plasmoid.configuration.hideHeader
        onToggled: plasmoid.configuration.autoHideHeader = checked
    }

    // Downloads are always reachable here; the toolbar only shows a temporary
    // indicator while something needs attention.
    MonoMenuItem {
        text: chatAiMenu.downloadAttention > 0 ? i18n("Downloads (%1)", chatAiMenu.downloadAttention) : i18n("Downloads")
        icon.name: "folder-download"
        onTriggered: chatAiMenu.downloadsRequested()
    }

    // Overflow items (only when the toolbar is too narrow for the button)
    PlasmaComponents3.MenuSeparator {
        visible: chatAiMenu.showFindItem || chatAiMenu.showHomeItem
        height: visible ? implicitHeight : 0
    }

    PlasmaComponents3.MenuItem {
        visible: chatAiMenu.showHomeItem
        height: visible ? implicitHeight : 0
        text: i18n("Home")
        icon.name: "go-home"
        enabled: chatAiMenu.webviewRoot !== null
        onTriggered: chatAiMenu.homeRequested()
    }

    PlasmaComponents3.MenuItem {
        visible: chatAiMenu.showFindItem
        height: visible ? implicitHeight : 0
        text: i18n("Find in Page")
        icon.name: "edit-find"
        enabled: chatAiMenu.webviewRoot !== null
        onTriggered: chatAiMenu.webviewRoot.toggleFind()
    }

    PlasmaComponents3.MenuSeparator {}

    PlasmaComponents3.Menu {
        id: settingsMenu
        title: i18n("ChatAI Settings")
        icon.name: "configure"

        Repeater {
            model: [
                { id: "general", text: i18n("General"), icon: "preferences-system" },
                { id: "sites", text: i18n("Sites"), icon: "internet-services" },
                { id: "permissions", text: i18n("Permissions"), icon: "preferences-system-privacy" },
                { id: "web", text: i18n("Web Features"), icon: "preferences-web-browser-stylesheets" },
                { id: "downloads", text: i18n("Downloads"), icon: "folder-download" },
                { id: "storage", text: i18n("Cache and Data"), icon: "drive-harddisk" },
                { id: "appearance", text: i18n("Appearance"), icon: "preferences-desktop-color" },
                { id: "advanced", text: i18n("Advanced"), icon: "preferences-other" }
            ]
            delegate: MonoMenuItem {
                required property var modelData
                text: modelData.text
                icon.name: modelData.icon
                onTriggered: chatAiMenu.settingsRequested(modelData.id)
            }
        }

        PlasmaComponents3.MenuSeparator {}

        PlasmaComponents3.MenuItem {
            text: i18n("Open Configuration Window…")
            icon.name: "configure"
            enabled: plasmoid.internalAction("configure") !== null
            onTriggered: plasmoid.internalAction("configure").trigger()
        }
    }

    MonoMenuItem {
        text: i18n("Keyboard Shortcuts")
        icon.name: "input-keyboard"
        onTriggered: chatAiMenu.shortcutsRequested()
    }

    PlasmaComponents3.MenuItem {
        visible: plasmoid.configuration.enableDevTools
        height: visible ? implicitHeight : 0
        text: chatAiMenu.webviewRoot && chatAiMenu.webviewRoot.devToolsOpen ? i18n("Close Developer Tools") : i18n("Developer Tools")
        icon.name: "code-context"
        enabled: chatAiMenu.webviewRoot !== null
        onTriggered: {
            if (chatAiMenu.webviewRoot.devToolsOpen)
                chatAiMenu.webviewRoot.closeDevTools();
            else
                chatAiMenu.webviewRoot.openDevTools();
        }
    }

    PlasmaComponents3.MenuItem {
        text: i18n("About ChatAI")
        icon.name: "help-about"
        onTriggered: chatAiMenu.aboutRequested()
    }
}
