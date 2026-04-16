import os
import json
from fastapi import HTTPException
import google.generativeai as genai

# Gemini API Yapılandırıcısı
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
else:
    raise RuntimeError("GEMINI_API_KEY .env dosyasında tanımlı değil!")

# PRD Madde 3.1.5'in direktifi: Multimodal yetenekli Flash Modeli
MODEL_NAME = "gemini-2.5-flash"


def process_bank_statement(pdf_text: str) -> list[dict]:
    """
    pdfplumber ile çıkarılan ham metin → Gemini 2.5 Flash → JSON array.

    Akış:
      finance_service.extract_text_from_pdf()  → ham metin (pdfplumber)
      → process_bank_statement()              → Gemini'ye gönder
      → JSON listesi                          → Kiracı eşleştirme
    """
    prompt = f"""
Sen gelişmiş bir emlak muhasebesi yapay zeka ajanısın. Emlak şirketinin
banka ekstresinden alınmış yapılandırılmamış metin bloklarını inceleyip,
gelen ödemeleri tekdüze, eksiksiz bir JSON listesi olarak çıkarman gerekiyor.

Görevin YALNIZCA GELİR aktarımlarını bulup, bu şemaya sadık kalarak geri dön:
[
    {{
        "sender_name": "Gönderen Adı Soyadı",
        "date": "İşlem Tarihi (YYYY-MM-DD)",
        "amount": "Tutar (Örn: 15000)",
        "description": "Açıklama",
        "category": "rent | dues | utility | other"
    }}
]

Kategori kuralları:
* description'da "kira", "kira ödemesi", "kira havalesi" geçiyorsa → "rent"
* description'da "aidat", "aidat ödemesi", "site bakım" geçiyorsa → "dues"
* description'da "fatura", "elektrik", "su", "doğalgaz", "internet", "telefon" geçiyorsa → "utility"
* Yukarıdakilerin hiçbiri değilse → "other"

Kurallar:
* Yalnızca [ ve ] barındıran salt JSON metni döndür (```json taglari kullanma, doğrudan '[' ile başla).
* Banka ücretleri, EFT kesintileri, ofis giderleri gibi eksi (-) paraları YOK SAY.
* Sadece Türk Lirası (TL) işlemleri dahil et.
* Gönderen adı soyadı eksik veya belirsizse dahil etme.

Çözümlenmesi İstenen Ham Banka Metni:
{pdf_text[:15000]}
"""

    try:
        model = genai.GenerativeModel(
            model_name=MODEL_NAME,
            system_instruction="Saf ve hatasız JSON formatından şaşmayan deterministik bir muhasebecisin."
        )
        response = model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(
                temperature=0.1,  # Hafifçe rastgele — muhasebe hassas ama sıfır değil
                response_mime_type="application/json",
            ),
        )

        parsed_json = json.loads(response.text)
        return parsed_json

    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="Gemini okunabilir bir JSON yanıtı üretemedi.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"LLM Analiz Başarısızlığı: {str(e)}")
