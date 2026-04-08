import os
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from dotenv import load_dotenv

load_dotenv()

# PRD'ye uygun PostgreSQL veritabanı bağlantı URI'si
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://emlakdefteri_user:emlakdefteri_password@localhost:5432/emlakdefteri")

# Asenkron Motorun ve Havuzun Kurulması
engine = create_async_engine(
    DATABASE_URL,
    echo=False,  # Geliştirme sürecinde logları görmek için True yapılabilir
    future=True,
    pool_pre_ping=True,
    pool_recycle=3600
)

# İstek başına kullanılacak Asenkron Oturum Oluşturucu
AsyncSessionLocal = async_sessionmaker(
    engine,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

# Dependency Injection ile FastAPI uç noktalarına (endpoints) dağıtılacak db jeneratörü
async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
