/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */
.pragma library

/*
 * Pure download bookkeeping shared by WebView.qml (the single downloads model)
 * and the download UI. No QML types here so it stays plain, testable JavaScript.
 *
 * State values mirror WebEngineDownloadRequest.DownloadState.
 */
var StateRequested = 0;
var StateInProgress = 1;
var StateCompleted = 2;
var StateCancelled = 3;
var StateInterrupted = 4;

function isActive(state) {
    return state === StateRequested || state === StateInProgress;
}

function isFinished(state) {
    return state === StateCompleted || state === StateCancelled || state === StateInterrupted;
}

/*
 * Aggregate over an array of plain objects
 *   { state, receivedBytes, totalBytes, seen, isPaused }
 * Returns:
 *   active            downloads requested or in progress
 *   paused            active downloads currently paused
 *   completedUnseen   completed downloads the user has not opened/acknowledged
 *   failedUnseen      interrupted downloads not yet acknowledged
 *   progress          overall fraction (0..1) weighted by bytes over downloads
 *                     whose total size is known; -1 when only unknown sizes are active
 *   hasUnknownSize    at least one active download has no known total
 *   showIndicator     whether the toolbar indicator must be visible
 *   attention         completedUnseen + failedUnseen (badge count when nothing is active)
 */
function summarize(items) {
    var result = { active: 0, paused: 0, completedUnseen: 0, failedUnseen: 0, progress: 0, hasUnknownSize: false, showIndicator: false, attention: 0 };
    var knownTotal = 0;
    var knownReceived = 0;
    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        if (isActive(item.state)) {
            result.active++;
            if (item.isPaused)
                result.paused++;
            if (item.totalBytes > 0) {
                knownTotal += item.totalBytes;
                knownReceived += Math.min(item.receivedBytes || 0, item.totalBytes);
            } else {
                result.hasUnknownSize = true;
            }
        } else if (item.state === StateCompleted && !item.seen) {
            result.completedUnseen++;
        } else if (item.state === StateInterrupted && !item.seen) {
            result.failedUnseen++;
        }
    }
    if (result.active > 0)
        result.progress = knownTotal > 0 ? knownReceived / knownTotal : -1;
    result.attention = result.completedUnseen + result.failedUnseen;
    result.showIndicator = result.active > 0 || result.attention > 0;
    return result;
}

/*
 * Transfer rate from timestamped byte samples [{time (ms), bytes}] kept over a
 * sliding window. Returns bytes per second, or -1 when the window is too short
 * to be trustworthy (< 2 s or < 2 samples or no progress).
 */
function speedFromSamples(samples, windowMs) {
    if (!samples || samples.length < 2)
        return -1;
    var last = samples[samples.length - 1];
    var first = samples[0];
    for (var i = 0; i < samples.length; i++) {
        if (last.time - samples[i].time <= (windowMs || 10000)) {
            first = samples[i];
            break;
        }
    }
    var dt = (last.time - first.time) / 1000;
    var db = last.bytes - first.bytes;
    if (dt < 2 || db <= 0)
        return -1;
    return db / dt;
}

// Seconds remaining, or -1 when it cannot be estimated reliably.
function etaSeconds(receivedBytes, totalBytes, bytesPerSecond) {
    if (totalBytes <= 0 || bytesPerSecond <= 0 || receivedBytes > totalBytes)
        return -1;
    var eta = (totalBytes - receivedBytes) / bytesPerSecond;
    if (!isFinite(eta) || eta > 7 * 24 * 3600)
        return -1;
    return eta;
}

// Trim a samples array to the last `windowMs` (keeps at least the last one).
function pushSample(samples, time, bytes, windowMs) {
    var list = (samples || []).slice();
    list.push({ time: time, bytes: bytes });
    var cutoff = time - (windowMs || 10000);
    while (list.length > 2 && list[0].time < cutoff)
        list.shift();
    return list;
}

// Decimal units like browsers do. Returns { value, unitIndex } where unitIndex
// indexes ["B", "kB", "MB", "GB", "TB"]; the caller localizes the unit label.
function scaleBytes(bytes) {
    var value = Math.max(0, Number(bytes) || 0);
    var unitIndex = 0;
    while (value >= 1000 && unitIndex < 4) {
        value /= 1000;
        unitIndex++;
    }
    return { value: value, unitIndex: unitIndex, digits: unitIndex === 0 ? 0 : value < 10 ? 1 : 0 };
}

// Breeze icon for a file name (generic MIME categories).
function iconForFileName(fileName) {
    var ext = String(fileName || "").toLowerCase().split(".").pop();
    var map = {
        pdf: "application-pdf",
        zip: "application-zip", gz: "application-zip", xz: "application-zip", bz2: "application-zip", "7z": "application-zip", rar: "application-zip", tar: "application-zip",
        png: "image-x-generic", jpg: "image-x-generic", jpeg: "image-x-generic", gif: "image-x-generic", webp: "image-x-generic", svg: "image-x-generic", bmp: "image-x-generic",
        mp4: "video-x-generic", mkv: "video-x-generic", webm: "video-x-generic", mov: "video-x-generic",
        mp3: "audio-x-generic", ogg: "audio-x-generic", flac: "audio-x-generic", wav: "audio-x-generic", m4a: "audio-x-generic",
        txt: "text-x-generic", md: "text-markdown", csv: "text-csv", json: "application-json", xml: "text-xml", html: "text-html",
        py: "text-x-python", js: "text-x-javascript", sh: "text-x-script", qml: "text-x-qml", c: "text-x-csrc", cpp: "text-x-c++src", h: "text-x-chdr",
        doc: "application-msword", docx: "application-vnd.openxmlformats-officedocument.wordprocessingml.document",
        xls: "application-vnd.ms-excel", xlsx: "application-vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ppt: "application-vnd.ms-powerpoint", pptx: "application-vnd.openxmlformats-officedocument.presentationml.presentation",
        odt: "application-vnd.oasis.opendocument.text", ods: "application-vnd.oasis.opendocument.spreadsheet",
        iso: "application-x-cd-image", deb: "application-x-deb", rpm: "application-x-rpm", appimage: "application-x-executable", pkg: "application-x-archive"
    };
    return map[ext] || "application-octet-stream";
}
