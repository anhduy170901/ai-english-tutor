# Code Review — AI English Tutor Backend

Phạm vi: Toàn bộ mã nguồn `.cs` trong `src/` (API, Application, Domain, Infrastructure, Persistence) + `docker-compose.yml`.
Trạng thái: **Đã cập nhật & xử lý (Ngày 15/09/2026)**.

---

## 1. [High] IDOR trên VoiceHub — client tự chọn `sessionId` tuỳ ý

**File:** `src/AiEnglishTutor.API/Hubs/VoiceHub.cs`

### Hiện trạng ban đầu:
`ProcessUserAudio` và `ProcessUserText` nhận `sessionId` trực tiếp từ client, cho phép client bất kỳ gửi tin nhắn vào session của người khác.

### Giải pháp đã xử lý (Session Pinning Mitigation):
- **Cơ chế:** Ghim `SessionId` chặt chẽ vào từng kết nối (`Context.Items["SessionId"]`).
  - Nếu connection đã ghim phiên (sau khi gọi `StartSession` hoặc `JoinSession`), mọi request gửi kèm `sessionId` lệch với phiên đã ghim đều bị từ chối ngay lập tức (`HubException: Unauthorized: Connection is bound to a different session`).
  - Bổ sung method `JoinSession(Guid sessionId)` kiểm tra session tồn tại và đang `Active` trong DB trước khi ghim vào connection (phục vụ client reconnect).
  - Tương thích ngược với client Flutter Mobile: nếu client gửi `sessionId` hợp lệ lần đầu sau khi reconnect, hub sẽ kiểm tra trong DB và ghim phiên tự động.

