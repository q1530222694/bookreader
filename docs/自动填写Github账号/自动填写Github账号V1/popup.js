// 生成随机字符串的辅助函数（包含字母和数字）
function generateRandomString(length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

// 专门生成一个纯字母的辅助函数（用于首字母）
function generateRandomLetter() {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    return letters.charAt(Math.floor(Math.random() * letters.length));
}

// 生成强密码
function generatePassword() {
    return 'Git#' + generateRandomString(8).toUpperCase() + generateRandomString(4);
}

// 格式化时间
function getNowFormatDate() {
    const date = new Date();
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}:${String(date.getSeconds()).padStart(2, '0')}`;
}

// 渲染历史记录列表
function renderHistory() {
    const historyListContainer = document.getElementById('historyList');
    historyListContainer.innerHTML = '';

    chrome.storage.local.get(['accountHistory'], function(result) {
        const history = result.accountHistory || [];
        if (history.length === 0) {
            historyListContainer.innerHTML = '<div style="color:#999; text-align:center; padding: 20px 0; font-size:12px;">暂无生成记录</div>';
            return;
        }

        history.forEach((item, index) => {
            // 兼容旧数据：如果历史数据里没有 emailPrefix 字段，自动从 email 里截取前缀
            const prefix = item.emailPrefix || (item.email ? item.email.split('@')[0] : '');

            const itemDiv = document.createElement('div');
            itemDiv.className = 'history-item';
            itemDiv.innerHTML = `
                <div class="history-time">[${item.time}]</div>
                <div class="history-details">
                    <strong>前:</strong> ${prefix}<br>
                    <strong>邮:</strong> ${item.email}<br>
                    <strong>主:</strong> ${item.username}<br>
                    <strong>密:</strong> ${item.password}
                </div>
                <div class="history-ops">
                    <button class="mini-copy-btn" data-text="${prefix}">复制前缀</button>
                    <button class="mini-copy-btn" data-text="${item.email}">复制邮箱</button>
                    <button class="mini-copy-btn" data-text="${item.username}">复制用户</button>
                    <button class="mini-copy-btn" data-text="${item.password}">复制密码</button>
                </div>
            `;
            historyListContainer.appendChild(itemDiv);
        });

        // 为历史记录中的迷你复制按钮绑定事件
        historyListContainer.querySelectorAll('.mini-copy-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const textToCopy = e.target.getAttribute('data-text');
                navigator.clipboard.writeText(textToCopy).then(() => {
                    const originalText = e.target.innerText;
                    e.target.innerText = "已复制";
                    setTimeout(() => { e.target.innerText = originalText; }, 1000);
                });
            });
        });
    });
}

// 新增：恢复上一次显示的账号信息到输入框中
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

// 页面打开时，首先渲染一次历史记录，并恢复上一次的数据
document.addEventListener('DOMContentLoaded', () => {
    renderHistory();
    restoreCurrentAccount(); // 调用恢复数据函数
});

// 绑定生成按钮事件
document.getElementById('generateBtn').addEventListener('click', () => {
    const firstLetter = generateRandomLetter();
    const remainingStr = generateRandomString(7);
    const baseString = firstLetter + remainingStr;
    
    // 生成数据
    const emailPrefix = baseString; 
    const email = baseString + "@outlook.com"; 
    const username = "User-" + baseString;
    const password = generatePassword();
    const timeStr = getNowFormatDate();

    // 更新当前的主界面显示
    document.getElementById('emailPrefix').value = emailPrefix; 
    document.getElementById('email').value = email;
    document.getElementById('username').value = username;
    document.getElementById('password').value = password;

    // 1. 同步到当前页面填写字段（供 content.js 自动填充使用）
    chrome.storage.local.set({
        githubData: { email, username, password }
    });

    // 2. 新增：缓存当前框内的信息，防止关闭 popup 后丢失
    chrome.storage.local.set({
        lastGeneratedAccount: { emailPrefix, email, username, password }
    });

    // 3. 追加到历史记录中
    chrome.storage.local.get(['accountHistory'], function(result) {
        const history = result.accountHistory || [];
        // 将新记录插入到数组最前面
        history.unshift({ time: timeStr, emailPrefix, email, username, password });
        
        // 限制最多保存100条记录，防止占用过多存储空间
        if (history.length > 100) history.pop();

        chrome.storage.local.set({ accountHistory: history }, () => {
            // 重新渲染历史列表
            renderHistory();
        });
    });
});

// 主界面的复制按钮逻辑
document.querySelectorAll('.copy-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        const targetId = e.target.getAttribute('data-target');
        const inputElement = document.getElementById(targetId);
        if (!inputElement.value) return;

        navigator.clipboard.writeText(inputElement.value).then(() => {
            const originalText = e.target.innerText;
            e.target.innerText = "已复制!";
            setTimeout(() => { e.target.innerText = originalText; }, 1500);
        });
    });
});

// 清空历史记录按钮逻辑
document.getElementById('clearBtn').addEventListener('click', () => {
    if (confirm('确定要清空所有的生成记录吗？')) {
        // 清空历史的同时，也把当前框里的缓存和显示一起清空，回归初始状态
        chrome.storage.local.set({ accountHistory: [], lastGeneratedAccount: null }, () => {
            if (document.getElementById('emailPrefix')) document.getElementById('emailPrefix').value = '';
            if (document.getElementById('email')) document.getElementById('email').value = '';
            if (document.getElementById('username')) document.getElementById('username').value = '';
            if (document.getElementById('password')) document.getElementById('password').value = '';
            renderHistory();
        });
    }
});