(() => {
  const RESERVED_PROFILE_PATHS = new Set([
    "compose",
    "explore",
    "grok",
    "home",
    "i",
    "intent",
    "login",
    "logout",
    "messages",
    "notifications",
    "search",
    "settings",
    "share",
    "signup"
  ]);

  function encoded(value) {
    return encodeURIComponent(value);
  }

  function firstQueryValue(url, ...names) {
    for (const name of names) {
      const value = url.searchParams.get(name);
      if (value) {
        return value;
      }
    }
    return null;
  }

  function deepLinkForPage(pageURL) {
    const url = new URL(pageURL);
    const pathParts = url.pathname.split("/").filter(Boolean);
    const firstPart = (pathParts[0] || "").toLowerCase();

    const statusIndex = pathParts.findIndex(
      (part) => part.toLowerCase() === "status"
    );
    if (statusIndex >= 0 && /^\d+$/.test(pathParts[statusIndex + 1] || "")) {
      return `bhtwitter://status?id=${encoded(pathParts[statusIndex + 1])}`;
    }

    if (pathParts.length === 0 || firstPart === "home") {
      return "bhtwitter://timeline";
    }

    if (firstPart === "explore") {
      return "bhtwitter://search?query=";
    }

    if (firstPart === "search") {
      const query = firstQueryValue(url, "q", "query") || "";
      return `bhtwitter://search?query=${encoded(query)}`;
    }

    if (firstPart === "notifications") {
      return "bhtwitter://mentions";
    }

    if (firstPart === "messages") {
      if ((pathParts[1] || "").toLowerCase() === "compose") {
        return "bhtwitter://messages/compose";
      }
      return "bhtwitter://connect";
    }

    if (firstPart === "compose" && (pathParts[1] || "").toLowerCase() === "post") {
      return "bhtwitter://post";
    }

    if (firstPart === "grok") {
      return "bhtwitter://grok";
    }

    if (firstPart === "i" && (pathParts[1] || "").toLowerCase() === "communities") {
      return "bhtwitter://communities";
    }

    if (firstPart === "settings") {
      const settingsPath = pathParts.slice(1).join("/");
      return settingsPath
        ? `bhtwitter://settings/${settingsPath}`
        : "bhtwitter://settings";
    }

    if (pathParts.length === 1 && !RESERVED_PROFILE_PATHS.has(firstPart)) {
      return `bhtwitter://user?screen_name=${encoded(pathParts[0])}`;
    }

    const fallbackPath = url.pathname.replace(/^\/+/, "");
    return `bhtwitter://${fallbackPath}${url.search}${url.hash}`;
  }

  browser.runtime.onMessage.addListener((message) => {
    if (!message || message.type !== "BHTWITTER_OPEN_CURRENT_PAGE") {
      return undefined;
    }

    const deepLink = deepLinkForPage(window.location.href);
    setTimeout(() => {
      window.location.assign(deepLink);
    }, 0);

    return Promise.resolve({ deepLink });
  });
})();
