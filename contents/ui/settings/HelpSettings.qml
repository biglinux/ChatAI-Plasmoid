/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

// Help page: in-app shortcut reference and icon credits, with wrapping labels
// so the dialog stays responsive.
ColumnLayout {
    id: page

    spacing: Kirigami.Units.largeSpacing

    readonly property var shortcuts: [
        { keys: "Ctrl+F", text: i18n("Find in page") },
        { keys: "Ctrl++ / Ctrl+-", text: i18n("Zoom in / out") },
        { keys: "Ctrl+0", text: i18n("Reset zoom") },
        { keys: "F11", text: i18n("Full screen (Esc exits)") },
        { keys: i18nc("mouse buttons", "Mouse back / forward"), text: i18n("Navigate history") },
        { keys: "Esc", text: i18n("Close find bar, settings or full screen") }
    ]

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: i18n("ChatAI embeds the official web apps of AI assistants in a native Plasma widget, with a persistent profile, per-site permissions and a memory-conscious web engine lifecycle. It does not provide an AI API and does not bypass authentication or anti-bot protections.")
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        text: i18n("Keyboard shortcuts")
        level: 3
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        Repeater {
            model: page.shortcuts
            delegate: QQC2.Label {
                required property var modelData
                Kirigami.FormData.label: modelData.keys
                text: modelData.text
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        text: i18n("Credits")
        level: 3
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.8
        text: i18n("Provider icons: Icons8, IconScout, Simple Icons (CC0) and the services' own brand assets. Trademarks belong to their owners.")
    }
}
