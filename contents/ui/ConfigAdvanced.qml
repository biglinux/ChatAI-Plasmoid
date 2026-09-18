/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick

import org.kde.kcmutils as KCM

import "settings"

// Plasma configuration dialog host for the shared Advanced settings page.
KCM.SimpleKCM {
    AdvancedSettings {
        width: parent ? parent.width : implicitWidth
    }
}
