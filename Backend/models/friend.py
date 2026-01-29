from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.sql import func
from database import Base


class Friendship(Base):
    """Модель дружбы между пользователями"""
    __tablename__ = "friendships"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    friend_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Статус: pending, accepted, blocked
    status = Column(String(20), default="pending", nullable=False)
    
    # Кто инициировал запрос
    initiated_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Временные метки
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Уникальное ограничение для пары пользователей
    __table_args__ = (
        UniqueConstraint('user_id', 'friend_id', name='unique_friendship'),
    )
    
    def to_dict(self):
        """Преобразует модель в словарь"""
        return {
            "id": self.id,
            "user_id": self.user_id,
            "friend_id": self.friend_id,
            "status": self.status,
            "initiated_by": self.initiated_by,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
