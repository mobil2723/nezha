// ==UserScript==
// @name         网页一键保存（增强版）
// @namespace    http://tampermonkey.net/
// @version      0.4
// @description  将网页保存为单个HTML文件，保留原始格式和样式，增强防重定向功能
// @author       mobil2723
// @match        *://*/*
// @grant        GM_addStyle
// ==/UserScript==

(function() {
    'use strict';

    // 添加按钮样式
    GM_addStyle(`
        .save-page-btn {
            position: fixed;
            top: 100px;
            right: 20px;
            z-index: 9999;
            background-color: #3498db;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            opacity: 0.8;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            display: flex;
            flex-direction: column;
            align-items: center;
            user-select: none;
            transform-origin: center;
        }
        .save-page-btn.collapsed {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            overflow: hidden;
            padding: 0;
            transform: scale(0.8);
        }
        .save-page-btn .drag-handle {
            width: 100%;
            height: 20px;
            cursor: move;
            display: flex;
            align-items: center;
            justify-content: center;
            background-color: rgba(0,0,0,0.1);
        }
        .save-page-btn .drag-handle::before {
            content: "⋮⋮";
            font-size: 12px;
            color: rgba(255,255,255,0.8);
        }
        .save-page-btn .btn-content {
            padding: 10px 20px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            transform-origin: center;
            opacity: 1;
        }
        .save-page-btn.collapsed .btn-content {
            transform: scale(0);
            opacity: 0;
        }
        .save-page-btn .collapse-toggle {
            position: absolute;
            top: 0;
            right: 0;
            width: 20px;
            height: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            font-size: 14px;
            color: rgba(255,255,255,0.8);
            transition: transform 0.3s;
        }
        .save-page-btn.collapsed .collapse-toggle {
            transform: rotate(180deg);
        }
        .save-page-btn:hover {
            opacity: 1;
        }
    `);

    // 创建保存按钮
    function createSaveButton() {
        const button = document.createElement('div');
        button.className = 'save-page-btn';
        button.innerHTML = `
            <div class="drag-handle"></div>
            <div class="collapse-toggle">−</div>
            <div class="btn-content">保存页面</div>
        `;

        // 添加拖动功能
        let isDragging = false;
        let dragStartX, dragStartY, initialX, initialY;
        const dragHandle = button.querySelector('.drag-handle');

        dragHandle.addEventListener('mousedown', (e) => {
            isDragging = true;
            dragStartX = e.clientX;
            dragStartY = e.clientY;
            initialX = button.offsetLeft;
            initialY = button.offsetTop;

            // 防止拖动时选中文本
            e.preventDefault();
        });

        document.addEventListener('mousemove', (e) => {
            if (!isDragging) return;

            const dx = e.clientX - dragStartX;
            const dy = e.clientY - dragStartY;

            const newX = initialX + dx;
            const newY = initialY + dy;

            // 确保按钮不会超出视口
            const maxX = window.innerWidth - button.offsetWidth;
            const maxY = window.innerHeight - button.offsetHeight;

            button.style.left = Math.min(Math.max(0, newX), maxX) + 'px';
            button.style.top = Math.min(Math.max(0, newY), maxY) + 'px';
            button.style.right = 'auto';
        });

        document.addEventListener('mouseup', () => {
            isDragging = false;
        });

        // 修改折叠/展开功能
        const collapseToggle = button.querySelector('.collapse-toggle');
        const btnContent = button.querySelector('.btn-content');
        let isCollapsed = false;

        // 获取按钮的初始尺寸
        let initialWidth, initialHeight;

        button.addEventListener('DOMContentLoaded', () => {
            initialWidth = button.offsetWidth;
            initialHeight = button.offsetHeight;
        });

        collapseToggle.addEventListener('click', (e) => {
            e.stopPropagation();
            isCollapsed = !isCollapsed;

            // 保存当前位置
            const rect = button.getBoundingClientRect();
            const centerX = rect.left + rect.width / 2;
            const centerY = rect.top + rect.height / 2;

            button.classList.toggle('collapsed');

            if (isCollapsed) {
                collapseToggle.textContent = '+';
                btnContent.style.display = 'none';

                // 调整位置以保持中心点不变
                const newRect = button.getBoundingClientRect();
                const dx = (rect.width - newRect.width) / 2;
                const dy = (rect.height - newRect.height) / 2;

                button.style.transform = `translate(${dx}px, ${dy}px) scale(0.8)`;
            } else {
                collapseToggle.textContent = '−';
                btnContent.style.display = 'block';
                button.style.transform = 'none';
            }
        });

        // 添加过渡结束事件监听器
        button.addEventListener('transitionend', (e) => {
            if (e.propertyName === 'transform' && !isCollapsed) {
                btnContent.style.display = 'block';
            }
        });

        // 添加保存功能
        btnContent.addEventListener('click', saveArticle);

        // 添加双击展开功能
        button.addEventListener('dblclick', () => {
            if (isCollapsed) {
                isCollapsed = false;
                button.classList.remove('collapsed');
                collapseToggle.textContent = '−';
                btnContent.style.display = 'block';
            }
        });

        document.body.appendChild(button);
    }

    // 保存文章函数
    async function saveArticle() {
        const loadingMsg = showLoading();
        const timeoutId = setTimeout(() => {
            loadingMsg.remove();
            showMessage('保存超时，请重试', true);
        }, 30000); // 30秒超时

        try {
            const title = document.title.replace(/[\/\\\:\*\?\"\<\>\|]/g, '-');
            showProgress('正在收集样式...');

            // 并行加载所有外部样式表
            const styleSheets = Array.from(document.styleSheets);
            const stylePromises = styleSheets.map(async sheet => {
                try {
                    if (sheet.href) {
                        const response = await fetch(sheet.href);
                        return response.ok ? await response.text() : '';
                    } else if (sheet.cssRules) {
                        return Array.from(sheet.cssRules)
                            .map(rule => rule.cssText)
                            .join('\n');
                    }
                    return '';
                } catch (e) {
                    console.warn('样式加载失败:', e);
                    return '';
                }
            });

            const styles = (await Promise.all(stylePromises)).join('\n');

            showProgress('正在处理页面内容...');

            const contentClone = document.documentElement.cloneNode(true);

            if (!contentClone.querySelector('body')) {
                const body = document.createElement('body');
                body.innerHTML = document.body.innerHTML;
                contentClone.appendChild(body);
            }

            // 扩展需要清理的元素选择器
            const elementsToRemove = contentClone.querySelectorAll(`
                script, iframe,
                .save-page-btn, #loading-msg,
                [class*="ad-"], [id*="ad-"],
                [class*="advertisement"],
                [class*="banner"]:not([class*="header"]):not([class*="title"]),
                meta[http-equiv="refresh"],
                /* 油猴脚本和其他通用脚本添加的元素 */
                [class*="tampermonkey"],
                [id*="tampermonkey"],
                [class*="userscript"],
                [id*="userscript"],
                [class*="greasemonkey"],
                [id*="greasemonkey"],
                /* 常见的浮动工具栏和按钮 */
                [class*="toolbar"],
                [class*="float"],
                [class*="fixed"],
                [id*="toolbar"],
                [id*="float"],
                [id*="fixed"],
                /* 社交分享按钮 */
                [class*="share"],
                [id*="share"],
                /* 返回顶部按钮 */
                [class*="backtop"],
                [id*="backtop"],
                [class*="to-top"],
                [id*="to-top"],
                /* 其他常见的插件元素 */
                [class*="plugin"],
                [id*="plugin"],
                [class*="extension"],
                [id*="extension"],
                /* 自定义添加的按钮和工具栏 */
                .save-page-btn,
                #loading-msg,
                [style*="position: fixed"],
                [style*="position:fixed"]
            `);

            // 更安全的元素移除方式
            elementsToRemove.forEach(el => {
                try {
                    // 检查元素是否是文章主要内容的一部分
                    const isMainContent = el.closest('article, .article-content, .post-content, .entry-content, .main-content');
                    // 检查元素是否是固定定位或浮动元素
                    const style = window.getComputedStyle(el);
                    const isFloating = style.position === 'fixed' || style.position === 'sticky' || style.float !== 'none';

                    // 只移除非主要内容的浮动元素
                    if (!isMainContent && isFloating) {
                        el.parentNode?.removeChild(el);
                    }
                    // 或者移除明确是插件/脚本添加的元素
                    else if (
                        el.className.toString().match(/tampermonkey|userscript|greasemonkey|toolbar|plugin|extension/i) ||
                        (el.id || '').toString().match(/tampermonkey|userscript|greasemonkey|toolbar|plugin|extension/i)
                    ) {
                        el.parentNode?.removeChild(el);
                    }
                } catch (e) {
                    console.warn('元素清理失败:', e);
                }
            });

            // 处理所有超链接
            const links = contentClone.getElementsByTagName('a');
            Array.from(links).forEach(link => {
                // 保存原始链接到 data 属性
                if (link.href) {
                    link.setAttribute('data-original-href', link.href);
                    // 如果是相对路径，转换为绝对路径
                    try {
                        link.href = new URL(link.href, window.location.href).href;
                    } catch (e) {
                        console.warn('链接处理失败:', link.href);
                    }
                }
                // 移除可能导致自动跳转的事件处理器
                link.removeAttribute('onclick');
                link.removeAttribute('onmouseover');
                link.removeAttribute('onmousedown');
                // 强制在新标签页打开
                link.setAttribute('target', '_blank');
                link.setAttribute('rel', 'noopener noreferrer');
            });

            showProgress('正在处理图片...');

            // 并行处理图片
            const images = Array.from(contentClone.getElementsByTagName('img'));
            let processedImages = 0;

            await Promise.all(images.map(async img => {
                try {
                    if (!img.src || img.src.startsWith('data:')) return;

                    const response = await fetch(img.src);
                    const blob = await response.blob();
                    const base64 = await new Promise(resolve => {
                        const reader = new FileReader();
                        reader.onloadend = () => resolve(reader.result);
                        reader.readAsDataURL(blob);
                    });
                    img.src = base64;
                } catch (e) {
                    console.warn('图片处理失败:', img.src);
                } finally {
                    processedImages++;
                    showProgress(`正在处理图片 (${processedImages}/${images.length})...`);
                }
            }));

            showProgress('正在生成文件...');

            const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title}</title>
    <style>
        /* 外部样式表 */
        ${styles}
        /* 修复样式问题 */
        :root {
            /* 保持原始背景色和背景图 */
            background-color: ${getComputedStyle(document.documentElement).backgroundColor || '#fff'} !important;
            background-image: ${getComputedStyle(document.documentElement).backgroundImage} !important;
        }
        html, body {
            /* 保持原始背景色和背景图 */
            background-color: ${getComputedStyle(document.body).backgroundColor || 'inherit'} !important;
            background-image: ${getComputedStyle(document.body).backgroundImage} !important;
            background-repeat: ${getComputedStyle(document.body).backgroundRepeat} !important;
            background-position: ${getComputedStyle(document.body).backgroundPosition} !important;
            background-size: ${getComputedStyle(document.body).backgroundSize} !important;
            background-attachment: ${getComputedStyle(document.body).backgroundAttachment} !important;
            min-height: 100vh;
            margin: 0;
            padding: 0;
            width: 100%;
            max-width: 100%;
            overflow-x: hidden;
        }
        img {
            max-width: 100%;
            height: auto;
            object-fit: contain;
        }
        * {
            box-sizing: border-box;
            max-width: 100%;
        }
        /* 保持原始布局 */
        .main-content,
        .article-content,
        main,
        article {
            width: 100% !important;
            max-width: 100% !important;
            margin: 0 auto !important;
            padding: 15px !important;
            /* 保持内容区域的背景 */
            background-color: inherit !important;
        }
        /* 图片容器样式 */
        figure,
        .image-container {
            max-width: 100% !important;
            margin: 10px 0 !important;
            text-align: center !important;
        }
        /* 表格样式修复 */
        table {
            width: auto !important;
            max-width: 100% !important;
            overflow-x: auto !important;
            display: block !important;
            background-color: inherit !important;
        }
        /* 代码块样式修复 */
        pre, code {
            white-space: pre-wrap !important;
            word-wrap: break-word !important;
            max-width: 100% !important;
            overflow-x: auto !important;
            background-color: inherit !important;
        }
        /* 链接样式 */
        a[data-original-href] {
            color: #0066cc;
            text-decoration: underline;
            word-break: break-word;
        }
        a[data-original-href]:hover {
            color: #003366;
        }
        a[data-original-href]::after {
            content: " ↗";
            font-size: 0.8em;
            color: #666;
        }
        /* 响应式布局 */
        @media screen and (min-width: 768px) {
            .main-content,
            .article-content,
            main,
            article {
                max-width: 1200px !important;
                margin: 0 auto !important;
                /* 保持内容区域背景色 */
                background-color: ${getComputedStyle(document.querySelector('.main-content, .article-content, main, article') || document.body).backgroundColor || 'inherit'} !important;
            }
        }
    </style>
</head>
<body>
    ${contentClone.querySelector('body')?.innerHTML || document.body.innerHTML}
    <script>
    // 增强的防跳转代码
    (function() {
        // 原始的setTimeout和setInterval函数备份
        const originalSetTimeout = window.setTimeout;
        const originalSetInterval = window.setInterval;
        const originalClearTimeout = window.clearTimeout;
        const originalClearInterval = window.clearInterval;

        // 保存定时器ID
        const timeoutIds = new Set();
        const intervalIds = new Set();

        // 拦截setTimeout
        window.setTimeout = function(callback, delay, ...args) {
            // 检查回调函数的代码（如果是函数）
            if (typeof callback === 'function') {
                const callbackString = callback.toString();
                // 检查是否包含重定向代码
                if (callbackString.includes('location') ||
                    callbackString.includes('csdn') ||
                    callbackString.includes('\\\\x') ||
                    callbackString.includes('//www')) {
                    console.warn('已阻止可疑的setTimeout调用', callbackString);
                    return -1;
                }
            } else if (typeof callback === 'string') {
                // 如果是字符串回调，检查是否包含重定向代码
                if (callback.includes('location') ||
                    callback.includes('csdn') ||
                    callback.includes('\\\\x') ||
                    callback.includes('//www')) {
                    console.warn('已阻止可疑的setTimeout字符串调用', callback);
                    return -1;
                }
            }

            // 如果没有可疑内容，则正常设置定时器
            const id = originalSetTimeout.call(window, callback, delay, ...args);
            timeoutIds.add(id);
            return id;
        };

        // 拦截setInterval
        window.setInterval = function(callback, delay, ...args) {
            // 检查回调函数的代码（如果是函数）
            if (typeof callback === 'function') {
                const callbackString = callback.toString();
                // 检查是否包含重定向代码
                if (callbackString.includes('location') ||
                    callbackString.includes('csdn') ||
                    callbackString.includes('\\\\x') ||
                    callbackString.includes('//www')) {
                    console.warn('已阻止可疑的setInterval调用', callbackString);
                    return -1;
                }
            } else if (typeof callback === 'string') {
                // 如果是字符串回调，检查是否包含重定向代码
                if (callback.includes('location') ||
                    callback.includes('csdn') ||
                    callback.includes('\\\\x') ||
                    callback.includes('//www')) {
                    console.warn('已阻止可疑的setInterval字符串调用', callback);
                    return -1;
                }
            }

            // 如果没有可疑内容，则正常设置定时器
            const id = originalSetInterval.call(window, callback, delay, ...args);
            intervalIds.add(id);
            return id;
        };

        // 保持clearTimeout和clearInterval的正常功能
        window.clearTimeout = function(id) {
            timeoutIds.delete(id);
            return originalClearTimeout.call(window, id);
        };

        window.clearInterval = function(id) {
            intervalIds.delete(id);
            return originalClearInterval.call(window, id);
        };

        // 禁用常见的跳转方法
        window.onbeforeunload = null;

        // 阻止 history 操作
        const noop = function() {};
        history.pushState = noop;
        history.replaceState = noop;

        // 阻止 window.open
        window.open = noop;

        // 阻止 location 修改
        Object.defineProperty(window, 'location', {
            get: function() {
                return window.__location || window.__proto__.location;
            },
            set: function() {
                console.warn('已阻止对window.location的修改尝试');
                // 忽略设置操作
                return window.__location || window.__proto__.location;
            }
        });

        // 特别针对十六进制编码的URL
        const hexURLPattern = /\\\\x[0-9a-fA-F]{2}/g;
        const script = document.querySelectorAll('script');
        for (let i = 0; i < script.length; i++) {
            if (script[i].textContent && hexURLPattern.test(script[i].textContent)) {
                console.warn('发现可疑的十六进制编码URL，已移除脚本');
                script[i].parentNode.removeChild(script[i]);
            }
        }

        // 定期扫描并阻止重定向
        originalSetInterval.call(window, function() {
            // 阻止通过 meta refresh 跳转
            const metas = document.getElementsByTagName('meta');
            for (let i = 0; i < metas.length; i++) {
                if (metas[i].getAttribute('http-equiv') === 'refresh') {
                    console.warn('已移除meta refresh重定向');
                    metas[i].parentNode.removeChild(metas[i]);
                }
            }

            // 扫描并移除包含可疑重定向代码的脚本
            const scripts = document.getElementsByTagName('script');
            for (let i = 0; i < scripts.length; i++) {
                if (scripts[i].textContent &&
                   (scripts[i].textContent.includes('location.href') ||
                    scripts[i].textContent.includes('csdn.net') ||
                    scripts[i].textContent.includes('\\\\x') ||
                    hexURLPattern.test(scripts[i].textContent))) {
                    console.warn('已移除可疑脚本');
                    scripts[i].parentNode.removeChild(scripts[i]);
                }
            }
        }, 100);

        console.log('已启用增强的防重定向保护');
    })();
    </script>
</body>
</html>`;

            // 创建 Blob 对象
            const blob = new Blob([html], {
                type: 'text/html;charset=utf-8'
            });

            // 下载文件
            const a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = `${title}.html`;
            a.style.display = 'none';
            document.body.appendChild(a);
            a.click();

            // 清理
            setTimeout(() => {
                URL.revokeObjectURL(a.href);
                document.body.removeChild(a);
            }, 1000);

            clearTimeout(timeoutId);
            loadingMsg.remove();
            showMessage('保存成功！');
        } catch (error) {
            clearTimeout(timeoutId);
            loadingMsg.remove();
            showMessage('保存失败：' + error.message, true);
            console.error('保存失败：', error);
        }
    }

    // 显示加载提示
    function showLoading() {
        const div = document.createElement('div');
        div.id = 'loading-msg';
        div.style.cssText = `
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(0,0,0,0.8);
            color: white;
            padding: 20px;
            border-radius: 5px;
            z-index: 10000;
            min-width: 200px;
            text-align: center;
        `;
        div.textContent = '正在保存页面，请稍候...';
        document.body.appendChild(div);
        return div;
    }

    // 显示进度
    function showProgress(text) {
        const loadingMsg = document.getElementById('loading-msg');
        if (loadingMsg) {
            loadingMsg.textContent = text;
        }
    }

    // 显示消息
    function showMessage(text, isError = false) {
        const div = document.createElement('div');
        div.style.cssText = `
            position: fixed;
            top: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: ${isError ? '#ff4444' : '#4CAF50'};
            color: white;
            padding: 10px 20px;
            border-radius: 5px;
            z-index: 10000;
        `;
        div.textContent = text;
        document.body.appendChild(div);
        setTimeout(() => div.remove(), 3000);
    }

    // 添加防抖函数
    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    // 优化页面加载完成后添加按钮的逻辑
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', createSaveButton);
    } else {
        createSaveButton();
    }
})();
