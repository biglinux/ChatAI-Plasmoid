/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Shapes

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

/*
 * Temporary toolbar button shown only while downloads need attention:
 * a progress ring around the icon while transferring, a check badge (and a
 * count) for completed downloads not yet opened, a warning badge for errors.
 * Consumes WebView.downloadSummary; owns no state of its own.
 */
PlasmaComponents3.ToolButton {
    id: indicator

    // Result of Downloads.summarize(): active, paused, completedUnseen,
    // failedUnseen, progress, hasUnknownSize, showIndicator, attention.
    property var summary: ({ active: 0, paused: 0, completedUnseen: 0, failedUnseen: 0, progress: 0, hasUnknownSize: false, showIndicator: false, attention: 0 })

    readonly property bool transferring: summary.active > 0
    readonly property bool indeterminate: transferring && summary.progress < 0
    readonly property int percent: transferring && summary.progress >= 0 ? Math.round(summary.progress * 100) : 0
    readonly property bool hasError: summary.failedUnseen > 0

    display: PlasmaComponents3.AbstractButton.IconOnly
    icon.name: transferring ? "download" : hasError ? "data-warning" : "download-later"
    text: {
        if (transferring) {
            if (indeterminate)
                return i18np("One download in progress", "%1 downloads in progress", summary.active);
            return i18np("One download in progress, %2%", "%1 downloads in progress, %2%", summary.active, percent);
        }
        if (hasError)
            return i18np("One download failed", "%1 downloads failed", summary.failedUnseen);
        return i18np("One download completed, not opened yet", "%1 downloads completed, not opened yet", summary.completedUnseen);
    }
    Accessible.name: text
    Accessible.description: i18n("Open the downloads list")
    PlasmaComponents3.ToolTip.text: text
    PlasmaComponents3.ToolTip.visible: hovered
    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay

    // Entrance / exit
    opacity: visible ? 1 : 0
    scale: visible ? 1 : 0.6
    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutBack } }

    // Progress ring drawn around the icon. Determinate: arc = progress.
    // Indeterminate (unknown sizes): a short arc rotating slowly.
    Shape {
        id: ring
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing * 2
        height: width
        visible: indicator.transferring
        antialiasing: true
        layer.enabled: true
        layer.samples: 4
        Accessible.ignored: true

        property real angle: indicator.indeterminate ? 90 : Math.max(2, 360 * Math.max(0, Math.min(1, indicator.summary.progress)))
        Behavior on angle { enabled: !indicator.indeterminate; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutQuad } }

        rotation: -90
        RotationAnimation on rotation {
            running: indicator.indeterminate && indicator.visible
            from: -90; to: 270
            duration: 1400
            loops: Animation.Infinite
        }

        // Track
        ShapePath {
            strokeColor: Qt.alpha(Kirigami.Theme.textColor, 0.18)
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - 1.5; radiusY: ring.height / 2 - 1.5
                startAngle: 0; sweepAngle: 360
            }
        }
        // Progress
        ShapePath {
            strokeColor: indicator.summary.paused === indicator.summary.active && indicator.summary.active > 0 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
            strokeWidth: 2.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - 1.5; radiusY: ring.height / 2 - 1.5
                startAngle: 0; sweepAngle: ring.angle
            }
        }
    }

    // Badge: check for completed, warning for failed, or the count.
    Rectangle {
        id: badge
        visible: !indicator.transferring && indicator.summary.attention > 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        width: Math.max(Kirigami.Units.iconSizes.small * 0.7, badgeLabel.implicitWidth + 4)
        height: Kirigami.Units.iconSizes.small * 0.7
        radius: height / 2
        color: indicator.hasError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.positiveTextColor
        Accessible.ignored: true

        PlasmaComponents3.Label {
            id: badgeLabel
            anchors.centerIn: parent
            text: indicator.summary.attention > 1 ? indicator.summary.attention : (indicator.hasError ? "!" : "✓")
            font.pixelSize: Math.round(parent.height * 0.75)
            font.bold: true
            color: Kirigami.Theme.highlightedTextColor
        }
    }
}
