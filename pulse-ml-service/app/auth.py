"""Verification de la cle API via le header X-API-Key."""
from typing import Optional

from fastapi import Header, HTTPException, status

from app.config import settings


async def verify_api_key(x_api_key: Optional[str] = Header(None, alias="X-API-Key")) -> None:
    if not x_api_key or x_api_key != settings.api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Cle API absente ou invalide.",
        )
