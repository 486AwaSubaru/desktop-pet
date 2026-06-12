"""
mem0server 测试用例

使用方法：
    cd server/mem0server
    python -m pytest test_mem0server.py -v

依赖：
    pip install pytest pytest-asyncio httpx
"""
import pytest
import httpx
from unittest.mock import patch, MagicMock, AsyncMock
from fastapi import FastAPI
from fastapi.testclient import TestClient

# 在被测模块导入前，mock mem0 模块（避免真实连接）
with patch.dict("sys.modules", {"mem0": MagicMock()}):
    import sys
    from mem0server import app, AddMemoryRequest, SearchMemoryRequest


# ---------- Fixtures ----------

@pytest.fixture
def client():
    """提供 FastAPI TestClient 实例"""
    with TestClient(app) as c:
        yield c


# ---------- Health Check ----------

class TestHealth:
    """健康检查接口测试"""

    def test_health_returns_alive(self, client):
        """GET /health 应返回 {"status": "alive"}"""
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.json() == {"status": "alive"}


# ---------- Add Memory ----------

class TestAddMemory:
    """添加记忆接口测试"""

    def test_add_memory_success(self, client):
        """正常添加记忆应返回 201 + ok"""
        payload = {
            "user_id": "test_user",
            "messages": [
                {"role": "user", "content": "你好"},
                {"role": "assistant", "content": "你好！有什么可以帮你的？"}
            ]
        }
        resp = client.post("/add_memory", json=payload)
        assert resp.status_code == 201
        data = resp.json()
        assert data["status"] == "ok"
        # mem0 被 mock 后返回空 dict，只要不抛异常就算通过
        assert "data" in data

    def test_add_memory_missing_user_id(self, client):
        """缺少 user_id 应返回 422"""
        payload = {"messages": [{"role": "user", "content": "hi"}]}
        resp = client.post("/add_memory", json=payload)
        assert resp.status_code == 422

    def test_add_memory_missing_messages(self, client):
        """缺少 messages 应返回 422"""
        payload = {"user_id": "test_user"}
        resp = client.post("/add_memory", json=payload)
        assert resp.status_code == 422

    def test_add_memory_empty_messages(self, client):
        """空消息数组应返回 201（业务层允许空数组）"""
        payload = {"user_id": "test_user", "messages": []}
        resp = client.post("/add_memory", json=payload)
        assert resp.status_code == 201
        assert resp.json()["status"] == "ok"

    def test_add_memory_with_metadata(self, client):
        """携带 metadata 参数正常调用"""
        payload = {
            "user_id": "test_user",
            "messages": [{"role": "user", "content": "测试"}],
            "metadata": {"scene": "desktop_pet", "timestamp": 1234567890}
        }
        resp = client.post("/add_memory", json=payload)
        assert resp.status_code == 201
        assert resp.json()["status"] == "ok"


# ---------- Search Memory ----------

class TestSearchMemory:
    """搜索记忆接口测试"""

    def test_search_memory_success(self, client):
        """正常搜索应返回 200 + results 列表"""
        resp = client.post("/search_memory", json={
            "user_id": "test_user",
            "query": "今天天气怎么样"
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "results" in data
        assert isinstance(data["results"], list)

    def test_search_memory_with_limit(self, client):
        """指定 limit 参数"""
        resp = client.post("/search_memory", json={
            "user_id": "test_user",
            "query": "记忆",
            "limit": 3
        })
        assert resp.status_code == 200
        assert isinstance(resp.json()["results"], list)

    def test_search_memory_missing_query(self, client):
        """缺少 query 应返回 422"""
        resp = client.post("/search_memory", json={"user_id": "test_user"})
        assert resp.status_code == 422

    def test_search_memory_missing_user_id(self, client):
        """缺少 user_id 应返回 422"""
        resp = client.post("/search_memory", json={
            "query": "test",
        })
        assert resp.status_code == 422

    def test_search_memory_empty_query(self, client):
        """空字符串 query 应返回 200（业务层接受空查询）"""
        resp = client.post("/search_memory", json={
            "user_id": "test_user",
            "query": ""
        })
        assert resp.status_code == 200
        assert isinstance(resp.json()["results"], list)


# ---------- Pydantic 模型单元测试 ----------

class TestModels:
    """数据模型验证"""

    def test_add_memory_request_model(self):
        """AddMemoryRequest 构造与字段验证"""
        req = AddMemoryRequest(
            user_id="u1",
            messages=[{"role": "user", "content": "hi"}]
        )
        assert req.user_id == "u1"
        assert len(req.messages) == 1
        assert req.metadata is None

    def test_add_memory_request_with_metadata(self):
        """AddMemoryRequest 可选 metadata 字段"""
        req = AddMemoryRequest(
            user_id="u1",
            messages=[],
            metadata={"key": "val"}
        )
        assert req.metadata == {"key": "val"}

    def test_search_memory_request_model(self):
        """SearchMemoryRequest 构造与默认值"""
        req = SearchMemoryRequest(user_id="u1", query="test")
        assert req.limit == 5  # 确认默认值

    def test_search_memory_custom_limit(self):
        """SearchMemoryRequest 自定义 limit"""
        req = SearchMemoryRequest(user_id="u1", query="test", limit=10)
        assert req.limit == 10
