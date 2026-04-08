import pdfplumber
import io
import difflib
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Dict

from app.core.llm_processor import process_bank_statement
from app.models.tenants import Tenant, ContractStatus
from app.models.users import User
from app.models.finance import PaymentSchedule, PaymentStatus, FinancialTransaction, TransactionCategory, TransactionType
from datetime import datetime

async def extract_text_from_pdf(pdf_bytes: bytes) -> str:
    """Yazılım Mimarisi (Faz 5): PDF dosyasını tarayıp OCR yapmadan salt String çıkartır."""
    text_content = []
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            extracted = page.extract_text()
            if extracted:
                text_content.append(extracted)
    return "\n".join(text_content)

async def process_and_match_statement(db: AsyncSession, agency_id: str, pdf_bytes: bytes) -> Dict:
    """PDF -> LLM Analizi -> Makine Öğrenmesi Dışı Difflib İsim Kıyaslaması -> SQL Mühürü"""
    
    # 1. Metin Çıkarımı
    raw_text = await extract_text_from_pdf(pdf_bytes)
    if len(raw_text) < 20:
        return {"success": False, "message": "Gönderdiğiniz Dekont okunamıyor veya resim formatında."}

    # 2. LLM Prompting
    ai_transactions = process_bank_statement(raw_text)
    if not ai_transactions:
        return {"success": True, "total_found": 0, "matched_results": []}

    # 3. İzole Edilmiş 'Aktif Kiracılar' Havuzu Çekilir
    stmt = (
        select(Tenant, User.full_name)
        .join(User, Tenant.user_id == User.id)
        .where(Tenant.agency_id == agency_id, Tenant.status == ContractStatus.active)
    )
    result = await db.execute(stmt)
    db_tenants_rows = result.all()

    matched_results = []
    
    # 4. Deterministik (Değişmez) Karar Ağacı Eşleştirmesi!
    for ai_tx in ai_transactions:
        sender_name = str(ai_tx.get("sender_name", "")).strip().replace("İ", "i").lower()
        amount_paid = float(ai_tx.get("amount", 0.0))
        tx_date_str = ai_tx.get("date", str(datetime.now().date()))
        
        best_match_tenant = None
        best_score = 0.0
        
        # Levenshtein / SequenceMatcher: %82 tolerans eşiği (Ahmet YILMAZ != Ahmt Ylmz)
        for t_obj, user_name in db_tenants_rows:
            db_name = str(user_name).strip().replace("İ", "i").lower()
            score = difflib.SequenceMatcher(None, sender_name, db_name).ratio()
            
            if score > 0.82 and score > best_score:
                best_score = score
                best_match_tenant = t_obj
                
        is_matched = False
        payment_status_text = "Bulunamadı (Askıda Kaldı)"
        
        # Kiracıyı eşleştirmeyi başardık!
        if best_match_tenant:
             is_matched = True
             
             # Kiracının sisteme yüklenmiş PENDING bekleyen en eski borcunu bul (First In First Out)
             ps_stmt = select(PaymentSchedule).where(
                 PaymentSchedule.tenant_id == best_match_tenant.id,
                 PaymentSchedule.status == PaymentStatus.pending
             ).order_by(PaymentSchedule.due_date.asc())
             ps_result = await db.execute(ps_stmt)
             debts = ps_result.scalars().all()
             
             if debts:
                 target_debt = debts[0]
                 
                 # PARAYI BÖL VE KÜMELE
                 if amount_paid >= target_debt.amount:
                      target_debt.status = PaymentStatus.completed
                      target_debt.paid_amount = target_debt.amount
                      payment_status_text = f"Tamamı Ödendi ({amount_paid} ₺)"
                 else:
                      target_debt.status = PaymentStatus.partial
                      target_debt.paid_amount += amount_paid
                      payment_status_text = f"Eksik Tahsilat! (İçerideKalan: {target_debt.amount - target_debt.paid_amount} ₺)"
                      
                 # Kesinleşmiş işlemi Finans (Ana Kasa) tablomuza tescille
                 new_tx = FinancialTransaction(
                      agency_id=best_match_tenant.agency_id,
                      tenant_id=best_match_tenant.id,
                      unit_id=best_match_tenant.unit_id,
                      type=TransactionType.income,
                      category=target_debt.category,
                      amount=amount_paid,
                      transaction_date=datetime.strptime(tx_date_str, "%Y-%m-%d").date() if "-" in tx_date_str else datetime.now().date(),
                      description=f"[Otonom AI Eşleşmesi] Not: {ai_tx.get('description', '')}"
                 )
                 db.add(new_tx)
             else:
                 payment_status_text = "Bize Borcu Yoktu (Otomatik Avans Kasa aktarımı iptal edildi)"
                 
        matched_results.append({
             "yapay_zeka_ciktisi": ai_tx,
             "is_matched": is_matched,
             "matched_tenant_id": str(best_match_tenant.id) if best_match_tenant else None,
             "match_decision_score": best_score,
             "payment_evaluation": payment_status_text
        })

    await db.commit() # Tüm Borç kapamalarını ve JSON okumalarını diske kalıcı yazdırıyoruz!

    return {
        "success": True,
        "total_found": len(ai_transactions),
        "matched_results": matched_results
    }
