browser.browserAction.onClicked.addListener((tab) => {
  if (!tab || typeof tab.id !== "number") {
    return;
  }

  browser.tabs.sendMessage(tab.id, {
    type: "BHTWITTER_OPEN_CURRENT_PAGE"
  }).catch((error) => {
    console.error("Open in X could not contact the current page:", error);
  });
});
