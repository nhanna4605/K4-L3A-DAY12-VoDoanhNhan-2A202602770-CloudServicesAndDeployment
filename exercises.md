# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `*Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Võ Doanh Nhân  Mã học viên: 2A202602770

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống: deploy lên Railway nhưng quên set `AGENT_API_KEY` trong dashboard.
>
> - Nếu có mặc định `"changeme"`: app vẫn khởi động, `/health` trả 200, Railway
>   báo deploy thành công. Service công khai trên Internet với khóa `changeme` —
>   giá trị nằm ngay trong repo public, ai đọc code cũng biết — nên người lạ gọi
>   `/ask` thoải mái và tiêu ngân sách của mình. Mình chỉ phát hiện khi nhìn hóa đơn.
> - Không có mặc định: mình chạy thử image không truyền `AGENT_API_KEY`. Container
>   chết sau 0,84 giây (exit code 3), log ghi `ValidationError: 1 validation error
>   for Settings — agent_api_key Field required` rồi `Application startup failed.
>   Exiting.`. Trên Railway, healthcheck `/health` sẽ không bao giờ đạt nên deploy
>   bị đánh dấu thất bại và bản cũ vẫn chạy — lỗi hiện ra ngay lúc deploy.
>
> Điều mình phát hiện khi thử: lúc đầu app **không** chết dù thiếu key, vì
> `Settings` chỉ được đọc khi có request đầu tiên. Container vẫn chạy, `/health`
> vẫn 200, còn `/ready` trả 500 — tức "fail fast" chỉ đúng trên giấy (test CP1
> vẫn pass vì test tạo `Settings()` trực tiếp). Mình sửa bằng cách gọi
> `get_settings()` trong `lifespan` để cấu hình được kiểm tra ngay lúc khởi động.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thật từ `docker compose logs agent`:
>
> ```
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T09:57:22.078749+00:00", "user_id": "sv01", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}
> ```
>
> 1. **Tổng hợp theo trường.** Mỗi dòng parse được bằng `json.loads`, nên mình
>    cộng `cost_usd` theo `user_id` từ log của container: `sv-a` 3 request, tổng
>    0.00011595 USD; `sv-b` 2 request, tổng 0.0000663 USD → trả lời được "user
>    nào tiêu nhiều tiền nhất". `print("đã trả lời xong")` không có user, không có
>    số tiền, không có thời điểm nên không tính được gì.
> 2. **Lọc và cảnh báo.** Có `level`, `event`, `timestamp` nên đếm được số dòng
>    `level = "error"` trong 5 phút gần nhất để bắn cảnh báo, hoặc lọc riêng
>    `event = "ask_completed"`. Platform cũng tự hiểu cấu trúc: log trên Railway
>    hiện thành `[INFO] event="service_started" ... service="day12-agent"`, tức
>    Railway đã tách JSON thành từng trường để lọc. Chuỗi `print()` tự do thì
>    không lọc theo mức độ hay theo trường được.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1730 MB (`day12-agent:single` — `docker images` báo 1.73GB, nội dung nén 446MB) |
| Multi-stage | 271 MB (`day12-agent:prod` — nội dung nén 63.8MB) |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Bản multi-stage nhỏ hơn khoảng 6,4 lần (chênh khoảng 1,46GB). Mình xem bằng
> `docker history` và chạy thử lệnh bên trong từng image:
>
> - **Bộ công cụ build trong base `python:3.11` bản đầy đủ** — phần lớn nhất. Ba
>   layer `apt-get` của base chiếm khoảng 694 + 202 + 65 ≈ 961MB. Trong image
>   1 stage có sẵn `gcc`, `g++`, `make`, `git`, `curl`, `wget`, `ssh` và 469 gói
>   hệ thống; image multi-stage không có lệnh nào trong số đó, chỉ 87 gói. App
>   chạy không cần compiler — nó chỉ cần lúc cài thư viện.
> - **Hệ điều hành nền to hơn:** layer Debian của bản đầy đủ 134MB, bản slim 87.6MB.
> - **Rác của pip:** layer `pip install` của bản 1 stage nặng 95.1MB, còn thư viện
>   copy từ builder sang chỉ 65.5MB; trong đó 17MB là cache ở `/root/.cache/pip`
>   do bản 1 stage không dùng `--no-cache-dir`.
>
> Code của app chỉ khoảng 65KB ở cả hai bản — gần như toàn bộ chênh lệch là "đồ
> nghề" để build. Multi-stage cài thư viện ở stage `builder` rồi bỏ stage đó đi;
> stage `runtime` chỉ nhận thư mục `/install` đã cài xong.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Mình sửa `app/main.py` rồi chạy `docker compose build --progress=plain agent`:
>
> - **Dùng lại từ cache (`CACHED`):** `WORKDIR /build`, `COPY requirements.txt`,
>   `RUN pip install` (stage builder); `COPY --from=builder /install /usr/local`,
>   `RUN useradd`, `WORKDIR /app` (stage runtime).
> - **Chạy lại:** `COPY app ./app` (0,4 giây) và `COPY utils ./utils`. Thư mục
>   `utils` không đổi nhưng vẫn phải chạy lại vì nó nằm sau layer vừa thay đổi —
>   Docker hủy cache từ layer đầu tiên thay đổi trở đi.
> - Cả lần build chỉ mất **2 giây**. Lần build đầu, riêng bước `pip install` mất
>   khoảng 10 phút (16:09:44 → 16:19:36) vì mạng nhà mình chậm.
>
> Nếu đặt `COPY . .` trước `RUN pip install` (như `Dockerfile.single`): sửa 1 ký
> tự thì checksum của layer `COPY . .` đổi, kéo theo `pip install` phía sau mất
> cache → lần build nào cũng cài lại toàn bộ thư viện (với mạng của mình là
> khoảng 10 phút thay vì 2 giây). Tệ hơn, `COPY . .` chép cả README, tests… nên
> sửa một file không liên quan cũng làm mất cache.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện khi container chạy root:
>
> 1. Code có lỗ hổng cho phép chạy lệnh tùy ý (ví dụ một thư viện bị chèn mã độc,
>    hoặc lỗi deserialization) → kẻ tấn công chạy lệnh với quyền của process uvicorn.
> 2. Process đó là root trong container → kẻ tấn công ghi đè thư viện Python (cài
>    backdoor vào `fastapi` để lấy API key của mọi request), đọc `/etc/shadow`,
>    dùng sẵn `gcc`, `curl`, `ssh` có trong image 1 stage.
> 3. Root trong container cũng là UID 0 trên host (nếu không bật user namespace).
>    Chỉ cần thêm một cấu hình sai — mount `/var/run/docker.sock`, mount thư mục
>    host, chạy `--privileged` — hoặc một lỗ hổng của container runtime/kernel là
>    kẻ tấn công thoát ra host với quyền root.
>
> `USER appuser` cắt chuỗi ở bước 2 và 3: process chỉ còn là uid 10001. Mình thử
> trong image: `id` → `uid=10001(appuser)`; ghi đè
> `/usr/local/lib/python3.11/site-packages/fastapi/__init__.py` → `Permission
> denied`; sửa `/app/app/main.py` → `Permission denied`; đọc `/etc/shadow` →
> `Permission denied`. Có thoát ra được host thì cũng chỉ là một user thường
> không có quyền gì, không phải root.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request** trong 2 giây: gửi 10 request lúc 10:00:59 (dùng hết hạn
> mức của phút 10:00), rồi 10 request lúc 10:01:00 — bộ đếm vừa reset về 0 nên
> lại được thêm 10. Mỗi phút đồng hồ đều "đúng luật" nhưng thực tế là 20 request
> trong khoảng 1–2 giây.
>
> Mình kiểm chứng bằng chính `RateLimiter` của bài với timestamp giả: 20 request
> trong 1,45 giây vắt qua ranh giới phút → sliding window chỉ cho qua **10/20**,
> còn bộ đếm theo phút (mô phỏng) cho qua **20/20**. Sliding window luôn đếm các
> request trong đúng 60 giây ngay trước thời điểm hiện tại, nên ở bất kỳ khoảng
> 60 giây nào cũng không quá 10. Trên Railway, 15 request liên tiếp cho kết quả
> 10 lần `200` rồi `429` kèm header `Retry-After: 60`.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> - **Rate limit** giới hạn *số request* trong 60 giây (sorted set
>   `ratelimit:<user>`), chống spam, trả **429** và tự hết sau tối đa 60 giây.
> - **Cost guard** giới hạn *số tiền* trong tháng (`cost:<user>:<YYYY-MM>`, cộng
>   bằng `INCRBYFLOAT`), chống cháy hóa đơn, trả **402** và chỉ reset khi sang tháng.
>
> **Rate limit cho qua, cost guard chặn:** user gọi thong thả 2 request/phút —
> dưới hạn mức 10 — nhưng mỗi request gửi prompt rất dài (hàng chục nghìn token)
> hoặc gọi đều đặn cả tháng, tiền cộng dồn vượt 10 USD. Mình thử bằng cách đặt
> `cost:sv-budget:2026-09 = 999` trong Redis: `/ask` trả `402 monthly budget
> exceeded` dù user này mới gọi đúng 1 request.
>
> **Ngược lại:** user bắn 15 request trong vài giây, mỗi request chỉ tốn khoảng
> 0.00002 USD — còn rất xa 10 USD — nên cost guard cho qua, nhưng rate limit
> chặn từ request thứ 11 (quan sát thật: 10 lần `200` rồi `429`).
>
> Quan sát thêm: request bị 402 vẫn tốn 1 lượt rate limit, vì trong `/ask`
> limiter chạy trước guard.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> 1. Giây 0: Redis mất kết nối. Cả 3 container dùng chung một Redis, nên
>    endpoint gộp của cả 3 cùng lúc trả lỗi.
> 2. Orchestrator gọi liveness probe theo chu kỳ; sau vài lần thất bại liên tiếp
>    nó đánh dấu **cả 3** container là unhealthy.
> 3. Orchestrator restart cả 3 cùng lúc: process bị kill, request đang xử lý dở
>    bị cắt → user thấy 502.
> 4. Trong lúc 3 container khởi động lại, không còn instance nào phục vụ — kể cả
>    những request lẽ ra chỉ cần nhận một câu 503 gọn gàng.
> 5. Giây 30: Redis quay lại, nhưng các container còn đang khởi động, hoặc lại
>    fail probe lúc khởi động rồi bị restart tiếp (vòng backoff) → sự cố 30 giây
>    của Redis thành sự cố dài hơn của cả hệ thống.
>
> Tách ra thì Redis chết chỉ làm `/ready` trả 503 → load balancer ngừng gửi
> traffic, process vẫn sống. Mình thử `docker compose stop redis`: `/health` vẫn
> 200, `/ready` trả `503 {"status":"not ready","redis":false}`, container không
> bị restart (restart count = 0). `docker compose start redis` → `/ready` tự về
> 200 mà không cần restart agent, lịch sử hội thoại vẫn còn nguyên.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Chạy thẳng `--scale agent=3` thì `agent-2`, `agent-3` lỗi vì cổng `8000:8000`
> chỉ gán được cho một container. Mình dùng file phụ `docker-compose.scale.yml`
> (bỏ cổng riêng của agent, Nginx đứng trước chia vòng):
> `docker compose -f docker-compose.yml -f docker-compose.scale.yml up -d --scale agent=3`,
> rồi gọi `/ask` 6 lần với cùng `X-User-Id` qua `http://localhost`.
>
> - **Lịch sử trong Redis:** `history_length` = **0 2 4 6 8 10**, dù 6 lượt được
>   chia cho cả 3 container (mỗi container 2 lượt, xem trong `docker compose logs`).
> - **Giống dict Python:** mình chạy lại với `REDIS_URL=fake://` — mỗi container
>   một Redis giả trong RAM của chính nó, y hệt dict trong process. Kết quả
>   `history_length` = **0 0 0 2 2 2**, thứ tự container agent-1 → 2 → 3 → 1 → 2 → 3.
>   Ba lượt đầu rơi vào ba container chưa biết gì nên đều là 0; lượt 4–6 quay lại
>   container cũ, mỗi container chỉ nhớ lượt của chính nó nên là 2 (đáng ra phải
>   là 6, 8, 10). Agent "mất trí nhớ" tùy request rơi vào đâu, và container
>   restart là mất sạch lịch sử.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi:** app không đọc được `$PORT` trên Railway. `railway.toml` ban đầu có
> `startCommand = "uvicorn app.main:app --host 0.0.0.0 --port $PORT"`. Với service
> build từ Dockerfile, Railway chạy `startCommand` ở exec form (không qua shell)
> nên uvicorn nhận nguyên chuỗi `$PORT`. Mình tái hiện ở máy bằng `docker run`
> dạng exec và nhận đúng thông báo:
> `Error: Invalid value for '--port': '$PORT' is not a valid integer.` (exit code 2)
> — container chết ngay, healthcheck `/health` không bao giờ đạt, deploy thất bại.
>
> **Cách tìm ra:** trước khi `railway up`, mình đọc tài liệu Railway về start
> command: *"the start command overrides the image's ENTRYPOINT in exec form"* và
> muốn dùng biến môi trường thì phải *"wrap your command in a shell"*. Vì phát
> hiện trước khi deploy nên bản trên Railway không dính lỗi này; thông báo lỗi ở
> trên là do mình tái hiện ở máy để chắc chắn.
>
> **Cách sửa:** bỏ `startCommand` để Railway dùng `CMD` của Dockerfile:
> `CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]`
> — `sh -c` để thay biến `PORT`, `exec` để uvicorn là PID 1 và nhận được SIGTERM.
> Kèm theo đó sửa `builder = "DOCKERFILE"` và `restartPolicyType = "ON_FAILURE"`
> viết hoa đúng theo tài liệu. Kết quả: log Railway ghi `Uvicorn running on
> http://0.0.0.0:8080`, deploy thành công ngay lần đầu, `/health` và `/ready` đều 200.
