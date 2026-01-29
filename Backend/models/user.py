from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text
from sqlalchemy.sql import func
from database import Base


class User(Base):
    """Модель пользователя"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    
    # Профиль
    display_name = Column(String(50), nullable=True)
    avatar_url = Column(String(255), nullable=True)
    skin_data = Column(Text, nullable=True)  # JSON данные скина
    
    # Статус
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    is_banned = Column(Boolean, default=False)
    
    # Статистика
    total_playtime = Column(Integer, default=0)  # В секундах
    blocks_broken = Column(Integer, default=0)
    blocks_placed = Column(Integer, default=0)
    distance_walked = Column(Integer, default=0)
    
    # Временные метки
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    last_login = Column(DateTime(timezone=True), nullable=True)
    
    def to_dict(self):
        """Преобразует модель в словарь"""
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "display_name": self.display_name,
            "avatar_url": self.avatar_url,
            "is_active": self.is_active,
            "is_verified": self.is_verified,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "last_login": self.last_login.isoformat() if self.last_login else None
        }
    
    def to_dict_full(self):
        """Преобразует модель в полный словарь со статистикой"""
        data = self.to_dict()
        data.update({
            "stats": {
                "total_playtime": self.total_playtime,
                "blocks_broken": self.blocks_broken,
                "blocks_placed": self.blocks_placed,
                "distance_walked": self.distance_walked
            }
        })
        return data
