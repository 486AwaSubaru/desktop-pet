import json
import importlib
from fastapi import FastAPI, Request
from fastapi.routing import APIRoute

app = FastAPI(title="Dynamic Router Example")

def load_routes_from_config(config_path: str = "routes_config.json"):
    with open(config_path, "r") as f:
        config = json.load(f)

    for route_cfg in config.get("routes", []):
        path = route_cfg["path"]
        method = route_cfg["method"].lower()
        handler_module_path = route_cfg["handler_module"]
        handler_name = route_cfg["handler_name"]

        # 动态导入处理器函数
        try:
            module = importlib.import_module(handler_module_path)
            handler = getattr(module, handler_name)
        except (ModuleNotFoundError, AttributeError) as e:
            print(f"❌ Failed to load handler {handler_module_path}.{handler_name}: {e}")
            continue

        # 准备路由参数
        route_kwargs = {
            "path": path,
            "endpoint": handler,
            "methods": [method.upper()],
        }
        # 可选参数：summary, response_model, tags 等
        if "summary" in route_cfg:
            route_kwargs["summary"] = route_cfg["summary"]
        if "response_model" in route_cfg:
            # response_model 可能是字符串路径，需要动态导入
            response_model_path = route_cfg["response_model"]
            if "." in response_model_path:
                mod_path, cls_name = response_model_path.rsplit(".", 1)
                resp_mod = importlib.import_module(mod_path)
                response_model_cls = getattr(resp_mod, cls_name)
                route_kwargs["response_model"] = response_model_cls
        if "tags" in route_cfg:
            route_kwargs["tags"] = route_cfg["tags"]

        # 注册路由
        app.router.add_api_route(**route_kwargs)
        print(f"✅ Registered route: {method.upper()} {path} -> {handler_module_path}.{handler_name}")

# 在启动时执行路由加载
load_routes_from_config()


