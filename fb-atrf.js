// ==UserScript==
// @name                 Facebook Anti-Refresh & Ad-Blocker
// @namespace            CustomScripts
// @description          Ngăn chặn tự động refresh Feed và ẩn bài viết quảng cáo trên Facebook
// @author               areen-c & Gemini
// @match                *://*.facebook.com/*
// @version              2.0
// @license              MIT
// @run-at               document-start
// @grant                none
// ==/UserScript==

(function() {
    'use strict';

    console.log('[FB Optimizer] Khởi động...');

    // --- PHẦN 1: CHẶN AUTO REFRESH (Lừa trình duyệt tab luôn hoạt động) ---
    try {
        // Luôn giữ trạng thái hiển thị để FB không load lại khi bạn quay lại tab
        Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
        Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
        document.hasFocus = () => true;

        // Chặn các sự kiện nhận biết người dùng rời tab
        const blockEvents = ['visibilitychange', 'webkitvisibilitychange', 'blur'];
        const originalAddEventListener = EventTarget.prototype.addEventListener;
        
        EventTarget.prototype.addEventListener = function(type, listener, options) {
            if (blockEvents.includes(type)) return;
            return originalAddEventListener.call(this, type, listener, options);
        };
    } catch (e) {
        console.warn('[FB Optimizer] Lỗi ghi đè API:', e);
    }

    // --- PHẦN 2: CHẶN QUẢNG CÁO & GỢI Ý (CSS Injection) ---
    const injectAdBlocker = () => {
        const style = document.createElement('style');
        style.innerHTML = `
            /* Ẩn bài viết Được tài trợ (Sponsored) */
            div[aria-label*="Sponsored"], 
            div[aria-label*="Được tài trợ"],
            /* Ẩn các hộp gợi ý trên Feed */
            div[data-pagelet*="FeedUnit_Suggested"],
            div[data-pagelet*="GenericFeedUnit"],
            /* Ẩn quảng cáo bên phải (PC) */
            div[role="complementary"] div[data-pagelet="RightRail"] > div > div:nth-child(1) {
                display: none !important;
            }
        `;
        document.head.appendChild(style);
        console.log('[FB Optimizer] Đã nhúng bộ lọc quảng cáo');
    };

    // --- PHẦN 3: XỬ LÝ FETCH (Ngăn các request làm mới ngầm) ---
    const originalFetch = window.fetch;
    window.fetch = function(...args) {
        const url = typeof args[0] === 'string' ? args[0] : args[0].url;
        
        // Chặn các endpoint liên quan đến việc cập nhật Feed tự động
        const forbidden = ['/ajax/home/generic.php', '/ajax/pagelet/generic.php/HomeStream'];
        if (forbidden.some(e => url?.includes(e))) {
            return Promise.resolve(new Response('{}', { status: 200 }));
        }
        return originalFetch.apply(this, args);
    };

    // Thực thi khi DOM sẵn sàng
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', injectAdBlocker);
    } else {
        injectAdBlocker();
    }

})();
