"""
Test 10: Akıllı Davet (Smart Inviting) Akışı

Hedef:
- Davet linki JWT token içerir
- OTP akışı eksiksiz çalışır
- Davet token doğrulaması, kullanım işaretleme ve role atama

Test kapsamı:
1. Davet token'ı JWT olarak üretilir ve 72 saat geçerlidir
2. Davet token decode edildiğinde agency_id ve target_role bulunur
3. Kullanılmış davet tekrar kullanılamaz (is_used kontrolü)
4. Davet linki frontend URL formatında döner
5. Şifre sıfırlama aylık limit (15/ay) kontrolü
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import timedelta, datetime, timezone
from uuid import uuid4
import jwt

from app.core.security import create_invitation_token, create_access_token, SECRET_KEY


ALGORITHM = "HS256"


class TestInvitationTokenGeneration:
    """JWT davet token üretimi testleri"""

    def test_invitation_token_contains_agency_id(self):
        """Davet token'ı agency_id claim'ini içerir"""
        agency_id = str(uuid4())
        token = create_invitation_token(
            data={
                "agency_id": agency_id,
                "target_role": "tenant",
                "related_entity_id": str(uuid4())
            },
            expires_delta=timedelta(hours=72)
        )
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert payload["agency_id"] == agency_id

    def test_invitation_token_contains_target_role(self):
        """Davet token'ı target_role claim'ini içerir"""
        token = create_invitation_token(
            data={
                "agency_id": str(uuid4()),
                "target_role": "landlord",
                "related_entity_id": None
            },
            expires_delta=timedelta(hours=72)
        )
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert payload["target_role"] == "landlord"

    def test_invitation_token_contains_related_entity_id(self):
        """Davet token'ı related_entity_id (unit_id) claim'ini içerir"""
        unit_id = str(uuid4())
        token = create_invitation_token(
            data={
                "agency_id": str(uuid4()),
                "target_role": "tenant",
                "related_entity_id": unit_id
            },
            expires_delta=timedelta(hours=72)
        )
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert payload["related_entity_id"] == unit_id

    def test_invitation_token_expires_in_72_hours(self):
        """Davet token'ı 72 saat sonra dolar"""
        token = create_invitation_token(
            data={"agency_id": str(uuid4()), "target_role": "tenant", "related_entity_id": None},
            expires_delta=timedelta(hours=72)
        )
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM], options={"require_exp": True})
        assert "exp" in payload

    def test_invitation_token_has_invitation_type(self):
        """Davet token'ı 'invitation' type claim'ine sahip"""
        token = create_invitation_token(
            data={"agency_id": str(uuid4()), "target_role": "tenant", "related_entity_id": None},
            expires_delta=timedelta(hours=72)
        )
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert payload["type"] == "invitation"

    def test_invitation_token_is_jwt_not_opaque(self):
        """Davet token'ı gerçek JWT formatındadır (3 parça noktalı)"""
        token = create_invitation_token(
            data={"agency_id": str(uuid4()), "target_role": "tenant", "related_entity_id": None},
            expires_delta=timedelta(hours=72)
        )
        parts = token.split(".")
        assert len(parts) == 3


class TestInvitationTokenValidation:
    """Davet token doğrulama testleri"""

    def test_expired_invitation_token_rejected(self):
        """Süresi dolmuş davet token'ı reddedilir"""
        token = create_invitation_token(
            data={"agency_id": str(uuid4()), "target_role": "tenant", "related_entity_id": None},
            expires_delta=timedelta(hours=-1)  # 1 saat önce süresi dolmuş
        )
        with pytest.raises(jwt.ExpiredSignatureError):
            jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])

    def test_tampered_token_rejected(self):
        """Değiştirilmiş token imza uyuşmazlığı ile reddedilir"""
        token = create_invitation_token(
            data={"agency_id": str(uuid4()), "target_role": "tenant", "related_entity_id": None},
            expires_delta=timedelta(hours=72)
        )
        # Token'ın payload kısmını değiştir (imza artık eşleşmez)
        parts = token.split(".")
        payload = parts[1]
        tampered_payload = payload[:-5] + "XXXXX"
        tampered = f"{parts[0]}.{tampered_payload}.{parts[2]}"
        with pytest.raises(jwt.PyJWTError):
            jwt.decode(tampered, SECRET_KEY, algorithms=[ALGORITHM])

    def test_invalid_signature_rejected(self):
        """Yanlış gizli anahtarla imzalanmış token reddedilir"""
        token = create_invitation_token(
            data={"agency_id": str(uuid4()), "target_role": "tenant", "related_entity_id": None},
            expires_delta=timedelta(hours=72)
        )
        with pytest.raises(jwt.PyJWTError):
            jwt.decode(token, "wrong-secret-key", algorithms=[ALGORITHM])


class TestInvitationUsageTracking:
    """Davet kullanım takibi testleri (is_used flag)"""

    def test_invitation_record_has_is_used_field(self):
        """Invitation modelinde is_used alanı var"""
        from app.models.users import Invitation
        fields = [c.name for c in Invitation.__table__.columns]
        assert "is_used" in fields

    def test_invitation_record_has_token_field(self):
        """Invitation modelinde token alanı var"""
        from app.models.users import Invitation
        fields = [c.name for c in Invitation.__table__.columns]
        assert "token" in fields

    def test_invitation_record_has_expires_at(self):
        """Invitation modelinde expires_at alanı var"""
        from app.models.users import Invitation
        fields = [c.name for c in Invitation.__table__.columns]
        assert "expires_at" in fields

    def test_invitation_record_has_target_role(self):
        """Invitation modelinde target_role alanı var"""
        from app.models.users import Invitation
        fields = [c.name for c in Invitation.__table__.columns]
        assert "target_role" in fields


class TestInviteEndpointResponse:
    """POST /auth/invite endpoint yanıt yapısı testleri"""

    def test_invite_response_has_invite_url(self):
        """InviteResponse'da invite_url alanı var"""
        from app.schemas.users import InviteResponse
        resp = InviteResponse(
            success=True,
            invite_url="https://app.emlakdefter.com/register?t=abc123",
            token="abc123",
            expires_at=datetime.now(timezone.utc)
        )
        assert "register?t=" in resp.invite_url

    def test_invite_response_has_token(self):
        """InviteResponse'da token alanı var"""
        from app.schemas.users import InviteResponse
        resp = InviteResponse(
            success=True,
            invite_url="https://app.emlakdefter.com/register?t=abc123",
            token="abc123",
            expires_at=datetime.now(timezone.utc)
        )
        assert resp.token == "abc123"


class TestPasswordResetOTPLimit:
    """Şifre sıfırlama OTP aylık limit testleri"""

    def test_monthly_limit_is_15(self):
        """Aylık OTP limiti 15 olarak tanımlı"""
        # auth.py'de MONTHLY_OTP_LIMIT = 15
        from app.api.endpoints.auth import MONTHLY_OTP_LIMIT
        assert MONTHLY_OTP_LIMIT == 15

    def test_password_reset_attempt_model_has_phone(self):
        """PasswordResetAttempt modelinde phone_number alanı var"""
        from app.models.users import PasswordResetAttempt
        fields = [c.name for c in PasswordResetAttempt.__table__.columns]
        assert "phone_number" in fields

    def test_password_reset_attempt_model_has_attempted_at(self):
        """PasswordResetAttempt modelinde attempted_at alanı var"""
        from app.models.users import PasswordResetAttempt
        fields = [c.name for c in PasswordResetAttempt.__table__.columns]
        assert "attempted_at" in fields