> [!WARNING]
> **Giới hạn kỹ thuật & Lưu ý quan trọng:**
> Đây là **biện pháp giảm thiểu tạm thời (Mitigation)** nhằm chống hiện tượng rò rỉ / gửi chéo session (cross-session spoofing/hijacking) giữa các request trên cùng 1 kết nối.
> Do hệ thống hiện tại chưa có Authentication (#3) và `LearningSession` chưa có trường `UserId` (chủ sở hữu phiên), một người ngoài biết hoặc đoán trúng GUID của một phiên đang `Active` vẫn có thể kết nối và gọi `JoinSession`. Để đóng triệt để lỗ hổng IDOR, điều kiện tiên quyết là phải triển khai hệ thống xác thực người dùng (Auth) và kiểm tra quyền sở hữu (`session.UserId == currentUserId`).

---

## 2. [High] CORS cho phép mọi origin **kèm** AllowCredentials

**File:** `src/AiEnglishTutor.API/Program.cs`, `src/AiEnglishTutor.API/appsettings.json`

### Hiện trạng ban đầu:
`SetIsOriginAllowed(_ => true)` kết hợp cùng `AllowCredentials()` cho phép bất kỳ trang web độc hại nào gọi API bằng credentials của người dùng.

### Giải pháp đã xử lý:
- Thay thế toàn bộ wildcard bằng chính sách `DefaultCorsPolicy` đọc whitelist danh sách origin cụ thể từ cấu hình:
  ```csharp
  var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() 
      ?? new[] { "http://localhost:3000", "http://localhost:5000", ... };
  builder.Services.AddCors(options => {
      options.AddPolicy("DefaultCorsPolicy", policy => {
          policy.WithOrigins(allowedOrigins)
                .AllowAnyMethod()
                .AllowAnyHeader()
                .AllowCredentials();
      });
  });
  ```
- Khai báo các origin web development mặc định trong `appsettings.json`.

> [!NOTE]
> **Phạm vi bảo vệ:**
> Cấu hình CORS này **chỉ có hiệu lực đối với client chạy trên trình duyệt** (Web app, Flutter Web).
> Ứng dụng **Native Flutter Mobile** (iOS / Android) gọi HTTP/SignalR trực tiếp qua socket không gửi header `Origin` theo chuẩn trình duyệt, nên hoàn toàn **không chịu ảnh hưởng và không được bảo vệ bởi CORS** (cả cấu hình cũ lẫn mới).

---

## 3. [Medium] Toàn bộ API/Hub không có authentication/authorization

**File:** Tất cả Controllers (`SessionsController.cs`, `TestController.cs`) và `VoiceHub.cs`

### Hiện trạng:
Hệ thống hiện hoạt động ở chế độ Local Development / Single-user Demo, không có `[Authorize]`.

### Đánh giá & Định hướng:
- Đã ghi nhận trong tài liệu kiến trúc và metadata API.
- Chặn các endpoint test qua kiểm tra môi trường (xem mục 4).
- Kế hoạch Phase 3: Bổ sung Identity/JWT Bearer Token và liên kết `UserId` vào `LearningSession` để kích hoạt phân quyền hoàn chỉnh.

---

## 4. [Medium] `TestController` lộ endpoint chat/tts/stt thô, không giới hạn

**File:** `src/AiEnglishTutor.API/Controllers/TestController.cs`

### Hiện trạng ban đầu:
Endpoint proxy trực tiếp tới LLM/TTS/STT không qua kiểm tra môi trường, có thể bị lạm dụng làm proxy miễn phí nếu deploy công khai.

### Giải pháp đã xử lý:
- Inject `IWebHostEnvironment` vào `TestController`.
- Bổ sung guard check `if (!_environment.IsDevelopment()) return NotFound();` trên tất cả các action (`/chat`, `/tts`, `/stt`).
- Khi chạy ở môi trường ngoài Development (Staging, Production), toàn bộ endpoint này sẽ tự động trả về `404 Not Found`.

---

## 5. [Medium] Không hủy xử lý khi client ngắt kết nối SignalR (resource leak)

**File:** `src/AiEnglishTutor.API/Hubs/VoiceHub.cs`

### Hiện trạng ban đầu:
Vòng lặp streaming LLM và TTS không truyền `CancellationToken`. Nếu client đóng kết nối, server vẫn chạy stream đến hết, gây lãng phí tài nguyên CPU/GPU và kết nối mạng.

### Giải pháp đã xử lý:
- Sử dụng `Context.ConnectionAborted` truyền xuyên suốt:
  - `_sttService.TranscribeBytesAsync(audioBytes, cancellationToken)`
  - `_ollamaService.StreamResponseAsync(..., cancellationToken: cancellationToken)`
  - `_ttsService.StreamAudioAsync(sentence, cancellationToken: cancellationToken)`
  - `_mediator.Send(..., cancellationToken)`
- Bắt `OperationCanceledException` khi client ngắt kết nối để dừng xử lý ngay lập tức và ghi log thông tin nhẹ nhàng (`LogInformation`), giải phóng tài nguyên lập tức.

---

## 6. [Medium] `EdgeTtsService` dựa vào API nội bộ không chính thức của Microsoft Edge

**File:** `src/AiEnglishTutor.Infrastructure/Speech/EdgeTtsService.cs`, `src/AiEnglishTutor.API/Hubs/VoiceHub.cs`

### Hiện trạng ban đầu:
Khi kết nối WebSocket tới Edge TTS thất bại, method chỉ `yield break` âm thầm. Client không nhận được âm thanh và cũng không nhận được thông báo lỗi, rơi vào trạng thái treo.

### Giải pháp đã xử lý:
- Trong `EdgeTtsService`: 
  - Ném `InvalidOperationException("Failed to connect to Edge TTS WebSocket service.", ex)` khi kết nối thất bại.
  - **Xử lý WebSocket Message Fragmentation (`EndOfMessage`):** Tích lũy các frame mạng qua `MemoryStream` cho đến khi `result.EndOfMessage == true` mới tiến hành bóc tách `headerLength` (2 bytes Big-Endian) và payload audio. Ngăn ngừa hoàn toàn nguy cơ parse sai lệch vị trí header khi frame bị phân mảnh trên đường truyền TCP.
- Trong `VoiceHub`: Bắt lỗi TTS trong `StreamAudioSentenceToClient` và gửi `StatusUpdate` thông báo cho client ("Voice synthesis unavailable for this sentence"), cho phép hội thoại văn bản tiếp tục trơn tru mà không làm treo app.

---

## 7. [Medium] `WhisperSttService` giả định audio đầu vào đã là WAV PCM hợp lệ

**File:** `src/AiEnglishTutor.Infrastructure/Speech/WhisperSttService.cs`, `src/AiEnglishTutor.API/Hubs/VoiceHub.cs`

### Hiện trạng ban đầu:
Thư viện Whisper C++ native kỳ vọng audio PCM/WAV (16kHz mono). Nếu client gửi byte rỗng hoặc file định dạng khác, thư viện có thể throw exception khó đoán hoặc crash ở tầng native.

### Giải pháp đã xử lý:
- Thêm `ValidateWavHeader` trong `WhisperSttService`:
  - Kiểm tra kích thước tối thiểu (>= 44 bytes).
  - Kiểm tra định dạng RIFF (`0x52 0x49 0x46 0x46`) và WAVE (`0x57 0x41 0x56 0x45`).
  - Ném `ArgumentException("Audio format is invalid. Expected a 16kHz 16-bit mono WAV (RIFF/WAVE) format.")` nếu dữ liệu không hợp lệ trước khi gọi xuống thư viện native.
- Trong `VoiceHub.ProcessUserAudio`: Bắt `ArgumentException` và gửi phản hồi `StatusUpdate` rõ ràng về client thay vì làm sập pipeline.

---

## 8. [Low] Thiếu validate input ở tầng API → lỗi 500 thay vì 400

**File:** `src/AiEnglishTutor.API/Controllers/SessionsController.cs`, `src/AiEnglishTutor.API/Hubs/VoiceHub.cs`

### Hiện trạng ban đầu:
`Topic` không có validation. Nếu client gửi `null` hoặc chuỗi > 255 ký tự, lỗi rơi xuống EF Core và trả về HTTP 500.

### Giải pháp đã xử lý:
- Bổ sung DataAnnotations trong `SessionsController.cs`:
  ```csharp
  public record StartSessionRequest(
      [Required(ErrorMessage = "Topic is required")]
      [StringLength(255, MinimumLength = 1, ErrorMessage = "Topic must be between 1 and 255 characters")]
      string Topic, 
      CefrLevel TargetLevel = CefrLevel.B1);

  public record CompleteSessionRequest(
      [StringLength(2000, ErrorMessage = "Feedback cannot exceed 2000 characters")]
      string? Feedback = null);
  ```
- Thêm kiểm tra trong `VoiceHub.StartSession`: Ném `HubException` nếu `topic` rỗng hoặc dài hơn 255 ký tự.

---

## 9. [Low] `SendUserMessageCommandHandler` không kiểm tra trạng thái session

**File:** `src/AiEnglishTutor.Application/Usecases/Session/Commands/SendMessage/SendUserMessageCommand.cs`

### Hiện trạng ban đầu:
Handler cho phép thêm tin nhắn mới vào cả những session đã có trạng thái `Completed`.

### Giải pháp đã xử lý:
- Bổ sung kiểm tra trạng thái session trong `SendUserMessageCommandHandler`:
  ```csharp
  if (session.Status != SessionStatus.Active)
  {
      throw new InvalidOperationException($"Cannot add message: Session {request.SessionId} is already {session.Status}");
  }
  ```
- Đảm bảo tính nhất quán dữ liệu: Một session đã kết thúc sẽ không thể nhận thêm bất kỳ message nào.

---

## 10. [Low] Hardcoded credentials trong `docker-compose.yml` / connection string mặc định

**File:** `src/AiEnglishTutor.Persistence/DependencyInjection.cs`, `docker-compose.yml`, `.env.example`

### Hiện trạng ban đầu:
Chuỗi kết nối mặc định chứa mật khẩu plaintext hardcode trong code C# và `docker-compose.yml`.

### Giải pháp đã xử lý:
- Trong `DependencyInjection.cs`: Loại bỏ chuỗi fallback chứa password hardcode. Ném `InvalidOperationException` thông báo rõ ràng nếu thiếu `DefaultConnection` trong cấu hình.
- Trong `docker-compose.yml`: Sử dụng biến môi trường hỗ trợ override (`${POSTGRES_USER:-postgres}`, `${POSTGRES_PASSWORD:-postgrespassword}`, `${POSTGRES_DB:-ai_tutor_db}`).
- Tạo file mẫu `.env.example` hướng dẫn cấu hình biến môi trường an toàn.

---

## Tổng kết mức độ ưu tiên & Trạng thái xử lý

| # | Vấn đề | Mức độ | Loại | Trạng thái | Giải pháp đã triển khai |
|---|--------|--------|------|:----------:|-------------------------|
| 1 | IDOR trong VoiceHub | High | Bảo mật | **Đã giảm thiểu (Mitigated)** | Ghim session theo connection; từ chối cross-session spoofing; thêm `JoinSession`. *(Lưu ý: Cần Auth + `UserId` để đóng triệt để).* |
| 2 | CORS AllowAll + AllowCredentials | High | Bảo mật | **Đã xử lý (Resolved)** | Whitelist domain qua `appsettings.json`, ngăn chặn credential reflection trên Web/Browser. *(Native Mobile không dùng CORS).* |
| 3 | Không có auth/authorization | Medium | Bảo mật | **Ghi nhận (Documented)** | Xác định chế độ Local Demo; bảo vệ endpoint nhạy cảm; lên roadmap Phase 3. |
| 4 | TestController lộ endpoint không giới hạn | Medium | Bảo mật | **Đã xử lý (Resolved)** | Thêm guard check `_environment.IsDevelopment()`, trả về 404 trên production. |
| 5 | Không cancel khi client disconnect | Medium | Hiệu năng/Tài nguyên | **Đã xử lý (Resolved)** | Truyền `Context.ConnectionAborted` vào STT, Ollama, TTS và MediatR commands; dừng stream lập tức khi ngắt kết nối. |
| 6 | EdgeTtsService dùng API không chính thức | Medium | Độ tin cậy | **Đã xử lý (Resolved)** | Ném ngoại lệ khi mất kết nối; `VoiceHub` gửi `StatusUpdate` fallback cho client thay vì im lặng. |
| 7 | WhisperSttService giả định sai định dạng audio | Medium | Đúng đắn chức năng | **Đã xử lý (Resolved)** | Thêm `ValidateWavHeader` (RIFF/WAVE, length >= 44); ném `ArgumentException` và trả lỗi cho client. |
| 8 | Thiếu validate input Topic | Low | Đúng đắn/UX | **Đã xử lý (Resolved)** | Thêm DataAnnotations `[Required]`, `[StringLength]` vào DTO và Hub; trả về 400 Bad Request thay vì 500. |
| 9 | Không kiểm tra session Completed trước khi ghi message | Low | Tính nhất quán dữ liệu | **Đã xử lý (Resolved)** | Kiểm tra `session.Status == SessionStatus.Active` trong MediatR handler. |
| 10 | Hardcoded DB credentials | Low | Cấu hình/bảo mật | **Đã xử lý (Resolved)** | Bỏ fallback password trong code C#; tham số hóa `docker-compose.yml`; tạo `.env.example`. |
