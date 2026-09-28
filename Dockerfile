# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (bản production)
#
#   [x] Multi-stage: stage `builder` cài dependency, stage `runtime` chỉ
#       nhận kết quả cài đặt → không mang theo pip cache, file build tạm
#   [x] Base image python:3.11-slim cho cả hai stage
#   [x] COPY requirements.txt + pip install TRƯỚC khi COPY source code
#   [x] Chạy bằng user thường (appuser, uid 10001)
#   [x] HEALTHCHECK gọi /health
#   [x] Đọc cổng từ $PORT (mặc định 8000)
#
# Bản 1 stage ban đầu được giữ lại ở Dockerfile.single để so dung lượng.
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài thư viện vào /install ─────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Chỉ copy requirements.txt: layer pip install được cache cho tới khi
# danh sách thư viện đổi, sửa code không làm cài lại.
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime — image thật sự được deploy ──────────────────────
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Chỉ lấy thư viện đã cài từ builder
COPY --from=builder /install /usr/local

RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

# Source code copy sau cùng — layer hay thay đổi nhất nằm trên cùng
COPY app ./app
COPY utils ./utils

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${PORT:-8000}/health', timeout=3)" || exit 1

# sh -c để shell thay ${PORT:-8000}; exec để uvicorn thành PID 1 và nhận
# thẳng SIGTERM (không có exec thì sh là PID 1 và nuốt mất tín hiệu).
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
