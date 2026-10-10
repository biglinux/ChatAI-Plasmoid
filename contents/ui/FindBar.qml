/*
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *  SPDX-FileCopyrightText: 2025 Bruno Gonçalves <bigbruno@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Layouts
import QtWebEngine

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Find-in-page bar. Sized through implicitHeight so it can live in a layout.
Rectangle {
    id: findBar

    property bool findBarVisible: false
    property var webviewItem
    property alias findText: findField.text

    signal closeRequested()

    visible: findBarVisible
    implicitHeight: findBarVisible ? findBarRow.implicitHeight + Kirigami.Units.smallSpacing * 2 : 0
    color: Kirigami.Theme.backgroundColor
    Accessible.name: i18n("Find in page")

    RowLayout {
        id: findBarRow

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Kirigami.Units.smallSpacing
        }

        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.TextField {
            id: findField

            Layout.fillWidth: true

            placeholderText: i18n("Find in page…")
            onTextChanged: {
                if (webviewItem)
                    webviewItem.findText(text);
            }
            onAccepted: {
                if (webviewItem)
                    webviewItem.findText(text);
            }
            Keys.onEscapePressed: findBar.closeRequested()
        }

        PlasmaComponents3.ToolButton {
            icon.name: "go-up"
            text: i18n("Find previous")
            display: PlasmaComponents3.AbstractButton.IconOnly
            enabled: findField.text !== ""
            onClicked: {
                if (webviewItem)
                    webviewItem.findText(findField.text, WebEngineView.FindBackward);
            }
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        PlasmaComponents3.ToolButton {
            icon.name: "go-down"
            text: i18n("Find next")
            display: PlasmaComponents3.AbstractButton.IconOnly
            enabled: findField.text !== ""
            onClicked: {
                if (webviewItem)
                    webviewItem.findText(findField.text);
            }
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        PlasmaComponents3.ToolButton {
            icon.name: "dialog-close"
            text: i18n("Close")
            display: PlasmaComponents3.AbstractButton.IconOnly
            onClicked: findBar.closeRequested()
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.InOutQuad
        }
    }

    function focusAndSelect() {
        findField.forceActiveFocus();
        findField.selectAll();
    }

    function clearSearch() {
        findField.text = "";
        if (webviewItem)
            webviewItem.findText("");
    }
}
