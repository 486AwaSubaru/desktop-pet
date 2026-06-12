from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from mem0 import Memory

# ---------- 请求/响应模型 ----------
class AddMemoryRequest(BaseModel):
    user_id: str
    messages: List[Dict[str, str]]   # 格式: [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
    # 可选参数
    metadata: Optional[Dict[str, Any]] = None

class SearchMemoryRequest(BaseModel):
    user_id: str
    query: str
    limit: int = 5

class MemoryItem(BaseModel):
    memory: str
    score: Optional[float] = None
    metadata: Optional[Dict[str, Any]] = None

class SearchMemoryResponse(BaseModel):
    results: List[MemoryItem]


config = {
    "llm": {
        "provider": "deepseek",
        "config": {
            "model": "deepseek-v4-flash",  
            "api_key": "sk-f38022a1f24246029ac7e8364dc26876",
            "temperature": 0.2,
            "max_tokens": 131072,
            "top_p": 1.0
        }
    }
}

memory = Memory.from_config(config)   

# ---------- FastAPI 应用 ----------
app = FastAPI(title="Mem0 Gateway for Godot")

@app.post("/add_memory", status_code=201)
async def add_memory(request: AddMemoryRequest):
    """
    存储一段对话到 Mem0
    """
    try:
        result = memory.add(
            messages=request.messages,
            user_id=request.user_id,
            metadata=request.metadata
        )
        # result 包含每个消息生成的记忆，如 {"results": [{"id": "...", "memory": "..."}]}
        return {"status": "ok", "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/search_memory", response_model=SearchMemoryResponse)
async def search_memory(request: SearchMemoryRequest):
    """
    根据查询文本搜索相关记忆
    """
    try:
        results = memory.search(
            query=request.query,
            user_id=request.user_id,
            limit=request.limit
        )
        # results 结构: {"results": [{"memory": "...", "score": 0.9, ...}]}
        formatted = [
            MemoryItem(
                memory=item["memory"],
                score=item.get("score"),
                metadata=item.get("metadata")
            )
            for item in results.get("results", [])
        ]
        return SearchMemoryResponse(results=formatted)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "alive"}

# 如果你需要更底层的控制，也可以暴露 /memories 的增删改查
# 参考官方文档：https://docs.mem0.ai/api-reference/memories