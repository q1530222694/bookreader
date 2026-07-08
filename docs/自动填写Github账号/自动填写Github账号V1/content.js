// 模拟真实的输入事件 (为了触发 React/Vue 的状态更新)
function triggerReactInput(element, value) {
    if (element && element.value !== value) {
        element.value = value;
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
    }
}

// 深度模拟人类点击，绕过部分前端框架对自动化点击的检测
function simulateHumanClick(element) {
    if (!element) return;
    ['mouseover', 'mousedown', 'mouseup', 'click'].forEach(eventType => {
        const event = new MouseEvent(eventType, {
            view: window,
            bubbles: true,
            cancelable: true,
            buttons: 1
        });
        element.dispatchEvent(event);
    });
}

// 维护两个全局状态
let isEnabled = true;
let accountData = null;
let autofillInterval = null;

// 从 Storage 读取初始状态
chrome.storage.local.get(['githubData', 'isAutofillEnabled'], function(result) {
    if (result.githubData) accountData = result.githubData;
    if (result.isAutofillEnabled !== undefined) isEnabled = result.isAutofillEnabled;
    startAutofillTask();
});

// 监听状态实时变化
chrome.storage.onChanged.addListener((changes, namespace) => {
    if (changes.githubData) accountData = changes.githubData.newValue;
    if (changes.isAutofillEnabled) isEnabled = changes.isAutofillEnabled.newValue;
});

// 启动轮询检查任务
function startAutofillTask() {
    if (autofillInterval) clearInterval(autofillInterval);
    
    autofillInterval = setInterval(() => {
        if (!isEnabled || !accountData) return;

        const currentUrl = window.location.href;

        // ==================== 1. GitHub 登录页面 ====================
        if (currentUrl.includes('github.com/login')) {
            const loginField = document.querySelector('#login_field');
            if (loginField && !loginField.value) triggerReactInput(loginField, accountData.email);

            const passwordField = document.querySelector('#password');
            if (passwordField && !passwordField.value) triggerReactInput(passwordField, accountData.password);

            const loginForm = document.querySelector('form');
            if (loginForm) {
                let returnToInput = loginForm.querySelector('input[name="return_to"]');
                if (!returnToInput) {
                    returnToInput = document.createElement('input');
                    returnToInput.type = 'hidden';
                    returnToInput.name = 'return_to';
                    loginForm.appendChild(returnToInput);
                }
                if (returnToInput.value !== '/settings/security') {
                    returnToInput.value = '/settings/security';
                }
            }
        } 
        
        // ==================== 2. GitHub 注册页面 ====================
        else if (currentUrl.includes('github.com/signup')) {
            const emailInput = document.querySelector('#email');
            if (emailInput && !emailInput.value) triggerReactInput(emailInput, accountData.email);

            const passwordInput = document.querySelector('#password');
            if (passwordInput && !passwordInput.value) triggerReactInput(passwordInput, accountData.password);

            const loginInput = document.querySelector('#login');
            if (loginInput && !loginInput.value) triggerReactInput(loginInput, accountData.username);

            const optInCheckbox = document.querySelector('input[name="opt_in"]') || 
                                  document.querySelector('#opt_in') || 
                                  document.querySelector('input[type="checkbox"]');
            if (optInCheckbox) {
                if (!optInCheckbox.checked) simulateHumanClick(optInCheckbox);
            } else {
                const labels = document.querySelectorAll('label');
                for (let label of labels) {
                    if (label.innerText.includes('Receive occasional product updates') || 
                        label.innerText.includes('Email preferences')) {
                        simulateHumanClick(label);
                        break;
                    }
                }
            }
        }

        // ==================== 3. GitHub 安全设置及 2FA 流程页面 ====================
        else if (currentUrl.includes('github.com')) {
            
            // 动作 A：发现开启 2FA 的主按钮 -> 自动点击
            const enable2FaBtn = Array.from(document.querySelectorAll('a, button, summary')).find(
                el => el.textContent.trim() === 'Enable two-factor authentication'
            );
            if (enable2FaBtn && !enable2FaBtn.dataset.autoClicked) {
                enable2FaBtn.dataset.autoClicked = "true";
                simulateHumanClick(enable2FaBtn);
            }

            // 动作 B：恢复代码页面 -> 强制解锁并点击确认
            const downloadBtn = Array.from(document.querySelectorAll('button')).find(el => el.textContent.trim() === 'Download');
            const savedBtn = Array.from(document.querySelectorAll('button')).find(el => el.textContent.includes('I have saved'));

            if (downloadBtn && savedBtn) {
                // 第一步：点击下载
                if (!downloadBtn.dataset.autoClicked) {
                    downloadBtn.dataset.autoClicked = "true";
                    simulateHumanClick(downloadBtn);
                } 
                // 第二步：判断确认按钮是否解锁
                else if (!savedBtn.dataset.autoClicked) {
                    const isDisabled = savedBtn.disabled || savedBtn.getAttribute('aria-disabled') === 'true' || savedBtn.classList.contains('disabled');
                    
                    if (!isDisabled) {
                        // 已经变绿，延迟500ms后点击，保证状态稳定
                        savedBtn.dataset.autoClicked = "true";
                        setTimeout(() => simulateHumanClick(savedBtn), 500);
                    } else {
                        // 如果按钮还是灰的，说明 Chrome 把下载拦截了。
                        // 智能对策：立刻去点击网页上的“复制(Copy)”按钮来满足 GitHub 的验证！
                        const copyBtn = document.querySelector('clipboard-copy') || Array.from(document.querySelectorAll('button')).find(el => el.textContent.includes('Copy'));
                        
                        if (copyBtn && !copyBtn.dataset.autoClicked) {
                            copyBtn.dataset.autoClicked = "true";
                            simulateHumanClick(copyBtn);
                        } else {
                            // 暴力拆解兜底：强行拔除 disabled 属性并硬点
                            savedBtn.removeAttribute('disabled');
                            savedBtn.setAttribute('aria-disabled', 'false');
                            savedBtn.classList.remove('disabled');
                            savedBtn.dataset.autoClicked = "true";
                            setTimeout(() => simulateHumanClick(savedBtn), 500);
                        }
                    }
                }
            }
        }
        
        // ==================== 4. 资产库 kfz.wanwangwang.xyz ====================
        else if (currentUrl.includes('kfz.wanwangwang.xyz')) {
            const fillByLabelText = (labelText, valueToFill) => {
                const labels = document.querySelectorAll('label');
                for (let label of labels) {
                    if (label.innerText.includes(labelText)) {
                        let container = label.parentElement;
                        for (let i = 0; i < 3; i++) { 
                            if (!container) break;
                            const input = container.querySelector('input[type="text"], input[type="password"]');
                            if (input && !input.value) {
                                triggerReactInput(input, valueToFill);
                                return; 
                            }
                            container = container.parentElement;
                        }
                    }
                }
            };

            fillByLabelText('登录账号', accountData.username); 
            fillByLabelText('关联邮箱', accountData.email);    
            fillByLabelText('登录密码', accountData.password); 
        }

    }, 1000);
}