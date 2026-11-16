# Kế Hoạch: Real-time PCM Streaming (Mobile / Flutter)

> Phần Frontend của kế hoạch chuyển toàn hệ thống từ MP3-buffer-cả-câu sang PCM thô streaming trực tiếp, nhằm giảm độ trễ phản hồi giọng nói AI Tutor xuống dưới 1 giây.
> Repo liên quan: `backend/` (.NET 10) — xem `backend/PCM_STREAMING_PLAN.md` cho phần đối ứng phía server. **Hai bên phải deploy đồng thời**, xem cảnh báo breaking change bên dưới.

---

## Bối cảnh

Hiện tại `AudioPlayerService` nhận mỗi chunk qua SignalR (`ReceiveAudioChunk`) là **một file MP3 hoàn chỉnh cho cả câu** — ghi ra file tạm trên ổ đĩa, phát tuần tự qua `just_audio`, xóa file sau khi phát xong. Cách này ổn định nhưng có độ trễ: phải đợi backend tổng hợp xong cả câu mới nhận được audio đầu tiên.

Backend sẽ đổi sang gửi nhiều mẩu **PCM thô** (24kHz/16-bit/mono) ngay khi vừa nhận được từ Microsoft, không đợi hết câu. Phía mobile cần bỏ hẳn cơ chế file-based, chuyển sang bơm trực tiếp byte PCM vào buffer phát âm thanh phần cứng qua package `flutter_pcm_sound` (đã có sẵn trong `pubspec.yaml`, không cần thêm dependency).

---

## User Review Required

> [!WARNING]
> **Breaking wire-format change.** App này sẽ không phát được audio nếu nói chuyện với backend cũ (đang gửi MP3 blob/câu), và backend mới sẽ khiến app cũ (chờ MP3 hoàn chỉnh) không phát được gì. Bắt buộc **deploy backend + app cùng lúc**.

> [!NOTE]
> **API thật của `flutter_pcm_sound: ^3.3.3`** (đã tra lại từ pub.dev, khác với bản nháp ban đầu):
> ```dart
> FlutterPcmSound.setup({required int sampleRate, required int channelCount});
> FlutterPcmSound.feed(PcmArrayInt16 samples);
> FlutterPcmSound.start();                      // KHÔNG phải .play()
> FlutterPcmSound.setFeedThreshold(int frames);  // ngưỡng buffer
> FlutterPcmSound.setFeedCallback(callback);     // callback nhận remainingFrames, event-based — không tự chế timer
> ```
> `setup()` và `start()` chỉ gọi **một lần mỗi lượt nói**, không gọi lại mỗi khi nhận chunk.

> [!IMPORTANT]
> **Không cần tự xử lý byte lẻ (odd-byte) ở phía Flutter.** Backend (`EdgeTtsService`) đã đảm bảo mọi chunk gửi qua SignalR luôn có số byte chẵn (mỗi sample PCM 16-bit đủ 2 byte) trước khi tới client — Flutter chỉ việc convert `Uint8List` → `Int16List` và feed thẳng, không cần logic carry-over.

> [!NOTE]
> Tài liệu package không nêu rõ API "clear/flush buffer ngay lập tức" cho tính năng ngắt lời (barge-in) — cần tự kiểm tra source/example của package trước khi chốt cách implement `stop()`. Tạm thời dùng phương án an toàn: dừng feed + gọi lại `setup()` để reset trạng thái nếu không tìm thấy API dedicated.

---

## Proposed Changes

### `pubspec.yaml`
- **Không cần sửa** — `flutter_pcm_sound: ^3.3.3` đã có sẵn (dòng 51).

### [MODIFY] `lib/core/audio/audio_player_service.dart`

Viết lại hoàn toàn, bỏ cơ chế ghi file tạm `.mp3` + `just_audio` (`_audioQueue`, `_activeFile`, `_playNextInQueue`):

```dart
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

class AudioPlayerService implements IAudioPlayerService {
  bool _isSetup = false;
  bool _isStarted = false;
  final _isPlayingController = StreamController<bool>.broadcast();

  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  @override
  bool get isPlaying => _isStarted;

  Future<void> _ensureSetup() async {
    if (_isSetup) return;
    await FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
    FlutterPcmSound.setFeedThreshold(4000); // cần tune lại theo test thực tế trên thiết bị
    FlutterPcmSound.setFeedCallback((remainingFrames) {
      if (remainingFrames == 0) {
        _isStarted = false;
        _isPlayingController.add(false);
      }
    });
    _isSetup = true;
  }

  @override
  Future<void> enqueueAudioChunk(Uint8List chunk) async {
    if (chunk.isEmpty) return;
    await _ensureSetup();

    // Backend đảm bảo chunk luôn chẵn byte — feed thẳng, không cần bù byte lẻ.
    final pcm16 = chunk.buffer.asInt16List(chunk.offsetInBytes, chunk.lengthInBytes ~/ 2);
    await FlutterPcmSound.feed(PcmArrayInt16.fromList(pcm16));

    if (!_isStarted) {
      FlutterPcmSound.start(); // gọi một lần mỗi lượt nói, không phải mỗi chunk
      _isStarted = true;
      _isPlayingController.add(true);
    }
  }

  @override
  Future<void> stop() async {
    // TODO: verify API clear/reset buffer thật sự của package (xem ghi chú ở trên)
    // trước khi chốt hành vi barge-in.
    _isStarted = false;
    _isPlayingController.add(false);
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _isPlayingController.close();
  }
}
```

Giữ nguyên interface `IAudioPlayerService` (`isPlayingStream`, `isPlaying`, `enqueueAudioChunk`, `stop`, `dispose`) — không cần sửa `voice_tutor_bloc.dart` hay bất kỳ layer nào khác gọi vào service này.

### Không cần sửa

- **`lib/core/network/signalr_service.dart`** — `_onReceiveAudioChunk` đã generic-decode bytes (Uint8List/List/base64), không quan tâm định dạng audio bên trong, không cần đổi.
- **`lib/core/audio/audio_recorder_service.dart`** — đã ghi âm WAV 16kHz/16-bit/mono đúng chuẩn Whisper STT ở backend, không liên quan tới nhánh PCM output (TTS) này.

---

## Verification Plan

```bash
flutter analyze
```

**Manual (thực hiện sau khi backend đã pass verification riêng của nó — xem `backend/PCM_STREAMING_PLAN.md`):**
1. Kết nối app với backend đã deploy bản PCM mới, nói một câu tiếng Anh ("Hello, can you introduce yourself?").
2. Xác nhận âm thanh AI phát ra **sớm hơn rõ rệt** so với bản cũ (ngay từ cụm từ đầu tiên, không phải đợi hết câu).
3. Nghe kỹ toàn bộ câu trả lời dài (nhiều cụm) — không còn tiếng rè/nhiễu/lệch pha ở chỗ nối giữa các chunk.
4. Xác nhận **không còn file `.mp3`/`.wav` tạm nào được tạo ra** trong thư mục temp của thiết bị/máy ảo (kiểm tra qua file explorer hoặc log).
5. Test tắt/mở app giữa chừng khi AI đang nói — xác nhận không crash, không kẹt trạng thái `isPlaying = true` vĩnh viễn.
6. Test tính năng barge-in (bấm nói khi AI đang phát) — xác nhận buffer được xả kịp thời, không có tiếng cũ chồng lên tiếng mới.
