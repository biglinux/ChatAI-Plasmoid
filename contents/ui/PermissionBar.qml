/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Layouts
import QtWebEngine

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Inline prompt shown when a site asks for a permission whose policy is "Ask".
// The decision is persisted per origin by Qt WebEngine (StoreOnDisk).
Rectangle {
    id: permissionBar

    // A WebEnginePermission value (or null when nothing is pending).
    property var permission: null
    readonly property bool active: permission !== null && permission !== undefined

    signal granted()
    signal denied()

    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false
    color: Kirigami.Theme.backgroundColor
    border.color: Kirigami.Theme.highlightColor
    border.width: 1
    radius: Kirigami.Units.cornerRadius
    visible: active
    implicitHeight: active ? row.implicitHeight + Kirigami.Units.smallSpacing * 2 : 0
    Accessible.role: Accessible.AlertMessage
    Accessible.name: messageLabel.text

    function typeInfo(type, host) {
        switch (type) {
        case WebEnginePermission.PermissionType.Notifications:
            return { icon: "preferences-desktop-notification", text: i18n("%1 wants to show notifications", host) };
        case WebEnginePermission.PermissionType.MediaAudioCapture:
            return { icon: "audio-input-microphone", text: i18n("%1 wants to use your microphone", host) };
        case WebEnginePermission.PermissionType.MediaVideoCapture:
            return { icon: "camera-web", text: i18n("%1 wants to use your camera", host) };
        case WebEnginePermission.PermissionType.MediaAudioVideoCapture:
            return { icon: "camera-web", text: i18n("%1 wants to use your camera and microphone", host) };
        case WebEnginePermission.PermissionType.DesktopVideoCapture:
        case WebEnginePermission.PermissionType.DesktopAudioVideoCapture:
            return { icon: "video-display", text: i18n("%1 wants to share your screen", host) };
        case WebEnginePermission.PermissionType.Geolocation:
            return { icon: "mark-location", text: i18n("%1 wants to know your location", host) };
        case WebEnginePermission.PermissionType.ClipboardReadWrite:
            return { icon: "edit-paste", text: i18n("%1 wants to read your clipboard", host) };
        default:
            return { icon: "dialog-question", text: i18n("%1 requests a permission", host) };
        }
    }

    readonly property var info: active ? typeInfo(permission.permissionType, originHost) : ({ icon: "", text: "" })
    readonly property string originHost: active ? String(permission.origin).replace(/^[a-z]+:\/\//i, "").replace(/\/.*$/, "") : ""

    RowLayout {
        id: row

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Kirigami.Units.smallSpacing
        }
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: permissionBar.info.icon
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            PlasmaComponents3.Label {
                id: messageLabel
                text: permissionBar.info.text
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                text: i18n("Your choice is remembered for this site. Review it in Settings › Permissions.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        PlasmaComponents3.Button {
            text: i18n("Block")
            icon.name: "dialog-cancel"
            onClicked: permissionBar.denied()
        }

        PlasmaComponents3.Button {
            text: i18n("Allow")
            icon.name: "dialog-ok-apply"
            onClicked: permissionBar.granted()
        }
    }
}
