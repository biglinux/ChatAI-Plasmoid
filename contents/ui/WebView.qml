/*
 *  SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
 *  SPDX-FileCopyrightText: 2025 Bruno Gonçalves <bigbruno@gmail.com>
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtCore
import QtQuick
import QtQuick.Layouts
import QtWebEngine

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.notification
import org.kde.plasma.plasma5support as P5Support

import "Downloads.js" as Downloads

/*
 * Web engine host: profile, navigation, permissions, downloads, zoom,
 * fullscreen and lifecycle. Created lazily by the Loader in main.qml and
 * destroyed by Close to release the Chromium processes.
 */
Item {
    id: webViewRoot

    required property QtObject providerModel

    // Set by main.qml: true while the popup is collapsed or the settings
    // panel covers the view. Drives visibility and lifecycle freezing.
    property bool hidden: false

    readonly property alias webview: webview
    readonly property alias downloads: downloadsModel
    readonly property string effectiveProfileName: String(plasmoid.configuration.webEngineProfileName || "").replace(/[^A-Za-z0-9._-]/g, "-").slice(0, 64) || providerModel.defaultProfileName
    property var webProfile: null

    property bool hasLoadError: false
    property string loadErrorDetails: ""
    // True when the main document has been waiting for the server for a while
    // (some anti-bot front ends hold the connection without answering).
    property bool slowResponse: false
    // CSS viewport width seen by the page (zoom shrinks it). Below 768 px most
    // assistants switch to mobile layouts whose sign-in flows misbehave here.
    readonly property int desktopViewportWidth: 768
    readonly property real cssViewportWidth: webview.zoomFactor > 0 ? webview.width / webview.zoomFactor : webview.width
    property bool mobileLayoutHintDismissed: false
    property bool findBarVisible: false

    // Navigation funnel: every navigation (initial load, provider switch, Home,
    // custom address) goes through navigateTo(). The load is deferred one tick
    // and coalesced, so the config.url change and the goHome() call that follow
    // a provider switch never fire two competing navigations, and stop() always
    // settles before the new URL is assigned. This is what makes switching
    // assistants load reliably every time.
    property string pendingUrl: ""
    property bool navScheduled: false

    // Permissions
    property var pendingPermission: null
    property var permissionQueue: []
    property int permissionsRevision: 0

    // State exposed to the header and menus
    property bool clearingCache: false
    readonly property bool devToolsOpen: devToolsLoader.active
    readonly property bool fullScreenActive: fullScreenLoader.item ? fullScreenLoader.item.active : false
    readonly property bool loading: webview.loading
    readonly property bool canGoBack: webview.canGoBack
    readonly property bool canGoForward: webview.canGoForward
    readonly property int zoomPercent: Math.round(webview.zoomFactor * 100)
    readonly property var zoomSteps: [0.5, 0.67, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0]
    readonly property string currentTitle: webview.title
    readonly property string currentUrl: String(webview.url || "")
    readonly property int renderProcessPid: webview.renderProcessPid
    readonly property int lifecycleState: webview.lifecycleState
    readonly property int recommendedState: webview.recommendedState

    // Downloads: the single source of truth is downloadsModel (below);
    // downloadSummary is derived for the toolbar indicator and menus.
    property int downloadsRevision: 0
    readonly property var downloadSummary: Downloads.summarize(downloadItems(downloadsRevision))
    readonly property int activeDownloadCount: downloadSummary.active
    readonly property real activeDownloadProgress: Math.max(0, downloadSummary.progress)
    property var downloadCache: ({})
    // Emitted when a download completes or fails so the toolbar can reveal
    // the indicator briefly (never a modal popup).
    signal downloadAttention()

    // OAuth / window.open() popups are shown in AuthPopup with the same profile.
    readonly property bool authPopupOpen: authPopupLoader.active

    // Anything that must not be interrupted by freezing the page.
    readonly property bool busy: webview.loading || webview.recentlyAudible || activeDownloadCount > 0
        || pendingPermission !== null || devToolsOpen || clearingCache || fullScreenActive || authPopupOpen

    readonly property var currentProvider: providerModel.providerForUrl(plasmoid.configuration.url)

    readonly property int policyAsk: 0
    readonly property int policyAllow: 1
    readonly property int policyBlock: 2

    Layout.fillWidth: true
    Layout.fillHeight: true

    Component.onCompleted: {
        // Prototype instances must be created after the component is ready;
        // creating them inside a binding crashes QQuickWebEngineView::setProfile.
        const profile = profilePrototype.instance();
        configureProfile(profile);
        webProfile = profile;
        applyZoom();
        // Initial load, explicit (there is no reactive url binding).
        goHome();
    }

    Connections {
        target: plasmoid.configuration

        function onUrlChanged() {
            webViewRoot.configureProfile();
            webViewRoot.hasLoadError = false;
            // Do not carry the previous provider's icon over; the new one
            // arrives through WebEngineView.icon.
            plasmoid.configuration.favIcon = "";
            // Navigate to the newly selected provider / address.
            webViewRoot.goHome();
        }
        function onDownloadPathChanged() { webViewRoot.configureProfile(); }
        function onCustomUserAgentChanged() { webViewRoot.configureProfile(); }
        function onCompatibilityUserAgentChanged() { webViewRoot.configureProfile(); }
        function onZoomFactorChanged() { webViewRoot.applyZoom(); }
    }

    // ---- helpers -----------------------------------------------------------

    function isHttpUrl(value) {
        return providerModel.isHttpUrl(value);
    }

    function localPath(value) {
        let path = String(value || "").trim();
        if (path.indexOf("file://") === 0)
            path = path.replace(/^file:\/\/(localhost)?/, "");
        return path || String(StandardPaths.writableLocation(StandardPaths.DownloadLocation)).replace(/^file:\/\/(localhost)?/, "");
    }

    function downloadDirectory() {
        const path = localPath(plasmoid.configuration.downloadPath);
        return path.charAt(0) === "/" ? path : localPath("");
    }

    function safeFileName(value, fallback) {
        let name = String(value || fallback || "download").split(/[\\/]/).pop();
        // Strip control characters, path separators and reserved characters.
        name = name.replace(/[\x00-\x1f\x7f<>:"|?*]/g, "_").replace(/\.\./g, "_").trim();
        if (name === "." || name === "..")
            name = fallback || "download";
        return name || fallback || "download";
    }

    function configureProfile(profileOverride) {
        const profile = profileOverride || webProfile;
        if (!profile)
            return;
        profile.httpUserAgent = providerModel.effectiveUserAgent(WebEngine.defaultProfile.httpUserAgent, currentProvider);
        profile.downloadPath = downloadDirectory();
    }

    // ---- navigation API used by Header / menu ------------------------------

    function goHome() {
        navigateTo(currentProvider ? currentProvider.url : plasmoid.configuration.url);
    }

    // Single navigation entry point. Aborts any in-flight load (some pages, e.g.
    // ChatGPT bouncing to a blocked Google sign-in, keep redirecting and would
    // override a plain assignment), then loads on the next tick so stop() has
    // settled. Multiple calls in the same tick collapse into one load.
    function navigateTo(url) {
        if (!isHttpUrl(url)) {
            loadErrorDetails = i18n("The configured address is not a valid HTTP or HTTPS URL.");
            hasLoadError = true;
            return;
        }
        hasLoadError = false;
        pendingUrl = url;
        if (navScheduled)
            return;
        navScheduled = true;
        webview.stop();
        Qt.callLater(startPendingNavigation);
    }

    function startPendingNavigation() {
        navScheduled = false;
        const url = pendingUrl;
        if (!url)
            return;
        if (String(webview.url) === url)
            webview.reload();
        else
            webview.url = url;
        navWatchdog.restart();
    }

    function goBack() { if (webview.canGoBack) webview.goBack(); }
    function goForward() { if (webview.canGoForward) webview.goForward(); }
    function reload() { hasLoadError = false; webview.reload(); }
    function reloadBypassCache() { hasLoadError = false; webview.reloadAndBypassCache(); }
    function stop() { webview.stop(); }
    function toggleFind() { findBarVisible = !findBarVisible; }

    function openExternally() {
        if (isHttpUrl(currentUrl))
            Qt.openUrlExternally(currentUrl);
    }

    function copyUrl() {
        clipboardHelper.text = currentUrl;
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        clipboardHelper.text = "";
    }

    // ---- zoom --------------------------------------------------------------

    function applyZoom() {
        const factor = Math.min(5.0, Math.max(0.25, Number(plasmoid.configuration.zoomFactor) || 1.0));
        if (Math.abs(webview.zoomFactor - factor) > 0.001)
            webview.zoomFactor = factor;
    }

    function setZoom(factor) {
        plasmoid.configuration.zoomFactor = Math.min(5.0, Math.max(0.25, factor));
        applyZoom();
    }

    function zoomIn() {
        const current = webview.zoomFactor;
        const next = zoomSteps.find(step => step > current + 0.001);
        setZoom(next !== undefined ? next : Math.min(5.0, current + 0.25));
    }

    function zoomOut() {
        const current = webview.zoomFactor;
        const lower = zoomSteps.filter(step => step < current - 0.001);
        setZoom(lower.length ? lower[lower.length - 1] : Math.max(0.25, current - 0.25));
    }

    function zoomReset() { setZoom(1.0); }

    // ---- fullscreen --------------------------------------------------------

    function enterFullScreen() {
        fullScreenLoader.active = true;
        fullScreenLoader.item.enter(webview);
    }

    function exitFullScreen() {
        if (fullScreenLoader.item)
            fullScreenLoader.item.leave();
        if (webview.isFullScreen)
            webview.fullScreenCancelled();
        fullScreenLoader.active = false;
    }

    function toggleFullScreen() {
        if (fullScreenActive)
            exitFullScreen();
        else
            enterFullScreen();
    }

    // ---- devtools ----------------------------------------------------------

    function openDevTools() {
        devToolsLoader.active = true;
        devToolsLoader.item.show();
        devToolsLoader.item.requestActivate();
    }

    function closeDevTools() {
        devToolsLoader.active = false;
    }

    // ---- cache & permissions management -----------------------------------

    function clearHttpCache() {
        if (!webProfile || clearingCache)
            return;
        clearingCache = true;
        webProfile.clearHttpCache();
    }

    function listPermissions() {
        return webProfile ? webProfile.listAllPermissions() : [];
    }

    function resetPermission(permission) {
        if (permission)
            permission.reset();
        permissionsRevision++;
    }

    function resetAllPermissions() {
        listPermissions().forEach(permission => permission.reset());
        permissionsRevision++;
    }

    // ---- lifecycle ----------------------------------------------

    onHiddenChanged: {
        if (!hidden) {
            freezeTimer.stop();
            discardTimer.stop();
            // A visible page must be Active: order matters.
            webview.lifecycleState = WebEngineView.LifecycleState.Active;
            webview.visible = true;
        } else {
            webview.visible = false;
            if (plasmoid.configuration.freezeWhenHidden)
                freezeTimer.restart();
            if (plasmoid.configuration.discardAfterMinutes > 0)
                discardTimer.restart();
        }
    }

    function tryFreeze() {
        if (!hidden || !plasmoid.configuration.freezeWhenHidden)
            return;
        if (busy || webview.recommendedState === WebEngineView.LifecycleState.Active) {
            // The engine still recommends Active (audio, upload, form work…): retry later.
            freezeTimer.restart();
            return;
        }
        if (webview.lifecycleState === WebEngineView.LifecycleState.Active)
            webview.lifecycleState = WebEngineView.LifecycleState.Frozen;
    }

    Timer {
        id: freezeTimer
        interval: 30 * 1000
        onTriggered: webViewRoot.tryFreeze()
    }

    Timer {
        id: discardTimer
        interval: Math.max(1, plasmoid.configuration.discardAfterMinutes) * 60 * 1000
        onTriggered: {
            if (!webViewRoot.hidden || webViewRoot.busy || webview.lifecycleState === WebEngineView.LifecycleState.Discarded)
                return;
            if (webview.recommendedState !== WebEngineView.LifecycleState.Active)
                webview.lifecycleState = WebEngineView.LifecycleState.Discarded;
        }
    }

    Timer {
        id: slowResponseTimer
        interval: 12 * 1000
        onTriggered: {
            if (webview.loading && webview.loadProgress < 10)
                webViewRoot.slowResponse = true;
        }
    }

    // Safety net: if a requested navigation silently never took (target still
    // not showing and nothing is loading), force it once.
    Timer {
        id: navWatchdog
        interval: 2500
        onTriggered: {
            if (webViewRoot.pendingUrl && String(webview.url) !== webViewRoot.pendingUrl && !webview.loading)
                webview.url = webViewRoot.pendingUrl;
        }
    }

    // ---- downloads ---------------------------------------------------------
    //
    // Model roles: downloadId, fileName, fullPath, sourceUrl, mimeType,
    // progress (0..1), receivedBytes, totalBytes (0 = unknown), isPdfExport,
    // state (WebEngineDownloadRequest.DownloadState), isPaused, error,
    // seen (opened/acknowledged by the user), speed (B/s or -1), eta (s or -1).
    // UI updates from receivedBytesChanged are throttled to ~4/s.

    readonly property int downloadUiIntervalMs: 250

    function downloadItems() {
        const items = [];
        for (let i = 0; i < downloadsModel.count; i++) {
            const item = downloadsModel.get(i);
            items.push({ state: item.state, receivedBytes: item.receivedBytes, totalBytes: item.totalBytes, seen: item.seen, isPaused: item.isPaused });
        }
        return items;
    }

    ListModel {
        id: downloadsModel

        function addDownload(downloadItem, fileName, path, isPdf) {
            const downloadId = downloadItem ? String(downloadItem.id) : "pdf-" + Date.now().toString();
            append({
                "downloadId": downloadId,
                "fileName": fileName,
                "fullPath": path,
                "sourceUrl": downloadItem ? String(downloadItem.url) : "",
                "mimeType": downloadItem ? String(downloadItem.mimeType || "") : "application/pdf",
                "progress": 0,
                "receivedBytes": 0,
                "totalBytes": downloadItem && downloadItem.totalBytes > 0 ? downloadItem.totalBytes : 0,
                "isPdfExport": isPdf,
                "state": downloadItem ? downloadItem.state : WebEngineDownloadRequest.DownloadInProgress,
                "isPaused": downloadItem ? downloadItem.isPaused : false,
                "error": "",
                "seen": false,
                "speed": -1,
                "eta": -1
            });
            webViewRoot.downloadsRevision++;
            return count - 1;
        }

        function removeAt(index) {
            const item = get(index);
            if (item && item.downloadId)
                delete webViewRoot.downloadCache[item.downloadId];
            remove(index);
            webViewRoot.downloadsRevision++;
        }

        function clearFinished() {
            for (let i = count - 1; i >= 0; i--) {
                if (Downloads.isFinished(get(i).state))
                    removeAt(i);
            }
        }
    }

    function downloadIndex(downloadId) {
        const id = String(downloadId || "");
        for (let i = 0; i < downloadsModel.count; i++) {
            if (String(downloadsModel.get(i).downloadId) === id)
                return i;
        }
        return -1;
    }

    function setDownloadProperty(index, role, value) {
        if (downloadsModel.get(index)[role] !== value)
            downloadsModel.setProperty(index, role, value);
    }

    function applyDownloadUpdate(download) {
        if (!download)
            return;
        const index = downloadIndex(download.id);
        if (index < 0)
            return;
        const entry = downloadCache[String(download.id)];
        const now = Date.now();
        const total = download.totalBytes > 0 ? download.totalBytes : 0;
        const received = download.receivedBytes;
        const progress = total > 0 ? Math.min(1, received / total) : 0;
        let speed = -1;
        let eta = -1;
        if (entry && download.state === WebEngineDownloadRequest.DownloadInProgress && !download.isPaused) {
            entry.samples = Downloads.pushSample(entry.samples, now, received, 10000);
            speed = Downloads.speedFromSamples(entry.samples, 10000);
            eta = Downloads.etaSeconds(received, total, speed);
        }
        setDownloadProperty(index, "state", download.state);
        setDownloadProperty(index, "receivedBytes", received);
        setDownloadProperty(index, "totalBytes", total);
        setDownloadProperty(index, "progress", download.state === WebEngineDownloadRequest.DownloadCompleted ? 1 : progress);
        setDownloadProperty(index, "isPaused", download.isPaused);
        setDownloadProperty(index, "error", download.interruptReasonString || "");
        setDownloadProperty(index, "speed", speed);
        setDownloadProperty(index, "eta", eta);
        if (entry) {
            entry.lastUpdate = now;
            entry.pending = false;
        }
        downloadsRevision++;
    }

    // Byte counters change hundreds of times per second; coalesce them.
    function scheduleDownloadUpdate(download) {
        const entry = downloadCache[String(download.id)];
        if (!entry) {
            applyDownloadUpdate(download);
            return;
        }
        if (Date.now() - entry.lastUpdate >= downloadUiIntervalMs) {
            applyDownloadUpdate(download);
        } else {
            entry.pending = true;
            if (!downloadFlushTimer.running)
                downloadFlushTimer.start();
        }
    }

    Timer {
        id: downloadFlushTimer
        interval: webViewRoot.downloadUiIntervalMs
        onTriggered: {
            for (const id in webViewRoot.downloadCache) {
                const entry = webViewRoot.downloadCache[id];
                if (entry && entry.pending)
                    webViewRoot.applyDownloadUpdate(entry.download);
            }
        }
    }

    function downloadEntry(downloadId) {
        return downloadCache[String(downloadId || "")] || null;
    }

    function cancelDownload(downloadId) {
        const entry = downloadEntry(downloadId);
        if (entry)
            entry.download.cancel();
    }

    function pauseDownload(downloadId) {
        const entry = downloadEntry(downloadId);
        if (entry)
            entry.download.pause();
    }

    function resumeDownload(downloadId) {
        const entry = downloadEntry(downloadId);
        if (entry)
            entry.download.resume();
    }

    function markDownloadSeen(downloadId) {
        const index = downloadIndex(downloadId);
        if (index >= 0 && !downloadsModel.get(index).seen) {
            downloadsModel.setProperty(index, "seen", true);
            downloadsRevision++;
        }
    }

    function downloadFileUrl(path) {
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
    }

    function openDownload(downloadId) {
        const index = downloadIndex(downloadId);
        if (index < 0)
            return;
        const item = downloadsModel.get(index);
        markDownloadSeen(downloadId);
        if (item.fullPath)
            Qt.openUrlExternally(downloadFileUrl(item.fullPath));
    }

    // Ask the file manager to reveal the file (org.freedesktop.FileManager1,
    // implemented by Dolphin and others); falls back to opening the folder.
    function showDownloadInFolder(downloadId) {
        const index = downloadIndex(downloadId);
        if (index < 0)
            return;
        const item = downloadsModel.get(index);
        markDownloadSeen(downloadId);
        if (!item.fullPath)
            return;
        const fileUrl = downloadFileUrl(item.fullPath);
        const quoted = "'" + fileUrl.replace(/'/g, "'\\''") + "'";
        fileManagerBridge.pendingFolder = item.fullPath.replace(/\/[^/]*$/, "");
        fileManagerBridge.connectSource("dbus-send --session --print-reply --dest=org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems array:string:" + quoted + " string:''");
    }

    P5Support.DataSource {
        id: fileManagerBridge
        engine: "executable"
        property string pendingFolder: ""
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
            if (Number(data["exit code"]) !== 0 && pendingFolder)
                Qt.openUrlExternally(webViewRoot.downloadFileUrl(pendingFolder));
            pendingFolder = "";
        }
    }

    // Re-request a cancelled or interrupted download from its original URL.
    // (Finished requests are released by Qt, so resume() is not available.)
    function retryDownload(downloadId) {
        const index = downloadIndex(downloadId);
        if (index < 0)
            return;
        const item = downloadsModel.get(index);
        const source = String(item.sourceUrl || "");
        if (!isHttpUrl(source))
            return;
        downloadsModel.removeAt(index);
        webview.runJavaScript("(function (u) { const a = document.createElement('a'); a.href = u; a.download = ''; a.rel = 'noopener'; document.body.appendChild(a); a.click(); a.remove(); })(" + JSON.stringify(source) + ")");
    }

    function removeDownload(downloadId) {
        const index = downloadIndex(downloadId);
        if (index >= 0 && Downloads.isFinished(downloadsModel.get(index).state))
            downloadsModel.removeAt(index);
    }

    function clearFinishedDownloads() {
        downloadsModel.clearFinished();
    }

    // Per-download KDE notification with Open / Show in Folder actions.
    Component {
        id: downloadNotificationComponent
        Notification {
            id: downloadNotification
            property string downloadId
            componentName: "plasma_workspace"
            eventId: "notification"
            iconName: "folder-download"
            actions: [
                NotificationAction {
                    label: i18n("Open")
                    onActivated: webViewRoot.openDownload(downloadNotification.downloadId)
                },
                NotificationAction {
                    label: i18n("Show in Folder")
                    onActivated: webViewRoot.showDownloadInFolder(downloadNotification.downloadId)
                }
            ]
            onClosed: destroy()
        }
    }

    function notifyDownloadFinished(download, ok) {
        const notification = downloadNotificationComponent.createObject(webViewRoot, { downloadId: String(download.id) });
        notification.title = ok ? i18n("Download finished") : i18n("Download failed");
        notification.text = ok ? download.downloadFileName : i18n("%1 — %2", download.downloadFileName, download.interruptReasonString || i18n("interrupted"));
        notification.iconName = ok ? "folder-download" : "data-warning";
        notification.sendEvent();
    }

    function printPage() {
        webview.runJavaScript("document.title", function (title) {
            const directory = webViewRoot.downloadDirectory();
            const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
            const safeName = webViewRoot.safeFileName(title, "ChatAI").replace(/[^a-z0-9._-]/gi, "-").toLowerCase();
            const filename = `${directory}/${safeName}-${timestamp}.pdf`;
            downloadsModel.addDownload(null, `${safeName}-${timestamp}.pdf`, filename, true);
            webview.printToPdf(filename, WebEngineView.A4, WebEngineView.Portrait);
        });
    }

    function saveMHTML() {
        webview.triggerWebAction(WebEngineView.SavePage);
    }

    // ---- notifications -----------------------------------------------------

    Notification {
        id: webNotification
        // Standard Plasma event: no per-applet .notifyrc required.
        componentName: "plasma_workspace"
        eventId: "notification"
        iconName: "dialog-information"
    }

    function showNotification(title, message, icon) {
        webNotification.title = title || i18n("ChatAI");
        webNotification.text = message;
        webNotification.iconName = icon || "dialog-information";
        webNotification.sendEvent();
    }

    // ---- permissions --------------------------------------------

    function combinePolicies(a, b) {
        if (a === policyBlock || b === policyBlock)
            return policyBlock;
        if (a === policyAllow && b === policyAllow)
            return policyAllow;
        return policyAsk;
    }

    function policyForPermission(type) {
        const config = plasmoid.configuration;
        switch (type) {
        case WebEnginePermission.PermissionType.Notifications:
            return config.notificationsPolicy;
        case WebEnginePermission.PermissionType.MediaAudioCapture:
            return config.microphonePolicy;
        case WebEnginePermission.PermissionType.MediaVideoCapture:
            return config.webcamPolicy;
        case WebEnginePermission.PermissionType.MediaAudioVideoCapture:
            return combinePolicies(config.microphonePolicy, config.webcamPolicy);
        case WebEnginePermission.PermissionType.DesktopVideoCapture:
        case WebEnginePermission.PermissionType.DesktopAudioVideoCapture:
            return config.screenSharePolicy;
        case WebEnginePermission.PermissionType.Geolocation:
            return config.geolocationPolicy;
        case WebEnginePermission.PermissionType.ClipboardReadWrite:
            return config.clipboardPolicy;
        default:
            // MouseLock, LocalFontsAccess, Unsupported and anything newer.
            return policyBlock;
        }
    }

    function handlePermission(permission) {
        const policy = policyForPermission(permission.permissionType);
        if (policy === policyAllow) {
            permission.grant();
        } else if (policy === policyAsk) {
            if (pendingPermission === null)
                pendingPermission = permission;
            else
                permissionQueue.push(permission);
        } else {
            permission.deny();
        }
    }

    function resolvePendingPermission(grant) {
        const permission = pendingPermission;
        pendingPermission = null;
        if (permission) {
            if (grant)
                permission.grant();
            else
                permission.deny();
            permissionsRevision++;
        }
        if (permissionQueue.length)
            pendingPermission = permissionQueue.shift();
    }

    // ---- profile -----------------------------------------------------------

    WebEngineProfilePrototype {
        id: profilePrototype

        storageName: webViewRoot.effectiveProfileName
        httpCacheType: WebEngineProfile.DiskHttpCache
        httpCacheMaximumSize: Math.max(0, plasmoid.configuration.httpCacheMaximumSize) * 1024 * 1024
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        persistentPermissionsPolicy: WebEngineProfile.StoreOnDisk
    }

    Connections {
        target: webViewRoot.webProfile

        function onPresentNotification(notification) {
            webViewRoot.showNotification(notification.title, notification.message);
            notification.show();
        }

        function onClearHttpCacheCompleted() {
            webViewRoot.clearingCache = false;
        }

        function onDownloadRequested(download) {
            const directory = webViewRoot.downloadDirectory();
            const fileName = webViewRoot.safeFileName(download.downloadFileName, "download");

            for (let i = 0; i < downloadsModel.count; i++) {
                const current = downloadsModel.get(i);
                if (Downloads.isActive(current.state) && current.fileName === fileName && !current.isPdfExport) {
                    webViewRoot.showNotification(i18n("Download in progress"), i18n("The file '%1' is already being downloaded", fileName), "dialog-warning");
                    download.cancel();
                    return;
                }
            }

            download.downloadDirectory = directory;
            download.downloadFileName = fileName;
            downloadsModel.addDownload(download, fileName, directory + "/" + fileName, false);

            // Byte counters are throttled; state and pause changes apply at once.
            const throttled = function () { webViewRoot.scheduleDownloadUpdate(download); };
            const immediate = function () { webViewRoot.applyDownloadUpdate(download); };
            download.receivedBytesChanged.connect(throttled);
            download.totalBytesChanged.connect(throttled);
            download.stateChanged.connect(immediate);
            download.isPausedChanged.connect(immediate);
            webViewRoot.downloadCache[String(download.id)] = { download: download, throttled: throttled, immediate: immediate, samples: [], lastUpdate: 0, pending: false };
            download.accept();
            webViewRoot.applyDownloadUpdate(download);
        }

        function onDownloadFinished(download) {
            webViewRoot.applyDownloadUpdate(download);
            const id = String(download.id);
            const entry = webViewRoot.downloadCache[id];
            if (entry) {
                download.receivedBytesChanged.disconnect(entry.throttled);
                download.totalBytesChanged.disconnect(entry.throttled);
                download.stateChanged.disconnect(entry.immediate);
                download.isPausedChanged.disconnect(entry.immediate);
            }
            delete webViewRoot.downloadCache[id];
            if (download.state === WebEngineDownloadRequest.DownloadCompleted) {
                webViewRoot.notifyDownloadFinished(download, true);
                webViewRoot.downloadAttention();
            } else if (download.state === WebEngineDownloadRequest.DownloadInterrupted) {
                webViewRoot.notifyDownloadFinished(download, false);
                webViewRoot.downloadAttention();
            }
        }
    }

    // ---- the view ----------------------------------------------------------

    WebEngineView {
        id: webview

        anchors.fill: parent
        // No reactive url binding: navigation is driven only by navigateTo()
        // (initial load in Component.onCompleted, then provider switch / Home /
        // custom address), so nothing competes with an in-flight load.
        profile: webViewRoot.webProfile || WebEngine.defaultProfile

        onIconChanged: {
            // Chromium already picked the best icon declared by the page.
            const value = String(icon || "").replace(/^image:\/\/favicon\//, "");
            if (!webViewRoot.isHttpUrl(value))
                return;
            if (plasmoid.configuration.favIcon !== value)
                plasmoid.configuration.favIcon = value;
            if (plasmoid.configuration.lastFavIcon !== value)
                plasmoid.configuration.lastFavIcon = value;
        }

        onLinkHovered: hoveredUrl => {
            const text = String(hoveredUrl || "");
            if (text === "") {
                hideStatusText.start();
            } else {
                statusText.text = text;
                statusBubble.visible = true;
                hideStatusText.stop();
            }
        }

        onContextMenuRequested: request => {
            if (request.isContentEditable || request.selectedText || request.mediaType !== ContextMenuRequest.MediaTypeNone) {
                request.accepted = false;
                return;
            }
            linkContextMenu.link = String(request.linkUrl || "");
            linkContextMenu.open(request.position.x, request.position.y);
            request.accepted = true;
        }

        onPermissionRequested: function (permission) {
            webViewRoot.handlePermission(permission);
        }

        onDesktopMediaRequested: function (request) {
            if (plasmoid.configuration.screenSharePolicy === webViewRoot.policyBlock || request.screensModel.rowCount() === 0)
                request.cancel();
            else
                request.selectScreen(request.screensModel.index(0, 0));
        }

        onLoadingChanged: function (loadingInfo) {
            if (loadingInfo.status === WebEngineView.LoadStartedStatus) {
                webViewRoot.hasLoadError = false;
                webViewRoot.slowResponse = false;
                slowResponseTimer.restart();
            } else if (loadingInfo.status === WebEngineView.LoadFailedStatus) {
                slowResponseTimer.stop();
                webViewRoot.slowResponse = false;
                webViewRoot.hasLoadError = true;
                webViewRoot.loadErrorDetails = loadingInfo.errorString || i18n("The service did not provide an error description.");
            } else if (loadingInfo.status === WebEngineView.LoadSucceededStatus) {
                slowResponseTimer.stop();
                webViewRoot.slowResponse = false;
                if (String(webview.url) === webViewRoot.pendingUrl)
                    webViewRoot.pendingUrl = "";
                // Chromium keeps zoom per host; re-apply the global preference.
                webViewRoot.applyZoom();
            }
        }

        onLoadProgressChanged: {
            if (loadProgress >= 10) {
                slowResponseTimer.stop();
                webViewRoot.slowResponse = false;
            }
        }

        onPrintRequested: webview.triggerWebAction(WebEngineView.Print)

        onCertificateError: function (error) {
            webViewRoot.hasLoadError = true;
            webViewRoot.loadErrorDetails = error.description || i18n("The site's security certificate is not trusted.");
            error.rejectCertificate();
        }

        onFullScreenRequested: function (request) {
            if (request.toggleOn)
                webViewRoot.enterFullScreen();
            else
                webViewRoot.exitFullScreen();
            request.accept();
        }

        onRenderProcessTerminated: function (terminationStatus, exitCode) {
            webViewRoot.hasLoadError = true;
            webViewRoot.loadErrorDetails = i18n("The web content process stopped unexpectedly (exit code %1).", exitCode);
        }

        onPdfPrintingFinished: function (filePath, success) {
            for (let i = 0; i < downloadsModel.count; i++) {
                if (downloadsModel.get(i).fullPath === filePath) {
                    downloadsModel.setProperty(i, "state", success ? WebEngineDownloadRequest.DownloadCompleted : WebEngineDownloadRequest.DownloadInterrupted);
                    downloadsModel.setProperty(i, "progress", success ? 1 : 0);
                    if (!success)
                        downloadsModel.setProperty(i, "error", i18n("The PDF could not be created."));
                    webViewRoot.downloadsRevision++;
                    webViewRoot.downloadAttention();
                    break;
                }
            }
        }

        function openExternalIfSafe(url) {
            const target = String(url || "");
            if (!webViewRoot.isHttpUrl(target)) {
                webViewRoot.showNotification(i18n("Blocked navigation"), i18n("Only HTTP and HTTPS links can be opened from ChatAI."), "dialog-warning");
                return false;
            }
            Qt.openUrlExternally(target);
            return true;
        }

        // window.open(): dialogs/windows (OAuth popups such as "Continue with
        // Google", which need window.opener + postMessage + window.close()),
        // popups that start blank and sign-in URLs open in AuthPopup with the
        // same profile; plain target="_blank" links go to the system browser.
        onNewWindowRequested: function (request) {
            const url = String(request.requestedUrl);
            const startsBlank = url === "" || url === "about:blank";
            if (!startsBlank && !webViewRoot.isHttpUrl(url))
                return; // dropped: unknown scheme
            // DestinationType lives on the C++ base class and is not exposed to
            // QML; values per the Qt docs: InWindow=0, InTab=1, InDialog=2, InBackgroundTab=3.
            const destinationWindow = WebEngineNewWindowRequest.NewViewInWindow ?? 0;
            const destinationDialog = WebEngineNewWindowRequest.NewViewInDialog ?? 2;
            const wantsWindow = request.destination === destinationDialog || request.destination === destinationWindow;
            if (wantsWindow || startsBlank || webViewRoot.providerModel.isAuthUrl(url))
                webViewRoot.openAuthPopup(request);
            else
                openExternalIfSafe(url);
        }

        // A page in the main view calling window.close() (a callback that
        // expected to be a popup): nothing to close here; go back home.
        onWindowCloseRequested: webViewRoot.goHome()

        onNavigationRequested: function (request) {
            const requestedUrl = String(request.url);
            // Sub-frames legitimately navigate to about:blank, blob: and data:
            // (Cloudflare Turnstile, Google One Tap, React portals); only the
            // main frame is restricted to HTTP(S).
            if (!request.isMainFrame)
                return;
            if (!webViewRoot.isHttpUrl(requestedUrl)) {
                request.action = WebEngineNavigationRequest.IgnoreRequest;
                return;
            }
            const isLink = request.navigationType === WebEngineNavigationRequest.NavigationTypeLinkClicked;
            if (isLink && request.userInitiated && request.disposition !== WebEngineNavigationRequest.CurrentTabDisposition) {
                request.action = WebEngineNavigationRequest.IgnoreRequest;
                if (webViewRoot.providerModel.isAuthUrl(requestedUrl))
                    webview.url = requestedUrl;
                else
                    openExternalIfSafe(requestedUrl);
            }
        }

        // https://doc.qt.io/qt-6/qml-qtwebengine-webenginesettings.html
        settings {
            spatialNavigationEnabled: plasmoid.configuration.spatialNavigationEnabled
            allowWindowActivationFromJavaScript: true
            javascriptCanAccessClipboard: plasmoid.configuration.javascriptCanAccessClipboard
            javascriptCanOpenWindows: plasmoid.configuration.javascriptCanOpenWindows
            javascriptCanPaste: plasmoid.configuration.javascriptCanPaste
            unknownUrlSchemePolicy: plasmoid.configuration.allowUnknownUrlSchemes ? WebEngineSettings.AllowUnknownUrlSchemesFromUserInteraction : WebEngineSettings.DisallowUnknownUrlSchemes
            playbackRequiresUserGesture: plasmoid.configuration.playbackRequiresUserGesture
            focusOnNavigationEnabled: plasmoid.configuration.focusOnNavigationEnabled
            screenCaptureEnabled: plasmoid.configuration.screenSharePolicy !== webViewRoot.policyBlock
            pluginsEnabled: true
            forceDarkMode: {
                const color = Kirigami.Theme.backgroundColor;
                return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) < 0.5;
            }
        }
    }

    // Mouse back/forward buttons
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onPressed: mouse => {
            if (mouse.button === Qt.BackButton)
                webViewRoot.goBack();
            else if (mouse.button === Qt.ForwardButton)
                webViewRoot.goForward();
        }
    }

    Shortcut {
        sequence: StandardKey.Find
        onActivated: webViewRoot.findBarVisible = true
    }
    Shortcut {
        sequences: [StandardKey.ZoomIn, "Ctrl+="]
        onActivated: webViewRoot.zoomIn()
    }
    Shortcut {
        sequence: StandardKey.ZoomOut
        onActivated: webViewRoot.zoomOut()
    }
    Shortcut {
        sequence: "Ctrl+0"
        onActivated: webViewRoot.zoomReset()
    }
    Shortcut {
        sequence: "F11"
        onActivated: webViewRoot.toggleFullScreen()
    }

    // Hidden helper used by copyUrl(); TextEdit.copy() uses the system clipboard.
    TextEdit {
        id: clipboardHelper
        visible: false
        width: 0
        height: 0
    }

    ContextMenu {
        id: linkContextMenu
        webviewItem: webview
        onReloadRequested: webViewRoot.reload()
        onSavePdfRequested: webViewRoot.printPage()
        onSaveMhtmlRequested: webViewRoot.saveMHTML()
    }

    function openAuthPopup(request) {
        if (authPopupLoader.active)
            authPopupLoader.active = false;
        authPopupLoader.active = true;
        request.openIn(authPopupLoader.item.view);
    }

    function closeAuthPopup() {
        authPopupLoader.active = false;
    }

    Loader {
        id: authPopupLoader
        anchors.fill: parent
        z: 25
        active: false
        sourceComponent: AuthPopup {
            profile: webViewRoot.webProfile
            providerModel: webViewRoot.providerModel
            permissionHandler: webViewRoot.handlePermission
            certificateErrorHandler: function (error) {
                error.rejectCertificate();
                webViewRoot.showNotification(i18n("Sign-in blocked"), i18n("The sign-in site's security certificate is not trusted."), "dialog-warning");
                webViewRoot.closeAuthPopup();
            }
            onCloseRequested: webViewRoot.closeAuthPopup()
            onExternalOpenRequested: url => webview.openExternalIfSafe(url)
        }
    }

    Loader {
        id: fullScreenLoader
        active: false
        source: "FullScreenWindow.qml"
        onLoaded: item.exitRequested.connect(webViewRoot.exitFullScreen)
    }

    Loader {
        id: devToolsLoader
        active: false
        source: "DevToolsWindow.qml"
        onLoaded: {
            item.inspected = webview;
            item.closeRequested.connect(webViewRoot.closeDevTools);
        }
    }

    ColumnLayout {
        id: topOverlays
        z: 10
        spacing: 0
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        PlasmaComponents3.ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 3 : 0
            visible: webview.loading && webview.loadProgress < 100
            from: 0
            to: 100
            value: webview.loadProgress
        }

        Kirigami.InlineMessage {
            id: slowResponseMessage
            Layout.fillWidth: true
            Layout.margins: visible ? Kirigami.Units.smallSpacing : 0
            visible: webViewRoot.slowResponse
            type: Kirigami.MessageType.Warning
            text: i18n("%1 is taking long to respond. Some services hold the connection for automated clients; retrying usually works.", webViewRoot.providerModel.hostOf(webViewRoot.currentUrl) || i18n("The site"))
            actions: [
                Kirigami.Action {
                    icon.name: "view-refresh"
                    text: i18n("Retry")
                    onTriggered: webViewRoot.goHome()
                },
                Kirigami.Action {
                    icon.name: "internet-web-browser"
                    text: i18n("Open in Browser")
                    onTriggered: {
                        if (webViewRoot.isHttpUrl(plasmoid.configuration.url))
                            Qt.openUrlExternally(plasmoid.configuration.url);
                    }
                }
            ]
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: visible ? Kirigami.Units.smallSpacing : 0
            visible: !webViewRoot.mobileLayoutHintDismissed && webViewRoot.cssViewportWidth < webViewRoot.desktopViewportWidth && webview.width > 0
            type: Kirigami.MessageType.Information
            showCloseButton: true
            onVisibleChanged: if (!visible && webViewRoot.cssViewportWidth < webViewRoot.desktopViewportWidth) webViewRoot.mobileLayoutHintDismissed = true
            text: webview.zoomFactor > 1.01
                ? i18n("At %1% zoom the page sees a %2 px wide viewport and switches to its mobile layout, which may break sign-in. Reset the zoom or widen the widget.", webViewRoot.zoomPercent, Math.round(webViewRoot.cssViewportWidth))
                : i18n("The page sees a %1 px wide viewport and switches to its mobile layout, which may break sign-in. Widen the widget by dragging its edge.", Math.round(webViewRoot.cssViewportWidth))
            actions: [
                Kirigami.Action {
                    visible: webview.zoomFactor > 1.01
                    icon.name: "zoom-original"
                    text: i18n("Reset Zoom")
                    onTriggered: webViewRoot.zoomReset()
                }
            ]
        }

        PermissionBar {
            Layout.fillWidth: true
            Layout.margins: active ? Kirigami.Units.smallSpacing : 0
            permission: webViewRoot.pendingPermission
            onGranted: webViewRoot.resolvePendingPermission(true)
            onDenied: webViewRoot.resolvePendingPermission(false)
        }

        FindBar {
            id: findBar
            Layout.fillWidth: true
            findBarVisible: webViewRoot.findBarVisible
            webviewItem: webview
            onCloseRequested: webViewRoot.findBarVisible = false
            onFindBarVisibleChanged: {
                if (findBarVisible)
                    findBar.focusAndSelect();
                else
                    findBar.clearSearch();
            }
        }
    }

    Rectangle {
        id: errorOverlay

        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
        opacity: 0.98
        visible: webViewRoot.hasLoadError
        z: 20

        ErrorView {
            anchors.centerIn: parent
            width: Math.min(parent.width - Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 25)
            errorDetails: webViewRoot.loadErrorDetails
            onRetryRequested: webViewRoot.reload()
            onOpenExternallyRequested: {
                if (webViewRoot.isHttpUrl(plasmoid.configuration.url))
                    Qt.openUrlExternally(plasmoid.configuration.url);
            }
        }
    }

    Rectangle {
        id: statusBubble

        readonly property int padding: Kirigami.Units.smallSpacing * 2

        color: Kirigami.Theme.backgroundColor
        visible: false
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: Math.min(statusText.implicitWidth + padding, parent.width)
        height: statusText.implicitHeight + padding
        radius: Kirigami.Units.cornerRadius

        PlasmaComponents3.Label {
            id: statusText
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            elide: Text.ElideMiddle
            verticalAlignment: Text.AlignVCenter

            Timer {
                id: hideStatusText
                interval: 750
                onTriggered: {
                    statusText.text = "";
                    statusBubble.visible = false;
                }
            }
        }
    }

}
