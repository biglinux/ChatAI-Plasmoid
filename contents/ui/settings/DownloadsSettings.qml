/*
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *  SPDX-FileCopyrightText: 2025 Bruno Gonçalves <bigbruno@gmail.com>
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import QtWebEngine

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import ".."

ColumnLayout {
    id: page

    property QtObject providerModel: internalModel
    property var runtime: null
    readonly property bool modalOpen: folderDialog.visible

    spacing: Kirigami.Units.largeSpacing

    ProviderModel {
        id: internalModel
    }

    function defaultDownloadPath() {
        return String(StandardPaths.writableLocation(StandardPaths.DownloadLocation)).replace(/^file:\/\/(localhost)?/, "");
    }

    function localPath(value) {
        return String(value || "").replace(/^file:\/\/(localhost)?/, "");
    }

    readonly property string effectivePath: localPath(plasmoid.configuration.downloadPath) || defaultDownloadPath()

    Kirigami.FormLayout {
        Layout.fillWidth: true

        RowLayout {
            Kirigami.FormData.label: i18n("Folder:")
            Layout.fillWidth: true

            QQC2.TextField {
                id: pathField
                Layout.fillWidth: true
                text: page.localPath(plasmoid.configuration.downloadPath)
                placeholderText: page.defaultDownloadPath()
                Accessible.name: i18n("Download folder")
                onEditingFinished: {
                    const value = text.trim();
                    if (value === "" || value.charAt(0) === "/")
                        plasmoid.configuration.downloadPath = value;
                }
            }

            QQC2.Button {
                icon.name: "folder"
                text: i18n("Choose…")
                onClicked: folderDialog.open()
            }
        }

        QQC2.Label {
            text: i18n("Leave empty to use the system Downloads folder. Files are saved automatically with a sanitized name and are never executed.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.Button {
            icon.name: "folder-open"
            text: i18n("Open Download Folder")
            onClicked: Qt.openUrlExternally("file://" + page.effectivePath)
        }
    }

    FolderDialog {
        id: folderDialog
        title: i18n("Choose Download Folder")
        currentFolder: "file://" + page.effectivePath
        onAccepted: plasmoid.configuration.downloadPath = page.localPath(selectedFolder)
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        text: i18n("Current downloads")
        level: 3
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: page.runtime === null
        type: Kirigami.MessageType.Information
        text: i18n("Downloads are listed here while the ChatAI widget is open.")
    }

    QQC2.Label {
        visible: page.runtime !== null && page.runtime.downloads.count === 0
        text: i18n("No downloads in this session.")
        opacity: 0.7
    }

    Repeater {
        model: page.runtime ? page.runtime.downloads : null

        delegate: RowLayout {
            id: downloadRow
            required property var model
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: downloadRow.model.fileName
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
            QQC2.ProgressBar {
                visible: downloadRow.model.state === WebEngineDownloadRequest.DownloadInProgress
                from: 0
                to: 1
                value: downloadRow.model.progress
                indeterminate: downloadRow.model.totalBytes <= 0
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            }
            QQC2.Label {
                text: downloadRow.model.state === WebEngineDownloadRequest.DownloadCompleted ? i18n("Completed")
                    : downloadRow.model.state === WebEngineDownloadRequest.DownloadInProgress ? i18n("Downloading")
                    : downloadRow.model.state === WebEngineDownloadRequest.DownloadCancelled ? i18n("Cancelled")
                    : downloadRow.model.state === WebEngineDownloadRequest.DownloadInterrupted ? (downloadRow.model.error || i18n("Interrupted"))
                    : i18n("Waiting")
                opacity: 0.8
            }
        }
    }

    QQC2.Button {
        visible: page.runtime !== null && page.runtime.downloads.count > 0
        icon.name: "edit-clear-history"
        text: i18n("Clear Finished Downloads")
        onClicked: page.runtime.clearFinishedDownloads()
    }
}
