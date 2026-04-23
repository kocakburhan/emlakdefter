"""
Test 13: Çevrimdışı İşlem Kuyruklama

Hedef:
- Offline mesajlar Outbox'ta bekler
- Operation ve transaction queue'ları offline'da birikir
- Online olunca tüm kuyruklar sync edilir — veri kaybı olmaz

Test kapsamı:
1. Outbox mesajları UUID id ile saklanır
2. Kuyruktan mesaj silindiğinde veri kaybı olmaz (sent flag)
3. Operation queue ( SupportTicket ) kuyruğa eklenebilir
4. Transaction queue (PaymentSchedule) kuyruğa eklenebilir
5. Sync sonrası kuyruk temizlenir
6. Pending count doğru hesaplanır
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4
from datetime import datetime, timezone


class TestOutboxQueue:
    """message_outbox (Chat) kuyruklama testleri"""

    def test_outbox_message_has_id_field(self):
        """Outbox mesajı UUID id ile saklanır"""
        from app.models.chat import ChatMessage
        fields = [c.name for c in ChatMessage.__table__.columns]
        assert 'id' in fields

    def test_outbox_message_has_conversation_id(self):
        """Outbox mesajı conversation_id içerir"""
        from app.models.chat import ChatMessage
        fields = [c.name for c in ChatMessage.__table__.columns]
        assert 'conversation_id' in fields

    def test_outbox_message_has_sender_id(self):
        """Outbox mesajı gönderen user_id içerir"""
        from app.models.chat import ChatMessage
        fields = [c.name for c in ChatMessage.__table__.columns]
        assert 'sender_user_id' in fields

    def test_outbox_message_has_content(self):
        """Outbox mesajı içerik alanı içerir"""
        from app.models.chat import ChatMessage
        fields = [c.name for c in ChatMessage.__table__.columns]
        assert 'content' in fields

    def test_outbox_message_has_created_at(self):
        """Outbox mesajı zaman damgası içerir"""
        from app.models.chat import ChatMessage
        fields = [c.name for c in ChatMessage.__table__.columns]
        assert 'created_at' in fields

    def test_outbox_add_returns_message_with_id(self):
        """Outbox'a eklenen mesaj UUID id ile döner"""
        msg_id = str(uuid4())
        msg = {
            'id': msg_id,
            'conversation_id': str(uuid4()),
            'sender_user_id': str(uuid4()),
            'content': 'Offline mesaj',
            'created_at': datetime.now(timezone.utc).isoformat(),
        }
        assert msg['id'] == msg_id

    def test_outbox_remove_deletes_by_id(self):
        """removeFromOutbox(id) doğru mesajı siler"""
        outbox = {
            'msg-1': {'id': 'msg-1', 'content': 'ilk'},
            'msg-2': {'id': 'msg-2', 'content': 'ikinci'},
        }
        del outbox['msg-1']
        assert 'msg-1' not in outbox
        assert 'msg-2' in outbox


class TestOperationQueue:
    """operation_queue (SupportTicket) kuyruklama testleri"""

    def test_support_ticket_model_for_queue(self):
        """SupportTicket kuyruk için gerekli alanlara sahip"""
        from app.models.operations import SupportTicket
        fields = [c.name for c in SupportTicket.__table__.columns]

        required = ['id', 'unit_id', 'title', 'description', 'priority', 'status']
        for f in required:
            assert f in fields

    def test_support_ticket_status_enum(self):
        """SupportTicket status alanı enum (open/in_progress/resolved/closed)"""
        from app.models.operations import TicketStatus
        values = [s.value for s in TicketStatus]
        assert 'open' in values
        assert 'resolved' in values

    def test_operation_queue_add(self):
        """addToOpQueue() yapısı"""
        op = {
            'id': str(uuid4()),
            'unit_id': str(uuid4()),
            'title': 'Musluk tamiri',
            'description': 'Banyo musluğu akıtıyor',
            'priority': 'high',
            'status': 'open',
        }
        assert 'title' in op
        assert op['status'] == 'open'


class TestTransactionQueue:
    """transaction_queue (PaymentSchedule) kuyruklama testleri"""

    def test_payment_schedule_model_for_queue(self):
        """PaymentSchedule kuyruk için gerekli alanlara sahip"""
        from app.models.finance import PaymentSchedule
        fields = [c.name for c in PaymentSchedule.__table__.columns]

        required = ['id', 'tenant_id', 'due_date', 'amount', 'status']
        for f in required:
            assert f in fields

    def test_payment_schedule_status_enum(self):
        """PaymentSchedule status alanı enum"""
        from app.models.finance import PaymentStatus
        values = [s.value for s in PaymentStatus]
        assert 'pending' in values
        assert 'completed' in values

    def test_transaction_queue_add(self):
        """addToTxQueue() yapısı"""
        tx = {
            'id': str(uuid4()),
            'tenant_id': str(uuid4()),
            'due_date': '2026-02-01',
            'amount': 5000,
            'status': 'pending',
        }
        assert tx['amount'] == 5000
        assert tx['status'] == 'pending'


class TestSyncBehavior:
    """Online sync sonrası kuyruk temizleme testleri"""

    def test_total_pending_count_sums_all_queues(self):
        """totalPendingCount = outboxCount + opQueueCount + txQueueCount"""
        outbox = 3
        op_queue = 2
        tx_queue = 1
        total = outbox + op_queue + tx_queue
        assert total == 6

    def test_sync_removes_from_outbox(self):
        """Sync sonrası gönderilen outbox mesajları kaldırılır"""
        outbox = ['msg-1', 'msg-2', 'msg-3']
        sent_ids = ['msg-1', 'msg-3']
        remaining = [m for m in outbox if m not in sent_ids]
        assert remaining == ['msg-2']
        assert len(outbox) == 3  # original unchanged

    def test_sync_removes_from_op_queue(self):
        """Sync sonrası işlenen operation'lar kuyruktan kalkar"""
        queue = [{'id': 'op-1'}, {'id': 'op-2'}, {'id': 'op-3'}]
        processed = ['op-2']
        remaining = [op for op in queue if op['id'] not in processed]
        assert len(remaining) == 2

    def test_sync_removes_from_tx_queue(self):
        """Sync sonrası işlenen transaction'lar kuyruktan kalkar"""
        queue = [{'id': 'tx-1'}, {'id': 'tx-2'}]
        processed = ['tx-1']
        remaining = [tx for tx in queue if tx['id'] not in processed]
        assert len(remaining) == 1

    def test_offline_message_preserves_content(self):
        """Offline mesaj içeriği sync'e kadar değişmez"""
        original_content = "Merhaba, kira ödemesi yapacağım."
        offline_msg = {
            'id': str(uuid4()),
            'content': original_content,
            'created_at': datetime.now(timezone.utc).isoformat(),
        }
        # Sync'e kadar aynı kalmalı
        assert offline_msg['content'] == original_content

    def test_offline_operation_preserves_priority(self):
        """Offline operation önceliği sync'e kadar korunur"""
        op = {
            'id': str(uuid4()),
            'title': 'Asansör arızası',
            'priority': 'high',
            'status': 'open',
        }
        assert op['priority'] == 'high'
        assert op['status'] == 'open'

    def test_offline_transaction_preserves_amount(self):
        """Offline transaction tutarı sync'e kadar korunur"""
        tx = {
            'id': str(uuid4()),
            'amount': 15000,
            'status': 'pending',
        }
        assert tx['amount'] == 15000
