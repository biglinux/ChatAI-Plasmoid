/*
 *  SPDX-FileCopyrightText: 2026 ChatAI-Plasmoid contributors
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: errorView

    property string errorDetails
    signal retryRequested()
    signal openExternallyRequested()

    spacing: Kirigami.Units.largeSpacing
    Accessible.name: i18n("Web content error")

    Kirigami.Icon {
        source: "network-error"
        Layout.preferredWidth: Kirigami.Units.iconSizes.large
        Layout.preferredHeight: width
        Layout.alignment: Qt.AlignHCenter
    }

    PlasmaComponents3.Label {
        text: i18n("This service could not be loaded inside ChatAI.")
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Accessible.name: text
    }

    PlasmaComponents3.Label {
        text: errorView.errorDetails
        visible: text.length > 0
        opacity: 0.75
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: 3
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Button {
            text: i18n("Try again")
            icon.name: "view-refresh"
            onClicked: errorView.retryRequested()
            Accessible.name: text
        }

        PlasmaComponents3.Button {
            text: i18n("Open in browser")
            icon.name: "internet-web-browser"
            onClicked: errorView.openExternallyRequested()
            Accessible.name: text
        }
    }
}
