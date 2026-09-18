/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtWebEngine

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import ".."

// Technical options and a sanitized diagnostics block.
ColumnLayout {
    id: page

    property QtObject providerModel: internalModel
    property var runtime: null
    readonly property bool modalOpen: false

    spacing: Kirigami.Units.largeSpacing

    ProviderModel {
        id: internalModel
    }

    function lifecycleName(state) {
        switch (state) {
        case WebEngineView.LifecycleState.Frozen: return "Frozen";
        case WebEngineView.LifecycleState.Discarded: return "Discarded";
        default: return "Active";
        }
    }

    function diagnostics() {
        const ua = String(WebEngine.defaultProfile.httpUserAgent);
        const webEngineVersion = (ua.match(/QtWebEngine\/([\d.]+)/) || [])[1] || i18n("unknown");
        const chromium = (ua.match(/Chrome\/([\d.]+)/) || [])[1] || i18n("unknown");
        const provider = providerModel.providerForUrl(plasmoid.configuration.url);
        const lines = [
            "ChatAI " + (plasmoid.metaData ? plasmoid.metaData.version : ""),
            "Qt WebEngine: " + webEngineVersion + " (Chromium " + chromium + ")",
            "Platform: " + Qt.platform.pluginName + " / " + Qt.platform.os,
            "Provider: " + (provider ? provider.id : i18n("custom")),
            "Profile: " + String(plasmoid.configuration.webEngineProfileName || providerModel.defaultProfileName),
            "Zoom: " + Math.round((Number(plasmoid.configuration.zoomFactor) || 1) * 100) + "%",
            "Compatibility UA: " + (plasmoid.configuration.compatibilityUserAgent ? "on" : "off")
        ];
        if (runtime) {
            lines.push("Render PID: " + runtime.renderProcessPid);
            lines.push("Lifecycle: " + lifecycleName(runtime.lifecycleState) + " (recommended " + lifecycleName(runtime.recommendedState) + ")");
            lines.push("URL: " + providerModel.hostOf(runtime.currentUrl));
        }
        return lines.join("\n");
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        type: Kirigami.MessageType.Warning
        visible: true
        text: i18n("These options are for troubleshooting. The defaults are the safe choice.")
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Browser identity:")
            text: i18n("Identify as Chromium (hide the Qt WebEngine token)")
            checked: plasmoid.configuration.compatibilityUserAgent
            onToggled: plasmoid.configuration.compatibilityUserAgent = checked
        }

        QQC2.Label {
            text: i18n("Not recommended for Google accounts: Google rejects browsers that hide their identity (\"This browser or app may not be secure\") and accepts the honest Qt WebEngine identity. Enable only if a specific site refuses the Qt WebEngine token.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Custom user agent:")
            Layout.fillWidth: true
            text: plasmoid.configuration.customUserAgent
            placeholderText: i18n("Leave empty for the default")
            onEditingFinished: plasmoid.configuration.customUserAgent = text.trim()
            Accessible.name: i18n("Custom user agent")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Resources:")
            text: i18n("Freeze the page while the widget is hidden")
            checked: plasmoid.configuration.freezeWhenHidden
            onToggled: plasmoid.configuration.freezeWhenHidden = checked
        }

        QQC2.Label {
            text: i18n("Pauses scripts of the hidden page after 30 seconds when the engine reports it is safe (no audio, upload or download). Resumes instantly on opening.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Discard hidden page after:")
            from: 0
            to: 720
            stepSize: 5
            value: plasmoid.configuration.discardAfterMinutes
            textFromValue: (value, locale) => value === 0 ? i18n("Never") : i18np("%1 minute", "%1 minutes", value)
            valueFromText: (text, locale) => parseInt(text) || 0
            onValueModified: plasmoid.configuration.discardAfterMinutes = value
            Accessible.name: i18n("Discard hidden page after")
        }

        QQC2.Label {
            text: i18n("Discarding frees most memory but reloads the page on the next opening; unsent text is lost.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Developer tools:")
            text: i18n("Show \"Developer Tools\" in the ⋮ menu")
            checked: plasmoid.configuration.enableDevTools
            onToggled: plasmoid.configuration.enableDevTools = checked
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        text: i18n("Diagnostics")
        level: 3
    }

    QQC2.TextArea {
        id: diagnosticsArea
        Layout.fillWidth: true
        readOnly: true
        wrapMode: TextEdit.Wrap
        font.family: "monospace"
        text: page.diagnostics()
        Accessible.name: i18n("Diagnostics")
    }

    RowLayout {
        spacing: Kirigami.Units.smallSpacing

        QQC2.Button {
            icon.name: "view-refresh"
            text: i18n("Refresh")
            onClicked: diagnosticsArea.text = page.diagnostics()
        }

        QQC2.Button {
            icon.name: "edit-copy"
            text: i18n("Copy Diagnostics")
            onClicked: {
                diagnosticsArea.selectAll();
                diagnosticsArea.copy();
                diagnosticsArea.deselect();
            }
        }
    }

    QQC2.Label {
        text: i18n("No cookies, tokens or page contents are included.")
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
}
