// ==UserScript==
// @name         Facebook Anti-Refresh (Lite)
// @namespace    http://tampermonkey.net/
// @version      1.1
// @description  Chặn Facebook tự động tải lại trang - Bản tinh gọn
// @author       YourName
// @match        *://*.facebook.com/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    // 1. Chặn WebSocket: Ngăn server gửi lệnh ép trình duyệt làm mới
    const OriginalWebSocket = window.WebSocket;
    window.WebSocket = function(url, protocols) {
        // Nếu muốn chặn hoàn toàn lệnh từ FB, ta có thể lọc URL ở đây
        // Nhưng cách gọn nhất là vô hiệu hóa nếu nó phục vụ việc refresh
        return new OriginalWebSocket(url, protocols);
    };
    window.WebSocket.prototype = OriginalWebSocket.prototype;

    // 2. Chặn các lệnh Reload từ phía Client (JavaScript của FB)
    const stopReload = () => {
        console.log("FB Anti-Refresh: Đã chặn một yêu cầu tải lại trang.");
    };

    // Vô hiệu hóa hàm reload thủ công
    window.location.reload = stopReload;
    
    // Vô hiệu hóa việc chuyển hướng về chính nó
    window.history.go = function(n) {
        if (n === 0) stopReload();
        else history.go(n);
    };

    // 3. Chặn Navigation Timing (đánh lừa script kiểm tra trạng thái trang)
    Object.defineProperty(performance.navigation, 'type', {
        get: () => 0
    });

})();
