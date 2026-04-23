import os
import json
from fastapi import HTTPException

# Yeni google-genai SDK — eski google.generativeai yerine (deprecated)
from google import genai
from google.genai import types

# Gemini API Yapılandırıcısı
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY .env dosyasında tanımlı değil!")

# İstemci — global singleton
_client = genai.Client(api_key=GEMINI_API_KEY)

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
        response = _client.models.generate_content(
            model=MODEL_NAME,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction="Saf ve hatasız JSON formatından şaşmayan deterministik bir muhasebecisin.",
                temperature=0.1,
                response_mime_type="application/json",
            ),
        )

        parsed_json = json.loads(response.text)
        return parsed_json

    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="Gemini okunabilir bir JSON yanıtı üretemedi.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"LLM Analiz Başarısızlığı: {str(e)}")


def process_bank_statement_from_pdf_bytes(pdf_bytes: bytes) -> list[dict]:
    """
    Scanned PDF'ler için multimodal yaklaşım.
    pdfplumber yeterli text çıkaramadığında bu fonksiyon çağrılır.
    Gemini 2.5 Flash PDF bytes'i direkt okuyabilir (OCR yapmadan).

    Not: Büyük PDF'ler için her sayfa ayrı işlenir (timeout önleme).
    """
    import fitz

    prompt = """
Sen gelişmiş bir emlak muhasebesi yapay zeka ajanısın. Bir banka dekontu sayfasını inceleyip,
gelen ödemeleri tekdüze, eksiksiz bir JSON listesi olarak çıkarman gerekiyor.

Görevin YALNIZCA GELİR aktarımlarını bulup, bu şemaya sadık kalarak geri dön:
[
    {{
        "sender_name": "Gönderen Adı Soyadı",
        "date": "İşlem Tarihi (GG.AA.YYYY veya YYYY-MM-DD)",
        "amount": "Tutar (Sayı, Örn: 15000)",
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
* Yalnızca [ ile başlayan salt JSON döndür (```json taglari kullanma).
* Eksi (-) paraları YOK SAY.
* Sadece Türk Lirası (TL) işlemleri dahil et.
* Gönderen adı eksik veya belirsizse dahil etme.

Eğer bu sayfada okunabilir işlem yoksa boş liste [] döndür.
"""

    all_transactions = []

    try:
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        # Sadece ilk 3 sayfayı işle (test için yeterli, hızlı)
        max_pages_to_process = 3
        num_pages = len(doc)

        for page_num in range(min(max_pages_to_process, num_pages)):
            page = doc[page_num]

            # Her sayfayı küçük JPG olarak çıkar (kalite 60, 1x zoom = ~100KB)
            mat = fitz.Matrix(1, 1)
            pix = page.get_pixmap(matrix=mat, alpha=False)
            img_bytes = pix.tobytes("jpeg")

            # Boş sayfa kontrolü
            if len(img_bytes) < 5000:  # Çok küçük görsel = muhtemelen boş
                continue

            pdf_part = types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg")

            response = _client.models.generate_content(
                model=MODEL_NAME,
                contents=[types.Content(parts=[pdf_part]), prompt],
                config=types.GenerateContentConfig(
                    system_instruction="Saf ve hatasız JSON formatından şaşmayan deterministik bir muhasebecisin.",
                    temperature=0.1,
                    response_mime_type="application/json",
                ),
            )

            try:
                transactions = json.loads(response.text)
                if isinstance(transactions, list):
                    all_transactions.extend(transactions)
            except json.JSONDecodeError:
                continue

        doc.close()
        return all_transactions

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"LLM Multimodal Analiz Başarısızlığı: {str(e)}")
