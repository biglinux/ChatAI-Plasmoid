/*
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

ColumnLayout {
    id: page

    property QtObject providerModel: internalModel
    property var runtime: null
    readonly property bool modalOpen: false

    spacing: Kirigami.Units.largeSpacing

    ProviderModel {
        id: internalModel
    }

    readonly property var metaData: plasmoid.metaData
    readonly property string version: metaData && metaData.version ? metaData.version : "1.0.1"
    readonly property string website: metaData && metaData.website ? metaData.website : "https://github.com/ruscher/ChatAI-Plasmoid"
    readonly property string bugUrl: metaData && metaData.bugReportUrl ? metaData.bugReportUrl : website + "/issues"
    readonly property var authors: metaData && metaData.authors && metaData.authors.length ? metaData.authors : [
        { name: "Denys Madureira", emailAddress: "denysmb@zoho.com" },
        { name: "Bruno Gonçalves", emailAddress: "bigbruno@gmail.com" },
        { name: "Rafael Ruscher", emailAddress: "rruscher@gmail.com" }
    ]
    readonly property string contrast: {
        const color = Kirigami.Theme.backgroundColor;
        return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) > 0.5 ? "dark" : "light";
    }

    readonly property var shortcuts: [
        { keys: "Ctrl+F", text: i18n("Find in page") },
        { keys: "Ctrl++ / Ctrl+-", text: i18n("Zoom in / out") },
        { keys: "Ctrl+0", text: i18n("Reset zoom") },
        { keys: "F11", text: i18n("Full screen (Esc exits)") },
        { keys: i18nc("mouse buttons", "Mouse back / forward"), text: i18n("Navigate history") },
        { keys: "Esc", text: i18n("Close find bar, settings or full screen") }
    ]

    RowLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            source: Qt.resolvedUrl("../assets/logo-" + page.contrast + ".svg")
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            isMask: false
        }

        ColumnLayout {
            spacing: 0
            Kirigami.Heading {
                text: i18n("ChatAI")
                level: 1
            }
            QQC2.Label {
                text: i18n("Version %1", page.version)
                opacity: 0.8
            }
            QQC2.Label {
                text: i18n("AI assistants inside KDE Plasma")
                wrapMode: Text.WordWrap
            }
        }
    }

    QQC2.Label {
        text: i18n("ChatAI embeds the official web apps of AI assistants in a native Plasma widget, with a persistent profile, per-site permissions and a memory-conscious web engine lifecycle. It does not provide an AI API and does not bypass authentication or anti-bot protections.")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        Kirigami.UrlButton {
            Kirigami.FormData.label: i18n("Repository:")
            url: page.website
        }

        Kirigami.UrlButton {
            Kirigami.FormData.label: i18n("Report a problem:")
            url: page.bugUrl
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("License:")
            text: "GPL-2.0-or-later"
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        text: i18n("Authors")
        level: 3
    }

    Repeater {
        model: page.authors
        delegate: QQC2.Label {
            required property var modelData
            text: modelData.emailAddress ? "%1 <%2>".arg(modelData.name).arg(modelData.emailAddress) : modelData.name
            textFormat: Text.PlainText
        }
    }

    QQC2.Label {
        text: i18n("Provider icons: Icons8, IconScout, Simple Icons (CC0) and the services' own brand assets. Trademarks belong to their owners.")
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        text: i18n("Keyboard shortcuts")
        level: 3
    }

    GridLayout {
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.smallSpacing

        Repeater {
            model: page.shortcuts
            delegate: QQC2.Label {
                required property var modelData
                required property int index
                text: modelData.keys
                font.bold: true
                Layout.row: index
                Layout.column: 0
            }
        }

        Repeater {
            model: page.shortcuts
            delegate: QQC2.Label {
                required property var modelData
                required property int index
                text: modelData.text
                Layout.row: index
                Layout.column: 1
                Layout.fillWidth: true
            }
        }
    }
}
