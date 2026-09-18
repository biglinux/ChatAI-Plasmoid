/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Window
import QtWebEngine

// Developer tools in a separate window. Created on demand by a Loader and
// destroyed when closed so ordinary users never pay for it.
Window {
    id: devToolsWindow

    property var inspected: null

    signal closeRequested()

    width: Screen.width * 0.6
    height: Screen.height * 0.6
    title: i18n("ChatAI — Developer tools")
    color: "black"

    WebEngineView {
        id: devToolsView
        anchors.fill: parent
        inspectedView: devToolsWindow.inspected
    }

    onClosing: closeRequested()
}
