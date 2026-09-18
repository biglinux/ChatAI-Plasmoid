/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

/*
 * In-widget settings host. Shows the same page components used by the Plasma
 * configuration dialog (contents/ui/settings/), bound to the same
 * plasmoid.configuration — one backend, two hosts.
 */
Item {
    id: panel

    required property QtObject providerModel
    // WebView.qml root while loaded; pages use it for cache/permission actions.
    property var runtime: null
    property string category: "general"

    signal closeRequested()
    signal profileRecreationRequested()

    readonly property bool modalOpen: pageLoader.item ? Boolean(pageLoader.item.modalOpen) : false
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 34

    readonly property var categories: [
        { id: "general", text: i18n("General"), icon: "preferences-system", source: "settings/GeneralSettings.qml" },
        { id: "sites", text: i18n("Sites"), icon: "internet-services", source: "settings/SitesSettings.qml" },
        { id: "permissions", text: i18n("Permissions"), icon: "preferences-system-privacy", source: "settings/PermissionsSettings.qml" },
        { id: "web", text: i18n("Web Features"), icon: "preferences-web-browser-stylesheets", source: "settings/WebFeaturesSettings.qml" },
        { id: "downloads", text: i18n("Downloads"), icon: "folder-download", source: "settings/DownloadsSettings.qml" },
        { id: "storage", text: i18n("Cache and Data"), icon: "drive-harddisk", source: "settings/StorageSettings.qml" },
        { id: "appearance", text: i18n("Appearance"), icon: "preferences-desktop-color", source: "settings/AppearanceSettings.qml" },
        { id: "advanced", text: i18n("Advanced"), icon: "preferences-other", source: "settings/AdvancedSettings.qml" },
        { id: "about", text: i18n("About"), icon: "help-about", source: "settings/AboutSettings.qml" }
    ]

    readonly property int currentIndex: Math.max(0, categories.findIndex(entry => entry.id === category))
    readonly property var currentEntry: categories[currentIndex]

    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    Shortcut {
        sequence: "Escape"
        onActivated: panel.closeRequested()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Category list
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: panel.narrow ? Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing * 3 : Kirigami.Units.gridUnit * 11
            Layout.maximumWidth: Layout.preferredWidth
            spacing: 0

            ListView {
                id: categoryList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: panel.categories
                currentIndex: panel.currentIndex
                keyNavigationEnabled: true
                Accessible.name: i18n("Settings categories")

                delegate: PlasmaComponents3.ItemDelegate {
                    id: categoryDelegate
                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.text
                    icon.name: modelData.icon
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    padding: Kirigami.Units.smallSpacing + Kirigami.Units.smallSpacing / 2
                    display: panel.narrow ? PlasmaComponents3.AbstractButton.IconOnly : PlasmaComponents3.AbstractButton.TextBesideIcon
                    highlighted: ListView.isCurrentItem
                    Accessible.name: modelData.text
                    PlasmaComponents3.ToolTip.text: modelData.text
                    PlasmaComponents3.ToolTip.visible: panel.narrow && hovered
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: panel.category = modelData.id
                }
            }
        }

        Kirigami.Separator {
            Layout.fillHeight: true
        }

        // Page
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: panel.currentEntry.icon
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }

                Kirigami.Heading {
                    text: panel.currentEntry.text
                    level: 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "dialog-close"
                    text: i18n("Back to the assistant")
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    Accessible.name: text
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: panel.closeRequested()
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            QQC2.ScrollView {
                id: scrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                contentHeight: pageLoader.height + Kirigami.Units.largeSpacing * 2
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                Loader {
                    id: pageLoader
                    x: Kirigami.Units.largeSpacing
                    y: Kirigami.Units.largeSpacing
                    width: scrollView.availableWidth - Kirigami.Units.largeSpacing * 2
                    function loadPage() {
                        setSource(panel.currentEntry.source, { providerModel: panel.providerModel });
                    }
                    Component.onCompleted: loadPage()
                    Connections {
                        target: panel
                        function onCurrentEntryChanged() { pageLoader.loadPage(); }
                    }
                    onLoaded: {
                        item.runtime = Qt.binding(() => panel.runtime);
                        if (item.profileRecreationRequested !== undefined)
                            item.profileRecreationRequested.connect(panel.profileRecreationRequested);
                    }
                }
            }
        }
    }
}
