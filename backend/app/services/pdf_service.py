"""
PDF Report Service — PRD §4.1.6, §4.1.10-E
reportlab tabanlı profesyonel PDF raporu üretir (logo, tarih, logolu).
"""
import io
from datetime import date, datetime
from typing import List, Dict, Any, Optional

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, KeepTogether,
)
from reportlab.lib.enums import TA_RIGHT, TA_CENTER, TA_LEFT


# ─── Renkler ────────────────────────────────────────────────────────────────
DARK_BG = colors.HexColor("#1A1A1A")
ACCENT = colors.HexColor("#5B8DEF")
SUCCESS = colors.HexColor("#6B8E6B")
WARNING = colors.HexColor("#ED6C02")
ERROR = colors.HexColor("#AD7B7B")
TEXT_DARK = colors.HexColor("#333333")
TEXT_LIGHT = colors.HexColor("#888888")
ROW_ALT = colors.HexColor("#F5F5F5")
HEADER_BG = colors.HexColor("#3D3D3D")


def _styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle("title", fontName="Helvetica-Bold", fontSize=18,
                                textColor=TEXT_DARK, spaceAfter=4),
        "subtitle": ParagraphStyle("subtitle", fontName="Helvetica", fontSize=10,
                                   textColor=TEXT_LIGHT, spaceAfter=2),
        "section": ParagraphStyle("section", fontName="Helvetica-Bold", fontSize=12,
                                  textColor=ACCENT, spaceAfter=6, spaceBefore=14),
        "body": ParagraphStyle("body", fontName="Helvetica", fontSize=9, textColor=TEXT_DARK),
        "money": ParagraphStyle("money", fontName="Helvetica-Bold", fontSize=9, textColor=TEXT_DARK,
                                alignment=TA_RIGHT),
        "header": ParagraphStyle("header", fontName="Helvetica-Bold", fontSize=9,
                                  textColor=colors.white, alignment=TA_CENTER),
        "kpi_label": ParagraphStyle("kpi_label", fontName="Helvetica", fontSize=8,
                                    textColor=TEXT_LIGHT),
        "kpi_value": ParagraphStyle("kpi_value", fontName="Helvetica-Bold", fontSize=16,
                                      textColor=ACCENT),
        "footer": ParagraphStyle("footer", fontName="Helvetica", fontSize=7,
                                  textColor=TEXT_LIGHT, alignment=TA_CENTER),
    }


def _page_template(canvas, doc):
    """PDF sayfa header/footer."""
    canvas.saveState()
    # Footer
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(TEXT_LIGHT)
    canvas.drawString(20 * mm, 12 * mm, f"Emlakdefter — {date.today().strftime('%d.%m.%Y')}")
    canvas.drawRightString(190 * mm, 12 * mm, f"Sayfa {doc.page}")
    # Header bar
    canvas.setFillColor(ACCENT)
    canvas.rect(0, 270 * mm, 210 * mm, 5 * mm, fill=1, stroke=0)
    canvas.restoreState()


def _money_fmt(val: Any) -> str:
    try:
        return f"₺{float(val):,.0f}".replace(",", ".")
    except (TypeError, ValueError):
        return "—"


# ─── BI Analytics PDF ──────────────────────────────────────────────────────

