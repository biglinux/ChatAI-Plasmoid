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

import "IconModes.js" as IconModes

// Provider picker: icon + name, keyboard accessible, fed by ProviderModel.
// Selecting an entry writes plasmoid.configuration.url and emits selected().
PlasmaComponents3.ComboBox {
    id: selector

    required property QtObject providerModel

    signal selected()
    signal customAddressRequested()

    readonly property string customEntryId: "__custom__"
    readonly property var entries: {
        const list = providerModel.enabledProviders.slice();
        if (!plasmoid.configuration.hideCustomURL)
            list.push({ id: customEntryId, name: i18n("Custom address…"), url: "", iconId: "", iconStyles: [], custom: true, isCustomEntry: true });
        return list;
    }
    readonly property var currentProvider: providerModel.providerForUrl(plasmoid.configuration.url)
    readonly property string contrast: {
        const color = Kirigami.Theme.backgroundColor;
        return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) > 0.5 ? "dark" : "light";
    }

    function iconFor(provider) {
        if (!provider || provider.isCustomEntry)
            return provider && provider.isCustomEntry ? "link" : Qt.resolvedUrl("assets/logo-" + contrast + ".svg");
        const source = providerModel.iconSource(provider, "colorful", contrast);
        return source ? Qt.resolvedUrl(source) : Qt.resolvedUrl("assets/logo-" + contrast + ".svg");
    }

    function syncIndex() {
        const provider = currentProvider;
        let index = -1;
        if (provider)
            index = entries.findIndex(entry => entry.id === provider.id);
        currentIndex = index;
    }

    model: entries
    textRole: "name"
    valueRole: "id"
    displayText: currentIndex >= 0 ? currentText : providerModel.nameForUrl(plasmoid.configuration.url)
    Accessible.name: i18n("AI assistant")
    Accessible.description: displayText

    Layout.fillWidth: true
    Layout.minimumWidth: Kirigami.Units.gridUnit * 7

    PlasmaComponents3.ToolTip.text: i18n("Choose the AI assistant")
    PlasmaComponents3.ToolTip.visible: hovered && !popup.visible
    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay

    Component.onCompleted: syncIndex()
    onEntriesChanged: syncIndex()

    Connections {
        target: plasmoid.configuration
        function onUrlChanged() { selector.syncIndex(); }
    }

    onActivated: index => {
        const entry = entries[index];
        if (!entry)
            return;
        if (entry.isCustomEntry) {
            syncIndex();
            customAddressRequested();
            return;
        }
        if (plasmoid.configuration.url !== entry.url)
            plasmoid.configuration.url = entry.url;
        selected();
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: selector.iconFor(selector.currentIndex >= 0 ? selector.entries[selector.currentIndex] : selector.currentProvider)
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            Layout.leftMargin: Kirigami.Units.smallSpacing
        }

        PlasmaComponents3.Label {
            text: selector.displayText
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    delegate: PlasmaComponents3.ItemDelegate {
        id: delegateItem

        required property int index
        required property var modelData

        width: ListView.view ? ListView.view.width : implicitWidth
        highlighted: selector.highlightedIndex === index
        text: modelData.name
        Accessible.name: modelData.name

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: selector.iconFor(delegateItem.modelData)
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            PlasmaComponents3.Label {
                text: delegateItem.modelData.name
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                visible: !delegateItem.modelData.custom && Boolean(delegateItem.modelData.category)
                text: selector.providerModel.categoryName(delegateItem.modelData.category)
                font: Kirigami.Theme.smallFont
                opacity: 0.6
            }
        }
    }
}
