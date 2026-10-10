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

// Global permission policies per type plus the per-site decisions stored by
// Qt WebEngine.
ColumnLayout {
    id: page

    property QtObject providerModel: internalModel
    property var runtime: null
    readonly property bool modalOpen: false

    spacing: Kirigami.Units.largeSpacing

    ProviderModel {
        id: internalModel
    }

    readonly property var policyNames: [i18n("Ask per site"), i18n("Always allow"), i18n("Always block")]

    readonly property var permissionTypes: [
        { key: "notificationsPolicy", label: i18n("Notifications:"), icon: "preferences-desktop-notification", hint: i18n("Shown as Plasma notifications.") },
        { key: "microphonePolicy", label: i18n("Microphone:"), icon: "audio-input-microphone", hint: i18n("Voice input. Only active while a site you allowed is recording.") },
        { key: "webcamPolicy", label: i18n("Camera:"), icon: "camera-web", hint: "" },
        { key: "screenSharePolicy", label: i18n("Screen sharing:"), icon: "video-display", hint: i18n("The primary screen is shared when allowed.") },
        { key: "geolocationPolicy", label: i18n("Location:"), icon: "mark-location", hint: "" },
        { key: "clipboardPolicy", label: i18n("Read clipboard:"), icon: "edit-paste", hint: i18n("Lets a page read what you copied. Pasting with Ctrl+V never needs this.") }
    ]

    function typeName(type) {
        switch (type) {
        case WebEnginePermission.PermissionType.Notifications: return i18n("Notifications");
        case WebEnginePermission.PermissionType.MediaAudioCapture: return i18n("Microphone");
        case WebEnginePermission.PermissionType.MediaVideoCapture: return i18n("Camera");
        case WebEnginePermission.PermissionType.MediaAudioVideoCapture: return i18n("Camera and microphone");
        case WebEnginePermission.PermissionType.DesktopVideoCapture:
        case WebEnginePermission.PermissionType.DesktopAudioVideoCapture: return i18n("Screen sharing");
        case WebEnginePermission.PermissionType.Geolocation: return i18n("Location");
        case WebEnginePermission.PermissionType.ClipboardReadWrite: return i18n("Clipboard");
        case WebEnginePermission.PermissionType.MouseLock: return i18n("Mouse lock");
        case WebEnginePermission.PermissionType.LocalFontsAccess: return i18n("Local fonts");
        default: return i18n("Other");
        }
    }

    function stateName(state) {
        switch (state) {
        case WebEnginePermission.State.Granted: return i18n("Allowed");
        case WebEnginePermission.State.Denied: return i18n("Blocked");
        case WebEnginePermission.State.Ask: return i18n("Ask");
        default: return i18n("Unknown");
        }
    }

    function sitePermissions() {
        if (!runtime)
            return [];
        // Depend on the revision so the list refreshes after grant/deny/reset.
        void runtime.permissionsRevision;
        return runtime.listPermissions().filter(permission => permission.isValid);
    }

    readonly property var savedPermissions: sitePermissions()

    Kirigami.Heading {
        text: i18n("Default behaviour")
        level: 3
    }

    QQC2.Label {
        text: i18n("\"Ask per site\" shows a prompt inside ChatAI the first time a site requests the permission; the answer is remembered for that site.")
        wrapMode: Text.WordWrap
        opacity: 0.8
        Layout.fillWidth: true
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        Repeater {
            model: page.permissionTypes

            delegate: ColumnLayout {
                id: policyRow
                required property var modelData
                Kirigami.FormData.label: modelData.label
                spacing: 0

                QQC2.ComboBox {
                    model: page.policyNames
                    currentIndex: Math.min(2, Math.max(0, Number(plasmoid.configuration[policyRow.modelData.key]) || 0))
                    onActivated: index => plasmoid.configuration[policyRow.modelData.key] = index
                    Accessible.name: policyRow.modelData.label
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                }

                QQC2.Label {
                    visible: text !== ""
                    text: policyRow.modelData.hint
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        text: i18n("Saved site permissions")
        level: 3
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: page.runtime === null
        type: Kirigami.MessageType.Information
        text: i18n("Open the ChatAI widget to review the permissions saved per site. They are stored in the web engine profile.")
    }

    QQC2.Label {
        visible: page.runtime !== null && page.savedPermissions.length === 0
        text: i18n("No site has saved permissions yet.")
        opacity: 0.7
    }

    Repeater {
        model: page.savedPermissions

        delegate: RowLayout {
            id: permissionRow
            required property var modelData
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: String(permissionRow.modelData.origin).replace(/^[a-z]+:\/\//i, "").replace(/\/$/, "")
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: page.typeName(permissionRow.modelData.permissionType)
                opacity: 0.8
            }
            QQC2.Label {
                text: page.stateName(permissionRow.modelData.state)
                font.bold: true
                color: permissionRow.modelData.state === WebEnginePermission.State.Granted ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
            }
            QQC2.ToolButton {
                icon.name: "edit-undo"
                text: i18n("Reset")
                display: QQC2.AbstractButton.IconOnly
                onClicked: page.runtime.resetPermission(permissionRow.modelData)
                QQC2.ToolTip.text: i18n("Ask again next time")
                QQC2.ToolTip.visible: hovered
            }
        }
    }

    QQC2.Button {
        visible: page.runtime !== null && page.savedPermissions.length > 0
        icon.name: "edit-clear-all"
        text: i18n("Reset All Site Permissions…")
        onClicked: resetDialog.open()
    }

    Kirigami.PromptDialog {
        id: resetDialog
        title: i18n("Reset all site permissions?")
        subtitle: i18n("Every site will ask again the next time it needs a permission. Logins are not affected.")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: page.runtime.resetAllPermissions()
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    QQC2.Label {
        text: i18n("Privacy: the microphone, camera, screen and location are only used after you allow them, and only by the site that asked. Login data belongs to the web engine profile (see Cache and Data). ChatAI does not read page contents or credentials.")
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.8
        Layout.fillWidth: true
    }
}