def build_bi_pdf(dashboard_data: Dict[str, Any], agency_name: str = "") -> bytes:
    """
    BI Analytics PDF raporu — PRD §4.1.10-E.
    Çok bölümlü: Özet | Doluluk | Finansal | Tahsilat
    """
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        topMargin=25 * mm,
        bottomMargin=20 * mm,
        title=f"BI Rapor — {agency_name}",
        author="Emlakdefter",
    )

    styles = _styles()
    story = []

    # ── Kapak ──────────────────────────────────────────────────────────────
    story.append(Spacer(1, 10 * mm))
    story.append(Paragraph(agency_name or "Emlakdefter", styles["title"]))
    story.append(Paragraph("BI Analytics Raporu", ParagraphStyle(
        "bigsub", fontName="Helvetica-Bold", fontSize=24, textColor=ACCENT, spaceAfter=6)))
    story.append(Paragraph(f"Tarih: {date.today().strftime('%d.%m.%Y')} | "
                              f"Dönem: Son 12 Ay", styles["subtitle"]))
    story.append(Spacer(1, 6 * mm))
    story.append(HRFlowable(width="100%", thickness=2, color=ACCENT))
    story.append(Spacer(1, 10 * mm))

    # ── KPI Özet Kartları ─────────────────────────────────────────────────
    kpis = dashboard_data.get("kpis", {})
    kpi_data = [
        ("Toplam Mülk", kpis.get("total_properties", 0), ACCENT),
        ("Doluluk", f"%{kpis.get('occupancy_rate', 0):.1f}", SUCCESS),
        ("Aktif Kiracı", kpis.get("active_tenants", 0), ACCENT),
        ("Bekleyen", _money_fmt(kpis.get("pending_this_month", 0)), WARNING),
    ]
    kpi_cells = []
    for label, value, color in kpi_data:
        kpi_cells.append([
            Paragraph(str(value), ParagraphStyle("v", fontName="Helvetica-Bold",
                                                  fontSize=18, textColor=color, alignment=TA_CENTER)),
            Paragraph(label, styles["kpi_label"]),
        ])
    kpi_table = Table([kpi_cells[0], kpi_cells[1], kpi_cells[2], kpi_cells[3]],
                       colWidths=[47 * mm] * 4)
    kpi_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), ROW_ALT),
        ("ROUNDEDCORNERS", [8, 8, 8, 8]),
        ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E0E0E0")),
        ("BOX", (0, 0), (-1, -1), 1, colors.HexColor("#E0E0E0")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    story.append(kpi_table)
    story.append(Spacer(1, 12 * mm))

    # ── Doluluk Trend ─────────────────────────────────────────────────────
    story.append(Paragraph("Doluluk Trendi", styles["section"]))
    trend = dashboard_data.get("occupancy_trend", [])
    if trend:
        t_data = [[Paragraph("Ay", styles["header"]),
                   Paragraph("Doluluk (%)", styles["header"])]]
        for item in trend[-12:]:
            t_data.append([
                Paragraph(item.get("month", ""), styles["body"]),
                Paragraph(f"%{item.get('occupancy_rate', 0):.1f}", styles["money"]),
            ])
        t = Table(t_data, colWidths=[130 * mm, 50 * mm])
        t.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), HEADER_BG),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, ROW_ALT]),
            ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#E0E0E0")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("TOPPADDING", (0, 0), (-1, -1), 5),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ("ALIGN", (1, 0), (1, -1), "RIGHT"),
        ]))
        story.append(t)
    else:
        story.append(Paragraph("Veri mevcut değil.", styles["body"]))

    story.append(Spacer(1, 8 * mm))

    # ── Finansal Özet ─────────────────────────────────────────────────────
    story.append(Paragraph("Yıllık Finansal Özet", styles["section"]))
    fin = dashboard_data.get("financial_annual", {})
    monthly = fin.get("monthly_breakdown", [])[-12:]

    f_data = [[Paragraph("Ay", styles["header"]),
               Paragraph("Gelir", styles["header"]),
               Paragraph("Gider", styles["header"]),
               Paragraph("Net", styles["header"])]]
    for m in monthly:
        net = m.get("net_balance", 0)
        net_color = SUCCESS if net >= 0 else ERROR
        f_data.append([
            Paragraph(m.get("month", ""), styles["body"]),
            Paragraph(_money_fmt(m.get("total_income", 0)), styles["money"]),
            Paragraph(_money_fmt(m.get("total_expense", 0)), styles["money"]),
            Paragraph(_money_fmt(net),
                     ParagraphStyle("net", fontName="Helvetica-Bold", fontSize=9,
                                    textColor=net_color, alignment=TA_RIGHT)),
        ])

    f_table = Table(f_data, colWidths=[45 * mm, 45 * mm, 45 * mm, 45 * mm])
    f_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), HEADER_BG),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, ROW_ALT]),
        ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#E0E0E0")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("ALIGN", (1, 0), (-1, -1), "RIGHT"),
    ]))
    story.append(f_table)
    story.append(Spacer(1, 8 * mm))

    # ── Tahsilat Performans ───────────────────────────────────────────────
    story.append(Paragraph("Tahsilat Performansı", styles["section"]))
    coll = dashboard_data.get("collection", {})
    coll_items = coll.get("monthly_rates", [])[-12:] if isinstance(coll, dict) else []

    c_data = [[Paragraph("Ay", styles["header"]),
               Paragraph("Beklenen", styles["header"]),
               Paragraph("Tahsilat", styles["header"]),
               Paragraph("Oran", styles["header"])]]
    for item in coll_items:
        rate = item.get("collection_rate_percent", 0)
        rate_color = SUCCESS if rate >= 80 else (WARNING if rate >= 50 else ERROR)
        c_data.append([
            Paragraph(item.get("month", ""), styles["body"]),
            Paragraph(_money_fmt(item.get("expected_amount", 0)), styles["money"]),
            Paragraph(_money_fmt(item.get("collected_amount", 0)), styles["money"]),
            Paragraph(f"%{rate:.0f}", ParagraphStyle("rate", fontName="Helvetica-Bold",
                                                       fontSize=9, textColor=rate_color,
                                                       alignment=TA_RIGHT)),
        ])

    if c_data:
        c_table = Table(c_data, colWidths=[45 * mm, 45 * mm, 45 * mm, 45 * mm])
        c_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), HEADER_BG),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, ROW_ALT]),
            ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#E0E0E0")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("TOPPADDING", (0, 0), (-1, -1), 5),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ("ALIGN", (1, 0), (-1, -1), "RIGHT"),
        ]))
        story.append(c_table)
    else:
        story.append(Paragraph("Veri mevcut değil.", styles["body"]))

    # ── Footer note ─────────────────────────────────────────────────────
    story.append(Spacer(1, 10 * mm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#E0E0E0")))
    story.append(Spacer(1, 3 * mm))
    story.append(Paragraph(
        "Bu rapor Emlakdefter tarafından otomatik olarak oluşturulmuştur. "
        "Ev sahipleri ve ortaklar ile paylaşılabilir.",
        styles["footer"]))

    doc.build(story, onFirstPage=_page_template, onLaterPages=_page_template)
    buf.seek(0)
    return buf.getvalue()


# ─── Finansal Rapor PDF ───────────────────────────────────────────────────

def build_finance_pdf(transactions: List[Dict[str, Any]], agency_name: str = "",
                      start_date: Optional[date] = None, end_date: Optional[date] = None) -> bytes:
    """
    Finansal işlemler PDF raporu — PRD §4.1.6.
    Gelir-gider dökümü, tarih aralığına göre.
    """
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        topMargin=25 * mm,
        bottomMargin=20 * mm,
        title=f"Finansal Rapor — {agency_name}",
        author="Emlakdefter",
    )

    styles = _styles()
    story = []

    # ── Header ────────────────────────────────────────────────────────────
    story.append(Spacer(1, 6 * mm))
    date_range = ""
    if start_date:
        date_range += f"{start_date.strftime('%d.%m.%Y')}"
    if end_date:
        date_range += f" — {end_date.strftime('%d.%m.%Y')}"
    elif date_range == "":
        date_range = "Tüm Zamanlar"

    story.append(Paragraph(agency_name or "Emlakdefter", styles["title"]))
    story.append(Paragraph(f"Finansal Rapor — {date_range}", ParagraphStyle(
        "bigsub2", fontName="Helvetica-Bold", fontSize=14, textColor=ACCENT, spaceAfter=4)))
    story.append(Paragraph(f"Rapor Tarihi: {date.today().strftime('%d.%m.%Y')}", styles["subtitle"]))
    story.append(HRFlowable(width="100%", thickness=2, color=ACCENT))
    story.append(Spacer(1, 8 * mm))

    # ── Özet ─────────────────────────────────────────────────────────────
    total_income = sum(t.get("amount", 0) for t in transactions if t.get("type") == "income")
    total_expense = sum(t.get("amount", 0) for t in transactions if t.get("type") == "expense")
    net = total_income - total_expense

    summary_data = [
        [Paragraph("Toplam Gelir", styles["body"]),
         Paragraph(_money_fmt(total_income), ParagraphStyle("sum_g", fontName="Helvetica-Bold",
                                                            fontSize=12, textColor=SUCCESS, alignment=TA_RIGHT))],
        [Paragraph("Toplam Gider", styles["body"]),
         Paragraph(_money_fmt(total_expense), ParagraphStyle("sum_e", fontName="Helvetica-Bold",
                                                            fontSize=12, textColor=ERROR, alignment=TA_RIGHT))],
        [Paragraph("Net Denge", ParagraphStyle("net_l", fontName="Helvetica-Bold", fontSize=11,
                                               textColor=TEXT_DARK)),
         Paragraph(_money_fmt(net), ParagraphStyle("sum_n", fontName="Helvetica-Bold",
                                                   fontSize=14,
                                                   textColor=SUCCESS if net >= 0 else ERROR,
                                                   alignment=TA_RIGHT))],
    ]
    sum_table = Table(summary_data, colWidths=[140 * mm, 50 * mm])
    sum_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), ROW_ALT),
        ("BOX", (0, 0), (-1, -1), 1, colors.HexColor("#E0E0E0")),
        ("LINEBELOW", (0, 0), (-1, 1), 0.5, colors.HexColor("#E0E0E0")),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story.append(sum_table)
    story.append(Spacer(1, 10 * mm))

    # ── İşlem Tablosu ────────────────────────────────────────────────────
    story.append(Paragraph(f"İşlem Detayı ({len(transactions)} adet)", styles["section"]))

    tx_data = [[
        Paragraph("Tarih", styles["header"]),
        Paragraph("Açıklama", styles["header"]),
        Paragraph("Kategori", styles["header"]),
        Paragraph("Tür", styles["header"]),
        Paragraph("Tutar", styles["header"]),
    ]]

    for tx in transactions:
        tx_type = tx.get("type", "")
        amount = tx.get("amount", 0)
        type_label = "Gelir" if tx_type == "income" else ("Gider" if tx_type == "expense" else tx_type)
        amount_str = _money_fmt(amount) if tx_type == "income" else f"({_money_fmt(amount)})"
        amount_style = ParagraphStyle("am_g", fontName="Helvetica-Bold", fontSize=9,
                                      textColor=SUCCESS if tx_type == "income" else ERROR,
                                      alignment=TA_RIGHT)
        tx_date = tx.get("transaction_date")
        if isinstance(tx_date, str):
            try:
                tx_date = datetime.fromisoformat(tx_date.replace("Z", "+00:00")).strftime("%d.%m.%Y")
            except Exception:
                tx_date = tx_date[:10] if tx_date else ""
        elif hasattr(tx_date, "strftime"):
            tx_date = tx_date.strftime("%d.%m.%Y")
        else:
            tx_date = ""

        tx_data.append([
            Paragraph(tx_date, styles["body"]),
            Paragraph(tx.get("description", "") or tx.get("note", "") or "—", styles["body"]),
            Paragraph(tx.get("category", ""), styles["body"]),
            Paragraph(type_label, styles["body"]),
            Paragraph(amount_str, amount_style),
        ])

    tx_table = Table(tx_data, colWidths=[28 * mm, 60 * mm, 30 * mm, 22 * mm, 40 * mm])
    tx_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), HEADER_BG),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 8),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, ROW_ALT]),
        ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#E0E0E0")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
    ]))
    story.append(tx_table)

    story.append(Spacer(1, 10 * mm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#E0E0E0")))
    story.append(Spacer(1, 3 * mm))
    story.append(Paragraph(
        "Bu rapor Emlakdefter tarafından otomatik olarak oluşturulmuştur.",
        styles["footer"]))

    doc.build(story, onFirstPage=_page_template, onLaterPages=_page_template)
    buf.seek(0)
    return buf.getvalue()
