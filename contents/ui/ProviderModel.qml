/*
 *  SPDX-FileCopyrightText: 2026 ChatAI-Plasmoid contributors
 *  SPDX-FileCopyrightText: 2026 Rafael Ruscher <rruscher@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick


/*
 * Single source of truth for AI providers.
 *
 * Adding a provider means adding one entry to `builtInProviders` and one
 * `showX` Bool entry to contents/config/main.xml (plus SVG assets). Everything
 * else — selector, panel icon, settings page, user agent, auth handling —
 * reads from here.
 *
 * Fields:
 *   id, name, url, legacyUrls[], configKey, iconId, iconStyles[] (subset of
 *   "colorful", "filled", "outlined"), category, description, requiresLogin,
 *   supportsMicrophone, supportsCamera, supportsUpload, supportsNotifications,
 *   supportsWebSearch, userAgent (optional full override), stripQtToken
 *   (drop only the "QtWebEngine/x.y" token; avoid — Google sign-in rejects
 *   disguised browsers), loginNotes, compatibilityNotes.
 */
QtObject {
    id: providerModel

    readonly property string defaultUrl: "https://duck.ai/chat"
    readonly property string defaultProfileName: "chat-ai"

    readonly property var categories: ({
        general: i18nc("provider category", "General"),
        search: i18nc("provider category", "Search"),
        code: i18nc("provider category", "Code"),
        privacy: i18nc("provider category", "Privacy"),
        agent: i18nc("provider category", "Agents"),
        open: i18nc("provider category", "Open models")
    })

    readonly property string googleLoginNote: i18n("Google sign-in works with the default browser identity. If Google says the browser may not be secure, make sure \"Identify as Chromium\" is off in Advanced.")

    readonly property var builtInProviders: [
        {
            id: "chatgpt", name: "ChatGPT", url: "https://chatgpt.com", configKey: "showChatGPT",
            iconId: "chatgpt", iconStyles: ["colorful", "filled", "outlined"], category: "general",
            description: i18n("OpenAI's assistant with voice, files and web search."),
            requiresLogin: true, supportsMicrophone: true, supportsCamera: false, supportsUpload: true,
            supportsNotifications: true, supportsWebSearch: true, loginNotes: googleLoginNote
        },
        {
            id: "claude", name: "Claude", url: "https://claude.ai/new", configKey: "showClaude",
            iconId: "claude", iconStyles: ["colorful", "filled", "outlined"], category: "general",
            description: i18n("Anthropic's assistant for writing, analysis and code."),
            requiresLogin: true, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true,
            loginNotes: i18n("Claude only allows account creation and Google sign-in in well-known browsers. Sign in with an e-mail code or reuse credentials created in a regular browser.")
        },
        {
            id: "google", name: "Google Gemini", url: "https://gemini.google.com/app", configKey: "showGoogleGemini",
            iconId: "google", iconStyles: ["colorful", "filled", "outlined"], category: "general",
            description: i18n("Google's multimodal assistant."),
            requiresLogin: true, supportsMicrophone: true, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true, loginNotes: googleLoginNote
        },
        {
            id: "deepseek", name: "DeepSeek", url: "https://chat.deepseek.com", configKey: "showDeepSeek",
            iconId: "deepseek", iconStyles: ["colorful", "filled", "outlined"], category: "open",
            description: i18n("DeepSeek's chat with reasoning mode."),
            requiresLogin: true, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true
        },
        {
            id: "duckduckgo", name: "Duck.ai", url: "https://duck.ai/chat", legacyUrls: ["https://duckduckgo.com/chat"],
            configKey: "showDuckDuckGoChat", iconId: "duckduckgo", iconStyles: ["colorful", "filled", "outlined"], category: "privacy",
            description: i18n("Private, anonymous access to several models. No account needed."),
            requiresLogin: false, supportsMicrophone: true, supportsCamera: false, supportsUpload: false,
            supportsNotifications: false, supportsWebSearch: false
        },
        {
            id: "perplexity", name: "Perplexity", url: "https://www.perplexity.ai", configKey: "showPerplexity",
            iconId: "perplexity", iconStyles: ["colorful", "filled", "outlined"], category: "search",
            description: i18n("Answer engine with cited web sources."),
            requiresLogin: false, supportsMicrophone: true, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true
        },
        {
            id: "copilot", name: "Microsoft Copilot", url: "https://copilot.microsoft.com/", configKey: "showBingCopilot",
            iconId: "copilot", iconStyles: ["colorful", "filled", "outlined"], category: "general",
            description: i18n("Microsoft's assistant (formerly Bing Copilot)."),
            requiresLogin: false, supportsMicrophone: true, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true
        },
        {
            id: "githubcopilot", name: "GitHub Copilot", url: "https://github.com/copilot", configKey: "showGitHubCopilot",
            iconId: "githubcopilot", iconStyles: ["filled"], category: "code",
            description: i18n("Copilot Chat on github.com with repository context. Requires a GitHub account."),
            requiresLogin: true, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true,
        },
        {
            id: "mistral", name: "Mistral Vibe", url: "https://chat.mistral.ai", configKey: "showMistral",
            iconId: "mistral", iconStyles: ["colorful", "filled"], category: "general",
            description: i18n("Mistral's assistant and agent (formerly Le Chat)."),
            requiresLogin: true, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true, loginNotes: googleLoginNote
        },
        {
            id: "grok", name: "Grok", url: "https://grok.com", legacyUrls: ["https://x.com/i/grok"], configKey: "showGrok",
            iconId: "grok", iconStyles: [], category: "general",
            description: i18n("xAI's assistant. Works without an account with limits."),
            requiresLogin: false, supportsMicrophone: true, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true, loginNotes: googleLoginNote
        },
        {
            id: "qwen", name: "Qwen", url: "https://chat.qwen.ai", configKey: "showQwen",
            iconId: "qwen", iconStyles: ["colorful", "filled"], category: "open",
            description: i18n("Alibaba's Qwen Studio: chat, images, documents and web search."),
            requiresLogin: false, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true, loginNotes: googleLoginNote
        },
        {
            id: "kimi", name: "Kimi", url: "https://www.kimi.com", configKey: "showKimi",
            iconId: "kimi", iconStyles: ["filled"], category: "open",
            description: i18n("Moonshot AI's assistant with long-context and research modes."),
            requiresLogin: false, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true, loginNotes: googleLoginNote
        },
        {
            id: "manus", name: "Manus", url: "https://manus.im/app", configKey: "showManus",
            iconId: "manus", iconStyles: ["colorful", "filled"], category: "agent",
            description: i18n("General AI agent with a chat mode. Requires an account."),
            requiresLogin: true, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: true, supportsWebSearch: true, loginNotes: googleLoginNote
        },
        {
            id: "huggingface", name: "HuggingChat", url: "https://huggingface.co/chat", configKey: "showHugginChat",
            iconId: "huggingface", iconStyles: ["colorful", "filled", "outlined"], category: "open",
            description: i18n("Hugging Face's chat with open models (Omni router)."),
            requiresLogin: false, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true
        },
        {
            id: "meta", name: "Meta AI", url: "https://www.meta.ai", configKey: "showMetaAI",
            iconId: "meta", iconStyles: ["colorful", "filled"], category: "general",
            description: i18n("Meta's assistant. Availability depends on your region."),
            requiresLogin: true, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true
        },
        {
            id: "t3", name: "T3 Chat", url: "https://t3.chat", configKey: "showT3Chat",
            iconId: "t3", iconStyles: ["colorful", "filled", "outlined"], category: "general",
            description: i18n("Fast multi-model chat client."),
            requiresLogin: true, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true, loginNotes: googleLoginNote
        },
        {
            id: "you", name: "You.com", url: "https://you.com/?chatMode=default", configKey: "showYou",
            iconId: "you", iconStyles: ["colorful", "filled", "outlined"], category: "search",
            description: i18n("You.com chat. The product now targets enterprise users; a login is required."),
            requiresLogin: true, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true
        },
        {
            id: "blackbox", name: "BlackBox AI", url: "https://www.blackbox.ai", configKey: "showBlackBox",
            iconId: "blackbox", iconStyles: [], category: "code",
            description: i18n("Coding-oriented assistant."),
            requiresLogin: true, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true
        },
        {
            id: "lobechat", name: "LobeChat", url: "https://lobechat.com/chat", configKey: "showLobeChat",
            iconId: "lobechat", iconStyles: ["colorful"], category: "open",
            description: i18n("LobeHub cloud chat (bring your own keys or subscription)."),
            requiresLogin: true, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: true
        },
        {
            id: "bigagi", name: "Big-AGI", url: "https://get.big-agi.com", configKey: "showBigAGI",
            iconId: "bigagi", iconStyles: ["colorful"], category: "open",
            description: i18n("Big-AGI web client (bring your own keys)."),
            requiresLogin: false, supportsMicrophone: false, supportsCamera: false, supportsUpload: true,
            supportsNotifications: false, supportsWebSearch: false
        }
    ]

    // Custom providers come from customSitesJson; the legacy "name|url,…"
    // string is still understood so the settings dialog works before the
    // runtime migration has run.
    readonly property var customProviders: parseCustomProviders(plasmoid.configuration.customSitesJson, plasmoid.configuration.customSites)

    readonly property var providers: builtInProviders.concat(customProviders)

    // Reactive: the binding reads every configKey, so the engine re-evaluates
    // whenever any showX key or the custom list changes. No Connections needed.
    readonly property var enabledProviders: providers.filter(provider => isEnabled(provider))

    function isEnabled(provider) {
        return Boolean(provider) && (!provider.configKey || Boolean(plasmoid.configuration[provider.configKey]));
    }

    // True for http(s) URLs with a host. Only the scheme and host are checked:
    // QUrl converted to a JS string is "pretty decoded", so query strings may
    // legitimately contain spaces (e.g. OAuth "scope=openid profile email").
    // Rejecting those aborted every Google sign-in.
    function isHttpUrl(value) {
        return /^https?:\/\/[^\s\/?#]+([\/?#]|$)/i.test(String(value || ""));
    }

    // Stricter validation for addresses typed by the user or stored in the
    // configuration: no whitespace anywhere.
    function normalizeUrl(value) {
        let candidate = String(value || "").trim();
        if (!candidate || /\s/.test(candidate))
            return "";
        if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(candidate))
            candidate = "https://" + candidate;
        return isHttpUrl(candidate) ? candidate : "";
    }

    function hostOf(value) {
        const match = String(value || "").match(/^[a-z][a-z0-9+.-]*:\/\/([^/?#]+)/i);
        return match ? match[1].toLowerCase() : "";
    }

    function slug(value) {
        const result = String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
        return result || "site";
    }

    function parseCustomProviders(json, legacy) {
        let entries = [];
        const text = String(json || "").trim();
        if (text) {
            try {
                const parsed = JSON.parse(text);
                if (Array.isArray(parsed))
                    entries = parsed;
            } catch (error) {
                console.warn("ChatAI: customSitesJson is not valid JSON:", error);
            }
        } else if (legacy) {
            String(legacy).split(",").forEach(entry => {
                const separator = entry.indexOf("|");
                if (separator > 0)
                    entries.push({ name: entry.slice(0, separator), url: entry.slice(separator + 1) });
            });
        }
        const result = [];
        entries.forEach(entry => {
            if (!entry || typeof entry !== "object")
                return;
            const name = String(entry.name || "").trim();
            const url = normalizeUrl(entry.url);
            if (!name || !url)
                return;
            result.push({
                id: "custom-" + slug(name),
                name: name,
                url: url,
                configKey: "",
                iconId: "logo",
                iconStyles: [],
                category: "custom",
                custom: true,
                requiresLogin: false
            });
        });
        return result;
    }

    function serializeCustomProviders(list) {
        return JSON.stringify((list || []).map(entry => ({ name: String(entry.name || "").trim(), url: normalizeUrl(entry.url) }))
            .filter(entry => entry.name && entry.url));
    }

    function matchesUrl(base, candidate) {
        return candidate === base || candidate.indexOf(base + "/") === 0 || candidate.indexOf(base + "?") === 0;
    }

    function providerForUrl(value) {
        const candidate = String(value || "");
        return providers.find(provider => matchesUrl(provider.url, candidate)
            || (provider.legacyUrls || []).some(legacy => matchesUrl(legacy, candidate))) || null;
    }

    function nameForUrl(value) {
        const provider = providerForUrl(value);
        return provider ? provider.name : hostOf(value) || String(value || "");
    }

    function legacyUrlMap() {
        const map = {};
        builtInProviders.forEach(provider => (provider.legacyUrls || []).forEach(legacy => { map[legacy] = provider.url; }));
        return map;
    }

    function categoryName(category) {
        return categories[category] || (category === "custom" ? i18nc("provider category", "Custom") : "");
    }

    // Relative asset path for a provider icon, or "" when the project logo
    // should be used. `style` is "colorful", "filled" or "outlined";
    // `contrast` is "dark" or "light" (icon colour against the background).
    function iconSource(provider, style, contrast) {
        if (!provider || provider.custom)
            return "";
        const styles = provider.iconStyles || [];
        const iconId = provider.iconId || provider.id;
        if (style === "colorful") {
            if (styles.indexOf("colorful") !== -1)
                return "assets/colorful/" + iconId + ".svg";
            if (styles.indexOf("filled") !== -1)
                return "assets/filled/" + iconId + "-" + contrast + ".svg";
            return "";
        }
        if (style === "outlined" && styles.indexOf("outlined") !== -1)
            return "assets/outlined/" + iconId + "-" + contrast + ".svg";
        if (styles.indexOf("filled") !== -1)
            return "assets/filled/" + iconId + "-" + contrast + ".svg";
        if (style === "outlined" || style === "filled") {
            if (styles.indexOf("colorful") !== -1)
                return "assets/colorful/" + iconId + ".svg";
        }
        return "";
    }

    // Authentication URLs are kept inside the widget (main view or the OAuth
    // popup) instead of being sent to the external browser. Matching is by
    // exact host or subdomain — never by substring — optionally limited to
    // path prefixes. `accounts.google.com.evil.example` does not match.
    readonly property var authRules: [
        { host: "accounts.google.com" }, { host: "accounts.youtube.com" }, { host: "myaccount.google.com" },
        { host: "appleid.apple.com" }, { host: "login.live.com" }, { host: "login.microsoftonline.com" }, { host: "login.microsoft.com" },
        { host: "github.com", paths: ["/login", "/session", "/sessions"] },
        { host: "facebook.com" }, { host: "instagram.com" },
        { host: "x.com", paths: ["/i/flow", "/i/oauth2", "/oauth"] }, { host: "twitter.com", paths: ["/i/flow", "/i/oauth2", "/oauth"] },
        { host: "auth.openai.com" }, { host: "auth0.openai.com" }, { host: "login.anthropic.com" },
        { host: "account.mistral.ai" }, { host: "auth.mistral.ai" }, { host: "login.aliyun.com" }, { host: "account.qwen.ai" },
        { host: "auth.huggingface.co" }, { host: "accounts.x.ai" }, { host: "id.kimi.com" }, { host: "auth.perplexity.ai" }
    ]

    function hostMatches(host, ruleHost) {
        return host === ruleHost || host.endsWith("." + ruleHost);
    }

    function pathOf(value) {
        const match = String(value || "").match(/^[a-z][a-z0-9+.-]*:\/\/[^/?#]+([^?#]*)/i);
        return match ? (match[1] || "/") : "/";
    }

    function isAuthUrl(value) {
        const url = String(value || "");
        if (!isHttpUrl(url))
            return false;
        const host = hostOf(url).replace(/:\d+$/, "");
        const path = pathOf(url).toLowerCase();
        if (authRules.some(rule => hostMatches(host, rule.host) && (!rule.paths || rule.paths.some(prefix => path.indexOf(prefix) === 0))))
            return true;
        // Generic OAuth/OpenID paths on any host: keeps the flow in the widget,
        // it never grants anything else.
        return /(^|\/)(oauth2?|o\/oauth2|authorize|login|signin|sign_in|sign-in|sso|auth|openid|saml|consent|callback)(\/|$|\.)/.test(path);
    }

    // User agent policy: Qt WebEngine's honest default UA. Measured
    // 2026-09-17: Google sign-in ACCEPTS it and REJECTS a UA that claims plain
    // Chrome or Firefox ("browser or app may not be secure"), so hiding the
    // QtWebEngine token is opt-in (compatibilityUserAgent) or per provider
    // (stripQtToken). A provider may declare a full override (userAgent); an
    // advanced custom UA has the highest precedence.
    function stripQtToken(userAgent) {
        return String(userAgent || "").replace(/\s*QtWebEngine\/[\d.]+/, "");
    }

    function effectiveUserAgent(defaultUserAgent, provider) {
        const custom = String(plasmoid.configuration.customUserAgent || "").trim();
        if (custom)
            return custom;
        if (provider && provider.userAgent)
            return provider.userAgent;
        const base = String(defaultUserAgent || "");
        if (plasmoid.configuration.compatibilityUserAgent || (provider && provider.stripQtToken))
            return stripQtToken(base);
        return base;
    }
}
