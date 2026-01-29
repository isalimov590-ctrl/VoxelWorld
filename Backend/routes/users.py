from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from pydantic import BaseModel
from typing import Optional
from database import get_session
from models.user import User
from auth import verify_token

router = APIRouter(prefix="/users", tags=["Users"])


class UpdateProfileRequest(BaseModel):
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    skin_data: Optional[str] = None


class UpdateStatsRequest(BaseModel):
    total_playtime: Optional[int] = None
    blocks_broken: Optional[int] = None
    blocks_placed: Optional[int] = None
    distance_walked: Optional[int] = None


async def get_current_user(
    token: str,
    session: AsyncSession = Depends(get_session)
) -> User:
    """Получает текущего пользователя из токена"""
    payload = verify_token(token)
    
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
    
    user_id = int(payload.get("sub"))
    
    result = await session.execute(
        select(User).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return user


@router.get("/me")
async def get_me(
    token: str,
    session: AsyncSession = Depends(get_session)
):
    """Получает информацию о текущем пользователе"""
    user = await get_current_user(token, session)
    return user.to_dict_full()


@router.get("/{user_id}")
async def get_user(
    user_id: int,
    session: AsyncSession = Depends(get_session)
):
    """Получает информацию о пользователе по ID"""
    result = await session.execute(
        select(User).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return user.to_dict()


@router.get("/username/{username}")
async def get_user_by_username(
    username: str,
    session: AsyncSession = Depends(get_session)
):
    """Получает информацию о пользователе по имени"""
    result = await session.execute(
        select(User).where(User.username == username)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return user.to_dict()


@router.put("/me/profile")
async def update_profile(
    request: UpdateProfileRequest,
    token: str,
    session: AsyncSession = Depends(get_session)
):
    """Обновляет профиль пользователя"""
    user = await get_current_user(token, session)
    
    if request.display_name is not None:
        user.display_name = request.display_name
    
    if request.avatar_url is not None:
        user.avatar_url = request.avatar_url
    
    if request.skin_data is not None:
        user.skin_data = request.skin_data
    
    await session.commit()
    await session.refresh(user)
    
    return user.to_dict()


@router.put("/me/stats")
async def update_stats(
    request: UpdateStatsRequest,
    token: str,
    session: AsyncSession = Depends(get_session)
):
    """Обновляет статистику пользователя"""
    user = await get_current_user(token, session)
    
    if request.total_playtime is not None:
        user.total_playtime += request.total_playtime
    
    if request.blocks_broken is not None:
        user.blocks_broken += request.blocks_broken
    
    if request.blocks_placed is not None:
        user.blocks_placed += request.blocks_placed
    
    if request.distance_walked is not None:
        user.distance_walked += request.distance_walked
    
    await session.commit()
    await session.refresh(user)
    
    return user.to_dict_full()


@router.get("/search/{query}")
async def search_users(
    query: str,
    limit: int = 10,
    session: AsyncSession = Depends(get_session)
):
    """Поиск пользователей"""
    result = await session.execute(
        select(User).where(
            User.username.ilike(f"%{query}%")
        ).limit(limit)
    )
    users = result.scalars().all()
    
    return [user.to_dict() for user in users]
