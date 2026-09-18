/*
 *  SPDX-FileCopyrightText: 2020 Sora Steenvoort <sora@dillbox.me>
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *  SPDX-FileCopyrightText: 2025 Bruno Gonçalves <bigbruno@gmail.com>
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import org.kde.plasma.configuration

// Same categories, order and icons as SettingsPanel.qml (in-widget host).
ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "preferences-system"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Sites")
        icon: "internet-services"
        source: "ConfigSites.qml"
    }
    ConfigCategory {
        name: i18n("Permissions")
        icon: "preferences-system-privacy"
        source: "ConfigPermissions.qml"
    }
    ConfigCategory {
        name: i18n("Web Features")
        icon: "preferences-web-browser-stylesheets"
        source: "ConfigWebFeatures.qml"
    }
    ConfigCategory {
        name: i18n("Downloads")
        icon: "folder-download"
        source: "ConfigDownloads.qml"
    }
    ConfigCategory {
        name: i18n("Cache and Data")
        icon: "drive-harddisk"
        source: "ConfigStorage.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Advanced")
        icon: "preferences-other"
        source: "ConfigAdvanced.qml"
    }
    ConfigCategory {
        name: i18n("Help")
        icon: "help-hint"
        source: "ConfigHelp.qml"
    }
    // Plasma appends its own native "Keyboard Shortcuts" and "About" pages, so
    // we don't add those here (they would duplicate). The Help page carries the
    // shortcut reference and credits those native pages can't show.
}
