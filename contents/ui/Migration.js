/*
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */
.pragma library

// One-shot, idempotent migration of configuration written by ChatAI <= 1.0.0.
// `config` is plasmoid.configuration,
// `legacyUrlMap` maps legacy provider URLs to their canonical URL.

var CURRENT_VERSION = 2;
var LEGACY_DEFAULT_URL = "https://duckduckgo.com/chat";

var POLICY_ASK = 0;
var POLICY_ALLOW = 1;
var POLICY_BLOCK = 2;

// Legacy custom sites were stored as "name|url,name|url".
function parseLegacyCustomSites(serialized) {
    var result = [];
    String(serialized || "").split(",").forEach(function (entry) {
        var separator = entry.indexOf("|");
        if (separator <= 0)
            return;
        var name = entry.slice(0, separator).trim();
        var url = entry.slice(separator + 1).trim();
        if (name && /^https?:\/\/[^\s]+$/i.test(url))
            result.push({ name: name, url: url });
    });
    return result;
}

// Heuristic: a fresh installation has only default values. Any of these
// markers means the widget was used before this schema existed.
function isExistingInstall(config) {
    return Boolean(config.lastFavIcon) || Number(config.dialogWidth) > 0 || Boolean(config.customSites)
        || (config.url && config.url !== LEGACY_DEFAULT_URL && config.url !== "https://duck.ai/chat");
}

function run(config, legacyUrlMap) {
    var version = Number(config.configVersion) || 0;
    if (version >= CURRENT_VERSION)
        return false;

    var existing = isExistingInstall(config);

    // B1: keepOpen and pin represented the same state.
    if (config.keepOpen && !config.pin)
        config.pin = true;

    // B2: hidePrintButton was wired to the auto-hide button.
    if (config.hidePrintButton)
        config.hideAutoHideButton = true;

    // Custom sites: pipe/comma format -> JSON.
    if (config.customSites && !config.customSitesJson) {
        var sites = parseLegacyCustomSites(config.customSites);
        if (sites.length)
            config.customSitesJson = JSON.stringify(sites);
        config.customSites = "";
    }

    // Permissions: booleans -> per-type policy.
    if (existing) {
        if (config.notificationsEnabled === false)
            config.notificationsPolicy = POLICY_BLOCK;
        if (config.microphoneEnabled)
            config.microphonePolicy = POLICY_ALLOW;
        if (config.webcamEnabled)
            config.webcamPolicy = POLICY_ALLOW;
        if (config.screenShareEnabled)
            config.screenSharePolicy = POLICY_ALLOW;
        if (config.geolocationEnabled)
            config.geolocationPolicy = POLICY_ALLOW;
        // The default of javascriptCanPaste changed to false; keep the
        // behaviour existing users had.
        config.javascriptCanPaste = true;
    }

    // Provider URLs that moved (x.com/i/grok -> grok.com, duckduckgo.com/chat -> duck.ai/chat).
    if (legacyUrlMap) {
        var current = String(config.url || "");
        for (var legacy in legacyUrlMap) {
            if (current === legacy || current.indexOf(legacy + "/") === 0 || current.indexOf(legacy + "?") === 0) {
                config.url = legacyUrlMap[legacy];
                break;
            }
        }
    }

    // Schema 2: an earlier 1.0.1 build switched existing installs to the
    // Chromium-compatible identity; Google sign-in rejects that identity
    // ("browser or app may not be secure") while the honest Qt WebEngine UA
    // is accepted, so undo it. Users can re-enable it in Advanced.
    if (version < 2 && config.compatibilityUserAgent === true)
        config.compatibilityUserAgent = false;

    config.configVersion = CURRENT_VERSION;
    return true;
}
