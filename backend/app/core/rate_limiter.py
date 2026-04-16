"""
Rate Limiting Middleware — PRD §4.1.4 / §5
Korunan endpoint'ler:
  - POST /auth/fcm-token    → 10 req/dk (spam koruması)
  - POST /reset-password    → 5 req/dk (brute-force koruması)
  - POST /auth/request-password-reset-otp → 5 req/dk (OTP spam)
  - Genel API               → 100 req/dk
"""
import time
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi import Request
from fastapi.responses import JSONResponse

# ─── Limiter factory ────────────────────────────────────────────────────────────

def get_client_ip(req: Request) -> str:
    """X-Forwarded-For header'i varsa onu kullan, yoksa remote_address."""
    forwarded = req.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return get_remote_address(req)


limiter = Limiter(key_func=get_client_ip, default_limits=["100/minute"])


def rate_limit_exceeded_handler(req: Request, exc: RateLimitExceeded):
    """Rate limit aşıldığında döndürülecek JSON yanıtı."""
    return JSONResponse(
        status_code=429,
        content={
            "detail": "Çok fazla istek. Lütfen daha sonra tekrar deneyin.",
            "retry_after": getattr(exc, "retry_after", 60),
        },
    )


# ─── Endpoint-specific limits ─────────────────────────────────────────────────

# Auth endpoints — OTP/spam koruması
AUTH_LIMIT = "5/minute"
AUTH_FCM_LIMIT = "10/minute"
PASSWORD_RESET_LIMIT = "5/minute"

# General API
API_LIMIT = "100/minute"
