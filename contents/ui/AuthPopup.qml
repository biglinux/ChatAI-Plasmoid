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

/*
 * Auxiliary view for pages opened with window.open() — OAuth popups above all.
 * The request is handed over with WebEngineNewWindowRequest.openIn(view), so
 * the page keeps window.opener, postMessage() reaches the main page and
 * window.close() closes this view. Same profile, same session, same settings.
 */
Item {
    id: authPopup

    required property var profile
    required property QtObject providerModel
    // Called for permission requests so the popup follows the same policy.
    property var permissionHandler: null
    property var certificateErrorHandler: null

    readonly property alias view: popupView
    readonly property string host: providerModel.hostOf(String(popupView.url))
    readonly property bool secure: String(popupView.url).indexOf("https://") === 0

    signal closeRequested()
    signal externalOpenRequested(string url)

    Kirigami.Theme.colorSet: Kirigami.Theme.Header
    Kirigami.Theme.inherit: false

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: authPopup.secure ? "security-high" : "security-low"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                Accessible.ignored: true
            }

            PlasmaComponents3.Label {
                text: authPopup.host ? i18nc("popup window title with host", "Sign in — %1", authPopup.host) : i18n("Sign in")
                elide: Text.ElideMiddle
                Layout.fillWidth: true
                Accessible.name: text
            }

            PlasmaComponents3.BusyIndicator {
                running: popupView.loading
                visible: running
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            PlasmaComponents3.ToolButton {
                icon.name: "dialog-close"
                text: i18n("Close sign-in window")
                display: PlasmaComponents3.AbstractButton.IconOnly
                Accessible.name: text
                PlasmaComponents3.ToolTip.text: text
                PlasmaComponents3.ToolTip.visible: hovered
                PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: authPopup.closeRequested()
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        WebEngineView {
            id: popupView

            Layout.fillWidth: true
            Layout.fillHeight: true
            profile: authPopup.profile
            // Mirror the main view's relevant settings; popups never spawn popups.
            settings.javascriptCanOpenWindows: true
            settings.javascriptCanAccessClipboard: true
            settings.allowWindowActivationFromJavaScript: true

            onWindowCloseRequested: authPopup.closeRequested()

            onNewWindowRequested: function (request) {
                // A second-level popup is not supported: hand it to the browser.
                const url = String(request.requestedUrl);
                if (authPopup.providerModel.isHttpUrl(url))
                    authPopup.externalOpenRequested(url);
            }

            onNavigationRequested: function (request) {
                if (request.isMainFrame && !authPopup.providerModel.isHttpUrl(String(request.url)) && String(request.url) !== "about:blank")
                    request.action = WebEngineNavigationRequest.IgnoreRequest;
            }

            onPermissionRequested: function (permission) {
                if (authPopup.permissionHandler)
                    authPopup.permissionHandler(permission);
                else
                    permission.deny();
            }

            onCertificateError: function (error) {
                if (authPopup.certificateErrorHandler)
                    authPopup.certificateErrorHandler(error);
                else
                    error.rejectCertificate();
            }

            onRenderProcessTerminated: function (terminationStatus, exitCode) {
                if (terminationStatus === WebEngineView.CrashedTerminationStatus || terminationStatus === WebEngineView.KilledTerminationStatus)
                    authPopup.closeRequested();
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: authPopup.closeRequested()
    }
}
