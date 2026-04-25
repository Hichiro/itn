// ==UserScript==
// @name                 FB Anti-Refresh & Ad-Blocker (iOS Optimized)
// @namespace            CustomScripts
// @match                *://*.facebook.com/*
// @version              3.0
// @run-at               document-start
// @grant                none
// ==/UserScript==

(function() {
    'use strict';

    // 1. CHẶN REFRESH - Tối ưu cho iOS Safari
    const preventRefresh = () => {
        try {
            // Giả lập trạng thái luôn hiển thị để FB không tự nạp lại Feed khi quay lại tab
            Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
            Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });

            // Chặn các sự kiện mất tập trung mà FB dùng để trigger reload
            const heavyEvents = ['visibilitychange', 'webkitvisibilitychange', 'blur', 'pageshow'];
            const originalAEL = EventTarget.prototype.addEventListener;
            
            EventTarget.prototype.addEventListener = function(type, listener, options) {
                if (heavyEvents.includes(type)) return;
                return originalAEL.call(this, type, listener, options);
            };

            // Chặn đứng các nỗ lực gọi refresh từ server thông qua fetch
            const originalFetch = window.fetch;
            window.fetch = function(...args) {
                const url = typeof args[0] === 'string' ? args[0] : args[0].url;
                if (url?.includes('pull') || url?.includes('ajax/home/generic')) {
                    return Promise.resolve(new Response('{}', { status: 200 }));
                }
                return originalFetch.apply(this, args);
            };
        } catch (e) { console.debug('FB-AntiRefresh: Blocked by Safari sandbox'); }
    };

    // 2. CHẶN QUẢNG CÁO - Dùng CSS cho nhẹ máy
    const injectAdBlocker = () => {
        const style = document.createElement('style');
        style.textContent = `
            /* Chặn bài viết Được tài trợ & Gợi ý */
            div[aria-label*="Sponsored"], 
            div[aria-label*="Được tài trợ"],
            div[data-pagelet*="FeedUnit_Suggested"],
            div[data-pagelet*="AdBox"],
            div[aria-label="Ads"],
            /* Ẩn khu vực Video Reels nếu muốn Feed sạch hơn */
            div[data-pagelet*="Reels"],
            /* Chặn quảng cáo trong video */
            .video_ad_overlay, .ad_unit { display: none !important; }
        `;
        document.documentElement.appendChild(style);
    };

    // 3. XỬ LÝ NỘI DUNG ĐỘNG (Dành riêng cho Feed cuộn vô tận)
    const observeFeed = () => {
        const observer = new MutationObserver((mutations) => {
            // Safari iOS xử lý DOM nhanh hơn nếu ta gom nhóm thay đổi
            for (let mutation of mutations) {
                if (mutation.addedNodes.length) {
                    // Xóa các thẻ meta refresh nếu FB cố chèn vào sau
                    const meta = document.querySelector('meta[http-equiv="refresh"]');
                    if (meta) meta.remove();
                }
            }
        });

        observer.observe(document.documentElement, { childList: true, subtree: true });
    };

    // Khởi chạy
    preventRefresh();
    injectAdBlocker();
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', observeFeed);
    } else {
        observeFeed();
    }
})();
