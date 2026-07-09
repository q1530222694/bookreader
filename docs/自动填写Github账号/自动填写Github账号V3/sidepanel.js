// 【1. 顶部开关逻辑】
const toggleBtn = document.getElementById('autofillToggle');
const statusText = document.getElementById('switchStatusText');

chrome.storage.local.get(['isAutofillEnabled'], function(result) {
    const isEnabled = result.isAutofillEnabled !== false; 
    if (toggleBtn) toggleBtn.checked = isEnabled;
    if (statusText) statusText.innerText = isEnabled ? "自动填充: 开启" : "自动填充: 关闭";
});

if (toggleBtn) {
    toggleBtn.addEventListener('change', (e) => {
        const isEnabled = e.target.checked;
        if (statusText) statusText.innerText = isEnabled ? "自动填充: 开启" : "自动填充: 关闭";
        chrome.storage.local.set({ isAutofillEnabled: isEnabled });
    });
}

// 【2. 账号生成基础算法】
function generateRandomString(length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

function generateRandomLetter() {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    return letters.charAt(Math.floor(Math.random() * letters.length));
}

function generatePassword() {
    return 'Git#' + generateRandomString(8).toUpperCase() + generateRandomString(4);
}

function getNowFormatDate() {
    const date = new Date();
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}:${String(date.getSeconds()).padStart(2, '0')}`;
}

// 【3. 历史记录渲染逻辑】
function renderHistory() {
    const latestContainer = document.getElementById('latestHistory');
    const historyListContainer = document.getElementById('historyList');
    
    if (latestContainer) latestContainer.innerHTML = '';
    if (historyListContainer) historyListContainer.innerHTML = '';

    chrome.storage.local.get(['accountHistory'], function(result) {
        const history = result.accountHistory || [];
        
        if (history.length === 0) {
            if (latestContainer) latestContainer.innerHTML = '<div style="color:#999; text-align:center; padding: 10px 0; font-size:12px;">暂无生成记录</div>';
            if (historyListContainer) historyListContainer.innerHTML = '<div style="color:#999; text-align:center; padding: 20px 0; font-size:12px;">暂无生成记录</div>';
            return;
        }

        const createItemHtml = (item) => {
            const prefix = item.emailPrefix || (item.email ? item.email.split('@')[0] : '');
            return `
                <div class="history-time">[${item.time}]</div>
                <div class="history-details">
                    <strong>前:</strong> ${prefix}<br>
                    <strong>邮:</strong> ${item.email}<br>
                    <strong>主:</strong> ${item.username}<br>
                    <strong>密:</strong> ${item.password}
                </div>
                <div class="history-ops">
                    <button class="mini-copy-btn" data-text="${prefix}">前缀</button>
                    <button class="mini-copy-btn" data-text="${item.email}">邮箱</button>
                    <button class="mini-copy-btn" data-text="${item.username}">用户</button>
                    <button class="mini-copy-btn" data-text="${item.password}">密码</button>
                </div>
            `;
        };

        if (latestContainer) {
            const latestDiv = document.createElement('div');
            latestDiv.className = 'history-item';
            latestDiv.style.border = "1px solid #eee";
            latestDiv.style.background = "#f8f9fa";
            latestDiv.style.borderRadius = "4px";
            latestDiv.innerHTML = createItemHtml(history[0]);
            latestContainer.appendChild(latestDiv);
        }

        if (historyListContainer) {
            history.forEach((item) => {
                const itemDiv = document.createElement('div');
                itemDiv.className = 'history-item';
                itemDiv.innerHTML = createItemHtml(item);
                historyListContainer.appendChild(itemDiv);
            });
        }

        document.querySelectorAll('.mini-copy-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const textToCopy = e.target.getAttribute('data-text');
                navigator.clipboard.writeText(textToCopy).then(() => {
                    const originalText = e.target.innerText;
                    e.target.innerText = "成功";
                    setTimeout(() => { e.target.innerText = originalText; }, 1000);
                });
            });
        });
    });
}

// 【4. 弹窗交互逻辑】
const historyModal = document.getElementById('historyModal');
const viewAllBtn = document.getElementById('viewAllBtn');
const closeModalBtn = document.getElementById('closeModalBtn');

if (viewAllBtn && historyModal) viewAllBtn.addEventListener('click', () => historyModal.style.display = 'block');
if (closeModalBtn && historyModal) closeModalBtn.addEventListener('click', () => historyModal.style.display = 'none');
window.addEventListener('click', (event) => {
    if (historyModal && event.target === historyModal) historyModal.style.display = 'none';
});

// ==================== 核心后缀切换逻辑 ====================
let currentBaseAccount = null;

function getSelectedSuffix() {
    const selected = document.querySelector('input[name="accountSuffix"]:checked');
    return selected ? selected.value : "";
}

function applyCurrentAccount(addToHistory = false) {
    if (!currentBaseAccount) return;

    const suffix = getSelectedSuffix();
    const finalPrefix = currentBaseAccount.basePrefix + suffix;
    const finalEmail = finalPrefix + "@outlook.com";
    const finalUsername = "User-" + finalPrefix;
    const finalPassword = currentBaseAccount.password;

    if (document.getElementById('emailPrefix')) document.getElementById('emailPrefix').value = finalPrefix;
    if (document.getElementById('email')) document.getElementById('email').value = finalEmail;
    if (document.getElementById('username')) document.getElementById('username').value = finalUsername;
    if (document.getElementById('password')) document.getElementById('password').value = finalPassword;

    chrome.storage.local.set({
        githubData: { email: finalEmail, username: finalUsername, password: finalPassword },
        lastGeneratedAccount: { 
            basePrefix: currentBaseAccount.basePrefix, 
            password: currentBaseAccount.password, 
            suffix: suffix 
        }
    });

    if (addToHistory) {
        const timeStr = getNowFormatDate();
        chrome.storage.local.get(['accountHistory'], function(result) {
            const history = result.accountHistory || [];
            history.unshift({ time: timeStr, emailPrefix: finalPrefix, email: finalEmail, username: finalUsername, password: finalPassword });
            if (history.length > 100) history.pop();
            chrome.storage.local.set({ accountHistory: history }, renderHistory);
        });
    }
}

document.querySelectorAll('input[name="accountSuffix"]').forEach(radio => {
    radio.addEventListener('change', () => applyCurrentAccount(false));
});

const clearSuffixBtn = document.getElementById('clearSuffixBtn');
if (clearSuffixBtn) {
    clearSuffixBtn.addEventListener('click', () => {
        document.querySelectorAll('input[name="accountSuffix"]').forEach(r => r.checked = false);
        applyCurrentAccount(false);
    });
}

// 【5. 恢复当前界面账号】
function restoreCurrentAccount() {
    chrome.storage.local.get(['lastGeneratedAccount'], function(result) {
        if (result.lastGeneratedAccount) {
            const data = result.lastGeneratedAccount;
            if (data.basePrefix) {
                currentBaseAccount = { basePrefix: data.basePrefix, password: data.password };
                const savedSuffix = data.suffix || "";
                document.querySelectorAll('input[name="accountSuffix"]').forEach(r => {
                    r.checked = (r.value === savedSuffix);
                });
                applyCurrentAccount(false);
            } 
            else if (data.emailPrefix) {
                currentBaseAccount = { basePrefix: data.emailPrefix, password: data.password };
                applyCurrentAccount(false);
            }
        }
    });
}

// ==================== 🌟新增：常用邮箱自动保存与加载逻辑🌟 ====================
function loadCommonEmails() {
    chrome.storage.local.get(['commonEmailsConfig'], function(result) {
        const emails = result.commonEmailsConfig || { e1: '', e2: '', e3: '' };
        if (document.getElementById('commonEmail1')) document.getElementById('commonEmail1').value = emails.e1 || '';
        if (document.getElementById('commonEmail2')) document.getElementById('commonEmail2').value = emails.e2 || '';
        if (document.getElementById('commonEmail3')) document.getElementById('commonEmail3').value = emails.e3 || '';
    });
}

function saveCommonEmails() {
    const e1 = document.getElementById('commonEmail1')?.value || '';
    const e2 = document.getElementById('commonEmail2')?.value || '';
    const e3 = document.getElementById('commonEmail3')?.value || '';
    chrome.storage.local.set({ commonEmailsConfig: { e1, e2, e3 } });
}

// 绑定输入框事件，只要打字/粘贴，立刻自动存入本地
['commonEmail1', 'commonEmail2', 'commonEmail3'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('input', saveCommonEmails);
});

// 页面加载完毕后初始化所有数据
document.addEventListener('DOMContentLoaded', () => {
    renderHistory();
    restoreCurrentAccount();
    loadCommonEmails(); // 加载常用邮箱
});

// 【6. 主生成按钮逻辑】
const generateBtn = document.getElementById('generateBtn');
if (generateBtn) {
    generateBtn.addEventListener('click', () => {
        const firstLetter = generateRandomLetter();
        const remainingStr = generateRandomString(7);
        
        currentBaseAccount = {
            basePrefix: firstLetter + remainingStr,
            password: generatePassword()
        };
        
        document.querySelectorAll('input[name="accountSuffix"]').forEach(r => r.checked = false);
        applyCurrentAccount(true);
    });
}

// 【7. 主界面复制按钮逻辑 (通用版，能同时接管新加的常用邮箱按钮)】
document.querySelectorAll('.copy-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        const targetId = e.target.getAttribute('data-target');
        const inputElement = document.getElementById(targetId);
        if (!inputElement || !inputElement.value) return;
        
        navigator.clipboard.writeText(inputElement.value).then(() => {
            const originalText = e.target.innerText;
            e.target.innerText = "已复制!";
            setTimeout(() => { e.target.innerText = originalText; }, 1500);
        });
    });
});

// 【8. 清空历史记录逻辑】
const clearBtn = document.getElementById('clearBtn');
if (clearBtn) {
    clearBtn.addEventListener('click', () => {
        if (confirm('确定要清空所有的生成记录吗？')) {
            chrome.storage.local.set({ accountHistory: [], lastGeneratedAccount: null }, () => {
                if (document.getElementById('emailPrefix')) document.getElementById('emailPrefix').value = '';
                if (document.getElementById('email')) document.getElementById('email').value = '';
                if (document.getElementById('username')) document.getElementById('username').value = '';
                if (document.getElementById('password')) document.getElementById('password').value = '';
                
                currentBaseAccount = null;
                document.querySelectorAll('input[name="accountSuffix"]').forEach(r => r.checked = false);
                
                renderHistory();
                if (historyModal) historyModal.style.display = 'none'; 
            });
        }
    });
}

// 【9. 核弹级深度清理并跳转：GitHub】
const logoutBtn = document.getElementById('logoutBtn');
if (logoutBtn) {
    logoutBtn.addEventListener('click', () => {
        const originalText = logoutBtn.innerText;
        logoutBtn.innerText = "正在穿透沙盒清理(GitHub)...";
        logoutBtn.style.background = "#6c757d";

        const ghDomains = ["github.com"];
        
        const clearCookies = new Promise((resolve) => {
            chrome.cookies.getAllCookieStores(function(stores) {
                let storePromises = [];
                stores.forEach(store => {
                    let p = new Promise(resolveStore => {
                        chrome.cookies.getAll({ storeId: store.id }, function(cookies) {
                            let removePromises = [];
                            cookies.forEach(cookie => {
                                if (ghDomains.some(d => cookie.domain.includes(d))) {
                                    const domainName = cookie.domain.startsWith(".") ? cookie.domain.substring(1) : cookie.domain;
                                    const urlHttp = "http://" + domainName + cookie.path;
                                    const urlHttps = "https://" + domainName + cookie.path;
                                    
                                    let removeHttp = { url: urlHttp, name: cookie.name, storeId: store.id };
                                    let removeHttps = { url: urlHttps, name: cookie.name, storeId: store.id };
                                    
                                    if (cookie.partitionKey) {
                                        removeHttp.partitionKey = cookie.partitionKey;
                                        removeHttps.partitionKey = cookie.partitionKey;
                                    }

                                    removePromises.push(new Promise(r => chrome.cookies.remove(removeHttp, r)));
                                    removePromises.push(new Promise(r => chrome.cookies.remove(removeHttps, r)));
                                }
                            });
                            Promise.all(removePromises).then(resolveStore);
                        });
                    });
                    storePromises.push(p);
                });
                Promise.all(storePromises).then(resolve);
            });
        });

        const clearStorage = new Promise((resolve) => {
            chrome.tabs.query({}, function(tabs) {
                let injectPromises = [];
                tabs.forEach(tab => {
                    if (tab.url && ghDomains.some(d => tab.url.includes(d))) {
                        let p = chrome.scripting.executeScript({
                            target: { tabId: tab.id },
                            func: () => {
                                try {
                                    window.localStorage.clear();
                                    window.sessionStorage.clear();
                                } catch (e) {}
                            }
                        }).catch(err => console.log('Script injection ignored', err));
                        injectPromises.push(p);
                    }
                });
                Promise.all(injectPromises).then(resolve);
            });
        });

        Promise.all([clearCookies, clearStorage]).then(() => {
            logoutBtn.innerText = "退出成功！正在跳转...";
            logoutBtn.style.background = "#28a745";
            
            chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
                if (tabs[0] && tabs[0].id) {
                    const signupUrl = "https://github.com/signup?ref_cta=Sign+up&ref_loc=header+logged+out&ref_page=%2F&source=header-home";
                    chrome.tabs.update(tabs[0].id, { url: signupUrl }); 
                }
            });

            setTimeout(() => { 
                logoutBtn.innerText = originalText; 
                logoutBtn.style.background = "#dc3545"; 
            }, 2000);
        });
    });
}

// 【10. 核弹级深度清理并跳转：Microsoft】
const logoutMsBtn = document.getElementById('logoutMsBtn');
if (logoutMsBtn) {
    logoutMsBtn.addEventListener('click', () => {
        const originalText = logoutMsBtn.innerText;
        logoutMsBtn.innerText = "正在粉碎底层凭证与缓存...";
        logoutMsBtn.style.background = "#6c757d"; 

        const msDomains = [
            "microsoft.com", "live.com", "microsoftonline.com", "office.com",
            "msauth.net", "msftauth.net", "xboxlive.com", "windows.com"
        ];
        
        const clearCookies = new Promise((resolve) => {
            chrome.cookies.getAllCookieStores(function(stores) {
                let storePromises = [];
                stores.forEach(store => {
                    let p = new Promise(resolveStore => {
                        chrome.cookies.getAll({ storeId: store.id }, function(cookies) {
                            let removePromises = [];
                            cookies.forEach(cookie => {
                                if (msDomains.some(d => cookie.domain.includes(d))) {
                                    const domainName = cookie.domain.startsWith(".") ? cookie.domain.substring(1) : cookie.domain;
                                    const urlHttp = "http://" + domainName + cookie.path;
                                    const urlHttps = "https://" + domainName + cookie.path;
                                    
                                    let removeHttp = { url: urlHttp, name: cookie.name, storeId: store.id };
                                    let removeHttps = { url: urlHttps, name: cookie.name, storeId: store.id };
                                    
                                    if (cookie.partitionKey) {
                                        removeHttp.partitionKey = cookie.partitionKey;
                                        removeHttps.partitionKey = cookie.partitionKey;
                                    }

                                    removePromises.push(new Promise(r => chrome.cookies.remove(removeHttp, r)));
                                    removePromises.push(new Promise(r => chrome.cookies.remove(removeHttps, r)));
                                }
                            });
                            Promise.all(removePromises).then(resolveStore);
                        });
                    });
                    storePromises.push(p);
                });
                Promise.all(storePromises).then(resolve);
            });
        });

        const clearStorage = new Promise((resolve) => {
            chrome.tabs.query({}, function(tabs) {
                let injectPromises = [];
                tabs.forEach(tab => {
                    if (tab.url && msDomains.some(d => tab.url.includes(d))) {
                        let p = chrome.scripting.executeScript({
                            target: { tabId: tab.id },
                            func: () => {
                                try {
                                    window.localStorage.clear();
                                    window.sessionStorage.clear();
                                    if (window.indexedDB && window.indexedDB.databases) {
                                        window.indexedDB.databases().then(dbs => {
                                            dbs.forEach(db => window.indexedDB.deleteDatabase(db.name));
                                        }).catch(()=>{});
                                    }
                                    if (navigator.serviceWorker) {
                                        navigator.serviceWorker.getRegistrations().then(registrations => {
                                            for(let reg of registrations) { reg.unregister(); }
                                        }).catch(()=>{});
                                    }
                                } catch (e) {
                                    console.error("Storage clear error:", e);
                                }
                            }
                        }).catch(err => console.log('Script injection ignored for this tab', err));
                        injectPromises.push(p);
                    }
                });
                Promise.all(injectPromises).then(resolve);
            });
        });

        Promise.all([clearCookies, clearStorage]).then(() => {
            logoutMsBtn.innerText = "清理成功！正在跳转...";
            logoutMsBtn.style.background = "#28a745"; 
            
            chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
                if (tabs[0] && tabs[0].id) {
                    const msSignupUrl = "https://outlook.live.com/mail/?prompt=create_account";
                    chrome.tabs.update(tabs[0].id, { url: msSignupUrl });
                }
            });

            setTimeout(() => { 
                logoutMsBtn.innerText = originalText; 
                logoutMsBtn.style.background = "#0078d4"; 
            }, 2500);
        });
    });
}