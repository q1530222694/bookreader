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

        // 渲染最新一条
        if (latestContainer) {
            const latestDiv = document.createElement('div');
            latestDiv.className = 'history-item';
            latestDiv.style.border = "1px solid #eee";
            latestDiv.style.background = "#f8f9fa";
            latestDiv.style.borderRadius = "4px";
            latestDiv.innerHTML = createItemHtml(history[0]);
            latestContainer.appendChild(latestDiv);
        }

        // 渲染全部弹窗
        if (historyListContainer) {
            history.forEach((item) => {
                const itemDiv = document.createElement('div');
                itemDiv.className = 'history-item';
                itemDiv.innerHTML = createItemHtml(item);
                historyListContainer.appendChild(itemDiv);
            });
        }

        // 绑定迷你复制按钮
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

if (viewAllBtn && historyModal) {
    viewAllBtn.addEventListener('click', () => historyModal.style.display = 'block');
}
if (closeModalBtn && historyModal) {
    closeModalBtn.addEventListener('click', () => historyModal.style.display = 'none');
}
window.addEventListener('click', (event) => {
    if (historyModal && event.target === historyModal) {
        historyModal.style.display = 'none';
    }
});

// 【5. 恢复当前界面账号】
function restoreCurrentAccount() {
    chrome.storage.local.get(['lastGeneratedAccount'], function(result) {
        if (result.lastGeneratedAccount) {
            const data = result.lastGeneratedAccount;
            if (document.getElementById('emailPrefix')) document.getElementById('emailPrefix').value = data.emailPrefix || '';
            if (document.getElementById('email')) document.getElementById('email').value = data.email || '';
            if (document.getElementById('username')) document.getElementById('username').value = data.username || '';
            if (document.getElementById('password')) document.getElementById('password').value = data.password || '';
        }
    });
}

// 页面加载完毕后初始化
document.addEventListener('DOMContentLoaded', () => {
    renderHistory();
    restoreCurrentAccount();
});

// 【6. 主生成按钮逻辑】
const generateBtn = document.getElementById('generateBtn');
if (generateBtn) {
    generateBtn.addEventListener('click', () => {
        const firstLetter = generateRandomLetter();
        const remainingStr = generateRandomString(7);
        const baseString = firstLetter + remainingStr;
        
        const emailPrefix = baseString; 
        const email = baseString + "@outlook.com"; 
        const username = "User-" + baseString;
        const password = generatePassword();
        const timeStr = getNowFormatDate();

        // 渲染到界面
        if (document.getElementById('emailPrefix')) document.getElementById('emailPrefix').value = emailPrefix; 
        if (document.getElementById('email')) document.getElementById('email').value = email;
        if (document.getElementById('username')) document.getElementById('username').value = username;
        if (document.getElementById('password')) document.getElementById('password').value = password;

        // 保存到 Storage
        chrome.storage.local.set({
            githubData: { email, username, password },
            lastGeneratedAccount: { emailPrefix, email, username, password }
        });

        // 记录历史
        chrome.storage.local.get(['accountHistory'], function(result) {
            const history = result.accountHistory || [];
            history.unshift({ time: timeStr, emailPrefix, email, username, password });
            if (history.length > 100) history.pop();
            chrome.storage.local.set({ accountHistory: history }, renderHistory);
        });
    });
}

// 【7. 主界面复制按钮逻辑】
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
                renderHistory();
                if (historyModal) historyModal.style.display = 'none'; 
            });
        }
    });
}

// 【9. 一键退出 GitHub】
const logoutBtn = document.getElementById('logoutBtn');
if (logoutBtn) {
    logoutBtn.addEventListener('click', () => {
        const originalText = logoutBtn.innerText;
        logoutBtn.innerText = "正在清理登录状态...";
        logoutBtn.style.background = "#6c757d";

        chrome.cookies.getAll({ domain: "github.com" }, function(cookies) {
            let promises = cookies.map(cookie => {
                const protocol = cookie.secure ? "https://" : "http://";
                const domainName = cookie.domain.startsWith(".") ? cookie.domain.substring(1) : cookie.domain;
                const url = protocol + domainName + cookie.path;
                return new Promise((resolve) => chrome.cookies.remove({ url: url, name: cookie.name }, resolve));
            });

            Promise.all(promises).then(() => {
                logoutBtn.innerText = "退出成功！";
                logoutBtn.style.background = "#28a745";
                setTimeout(() => { 
                    logoutBtn.innerText = originalText; 
                    logoutBtn.style.background = "#dc3545"; 
                }, 2000);
            });
        });
    });
}

// 【10. 一键退出 Microsoft】
const logoutMsBtn = document.getElementById('logoutMsBtn');
if (logoutMsBtn) {
    logoutMsBtn.addEventListener('click', () => {
        const originalText = logoutMsBtn.innerText;
        logoutMsBtn.innerText = "正在清理微软全家桶...";
        logoutMsBtn.style.background = "#6c757d"; 

        const msDomains = ["microsoft.com", "live.com", "microsoftonline.com", "office.com"];
        let allPromises = [];

        msDomains.forEach(domain => {
            const p = new Promise((resolveDomain) => {
                chrome.cookies.getAll({ domain: domain }, function(cookies) {
                    let removePromises = cookies.map(cookie => {
                        const protocol = cookie.secure ? "https://" : "http://";
                        const domainName = cookie.domain.startsWith(".") ? cookie.domain.substring(1) : cookie.domain;
                        const url = protocol + domainName + cookie.path;
                        return new Promise((resolveRemove) => chrome.cookies.remove({ url: url, name: cookie.name }, resolveRemove));
                    });
                    Promise.all(removePromises).then(resolveDomain);
                });
            });
            allPromises.push(p);
        });

        Promise.all(allPromises).then(() => {
            logoutMsBtn.innerText = "退出成功！";
            logoutMsBtn.style.background = "#28a745"; 
            setTimeout(() => { 
                logoutMsBtn.innerText = originalText; 
                logoutMsBtn.style.background = "#0078d4"; 
            }, 2000);
        });
    });
}