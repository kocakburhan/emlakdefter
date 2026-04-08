import os
import json
import google.generativeai as genai
from fastapi import HTTPException

# Gemini API Yapılandırıcısı (Elinizdeki asıl API_KEY'i .env dosyanıza atmalısınız!)
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
else:
    print("[WARN] GEMINI_API_KEY çevresel değişkende bulunamadı! Tahsilat PDF okuyucu AI çökecektir.")

# PRD Madde 3.1.5'in direktifi: Multimodal yetenekli Flash Modeli
MODEL_NAME = "gemini-2.5-flash"

def process_bank_statement(pdf_text: str) -> list[dict]:
    """
    Sırf karmaşadan oluşan uzun bir Metin bloğunu (banka ekstresi pdf'i), MakulJSON dizisine çevirir.
    Prompt Engineering metotları ile "Halüsinasyon" sıfıra indirilmeye çalışılır.
    """
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="Canlı Gemini API Anahtarı (.env) eksik.")
        
    prompt = f"""
    Sen gelişmiş bir emlak muhasebesi yapay zeka ajanısın. Emlak şirketinin
    banka ekstresinden alınmış yapılandırılmamış metin bloklarını inceleyip, 
    gelen "Kira ve Aidat Havalelerini" tekdüze, eksiksiz bir JSON listesi olarak çıkarman gerekiyor.

    Görevin YALNIZCA GELİR (İbrahim Yılmaz: +15.000) aktarımlarını bulup, bu şemaya sadık kalarak geri dönmektir:
    [
        {{
            "sender_name": "Gönderen Adı Soyadı",
            "date": "İşlem Tarihi (YYYY-MM-DD)",
            "amount": "Tutar (Örn: 15000.5)",
            "description": "Kiracı tarafından yazılan dekont notu"
        }}
    ]

    * Yalnızca [ ve ] barındıran salt JSON metni döndür (```json taglari bile kullanma, doğrudan '[' ile başla). 
    * Banka ücretleri, EFT kesintileri, ofis fatura giderleri gibi eksi (-) paraları kesinlikle YOK SAY.
    
    Çözümlenmesi İstenen Ham Banka Metni (Plumber Extract):
    {pdf_text[:12000]} 
    """

    try:
        model = genai.GenerativeModel(
            model_name=MODEL_NAME,
            system_instruction="Saf ve hatasız JSON formatından şaşmayan deterministik bir muhasebecisin."
        )
        response = model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(
                temperature=0.0, # LLM'i katı deterministik kılıyoruz (Rastgeleliğe yer yok!)
                response_mime_type="application/json",
            ),
        )
        
        # Salt Metinden Dictionary'e geçiş
        parsed_json = json.loads(response.text)
        return parsed_json
        
    except json.JSONDecodeError:
         raise HTTPException(status_code=500, detail="Otonom YZ (Gemini) okunabilir bir JSON yanıtı üretemedi.")
    except Exception as e:
         raise HTTPException(status_code=500, detail=f"LLM Analiz Başarısızlığı: {str(e)}")
