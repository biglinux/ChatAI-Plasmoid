/*
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *  SPDX-FileCopyrightText: 2025 Bruno Gonçalves <bigbruno@gmail.com>
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import "IconModes.js" as IconModes

Item {
    id: compactRoot

    required property PlasmoidItem plasmoidItem
    required property QtObject providerModel

    readonly property string fallbackIcon: "help-about"
    readonly property bool isVertical: plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property var currentProvider: providerModel.providerForUrl(plasmoid.configuration.url)
    readonly property string providerName: currentProvider ? currentProvider.name : providerModel.nameForUrl(plasmoid.configuration.url) || i18n("ChatAI")

    Layout.minimumWidth: isVertical ? 0 : Kirigami.Units.iconSizes.medium
    Layout.minimumHeight: isVertical ? Kirigami.Units.iconSizes.medium : 0

    implicitWidth: Kirigami.Units.iconSizes.medium
    implicitHeight: Kirigami.Units.iconSizes.medium

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        property bool wasExpanded: false
        Accessible.role: Accessible.Button
        Accessible.name: i18n("Open ChatAI — %1", compactRoot.providerName)
        // No custom ToolTip here: Plasma already shows the standard applet
        // tooltip (toolTipMainText/toolTipSubText in main.qml). A second one
        // rendered on top of the icon and blocked the click.
        onPressed: wasExpanded = compactRoot.plasmoidItem.expanded
        onClicked: compactRoot.plasmoidItem.expanded = !wasExpanded
    }

    Kirigami.Icon {
        anchors.fill: parent
        source: compactRoot.iconSource()
        // Provider SVGs are pre-coloured; do not recolour them with the theme.
        isMask: false
    }

    function backgroundContrast() {
        const color = Kirigami.Theme.backgroundColor;
        const luma = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
        return luma > 0.5 ? "dark" : "light";
    }

    function logoFor(contrast) {
        return Qt.resolvedUrl("assets/logo-" + contrast + ".svg");
    }

    function iconSource() {
        const mode = plasmoid.configuration.iconMode;
        const contrast = backgroundContrast();

        if (mode === IconModes.Custom)
            return plasmoid.configuration.customIcon || fallbackIcon;

        if (mode === IconModes.Favicon) {
            const favicon = plasmoid.configuration.favIcon || plasmoid.configuration.lastFavIcon;
            if (favicon)
                return favicon;
            return logoFor(contrast);
        }

        if (mode === IconModes.Dark)
            return logoFor("dark");
        if (mode === IconModes.Light)
            return logoFor("light");

        if (mode === IconModes.Outlined || mode === IconModes.Filled || mode === IconModes.Colorful) {
            const style = mode === IconModes.Outlined ? "outlined" : mode === IconModes.Filled ? "filled" : "colorful";
            const source = providerModel.iconSource(currentProvider, style, contrast);
            return source ? Qt.resolvedUrl(source) : logoFor(contrast);
        }

        return logoFor(contrast);
    }
}
