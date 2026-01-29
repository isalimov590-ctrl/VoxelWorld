from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.sql import func
from database import Base


class Achievement(Base):
    """Модель достижения"""
    __tablename__ = "achievements"
    
    id = Column(Integer, primary_key=True, index=True)
    achievement_id = Column(String(50), unique=True, nullable=False)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=False)
    icon = Column(String(255), nullable=True)
    
    # Категория: exploration, combat, building, crafting
    category = Column(String(50), nullable=False)
    
    # Редкость: common, uncommon, rare, epic, legendary
    rarity = Column(String(20), default="common")
    
    # Условия получения (JSON)
    requirements = Column(Text, nullable=True)
    
    # Награда
    reward_points = Column(Integer, default=10)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    def to_dict(self):
        return {
            "id": self.id,
            "achievement_id": self.achievement_id,
            "name": self.name,
            "description": self.description,
            "icon": self.icon,
            "category": self.category,
            "rarity": self.rarity,
            "reward_points": self.reward_points
        }


class UserAchievement(Base):
    """Модель достижения пользователя"""
    __tablename__ = "user_achievements"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    achievement_id = Column(Integer, ForeignKey("achievements.id", ondelete="CASCADE"), nullable=False)
    
    # Прогресс (0-100)
    progress = Column(Integer, default=0)
    
    # Получено ли достижение
    unlocked = Column(Boolean, default=False)
    
    # Временные метки
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    unlocked_at = Column(DateTime(timezone=True), nullable=True)
    
    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "achievement_id": self.achievement_id,
            "progress": self.progress,
            "unlocked": self.unlocked,
            "unlocked_at": self.unlocked_at.isoformat() if self.unlocked_at else None
        }
