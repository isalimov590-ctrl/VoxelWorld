from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Настройки приложения"""
    
    # Приложение
    APP_NAME: str = "VoxelWorld Backend"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = True
    
    # База данных
    DATABASE_URL: str = "postgresql+asyncpg://voxelworld:password@localhost:5432/voxelworld"
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # JWT
    SECRET_KEY: str = "your-secret-key-change-this-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # CORS
    CORS_ORIGINS: list = [
        "http://localhost",
        "http://localhost:8080",
        "http://127.0.0.1",
    ]
    
    # Сервер
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # Игровые серверы
    GAME_SERVER_SECRET: str = "game-server-secret-change-this"
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
