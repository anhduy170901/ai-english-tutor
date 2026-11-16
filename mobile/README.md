# 📱 AI English Tutor — Mobile Client (Flutter)

Ứng dụng di động AI English Tutor được xây dựng bằng **Flutter**, mang lại trải nghiệm luyện nói tiếng Anh tương tác hai chiều thời gian thực (Full-Duplex Real-time Voice Call) với gia sư ảo AI.

---

## 🌟 Tính năng chính

- **Luyện nói hai chiều thời gian thực (Real-time Voice-to-Voice)**:
  - Thu âm bằng Push-To-Talk hoặc chế độ thoại rảnh tay.
  - Phụ đề hiển thị theo thời gian thực (Token-by-token Subtitles streaming).
  - Nghe phản hồi giọng nói mượt mà không độ trễ thông qua hardware PCM streaming.
- **Hỗ trợ ngắt lời tức thì (Barge-in)**:
  - Người dùng có thể nhấn nói đè hoặc bắt đầu câu nói mới bất cứ lúc nào, âm thanh cũ của AI sẽ dừng phát ngay lập tức.
- **Hiển thị trực quan trực tiếp (Audio Wave Visualizer)**:
  - Sóng âm thanh động hiển thị theo cường độ giọng nói của người dùng và trạng thái của AI (Đang lắng nghe, Đang suy nghĩ, Đang nói).
- **Chọn chủ đề & Cấp độ CEFR**:
  - Tùy chọn đa dạng chủ đề hội thoại (Daily Conversation, Job Interview, Travel, IELTS Speaking,...).
  - Chọn trình độ từ A1 đến C2.
- **Tổng kết & Đánh giá buổi học (Session Summary)**:
  - Xem lại lịch sử các câu hội thoại, các lỗi ngữ pháp đã được gia sư sửa và nhận xét tổng quan sau khi kết thúc.

---

## 🏗️ Kiến trúc & Công nghệ

Ứng dụng áp dụng **Clean Architecture** kết hợp **BLoC pattern**:

```text
mobile/lib/
├── app/                  # Khởi tạo App, theme và global providers
├── core/
│   ├── audio/            # AudioRecorderService (16kHz WAV), AudioPlayerService (PCM Streaming)
│   ├── constants/        # Định nghĩa màu sắc, URL API & SignalR Hub
│   ├── di/               # GetIt Service Locator
│   ├── network/          # SignalR Hub client service
│   ├── theme/            # Giao diện Dark theme hiện đại
│   └── utils/            # App logger
└── features/
    ├── session/          # Feature quản lý phiên học, chọn chủ đề & cấp độ, tổng kết
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    └── voice_tutor/      # Feature cuộc gọi thoại trực tiếp với AI Tutor
        ├── data/
        ├── domain/
        └── presentation/
```

### Các thư viện chính

- **`flutter_bloc`**: Quản lý trạng thái phân tách rõ ràng giữa Event, State và BLoC logic.
- **`flutter_pcm_sound`**: Nạp trực tiếp stream PCM thô (24kHz, 16-bit, Mono) vào tầng âm thanh phần cứng.
- **`record`**: Ghi âm chuẩn định dạng 16kHz Mono 16-bit WAV tối ưu cho Whisper STT.
- **`signalr_netcore`**: Kết nối WebSocket 2 chiều với backend .NET 10.
- **`dio` & `pretty_dio_logger`**: Quản lý các REST API request.
- **`flutter_animate` & `google_fonts`**: Hiệu ứng chuyển động mượt mà và font chữ hiện đại.

---

## 🚀 Hướng dẫn chạy ứng dụng

### 1. Cài đặt dependencies

```bash
cd mobile
flutter pub get
```

### 2. Cấu hình Backend Host

Mặc định cấu hình trong `lib/core/constants/api_constants.dart`:
- **macOS / Web / Simulator iOS**: Tự động trỏ về `localhost:5129`.
- **Android Emulator**: Tự động trỏ về `10.0.2.2:5129`.
- **Thiết bị thật (Physical Device)**: Cần truyền IP mạng LAN của máy tính chạy backend:
  ```bash
  flutter run --dart-define=BACKEND_HOST=192.168.1.xxx:5129
  ```

### 3. Khởi chạy trên thiết bị

```bash
# Chạy trên thiết bị mặc định
flutter run

# Liệt kê các thiết bị khả dụng
flutter devices

# Chạy trên thiết bị cụ thể (ví dụ macOS hoặc iPhone simulator)
flutter run -d macos
flutter run -d "iPhone 16 Pro"
```

---

## 🔒 Quyền hạn thiết bị (Permissions)

- **Microphone**:
  - **iOS** (`ios/Runner/Info.plist`): Đã cấu hình `NSMicrophoneUsageDescription`.
  - **Android** (`android/app/src/main/AndroidManifest.xml`): Đã cấu hình `android.permission.RECORD_AUDIO`.
  - **macOS** (`macos/Runner/DebugProfile.entitlements`): Đã kích hoạt `com.apple.security.device.audio-input`.
