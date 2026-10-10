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

// General behaviour. Shared by the Plasma configuration dialog and the
// in-widget settings panel; writes plasmoid.configuration directly.
ColumnLayout {
    id: page

    property QtObject providerModel: internalModel
    property var runtime: null
    readonly property bool modalOpen: false

    spacing: Kirigami.Units.largeSpacing

    ProviderModel {
        id: internalModel
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.ComboBox {
            id: homeCombo
            Kirigami.FormData.label: i18n("Assistant:")
            Layout.fillWidth: true
            model: page.providerModel.enabledProviders
            textRole: "name"
            valueRole: "url"
            Accessible.description: i18n("The assistant shown when the widget opens and when you press Home")
            function sync() {
                const provider = page.providerModel.providerForUrl(plasmoid.configuration.url);
                currentIndex = provider ? model.findIndex(entry => entry.id === provider.id) : -1;
            }
            Component.onCompleted: sync()
            onModelChanged: sync()
            onActivated: index => {
                const entry = model[index];
                if (entry && plasmoid.configuration.url !== entry.url)
                    plasmoid.configuration.url = entry.url;
            }
            Connections {
                target: plasmoid.configuration
                function onUrlChanged() { homeCombo.sync(); }
            }
        }

        QQC2.Label {
            text: i18n("Enable more assistants in the Sites page.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Window:")
            text: i18n("Keep the widget open when clicking outside (pin)")
            checked: plasmoid.configuration.pin
            onToggled: plasmoid.configuration.pin = checked
        }

        QQC2.CheckBox {
            text: i18n("Preload the assistant when Plasma starts")
            checked: plasmoid.configuration.loadOnStartup
            onToggled: plasmoid.configuration.loadOnStartup = checked
        }

        QQC2.Label {
            text: i18n("Preloading makes the first opening instant but keeps the web engine in memory from login.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: hideHeader
            Kirigami.FormData.label: i18n("Toolbar:")
            text: i18n("Hide the toolbar")
            checked: plasmoid.configuration.hideHeader
            onToggled: plasmoid.configuration.hideHeader = checked
        }

        QQC2.CheckBox {
            text: i18n("Hide the toolbar automatically and reveal it on hover")
            enabled: !hideHeader.checked
            checked: plasmoid.configuration.autoHideHeader
            onToggled: plasmoid.configuration.autoHideHeader = checked
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Links:")
            text: i18n("Links that would open a new window are opened in your default browser. Sign-in pages stay inside ChatAI so logins keep working.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
