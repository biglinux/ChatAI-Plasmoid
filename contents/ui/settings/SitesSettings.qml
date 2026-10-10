/*
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *  SPDX-FileCopyrightText: 2025 Bruno Gonçalves <bigbruno@gmail.com>
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import ".."

// Built-in assistants (switches) and custom sites (JSON in customSitesJson).
ColumnLayout {
    id: page

    property QtObject providerModel: internalModel
    property var runtime: null
    readonly property bool modalOpen: false

    // Index of the custom site being edited, or -1 when adding.
    property int editingIndex: -1

    spacing: Kirigami.Units.largeSpacing

    ProviderModel {
        id: internalModel
    }

    readonly property string contrast: {
        const color = Kirigami.Theme.backgroundColor;
        return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) > 0.5 ? "dark" : "light";
    }

    function iconFor(provider) {
        const source = providerModel.iconSource(provider, "colorful", contrast);
        return Qt.resolvedUrl(source ? "../" + source : "../assets/logo-" + contrast + ".svg");
    }

    function saveCustomSites(list) {
        plasmoid.configuration.customSitesJson = providerModel.serializeCustomProviders(list);
    }

    function customList() {
        return providerModel.customProviders.map(entry => ({ name: entry.name, url: entry.url }));
    }

    function submitCustomSite() {
        const name = nameField.text.trim();
        const url = providerModel.normalizeUrl(urlField.text);
        if (!name || !url) {
            validationMessage.visible = true;
            return;
        }
        const list = customList();
        const duplicate = list.findIndex((entry, index) => index !== editingIndex && (entry.name.toLowerCase() === name.toLowerCase() || entry.url === url));
        if (duplicate !== -1) {
            validationMessage.text = i18n("A custom site with this name or address already exists.");
            validationMessage.visible = true;
            return;
        }
        if (editingIndex >= 0 && editingIndex < list.length)
            list[editingIndex] = { name: name, url: url };
        else
            list.push({ name: name, url: url });
        saveCustomSites(list);
        cancelEdit();
    }

    function editCustomSite(index) {
        const list = customList();
        if (index < 0 || index >= list.length)
            return;
        editingIndex = index;
        nameField.text = list[index].name;
        urlField.text = list[index].url;
        nameField.forceActiveFocus();
    }

    function removeCustomSite(index) {
        const list = customList();
        if (index < 0 || index >= list.length)
            return;
        list.splice(index, 1);
        saveCustomSites(list);
        if (editingIndex === index)
            cancelEdit();
    }

    function cancelEdit() {
        editingIndex = -1;
        nameField.text = "";
        urlField.text = "";
        validationMessage.visible = false;
        validationMessage.text = i18n("Enter a name and a valid http:// or https:// address.");
    }

    Kirigami.Heading {
        text: i18n("Built-in assistants")
        level: 3
    }

    QQC2.Label {
        text: i18n("Enabled assistants appear in the toolbar selector. ChatAI embeds each service's official website; accounts, limits and features are controlled by the service.")
        wrapMode: Text.WordWrap
        opacity: 0.8
        Layout.fillWidth: true
    }

    Repeater {
        model: page.providerModel.builtInProviders

        delegate: QQC2.SwitchDelegate {
            id: providerDelegate
            required property var modelData

            Layout.fillWidth: true
            checked: Boolean(plasmoid.configuration[modelData.configKey])
            onToggled: plasmoid.configuration[modelData.configKey] = checked
            Accessible.name: modelData.name
            text: modelData.name

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: page.iconFor(providerDelegate.modelData)
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    isMask: false
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        QQC2.Label {
                            text: providerDelegate.modelData.name
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            text: page.providerModel.categoryName(providerDelegate.modelData.category)
                            font: Kirigami.Theme.smallFont
                            opacity: 0.6
                        }
                        QQC2.Label {
                            visible: providerDelegate.modelData.requiresLogin
                            text: i18n("Login required")
                            font: Kirigami.Theme.smallFont
                            opacity: 0.6
                        }
                    }

                    QQC2.Label {
                        text: providerDelegate.modelData.description || ""
                        visible: text !== ""
                        font: Kirigami.Theme.smallFont
                        opacity: 0.8
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    QQC2.Label {
                        text: [providerDelegate.modelData.loginNotes, providerDelegate.modelData.compatibilityNotes].filter(Boolean).join(" ")
                        visible: providerDelegate.checked && text !== ""
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        text: i18n("Custom sites")
        level: 3
    }

    QQC2.Label {
        text: i18n("Add any chat website by name and address. Custom sites use the ChatAI icon and get no special access to your system.")
        wrapMode: Text.WordWrap
        opacity: 0.8
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        QQC2.TextField {
            id: nameField
            placeholderText: i18n("Name")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
            onAccepted: page.submitCustomSite()
            Accessible.name: i18n("Site name")
        }

        QQC2.TextField {
            id: urlField
            placeholderText: "https://example.com/chat"
            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
            Layout.fillWidth: true
            onAccepted: page.submitCustomSite()
            Accessible.name: i18n("Site address")
        }

        QQC2.Button {
            icon.name: page.editingIndex >= 0 ? "document-save" : "list-add"
            text: page.editingIndex >= 0 ? i18n("Save") : i18n("Add")
            onClicked: page.submitCustomSite()
        }

        QQC2.ToolButton {
            visible: page.editingIndex >= 0
            icon.name: "dialog-cancel"
            text: i18n("Cancel editing")
            display: QQC2.AbstractButton.IconOnly
            onClicked: page.cancelEdit()
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
        }
    }

    Kirigami.InlineMessage {
        id: validationMessage
        Layout.fillWidth: true
        type: Kirigami.MessageType.Warning
        visible: false
        text: i18n("Enter a name and a valid http:// or https:// address.")
    }

    Repeater {
        model: page.providerModel.customProviders

        delegate: QQC2.ItemDelegate {
            id: customDelegate
            required property int index
            required property var modelData

            Layout.fillWidth: true
            text: modelData.name
            highlighted: page.editingIndex === index
            onClicked: page.editCustomSite(index)
            Accessible.name: i18n("%1 — %2", modelData.name, modelData.url)

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "link"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    QQC2.Label {
                        text: customDelegate.modelData.name
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    QQC2.Label {
                        text: customDelegate.modelData.url
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }

                QQC2.ToolButton {
                    icon.name: "document-edit"
                    text: i18n("Edit")
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: page.editCustomSite(customDelegate.index)
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                }

                QQC2.ToolButton {
                    icon.name: "list-remove"
                    text: i18n("Remove")
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: page.removeCustomSite(customDelegate.index)
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                }
            }
        }
    }

    Kirigami.PlaceholderMessage {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        visible: page.providerModel.customProviders.length === 0
        text: i18n("No custom sites added yet")
        icon.name: "link"
    }
}
