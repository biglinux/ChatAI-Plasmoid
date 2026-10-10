/*
 *  SPDX-FileCopyrightText: 2025 Bruno Gonçalves <bigbruno@gmail.com>
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import ".."

// Cache, site data and the WebEngine profile. Paths follow the documented
// WebEngineProfile defaults so no WebEngine instance is needed here.
ColumnLayout {
    id: page

    property QtObject providerModel: internalModel
    property var runtime: null
    readonly property bool modalOpen: false

    signal profileRecreationRequested()

    spacing: Kirigami.Units.largeSpacing

    ProviderModel {
        id: internalModel
    }

    function sanitizeProfileName(value) {
        return String(value || "").trim().replace(/[^A-Za-z0-9._-]/g, "-").slice(0, 64) || providerModel.defaultProfileName;
    }

    function stripFile(value) {
        return String(value || "").replace(/^file:\/\/(localhost)?/, "");
    }

    readonly property string profileName: sanitizeProfileName(plasmoid.configuration.webEngineProfileName)
    readonly property string cachePath: stripFile(StandardPaths.writableLocation(StandardPaths.CacheLocation)) + "/QtWebEngine/" + profileName
    readonly property string storagePath: stripFile(StandardPaths.writableLocation(StandardPaths.AppLocalDataLocation)) + "/QtWebEngine/" + profileName
    property string pendingProfileName: ""

    Kirigami.Heading {
        text: i18n("HTTP cache")
        level: 3
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.Label {
            Kirigami.FormData.label: i18n("Location:")
            text: page.cachePath
            wrapMode: Text.WrapAnywhere
            Layout.fillWidth: true
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Size limit:")
            from: 0
            to: 4096
            stepSize: 50
            value: plasmoid.configuration.httpCacheMaximumSize
            textFromValue: (value, locale) => value === 0 ? i18n("Automatic") : i18n("%1 MiB", value)
            valueFromText: (text, locale) => parseInt(text) || 0
            onValueModified: plasmoid.configuration.httpCacheMaximumSize = value
            Accessible.name: i18n("Cache size limit")
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                icon.name: "edit-clear-history"
                text: page.runtime && page.runtime.clearingCache ? i18n("Clearing…") : i18n("Clear Cache")
                enabled: page.runtime !== null && !page.runtime.clearingCache
                onClicked: page.runtime.clearHttpCache()
            }

            QQC2.BusyIndicator {
                running: page.runtime !== null && page.runtime.clearingCache
                visible: running
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            }

            QQC2.Button {
                icon.name: "folder-open"
                text: i18n("Open Cache Folder")
                onClicked: Qt.openUrlExternally("file://" + page.cachePath)
            }
        }

        QQC2.Label {
            text: page.runtime === null
                ? i18n("Open the ChatAI widget to clear the cache. Clearing removes downloaded page resources only; you stay signed in.")
                : i18n("Clearing removes downloaded page resources only; you stay signed in. Navigation is paused until it finishes.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        text: i18n("Site data and sessions")
        level: 3
    }

    QQC2.Label {
        text: i18n("Cookies, logins, local storage and per-site permissions live in the profile folder below. Qt WebEngine offers no way to wipe cookies from a widget while it is running: to end a session, use the site's own \"Sign out\", or switch to a new profile name. Site permissions can be reset in the Permissions page.")
        wrapMode: Text.WordWrap
        opacity: 0.8
        Layout.fillWidth: true
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        text: i18n("WebEngine profile")
        level: 3
    }

    QQC2.Label {
        text: i18n("Each storage name is a separate folder with its own cookies, logins, cache and permissions. Use different names to keep separate accounts in different widget instances.")
        wrapMode: Text.WordWrap
        opacity: 0.8
        Layout.fillWidth: true
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        RowLayout {
            Kirigami.FormData.label: i18n("Storage name:")
            Layout.fillWidth: true

            QQC2.TextField {
                id: profileField
                Layout.fillWidth: true
                text: page.profileName
                placeholderText: page.providerModel.defaultProfileName
                validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9._-]{0,64}/ }
                Accessible.name: i18n("Storage name")
                onAccepted: applyButton.clicked()
            }

            QQC2.Button {
                id: applyButton
                text: i18n("Apply")
                icon.name: "dialog-ok-apply"
                enabled: page.sanitizeProfileName(profileField.text) !== page.profileName
                onClicked: {
                    page.pendingProfileName = page.sanitizeProfileName(profileField.text);
                    profileDialog.open();
                }
            }

            QQC2.Button {
                text: i18n("Default")
                icon.name: "edit-reset"
                enabled: page.profileName !== page.providerModel.defaultProfileName
                onClicked: {
                    page.pendingProfileName = page.providerModel.defaultProfileName;
                    profileDialog.open();
                }
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Folder:")
            text: page.storagePath
            wrapMode: Text.WrapAnywhere
            Layout.fillWidth: true
        }

        QQC2.Button {
            icon.name: "folder-open"
            text: i18n("Open Profile Folder")
            onClicked: Qt.openUrlExternally("file://" + page.storagePath)
        }
    }

    Kirigami.PromptDialog {
        id: profileDialog
        title: i18n("Switch WebEngine profile?")
        subtitle: i18n("The assistant will reload using the profile \"%1\". You will be signed out of the current sessions until you sign in again; the data of the previous profile stays on disk and can be removed from its folder.", page.pendingProfileName)
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            plasmoid.configuration.webEngineProfileName = page.pendingProfileName;
            profileField.text = page.pendingProfileName;
            page.profileRecreationRequested();
        }
        onRejected: profileField.text = page.profileName
    }
}
