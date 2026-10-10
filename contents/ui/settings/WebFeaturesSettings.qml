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

// WebEngineSettings toggles, each with its consequence spelled out.
ColumnLayout {
    id: page

    property QtObject providerModel: internalModel
    property var runtime: null
    readonly property bool modalOpen: false

    spacing: Kirigami.Units.largeSpacing

    ProviderModel {
        id: internalModel
    }

    readonly property var features: [
        { key: "javascriptCanAccessClipboard", text: i18n("Let pages write to the clipboard"), hint: i18n("Needed by the \"Copy\" buttons of most assistants. Reading the clipboard is a separate permission.") },
        { key: "javascriptCanPaste", text: i18n("Let scripts paste from the clipboard"), hint: i18n("Allows a page to read the clipboard without asking. Ctrl+V works without this. Off by default for privacy.") },
        { key: "javascriptCanOpenWindows", text: i18n("Let pages open new windows"), hint: i18n("New windows are intercepted: sign-in pages stay in ChatAI, other links open in your browser.") },
        { key: "playbackRequiresUserGesture", text: i18n("Require a click before media plays"), hint: i18n("Blocks autoplaying audio and video (including voice replies) until you interact with the page.") },
        { key: "spatialNavigationEnabled", text: i18n("Spatial navigation with arrow keys"), hint: i18n("Move between links and fields with the arrow keys instead of Tab.") },
        { key: "focusOnNavigationEnabled", text: i18n("Focus the page after navigating"), hint: i18n("Lets you type immediately after the page loads. Disable if the page steals focus from the toolbar.") },
        { key: "allowUnknownUrlSchemes", text: i18n("Allow unknown link types after a click"), hint: i18n("Lets a link you click open another application (for example mailto: or a custom scheme). Links opened by scripts are still blocked.") }
    ]

    QQC2.Label {
        text: i18n("These options change how the embedded web engine behaves for every assistant. Changes apply immediately.")
        wrapMode: Text.WordWrap
        opacity: 0.8
        Layout.fillWidth: true
    }

    Repeater {
        model: page.features

        delegate: ColumnLayout {
            id: featureRow
            required property var modelData
            Layout.fillWidth: true
            spacing: 0

            QQC2.CheckBox {
                text: featureRow.modelData.text
                checked: Boolean(plasmoid.configuration[featureRow.modelData.key])
                onToggled: plasmoid.configuration[featureRow.modelData.key] = checked
            }

            QQC2.Label {
                text: featureRow.modelData.hint
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
            }
        }
    }
}
