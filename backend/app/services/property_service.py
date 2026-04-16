import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.properties import Property, PropertyUnit, PropertyType
from app.schemas.properties import PropertyCreate
from fastapi import HTTPException

async def create_property_with_autonomous_units(db: AsyncSession, agency_id: str, prop_in: PropertyCreate) -> Property:
    """
    Sistemin en ağır işçiliğini yapan Servis Katmanı. PRD Madde 4.1.2.
    Emlakçının Pydantic validasyonundan geçen isteğini alır:
    Eğer 'building' seçilmişse başlangıç/bitiş katına göre hesap yapıp yüzlerce 
    PropertyUnit bağımsız bölümünü otonom olarak (1 milisaniyede) DB Bulk Insert'e atar.
    """
    # 1. Ana Çatı Mülkün (Binanın/Arsanın) Veritabanına Yazılması
    new_property = Property(
        id=uuid.uuid4(),
        agency_id=uuid.UUID(agency_id),
        name=prop_in.name,
        type=prop_in.type,
        address=prop_in.address,
        central_dues=prop_in.central_dues,  
        features=prop_in.features or {}
    )
    
    db.add(new_property)
    await db.flush() # Property ID'yi dairelere yapıştıracağımız için anında cache'e flushlıyoruz
    
    units_to_create = []
    
    # 2. Otonom Generative Loop (Apartmanlar İçin)
    if prop_in.type == PropertyType.apartment_complex:
        if prop_in.start_floor is None or prop_in.end_floor is None or not prop_in.units_per_floor:
            raise HTTPException(status_code=400, detail="Bir 'apartment_complex' eklerken start_floor, end_floor ve units_per_floor zorunludur.")
            
        if prop_in.start_floor > prop_in.end_floor:
            raise HTTPException(status_code=400, detail="Başlangıç katı, bitiş katından büyük fiziksel bir mantıksızlık içeriyor.")
        
        calculated_total_units = 0
        door_counter = 1
        
        # Matematiksel Loop: Katlar X O Katta Bulunan Daire Hareketi
        for floor_num in range(prop_in.start_floor, prop_in.end_floor + 1):
            for _ in range(prop_in.units_per_floor):
                unit = PropertyUnit(
                    agency_id=new_property.agency_id,
                    property_id=new_property.id,
                    door_number=str(door_counter),
                    floor=str(floor_num),
                    dues_amount=new_property.central_dues # Ana binanın aidatını %100 miras aldı
                )
                units_to_create.append(unit)
                door_counter += 1
                calculated_total_units += 1
                
        new_property.total_units = calculated_total_units
        db.add_all(units_to_create) # Toplu enjekte (Hiçbir bekletme olmaksızın)
        
    # 3. Tekil Varlık Ataması (Müstakil / Arsalar)
    elif prop_in.type == PropertyType.standalone_house:
        # Arsa vb. mantıksal olarak içinde 1 adet görünmez bağımsız bölüme sahiptir
        unit = PropertyUnit(
            agency_id=new_property.agency_id,
            property_id=new_property.id,
            door_number="1", 
            floor="Zemin",
            dues_amount=new_property.central_dues
        )
        new_property.total_units = 1
        db.add(unit)
    else:
         raise HTTPException(status_code=400, detail="Tanımsız veya hatalı mülk tipi isteği algılandı.")
         
    await db.commit() # Database'e işlemi kilitle
    await db.refresh(new_property)
    return new_property
