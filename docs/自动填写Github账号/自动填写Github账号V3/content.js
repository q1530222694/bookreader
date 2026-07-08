(function() {
    // 突破 React/Vue/Knockout 的原生输入模拟
    function triggerReactInput(element, value) {
        if (!element) return;
        
        let setter = null;
        if (element.tagName.toLowerCase() === 'input') {
            setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value")?.set;
        } else if (element.tagName.toLowerCase() === 'select') {
            setter = Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, "value")?.set;
        }

        if (setter) {
            setter.call(element, value);
        } else {
            element.value = value;
        }

        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
        if (element.tagName.toLowerCase() === 'input') {
            element.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, key: 'a' }));
        }
        element.dispatchEvent(new Event('blur', { bubbles: true }));
    }

    // 深度模拟人类点击
    function simulateHumanClick(element) {
        if (!element) return;
        ['mouseover', 'mousedown', 'mouseup', 'click'].forEach(eventType => {
            const event = new MouseEvent(eventType, {
                view: window, bubbles: true, cancelable: true, buttons: 1
            });
            element.dispatchEvent(event);
        });
    }

    // 判断元素是否在屏幕上真正可见
    function isVisible(el) {
        return el && el.offsetWidth > 0 && el.offsetHeight > 0;
    }

    // 获取表单元素（专供微软）
    function getFormElement(selector) {
        return Array.from(document.querySelectorAll(selector)).find(el => 
            el && el.type !== 'hidden' && !el.disabled
        );
    }

    // 随机生成合理的英文姓名
    function getRandomMSName() {
        const firstNames = ["Alex", "Chris", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Jamie", "Avery", "Parker", "Sam", "Drew", "Robin"];
        const lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Wilson", "Anderson"];
        return {
            first: firstNames[Math.floor(Math.random() * firstNames.length)],
            last: lastNames[Math.floor(Math.random() * lastNames.length)]
        };
    }

    // 维护全局状态
    let isEnabled = true;
    let accountData = null;
    let autofillInterval = null;

    chrome.storage.local.get(['githubData', 'isAutofillEnabled'], function(result) {
        if (result.githubData) accountData = result.githubData;
        if (result.isAutofillEnabled !== undefined) isEnabled = result.isAutofillEnabled;
        startAutofillTask();
    });

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
                    if (returnToInput.value !== '/settings/security') returnToInput.value = '/settings/security';
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

                const optInCheckbox = document.querySelector('input[name="opt_in"]') || document.querySelector('#opt_in') || document.querySelector('input[type="checkbox"]');
                if (optInCheckbox) {
                    if (!optInCheckbox.checked) simulateHumanClick(optInCheckbox);
                } else {
                    const labels = document.querySelectorAll('label');
                    for (let label of labels) {
                        if (label.innerText.includes('Receive occasional product updates') || label.innerText.includes('Email preferences')) {
                            simulateHumanClick(label); break;
                        }
                    }
                }
            }

            // ==================== 3. GitHub 安全设置及 2FA 流程页面 ====================
            else if (currentUrl.includes('github.com')) {
                // 动作 1：自动点击开启双重验证
                const enable2FaBtn = Array.from(document.querySelectorAll('a, button, summary')).find(el => el.textContent.trim() === 'Enable two-factor authentication' && isVisible(el));
                if (enable2FaBtn && !enable2FaBtn.dataset.autoClicked) {
                    enable2FaBtn.dataset.autoClicked = "true";
                    simulateHumanClick(enable2FaBtn);
                }

                // 动作 2：自动下载并确认
                const pageText = document.body.innerText;
                if (pageText.includes('Download your recovery codes') || pageText.includes('Keep your recovery codes')) {
                    
                    const downloadBtn = Array.from(document.querySelectorAll('button, a')).find(el => el.textContent.includes('Download') && isVisible(el));
                    const savedBtn = Array.from(document.querySelectorAll('button')).find(el => el.textContent.includes('I have saved') && isVisible(el));

                    if (downloadBtn && savedBtn) {
                        if (!downloadBtn.dataset.autoClicked) {
                            downloadBtn.dataset.autoClicked = "true";
                            simulateHumanClick(downloadBtn);
                        } 
                        else if (!savedBtn.dataset.autoClicked) {
                            const isDisabled = savedBtn.disabled || savedBtn.getAttribute('aria-disabled') === 'true' || savedBtn.classList.contains('disabled');
                            if (!isDisabled) {
                                savedBtn.dataset.autoClicked = "true";
                                setTimeout(() => simulateHumanClick(savedBtn), 500);
                            } else {
                                const copyBtn = document.querySelector('clipboard-copy') || Array.from(document.querySelectorAll('button')).find(el => el.textContent.includes('Copy') && isVisible(el));
                                if (copyBtn && !copyBtn.dataset.autoClicked) {
                                    copyBtn.dataset.autoClicked = "true";
                                    simulateHumanClick(copyBtn);
                                } else {
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

                // ⭐ 增强动作 3：暴力接管 Done 按钮
                const doneBtn = Array.from(document.querySelectorAll('button, a, input')).find(el => {
                    // 使用 innerText 获取最干净的纯文本，防止被内部的 <span> 等标签干扰
                    const text = (el.innerText || el.value || el.textContent || '').trim().toLowerCase();
                    return (text === 'done' || text === '完成') && isVisible(el);
                });
                
                if (doneBtn && !doneBtn.dataset.autoClicked) {
                    doneBtn.dataset.autoClicked = "true";
                    // 第一重攻击：模拟人类环境
                    simulateHumanClick(doneBtn);
                    
                    // 第二重攻击：0.15秒后执行浏览器最底层原生点击兜底
                    setTimeout(() => {
                        if (typeof doneBtn.click === 'function') {
                            doneBtn.click();
                        }
                    }, 150);
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
                                if (input && !input.value) { triggerReactInput(input, valueToFill); return; }
                                container = container.parentElement;
                            }
                        }
                    }
                };
                fillByLabelText('登录账号', accountData.username); 
                fillByLabelText('关联邮箱', accountData.email);    
                fillByLabelText('登录密码', accountData.password); 
            }

            // ==================== 5. 微软 (Microsoft) 注册/登录页面 ====================
            else if (currentUrl.includes('live.com') || currentUrl.includes('microsoft.com')) {
                const msEmailInput = getFormElement('input[name="MemberName"], input[name="loginfmt"], #MemberName, #i0116, input[type="email"]');
                if (msEmailInput) {
                    const isSignup = document.querySelector('#LiveDomainBox') || currentUrl.includes('signup');
                    const targetValue = isSignup ? accountData.email.split('@')[0] : accountData.email;
                    if (msEmailInput.value !== targetValue) triggerReactInput(msEmailInput, targetValue);
                }

                const msPasswordInput = getFormElement('input[name="Password"], input[name="passwd"], #PasswordInput, #i0118, input[type="password"]');
                if (msPasswordInput) {
                    if (msPasswordInput.value !== accountData.password) triggerReactInput(msPasswordInput, accountData.password);
                }

                let fNameInput = getFormElement('#firstNameInput, #FirstName, input[name="firstName" i], input[aria-label*="first" i], input[aria-label*="名" i]');
                let lNameInput = getFormElement('#lastNameInput, #LastName, input[name="lastName" i], input[aria-label*="last" i], input[aria-label*="姓" i]');
                
                if (!fNameInput || !lNameInput) {
                    const pageText = document.body.innerText.toLowerCase();
                    if (pageText.includes('name') || pageText.includes('姓名') || pageText.includes('add your name')) {
                        const textInputs = Array.from(document.querySelectorAll('input[type="text"], input:not([type])')).filter(el => el.type !== 'hidden' && !el.disabled);
                        if (textInputs.length >= 2) {
                            if (!fNameInput) fNameInput = textInputs[0];
                            if (!lNameInput) lNameInput = textInputs[1];
                        }
                    }
                }

                if (fNameInput && lNameInput && !fNameInput.dataset.autoFilled) {
                    if (!window.tempMsName) window.tempMsName = getRandomMSName();
                    triggerReactInput(fNameInput, window.tempMsName.first);
                    triggerReactInput(lNameInput, window.tempMsName.last);
                    fNameInput.dataset.autoFilled = "true";
                }

                let birthMonth = getFormElement('select[id*="month" i], select[name*="month" i], input[id*="month" i], select[aria-label*="month" i], select[aria-label*="月"]');
                let birthDay = getFormElement('select[id*="day" i], select[name*="day" i], input[id*="day" i], select[aria-label*="day" i], select[aria-label*="日"]');
                let birthYear = getFormElement('input[id*="year" i], input[name*="year" i], select[id*="year" i], select[name*="year" i], input[aria-label*="year" i], input[aria-label*="年"]');
                
                if (!birthMonth || !birthDay || !birthYear) {
                    const pageText = document.body.innerText.toLowerCase();
                    if (pageText.includes('birthdate') || pageText.includes('出生日期') || pageText.includes('details') || pageText.includes('详细信息')) {
                        const allFields = Array.from(document.querySelectorAll('select, input')).filter(el => {
                            const t = el.type ? el.type.toLowerCase() : '';
                            return t !== 'hidden' && t !== 'submit' && t !== 'button' && t !== 'checkbox' && !el.disabled;
                        });
                        
                        let largeSelects = [];
                        allFields.forEach(el => {
                            if (el.tagName.toLowerCase() === 'select') {
                                let len = el.options.length;
                                if (len >= 12 && len <= 15) birthMonth = el;
                                else if (len >= 28 && len <= 33) birthDay = el;
                                else if (len > 33) largeSelects.push(el);
                            } else if (el.tagName.toLowerCase() === 'input') {
                                if (!birthYear) birthYear = el;
                                else if (!birthDay) birthDay = el;
                            }
                        });

                        if (!birthYear && largeSelects.length > 0) {
                            birthYear = largeSelects[largeSelects.length - 1]; 
                        }
                    }
                }

                if (birthMonth && birthDay && birthYear && !birthMonth.dataset.autoFilled) {
                    const rYearStr = (Math.floor(Math.random() * (2002 - 1990 + 1)) + 1990).toString();
                    
                    const fillElement = (el, val) => {
                        if (el.tagName.toLowerCase() === 'select') {
                            let validOpts = Array.from(el.options).filter(o => o.value && o.value.trim() !== '' && !o.disabled && !o.innerText.toLowerCase().includes('month') && !o.innerText.toLowerCase().includes('day') && !o.innerText.includes('月') && !o.innerText.includes('日'));
                            
                            if (validOpts.length > 0) {
                                let randomOpt = validOpts[Math.floor(Math.random() * validOpts.length)];
                                triggerReactInput(el, randomOpt.value);
                            } else if (el.options.length > 1) {
                                let idx = Math.floor(Math.random() * (el.options.length - 1)) + 1;
                                triggerReactInput(el, el.options[idx].value || el.options[idx].innerText);
                            }
                        } else {
                            triggerReactInput(el, val);
                        }
                    };

                    fillElement(birthMonth, "8"); 
                    fillElement(birthDay, "10");
                    fillElement(birthYear, rYearStr);

                    birthMonth.dataset.autoFilled = "true";
                }
            }

        }, 1000);
    }
})();