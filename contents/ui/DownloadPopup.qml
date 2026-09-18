/*
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *  SPDX-FileCopyrightText: 2025 Bruno Gonçalves <bigbruno@gmail.com>
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "Downloads.js" as Downloads

/*
 * Downloads list and actions (successor of the bottom DownloadBar). Reads the
 * single downloads model owned by WebView.qml and calls its actions; opened
 * from the temporary toolbar indicator and from the ⋮ menu.
 */
PlasmaComponents3.Popup {
    id: popup

    // WebView.qml root, or null while the view is not loaded.
    property var runtime: null

    signal openDownloadFolderRequested()
    signal chooseDownloadFolderRequested()

    readonly property var model: runtime ? runtime.downloads : null
    readonly property int count: model ? model.count : 0

    width: Kirigami.Units.gridUnit * 24
    padding: Kirigami.Units.smallSpacing
    // Non-negative margins make QQC2 keep the popup within the window bounds.
    margins: Kirigami.Units.smallSpacing
    modal: false
    focus: true
    closePolicy: PlasmaComponents3.Popup.CloseOnEscape | PlasmaComponents3.Popup.CloseOnPressOutsideParent

    readonly property var byteUnits: [i18nc("bytes", "B"), i18nc("kilobytes", "kB"), i18nc("megabytes", "MB"), i18nc("gigabytes", "GB"), i18nc("terabytes", "TB")]

    function formatBytes(bytes) {
        const scaled = Downloads.scaleBytes(bytes);
        return i18nc("file size: value and unit", "%1 %2", Number(scaled.value).toLocaleString(Qt.locale(), "f", scaled.digits), byteUnits[scaled.unitIndex]);
    }

    function formatSpeed(bytesPerSecond) {
        return i18nc("transfer rate", "%1/s", formatBytes(bytesPerSecond));
    }

    function formatEta(seconds) {
        if (seconds < 60)
            return i18np("%1 second left", "%1 seconds left", Math.round(seconds));
        if (seconds < 3600)
            return i18np("%1 minute left", "%1 minutes left", Math.round(seconds / 60));
        return i18np("%1 hour left", "%1 hours left", Math.round(seconds / 3600));
    }

    function statusText(item) {
        switch (item.state) {
        case Downloads.StateRequested:
            return i18n("Starting…");
        case Downloads.StateInProgress: {
            if (item.isPaused)
                return i18n("Paused — %1", item.totalBytes > 0 ? i18n("%1 of %2", formatBytes(item.receivedBytes), formatBytes(item.totalBytes)) : formatBytes(item.receivedBytes));
            const parts = [];
            parts.push(item.totalBytes > 0 ? i18n("%1 of %2", formatBytes(item.receivedBytes), formatBytes(item.totalBytes)) : formatBytes(item.receivedBytes));
            if (item.totalBytes > 0)
                parts.push(i18nc("percentage", "%1%", Math.round(item.progress * 100)));
            if (item.speed > 0)
                parts.push(formatSpeed(item.speed));
            if (item.eta > 0)
                parts.push(formatEta(item.eta));
            return parts.join(i18nc("separator between download status parts", " · "));
        }
        case Downloads.StateCompleted:
            return item.isPdfExport ? i18n("PDF saved — %1", formatBytes(item.totalBytes || item.receivedBytes)) : i18n("Completed — %1", formatBytes(item.totalBytes || item.receivedBytes));
        case Downloads.StateCancelled:
            return i18n("Cancelled");
        case Downloads.StateInterrupted:
            return item.error ? i18n("Interrupted — %1", item.error) : i18n("Interrupted");
        default:
            return i18n("Unknown state");
        }
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                text: i18n("Downloads")
                level: 3
                Layout.fillWidth: true
            }

            PlasmaComponents3.ToolButton {
                icon.name: "edit-clear-history"
                text: i18n("Clear finished")
                display: PlasmaComponents3.AbstractButton.IconOnly
                enabled: popup.runtime !== null && popup.count > popup.runtime.downloadSummary.active
                Accessible.name: text
                PlasmaComponents3.ToolTip.text: text
                PlasmaComponents3.ToolTip.visible: hovered
                PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: popup.runtime.clearFinishedDownloads()
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            visible: popup.count === 0
            icon.name: "download"
            text: i18n("No downloads in this session")
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 18)
            visible: popup.count > 0
            clip: true
            model: popup.model
            spacing: Kirigami.Units.smallSpacing
            keyNavigationEnabled: true
            Accessible.name: i18n("Downloads list")

            delegate: Item {
                id: row
                required property var model
                required property int index

                width: ListView.view ? ListView.view.width : implicitWidth
                height: rowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
                Accessible.role: Accessible.ListItem
                Accessible.name: i18n("%1: %2", model.fileName, popup.statusText(model))

                readonly property bool active: Downloads.isActive(model.state)
                readonly property bool completed: model.state === Downloads.StateCompleted
                readonly property bool failed: model.state === Downloads.StateInterrupted

                RowLayout {
                    id: rowLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: row.model.isPdfExport ? "application-pdf" : Downloads.iconForFileName(row.model.fileName)
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        Layout.alignment: Qt.AlignTop
                        opacity: row.model.state === Downloads.StateCancelled ? 0.5 : 1
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            PlasmaComponents3.Label {
                                text: row.model.fileName
                                elide: Text.ElideMiddle
                                font.bold: !row.model.seen && (row.completed || row.failed)
                                Layout.fillWidth: true
                            }
                            Kirigami.Icon {
                                visible: row.completed || row.failed
                                source: row.failed ? "data-warning" : "checkmark"
                                color: row.failed ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.positiveTextColor
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                Accessible.ignored: true
                            }
                        }

                        PlasmaComponents3.ProgressBar {
                            Layout.fillWidth: true
                            visible: row.active
                            from: 0
                            to: 1
                            value: row.model.progress
                            indeterminate: row.model.totalBytes <= 0 && !row.model.isPaused
                        }

                        PlasmaComponents3.Label {
                            text: popup.statusText(row.model)
                            font: Kirigami.Theme.smallFont
                            opacity: 0.75
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Actions
                    RowLayout {
                        spacing: 0
                        Layout.alignment: Qt.AlignTop

                        component ActionButton: PlasmaComponents3.ToolButton {
                            display: PlasmaComponents3.AbstractButton.IconOnly
                            Accessible.name: text
                            PlasmaComponents3.ToolTip.text: text
                            PlasmaComponents3.ToolTip.visible: hovered
                            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }

                        ActionButton {
                            visible: row.active && !row.model.isPdfExport
                            icon.name: row.model.isPaused ? "media-playback-start" : "media-playback-pause"
                            text: row.model.isPaused ? i18n("Resume") : i18n("Pause")
                            onClicked: row.model.isPaused ? popup.runtime.resumeDownload(row.model.downloadId) : popup.runtime.pauseDownload(row.model.downloadId)
                        }
                        ActionButton {
                            visible: row.active && !row.model.isPdfExport
                            icon.name: "dialog-cancel"
                            text: i18n("Cancel")
                            onClicked: popup.runtime.cancelDownload(row.model.downloadId)
                        }
                        ActionButton {
                            visible: row.completed
                            icon.name: "document-open"
                            text: i18n("Open")
                            onClicked: popup.runtime.openDownload(row.model.downloadId)
                        }
                        ActionButton {
                            visible: row.completed
                            icon.name: "folder-open"
                            text: i18n("Show in Folder")
                            onClicked: popup.runtime.showDownloadInFolder(row.model.downloadId)
                        }
                        ActionButton {
                            visible: (row.failed || row.model.state === Downloads.StateCancelled) && !row.model.isPdfExport && row.model.sourceUrl !== ""
                            icon.name: "view-refresh"
                            text: i18n("Retry")
                            onClicked: popup.runtime.retryDownload(row.model.downloadId)
                        }
                        ActionButton {
                            visible: !row.active
                            icon.name: "edit-delete-remove"
                            text: i18n("Remove from list")
                            onClicked: popup.runtime.removeDownload(row.model.downloadId)
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                icon.name: "folder-open"
                text: i18n("Open Download Folder")
                onClicked: popup.openDownloadFolderRequested()
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents3.ToolButton {
                icon.name: "folder"
                text: i18n("Choose Folder…")
                onClicked: popup.chooseDownloadFolderRequested()
            }
        }
    }
}
