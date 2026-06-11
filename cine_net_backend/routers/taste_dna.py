from __future__ import annotations

from fastapi import APIRouter, HTTPException

from models.schemas import TasteAvatarResponse, TasteDNA
from services.taste_dna import build_taste_dna, generate_taste_avatar


router = APIRouter(tags=["taste-dna"])


@router.get("/api/taste-dna", response_model=TasteDNA)
async def get_taste_dna() -> TasteDNA:
    return build_taste_dna()


@router.post("/api/taste-dna/avatar/generate", response_model=TasteAvatarResponse)
async def generate_taste_dna_avatar(force: bool = False) -> TasteAvatarResponse:
    try:
        return await generate_taste_avatar(force=force)
    except RuntimeError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
