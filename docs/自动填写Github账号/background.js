// 监听扩展图标点击事件，点击时在当前窗口打开侧边栏
chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true }).catch((error) => console.error(error));