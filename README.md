# WinTouch iOS (Native SwiftUI + UIKit)

Ứng dụng iOS Native cho phép biến iPhone thành **Trackpad chuột đa điểm & Bàn phím PC không dây** kết nối tới `WinTouch.exe` trên Windows qua Wi-Fi LAN.

## Điểm nổi bật
- **Khóa xoay ngang cấp hệ thống** (`Landscape` cố định ngay cả khi iPhone đang bật **Khóa hướng dọc** — xoay ngang cả Trackpad, Bàn phím PC và bàn phím Telex gốc của Apple).
- **Trackpad đa điểm 120Hz UIKit**: di chuột 1 ngón có gia tốc kiểu MacBook, chạm 1 ngón = Click trái, chạm đúp giữ = Kéo thả, chạm 2 ngón = Click phải, vuốt 2 ngón = Cuộn dọc/ngang, chụm 2 ngón = Zoom (`Ctrl + Wheel`), kèm rung Haptic nhẹ.
- **Bàn phím kép 2 chế độ**:
  - **Bàn phím iPhone gốc**: hỗ trợ gõ tiếng Việt Telex/VNI, giọng nói, emoji ở cả 2 chế độ **Gõ trực tiếp** và **Nhập đoạn rồi gửi/dán**, kèm dải phím chức năng PC (`Ctrl`, `Alt`, `Shift`, `Win` dính phím, `Esc`, `Tab`, `Del`, Mũi tên, `F1–F12`).
  - **Bàn phím PC ảo đầy đủ**: QWERTY + `F1–F12` + Mũi tên + `Numpad` bật/tắt nhanh.
- **Quét mã QR Camera gốc**: tự đọc `http://<IP>:<PORT>/?pin=<PIN>` từ `WinTouch.exe` và tự động kết nối lại.
- **Clipboard 2 chiều & Nguồn PC**: Đồng bộ Clipboard với PC và Khóa máy / Ngủ / Khởi động lại / Tắt nguồn (có hộp thoại xác nhận 2 bước).

## Cài đặt file `WinTouch.ipa` lên iPhone
File `WinTouch.ipa` được build dạng **Unsigned ARM64 (iOS 15+)** trên GitHub Actions:
- **TrollStore** (nếu máy hỗ trợ): cài trực tiếp vĩnh viễn không cần gia hạn.
- **AltStore / SideStore / Sideloadly**: chọn file `WinTouch.ipa`, ký bằng Apple ID cá nhân và cài vào iPhone.
