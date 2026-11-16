# Kế Hoạch: Real-time PCM Streaming (Backend)

> Phần Backend của kế hoạch chuyển toàn hệ thống từ MP3-buffer-cả-câu sang PCM thô streaming trực tiếp, nhằm giảm độ trễ phản hồi giọng nói AI Tutor xuống dưới 1 giây.
> Repo liên quan: `mobile/` (Flutter) — xem `mobile/PCM_STREAMING_PLAN.md` cho phần đối ứng phía client. **Hai bên phải deploy đồng thời**, xem cảnh báo breaking change bên dưới.

---

## Bối cảnh

Hiện tại: `EdgeTtsService` tổng hợp giọng nói dạng MP3, `VoiceHub` gom **toàn bộ audio của một câu** thành một blob hoàn chỉnh rồi mới gửi 1 lần qua SignalR (`ReceiveAudioChunk`). Cách này đã fix được bug "âm thanh bị xé vụn" (do trước đó bắn thẳng từng gói mạng ~1-2KB chưa đủ cấu trúc MP3), nhưng đánh đổi độ trễ: phải đợi tổng hợp xong cả câu mới có âm thanh đầu tiên.

Mục tiêu lần này: chuyển sang **PCM thô** (`raw-24khz-16bit-mono-pcm`) — định dạng không cần frame/header để giải mã, nên có thể stream từng mẩu nhỏ ngay khi nhận được từ Microsoft mà không sợ vỡ tiếng, đồng thời cắt câu AI trả lời thành cụm ngắn hơn (4-6 từ / theo dấu phẩy) để bắt đầu phát âm thanh sớm hơn.

---

## User Review Required

> [!WARNING]
> **Breaking wire-format change.** App cũ (chờ nhận 1 blob MP3 hoàn chỉnh/câu) sẽ không phát được gì nếu nói chuyện với backend mới (gửi nhiều mẩu PCM thô/câu), và ngược lại. Bắt buộc **deploy backend + app cùng lúc**, không rollout riêng lẻ được.

> [!IMPORTANT]
> **Xử lý byte lẻ (16-bit PCM alignment) phải làm ở Backend, không phải Flutter.** Ranh giới network chunk từ Microsoft không cam kết chia chẵn theo cặp byte (1 sample = 2 byte). `EdgeTtsService` phải tự giữ lại byte dư (nếu có) và ghép vào đầu chunk kế tiếp, đảm bảo **mọi chunk yield ra luôn có số byte chẵn** trước khi tới tay client — nếu để sót, mọi sample sau điểm lỗi sẽ bị lệch pha 1 byte, nghe như nhiễu/rè kéo dài chứ không tự phục hồi.

---

## Proposed Changes

### [MODIFY] `src/AiEnglishTutor.Infrastructure/Speech/EdgeTtsService.cs`

1. **Đổi output format** trong `speech.config` message:
   ```csharp
   "\"outputFormat\":\"raw-24khz-16bit-mono-pcm\""
   ```

2. **Vá lỗi không xử lý `EndOfMessage` (bắt buộc)** — hiện tại vòng lặp nhận WebSocket:
   ```csharp
   var result = await ws.ReceiveAsync(buffer, cancellationToken);
   // parse header ngay trên buffer, không check result.EndOfMessage
   ```
   Nếu một message của Microsoft bị chia thành nhiều WS frame, code hiện tại hiểu nhầm mỗi frame là một gói "header+audio" độc lập → parse sai vị trí header → cắt/rớt byte audio thật sự. Cần gom đủ **toàn bộ message** (loop `ReceiveAsync` cho tới khi `result.EndOfMessage == true`, dùng `MemoryStream` để accumulate) rồi mới parse header 2-byte length một lần trên message hoàn chỉnh.

3. **Vá carry-over byte lẻ** — sau khi trích được audio payload từ một message, nếu độ dài payload là số lẻ:
   - Giữ lại byte cuối cùng trong một buffer instance-level (`_leftoverByte`).
   - Ghép byte đó vào **đầu** payload của lần yield kế tiếp trước khi trả về.
   - Bất biến cần đảm bảo: **mọi `byte[]` mà `StreamAudioAsync` yield ra đều có `Length % 2 == 0`.**
   - Ở cuối stream (khi gặp `Path:turn.end` hoặc kết nối đóng), nếu còn 1 byte lẻ tồn đọng chưa dùng, log cảnh báo và bỏ nó (không đủ tạo thành 1 sample hoàn chỉnh).

