/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Window

// Real fullscreen for the embedded web view. The WebEngineView is reparented
// into this top-level window, which asks the compositor (Wayland xdg-shell or
// X11 _NET_WM_STATE) for fullscreen. No window-manager hacks are needed.
Window {
    id: fullScreenWindow

    property Item content: null
    property Item originalParent: null
    readonly property bool active: visible

    signal exitRequested()

    flags: Qt.Window
    color: "black"
    title: i18n("ChatAI — Full screen")

    function enter(item) {
        if (!item || active)
            return;
        content = item;
        originalParent = item.parent;
        item.parent = fullScreenWindow.contentItem;
        showFullScreen();
        requestActivate();
        item.forceActiveFocus();
    }

    function leave() {
        if (!active)
            return;
        if (content && originalParent) {
            content.parent = originalParent;
            content.forceActiveFocus();
        }
        content = null;
        originalParent = null;
        close();
    }

    onClosing: function (close) {
        // Window closed by the compositor (e.g. Alt+F4): give the view back.
        if (content && originalParent) {
            content.parent = originalParent;
            content = null;
            originalParent = null;
            exitRequested();
        }
    }

    Shortcut {
        sequences: ["Escape", "F11"]
        enabled: fullScreenWindow.active
        context: Qt.WindowShortcut
        onActivated: fullScreenWindow.exitRequested()
    }
}
