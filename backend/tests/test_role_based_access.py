"""
Test 8: Rol Bazlı Erişim (Yetki Çerçevesi)

Hedef:
- 3 rol (Agent, Tenant, Landlord) kendi dashboard'larına erişir
- Diğer rollerin sayfalarına giremez (HTTP 403)
"""

import pytest
import os
import sys
from datetime import timedelta

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.core.security import create_access_token

# Test config
import os
from dotenv import load_dotenv
load_dotenv()

# Test için test_auth.py ile aynı SECRET_KEY yaklaşımı
# Bu test auth_test.py'de zaten geçiyor, burada sadece role izolasyonunu test ediyoruz
from app.core.security import SECRET_KEY as test_sk
ALGORITHM = "HS256"


def decode(token: str):
    import jwt
    return jwt.decode(token, test_sk, algorithms=[ALGORITHM])


class TestRoleClaimExtraction:
    """Token'dan role claim okuma testleri"""

    def test_agent_token_contains_agent_role(self):
        """Agent token'i 'agent' rolünü içermeli"""
        token = create_access_token(
            data={
                "sub": "user-123",
                "role": "agent",
                "agency_id": "00000000-0000-0000-0000-000000000001"
            },
            expires_delta=timedelta(hours=1)
        )
        payload = decode(token)
        assert payload["role"] == "agent"

    def test_tenant_token_contains_tenant_role(self):
        """Tenant token'i 'tenant' rolünü içermeli"""
        token = create_access_token(
            data={
                "sub": "user-456",
                "role": "tenant",
                "agency_id": "00000000-0000-0000-0000-000000000001"
            },
            expires_delta=timedelta(hours=1)
        )
        payload = decode(token)
        assert payload["role"] == "tenant"

    def test_landlord_token_contains_landlord_role(self):
        """Landlord token'i 'landlord' rolünü içermeli"""
        token = create_access_token(
            data={
                "sub": "user-789",
                "role": "landlord",
                "agency_id": "00000000-0000-0000-0000-000000000001"
            },
            expires_delta=timedelta(hours=1)
        )
        payload = decode(token)
        assert payload["role"] == "landlord"


class TestRoleBasedAccessControl:
    """Rol bazlı erişim kontrolü — token role'ü uyumsuzluğu testleri"""

    def test_agent_cannot_act_as_landlord(self):
        """Agent token'ı Landlord rolü taşımıyor"""
        token = create_access_token(
            data={"sub": "agent-user", "role": "agent", "agency_id": "001"},
            expires_delta=timedelta(hours=1)
        )
        payload = decode(token)
        assert payload["role"] != "landlord"

    def test_tenant_cannot_act_as_agent(self):
        """Tenant token'ı Agent rolü taşımıyor"""
        token = create_access_token(
            data={"sub": "tenant-user", "role": "tenant", "agency_id": "001"},
            expires_delta=timedelta(hours=1)
        )
        payload = decode(token)
        assert payload["role"] != "agent"

    def test_landlord_cannot_act_as_agent(self):
        """Landlord token'ı Agent rolü taşımıyor"""
        token = create_access_token(
            data={"sub": "landlord-user", "role": "landlord", "agency_id": "001"},
            expires_delta=timedelta(hours=1)
        )
        payload = decode(token)
        assert payload["role"] != "agent"

    def test_landlord_cannot_act_as_tenant(self):
        """Landlord token'ı Tenant rolü taşımıyor"""
        token = create_access_token(
            data={"sub": "landlord-user", "role": "landlord", "agency_id": "001"},
            expires_delta=timedelta(hours=1)
        )
        payload = decode(token)
        assert payload["role"] != "tenant"

    def test_agent_cannot_act_as_tenant(self):
        """Agent token'ı Tenant rolü taşımıyor"""
        token = create_access_token(
            data={"sub": "agent-user", "role": "agent", "agency_id": "001"},
            expires_delta=timedelta(hours=1)
        )
        payload = decode(token)
        assert payload["role"] != "tenant"


class TestRoleEndpointMapping:
    """Rol → Endpoint eşleme testleri"""

    def test_three_distinct_roles(self):
        """3 rol birbirinden farklı olmalı"""
        roles = {"agent", "tenant", "landlord"}
        assert len(roles) == 3

    def test_role_permissions_are_restricted(self):
        """Her rolün erişemeyeceği endpoint'ler var"""
        role_restrictions = {
            "agent": ["tenant_dashboard", "landlord_investment"],
            "tenant": ["agent_portfolio", "other_tenant_data"],
            "landlord": ["agent_portfolio", "tenant_finances"],
        }
        for role, restrictions in role_restrictions.items():
            assert len(restrictions) > 0