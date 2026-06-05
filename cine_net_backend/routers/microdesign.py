"""MicroDesign 协议 API。"""
from fastapi import APIRouter

from services.microdesign.models import MicroDesignSchema

router = APIRouter(prefix="/api/microdesign", tags=["microdesign"])


@router.get("/schema", response_model=MicroDesignSchema)
async def microdesign_schema() -> MicroDesignSchema:
    """返回 Flutter 当前需要支持的 blocks/actions/styles 白名单。"""

    return MicroDesignSchema()