4. Giữ nguyên phần throw `InvalidOperationException` khi `ConnectAsync` thất bại (đã fix ở vòng review trước — không đổi).

### [MODIFY] `src/AiEnglishTutor.API/Hubs/VoiceHub.cs`

1. **Ngắt câu sớm hơn (clause-level breaking)** trong `ProcessUserTextInternal`:
   - Điều kiện flush hiện tại: `Regex.IsMatch(currentText, @"[.?!]\s*$|\n$")`
   - Mở rộng: flush thêm khi gặp dấu `,;:` **và** cụm hiện tại đã ≥ 4 từ kể từ lần flush gần nhất.
   - Đây là heuristic đơn giản, chấp nhận rủi ro nhỏ với câu có số thập phân ("3.14") hoặc viết tắt ("e.g.," "Mr.") — không cần xử lý hoàn hảo ở giai đoạn này.

2. **`StreamAudioSentenceToClient`: quay lại streaming trực tiếp**, bỏ cách buffer cả câu (`SynthesizeAudioAsync`) đang dùng hiện tại:
   ```csharp
   private async Task StreamAudioSentenceToClient(string phrase, CancellationToken cancellationToken)
   {
       try
       {
           await foreach (var pcmChunk in _ttsService.StreamAudioAsync(phrase, cancellationToken: cancellationToken))
           {
               if (pcmChunk.Length > 0 && !cancellationToken.IsCancellationRequested)
               {
                   await Clients.Caller.SendAsync("ReceiveAudioChunk", pcmChunk, cancellationToken);
               }
           }
       }
       catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
       {
           // Client đã ngắt kết nối — dừng êm, không log lỗi.
       }
       catch (Exception ex)
       {
           _logger.LogError(ex, "TTS generation failed for phrase: {Phrase}", phrase);
           await Clients.Caller.SendAsync("StatusUpdate", "Voice synthesis unavailable for this phrase.", cancellationToken);
       }
   }
   ```

### [MODIFY] `src/AiEnglishTutor.API/Controllers/TestController.cs`

- Endpoint `/api/test/tts` hiện trả `File(audioBytes, "audio/mpeg", "speech.mp3")` — sẽ sai hoàn toàn sau khi `EdgeTtsService` chuyển sang PCM (dữ liệu PCM thô không tự mô tả định dạng như MP3, mở file sẽ không phát được).
- Bọc thêm 44-byte WAV header (RIFF/WAVE, 24kHz/16-bit/mono) quanh audio bytes trước khi trả về, đổi content-type thành `audio/wav`, filename `speech.wav` — để vẫn nghe thử/test được qua browser hoặc Postman mà không cần app Flutter.

### (Tuỳ chọn — không chặn release lần này)

- **Tái sử dụng 1 `ClientWebSocket`** cho nhiều cụm từ trong cùng lượt nói thay vì mở connection mới mỗi cụm. Vì cắt câu ngắn hơn (4-6 từ) làm tăng đáng kể số lần handshake tới API không chính thức của Microsoft Edge TTS mỗi lượt trả lời — tăng rủi ro bị rate-limit/chặn (đã ghi nhận là rủi ro độ tin cậy trong `CODE_REVIEW.md` mục #6).
- **`CancelResponse()` hub method** để hủy `CancellationTokenSource` phía server khi user bắt đầu nói đè lên AI (barge-in thật sự ở server, hiện tại chỉ client tự xả buffer phía mình trong khi server vẫn tiếp tục sinh token/audio không ai nghe).

---

## Verification Plan

```bash
dotnet build
```

**Manual (theo đúng thứ tự để cô lập lỗi trước khi tích hợp với Flutter):**
1. Gọi `/api/test/tts` (sau khi bọc WAV) — nghe thử qua browser để xác nhận `EdgeTtsService` sinh PCM đúng, độc lập với client.
2. Test với câu dài (>15 từ, nhiều dấu phẩy) để ép nhiều lần cắt cụm — kiểm tra chỗ nối giữa các cụm có tiếng tách/rè không (dấu hiệu byte lẻ chưa xử lý đúng).
3. Test với câu có số thập phân/viết tắt để xem heuristic cắt câu có gây lỗi ngắt bất thường không.
4. Ngắt kết nối mạng đột ngột giữa chừng câu trả lời — xác nhận `CancellationToken` vẫn dừng đúng, không leak tài nguyên.
5. Đo lại độ trễ "thời điểm AI bắt đầu phát âm thanh" trước/sau khi đổi, xác nhận có cải thiện rõ rệt so với bản buffer-cả-câu.
