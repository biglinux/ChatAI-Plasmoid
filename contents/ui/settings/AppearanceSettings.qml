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
import org.kde.iconthemes as KIconThemes

import ".."
import "../IconModes.js" as IconModes

ColumnLayout {
    id: page

    property QtObject providerModel: internalModel
    property var runtime: null
    readonly property bool modalOpen: false

    spacing: Kirigami.Units.largeSpacing

    ProviderModel {
        id: internalModel
    }

    // Order must match IconModes.js values.
    readonly property var iconModeNames: [
        i18n("Website favicon"),
        i18n("ChatAI logo (adapts to the theme)"),
        i18n("ChatAI logo, dark"),
        i18n("ChatAI logo, light"),
        i18n("Assistant icon, outlined"),
        i18n("Assistant icon, filled"),
        i18n("Assistant icon, colorful"),
        i18n("Custom icon")
    ]

    readonly property var toolbarButtons: [
        { key: "hideKeepOpen", text: i18n("Pin") },
        { key: "hideNavigationButtons", text: i18n("Back and Forward") },
        { key: "hideRefreshButton", text: i18n("Reload") },
        { key: "hideHomeButton", text: i18n("Home") },
        { key: "hideCustomURL", text: i18n("\"Custom address…\" entry in the selector") },
        { key: "hideCloseButton", text: i18n("Close") }
    ]

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.ComboBox {
            id: iconModeCombo
            Kirigami.FormData.label: i18n("Panel icon:")
            model: page.iconModeNames
            currentIndex: plasmoid.configuration.iconMode
            onActivated: index => plasmoid.configuration.iconMode = index
            Layout.fillWidth: true
            Accessible.name: i18n("Panel icon")
        }

        QQC2.Label {
            visible: iconModeCombo.currentIndex === IconModes.Outlined || iconModeCombo.currentIndex === IconModes.Filled || iconModeCombo.currentIndex === IconModes.Colorful
            text: i18n("Assistants without a dedicated icon fall back to the ChatAI logo.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.Button {
            id: iconButton
            visible: iconModeCombo.currentIndex === IconModes.Custom
            Kirigami.FormData.label: i18n("Custom icon:")
            implicitWidth: previewIcon.width + Kirigami.Units.largeSpacing * 2
            implicitHeight: previewIcon.height + Kirigami.Units.largeSpacing
            Accessible.name: i18n("Choose custom icon")
            onClicked: iconDialog.open()

            KIconThemes.IconDialog {
                id: iconDialog
                onIconNameChanged: {
                    if (iconName)
                        plasmoid.configuration.customIcon = iconName;
                }
            }

            Kirigami.Icon {
                id: previewIcon
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.large
                height: width
                source: plasmoid.configuration.customIcon || "help-about"
            }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Toolbar buttons:")
            text: i18n("Hidden buttons remain available in the ⋮ menu where it makes sense. Auto-hide and Downloads always live in the ⋮ menu; a download indicator appears in the toolbar only while a download needs attention.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Repeater {
            model: page.toolbarButtons
            delegate: QQC2.CheckBox {
                required property var modelData
                text: modelData.text
                checked: !plasmoid.configuration[modelData.key]
                onToggled: plasmoid.configuration[modelData.key] = !checked
            }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Toolbar:")
            text: i18n("Hide Toolbar Automatically")
            checked: plasmoid.configuration.autoHideHeader
            enabled: !plasmoid.configuration.hideHeader
            onToggled: plasmoid.configuration.autoHideHeader = checked
        }

        QQC2.CheckBox {
            text: i18n("Always hide the toolbar")
            checked: plasmoid.configuration.hideHeader
            onToggled: plasmoid.configuration.hideHeader = checked
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Theme:")
            text: i18n("Colours, spacing and animations follow your Plasma theme. Pages receive a dark-mode hint when the theme is dark.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
