from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from pydantic import BaseModel
from database import get_session
from models.friend import Friendship
from models.user import User
from routes.users import get_current_user

router = APIRouter(prefix="/friends", tags=["Friends"])


class FriendRequest(BaseModel):
    friend_id: int


@router.get("/")
async def get_friends(
    token: str,
    session: AsyncSession = Depends(get_session)
):
    """Получает список друзей"""
    user = await get_current_user(token, session)
    
    # Находим все дружеские связи
    result = await session.execute(
        select(Friendship).where(
            and_(
                or_(
                    Friendship.user_id == user.id,
                    Friendship.friend_id == user.id
                ),
                Friendship.status == "accepted"
            )
        )
    )
    friendships = result.scalars().all()
    
    # Получаем ID друзей
    friend_ids = []
    for friendship in friendships:
        if friendship.user_id == user.id:
            friend_ids.append(friendship.friend_id)
        else:
            friend_ids.append(friendship.user_id)
    
    # Получаем информацию о друзьях
    if not friend_ids:
        return []
    
    result = await session.execute(
        select(User).where(User.id.in_(friend_ids))
    )
    friends = result.scalars().all()
    
    return [friend.to_dict() for friend in friends]


@router.get("/requests")
async def get_friend_requests(
    token: str,
    session: AsyncSession = Depends(get_session)
):
    """Получает входящие запросы в друзья"""
    user = await get_current_user(token, session)
    
    result = await session.execute(
        select(Friendship).where(
            and_(
                Friendship.friend_id == user.id,
                Friendship.status == "pending",
                Friendship.initiated_by != user.id
            )
        )
    )
    requests = result.scalars().all()
    
    # Получаем информацию о пользователях
    user_ids = [req.user_id for req in requests]
    
    if not user_ids:
        return []
    
    result = await session.execute(
        select(User).where(User.id.in_(user_ids))
    )
    users = result.scalars().all()
    
    return [user.to_dict() for user in users]


@router.post("/request")
async def send_friend_request(
    request: FriendRequest,
    token: str,
    session: AsyncSession = Depends(get_session)
):
    """Отправляет запрос в друзья"""
    user = await get_current_user(token, session)
    
    if user.id == request.friend_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot add yourself as friend"
        )
    
    # Проверяем существование пользователя
    result = await session.execute(
        select(User).where(User.id == request.friend_id)
    )
    friend = result.scalar_one_or_none()
    
    if not friend:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Проверяем существующую дружбу
    result = await session.execute(
        select(Friendship).where(
            or_(
                and_(
                    Friendship.user_id == user.id,
                    Friendship.friend_id == request.friend_id
                ),
                and_(
                    Friendship.user_id == request.friend_id,
                    Friendship.friend_id == user.id
                )
            )
        )
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Friend request already exists"
        )
    
    # Создаем запрос в друзья (двусторонний)
    friendship1 = Friendship(
        user_id=user.id,
        friend_id=request.friend_id,
        status="pending",
        initiated_by=user.id
    )
    
    friendship2 = Friendship(
        user_id=request.friend_id,
        friend_id=user.id,
        status="pending",
        initiated_by=user.id
    )
    
    session.add(friendship1)
    session.add(friendship2)
    await session.commit()
    
    return {"message": "Friend request sent"}


@router.post("/accept/{friend_id}")
async def accept_friend_request(
    friend_id: int,
    token: str,
    session: AsyncSession = Depends(get_session)
):
    """Принимает запрос в друзья"""
    user = await get_current_user(token, session)
    
    # Находим запрос
    result = await session.execute(
        select(Friendship).where(
            or_(
                and_(
                    Friendship.user_id == user.id,
                    Friendship.friend_id == friend_id
                ),
                and_(
                    Friendship.user_id == friend_id,
                    Friendship.friend_id == user.id
                )
            )
        )
    )
    friendships = result.scalars().all()
    
    if not friendships:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friend request not found"
        )
    
    # Обновляем статус обеих записей
    for friendship in friendships:
        friendship.status = "accepted"
    
    await session.commit()
    
    return {"message": "Friend request accepted"}


@router.delete("/{friend_id}")
async def remove_friend(
    friend_id: int,
    token: str,
    session: AsyncSession = Depends(get_session)
):
    """Удаляет друга или отклоняет запрос"""
    user = await get_current_user(token, session)
    
    # Находим дружбу
    result = await session.execute(
        select(Friendship).where(
            or_(
                and_(
                    Friendship.user_id == user.id,
                    Friendship.friend_id == friend_id
                ),
                and_(
                    Friendship.user_id == friend_id,
                    Friendship.friend_id == user.id
                )
            )
        )
    )
    friendships = result.scalars().all()
    
    if not friendships:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friendship not found"
        )
    
    # Удаляем обе записи
    for friendship in friendships:
        await session.delete(friendship)
    
    await session.commit()
    
    return {"message": "Friend removed"}
