## 全局初始化脚本（Autoload 单例）
## 在游戏启动时读取 data/config.json，将 API 配置和消息配置分发给其他单例
extends Node

const CONFIG_DIR = "res://data/config.json"

func _ready() -> void:
	var config_path = CONFIG_DIR

	# 检查配置文件是否存在
	if not FileAccess.file_exists(config_path):
		push_error("GlobalInit: 配置文件不存在 - ", config_path)
		return

	# 打开并读取文件
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("GlobalInit: 无法打开配置文件 - ", config_path, " (错误: ", FileAccess.get_open_error(), ")")
		return

	var content = file.get_as_text()
	file.close()

	# 解析 JSON
	var config_data = JSON.parse_string(content)
	if config_data == null:
		push_error("GlobalInit: 配置文件不是有效的 JSON 格式")
		return

	if not config_data is Array:
		push_error("GlobalInit: 配置文件根节点应为数组，实际类型: ", typeof(config_data))
		return

	# 遍历数组，取出 API_CONFIG 和 MESSAGE_CONFIG
	var api_loaded := false
	var message_loaded := false

	for entry in config_data:
		if not entry is Dictionary:
			continue

		if entry.has("API_CONFIG"):
			var api_cfg = entry["API_CONFIG"]
			if api_cfg is Array:
				LlmRequest.api_config = api_cfg          # → 传给 LLM 请求模块
				api_loaded = true
				print("GlobalInit: 已加载 API_CONFIG")
			else:
				push_error("GlobalInit: API_CONFIG 应为数组")

		if entry.has("MESSAGE_CONFIG"):
			var msg_cfg = entry["MESSAGE_CONFIG"]
			if msg_cfg is Array:
				MessageManage.message_config = msg_cfg    # → 传给消息管理模块
				message_loaded = true
				print("GlobalInit: 已加载 MESSAGE_CONFIG")
			else:
				push_error("GlobalInit: MESSAGE_CONFIG 应为数组")

	if not api_loaded:
		push_error("GlobalInit: 配置数组中未找到 API_CONFIG")
	if not message_loaded:
		push_error("GlobalInit: 配置数组中未找到 MESSAGE_CONFIG")
