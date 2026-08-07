"""
Shema database using the SQLAlchemy ORM
All updates via Alembic migrations
"""

import os

from dotenv import load_dotenv
from sqlalchemy import (Column, String, Integer, create_engine)
from sqlalchemy.orm import declarative_base


load_dotenv()
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "crypto_db")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "password")

DATABASEURL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}"

engine = create_engine(DATABASEURL)
Base = declarative_base()


class BaseModel(Base):
    """Parent class on Base class"""

    __abstract__ = True

    def __repr__(self):
        """Method return information about object"""
        return f"{self.__class__.__name__} id:{self.id}"


class MappingTB(BaseModel):
    """The class describes the database table catalogs of available crypto"""

    __tablename__ = "cryptomap"
    __table_args__ = {"comment": "Stores item of crypto symbol"}

    id = Column(Integer, primary_key=True, autoincrement=True)
    symbol = Column(String(5), nullable=False)
    name = Column(String(20), nullable=False)


def init_db():
    """Inicialise new database"""
    Base.metadata.create_all(engine)


if __name__ == "__main__":
    init_db()
