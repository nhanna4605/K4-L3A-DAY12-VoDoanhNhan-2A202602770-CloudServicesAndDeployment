# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Võ Doanh Nhân |
| Mã học viên | 2A202602770 |
| Repo | https://github.com/nhanna4605/K4-L3A-DAY12-VoDoanhNhan-2A202602770-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://agent-production-faa8.up.railway.app |
| Platform | Railway — build từ `Dockerfile`, cấu hình trong `railway.toml` |
| Ngày deploy | 2026-09-28 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | Railway tự gán (log khởi động: `Uvicorn running on 0.0.0.0:8080`) |
| `AGENT_API_KEY` | ✅ | set bằng `railway variable set AGENT_API_KEY --stdin`, giá trị đọc từ `.env` trên máy (không nằm trong repo); khác khóa dùng khi chạy local |
| `REDIS_URL` | ✅ | Redis add-on của Railway (service `Redis` cùng project), set bằng biến tham chiếu `${{Redis.REDIS_URL}}` → trỏ tới `redis.railway.internal` qua mạng nội bộ |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

**Ghi chú cấu hình:** `railway.toml` cố ý không đặt `startCommand`. Với service
build từ Dockerfile, Railway chạy `startCommand` ở exec form (không qua shell)
nên `$PORT` không được thay thành số cổng. Bỏ trống để Railway dùng `CMD` trong
Dockerfile (`sh -c "exec uvicorn ... --port ${PORT:-8000}"`).

## Lệnh Kiểm Tra

```bash
URL=https://agent-production-faa8.up.railway.app
# $AGENT_API_KEY ở đây là khóa đã set trên Railway (khác khóa local)

# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i $URL/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i $URL/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
#    (câu hỏi không dấu: Git Bash trên Windows gửi chữ có dấu sai bảng mã → 400)
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy la gi?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST $URL/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Output thật khi chạy các lệnh trên ngày 2026-09-28:

```
$ curl -i $URL/health
HTTP/1.1 200 OK
Content-Type: application/json
Date: Mon, 28 Sep 2026 10:38:06 GMT
Server: railway-hikari
x-railway-request-id: h6Y0Jwi2ScuS-yEi2h0iww
Content-Length: 57
x-hikari-trace: sin1.tr00
x-railway-edge: sin1
Connection: keep-alive

{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i $URL/ready
HTTP/1.1 200 OK
Content-Type: application/json
Date: Mon, 28 Sep 2026 10:38:06 GMT
Server: railway-hikari
x-railway-request-id: jPQNxUIPRgOtKTvpWUN5dQ
Content-Length: 31
x-hikari-trace: sin1.tr00
x-railway-edge: sin1
Connection: keep-alive

{"status":"ready","redis":true}

$ curl -i -X POST $URL/ask  (không có API key)
HTTP/1.1 401 Unauthorized
Content-Type: application/json
Date: Mon, 28 Sep 2026 10:38:09 GMT
Server: railway-hikari
x-railway-request-id: JC3mHCTQRGKXsbfcn6XIxQ
Content-Length: 39
x-hikari-trace: hkg1.aebn
x-railway-edge: hkg1
Connection: keep-alive

{"detail":"invalid or missing API key"}

$ curl -i -X POST $URL/ask  (có API key, X-User-Id: sv-test)
HTTP/1.1 200 OK
Content-Type: application/json
Date: Mon, 28 Sep 2026 10:38:11 GMT
Server: railway-hikari
x-railway-request-id: MujDQqCXQtKqDGui6WHkDg
Content-Length: 345
x-hikari-trace: hkg1.aebn
x-railway-edge: hkg1
vary: accept-encoding
Connection: keep-alive

{"answer":"Ngắn gọn: Deploy la gi phụ thuộc vào ba yếu tố — cấu hình qua biến môi trường, health check để orchestrator biết trạng thái, và giới hạn tài nguyên. (Mình đang nhớ 2 lượt trao đổi trước đó.)","user_id":"sv-test","history_length":2,"cost_usd":3.465e-05,"tokens":{"in":43,"out":47}}

$ for i in $(seq 1 15); do curl ... -H "X-User-Id: sv-test" ...; done
200 200 200 200 200 200 200 200 200 429 429 429 429 429 429
```

Đọc kết quả:

- Lệnh 4 có `history_length: 2` vì user `sv-test` đã hỏi một lần trước đó — lịch
  sử nằm trong Redis trên cloud nên vẫn còn.
- Lệnh 5 chỉ có 9 lần `200` vì lệnh 4 đã dùng 1 lượt trong cửa sổ 60 giây của
  cùng user `sv-test` (hạn mức 10/phút) → lượt thứ 10 trở đi bị `429`.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên Railway
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt
