## 消息管理脚本（Autoload 单例）
## 负责：本地消息历史读写、发送消息组装（含 System Prompt）、消息删除
extends Node

# 消息历史文件路径
const MESSAGE_DIR = 'res://data/message_history.json'
# 从 config.json 中读取的消息配置（如 System Prompt）
var message_config = []
# 本地消息历史数组（持久化到文件）
var message_array = []

func _ready() -> void:
	# LLM 响应完成后自动存入历史
	LlmRequest.response_complete.connect(add_message)

	var file = null
	if not FileAccess.file_exists(MESSAGE_DIR):
		# 消息文件不存在，创建一个空的
		file = FileAccess.open(MESSAGE_DIR, FileAccess.WRITE)
		if file == null:
			push_error("MessageManage: 无法创建消息历史文件 - ", MESSAGE_DIR, " (错误: ", FileAccess.get_open_error(), ")")
			return
		var json_str = JSON.stringify(message_array, '\t')
		file.store_string(json_str)
		file.close()
		print("MessageManage: 已创建新的消息历史文件")
		return

	# 读取已有的消息历史文件
	file = FileAccess.open(MESSAGE_DIR, FileAccess.READ)
	if file == null:
		push_error("MessageManage: 无法打开消息历史文件 - ", MESSAGE_DIR, " (错误: ", FileAccess.get_open_error(), ")")
		return

	var message_str = file.get_as_text()
	file.close()

	# 解析 JSON
	var parsed = JSON.parse_string(message_str)
	if parsed == null:
		push_error("MessageManage: 消息历史文件不是有效的 JSON 格式，将重置")
		message_array = []
		return

	if not parsed is Array:
		push_error("MessageManage: 消息历史文件应为数组，将重置")
		message_array = []
		return

	message_array = parsed
	print("MessageManage: 已加载消息历史，共 ", message_array.size(), " 条记录")

## 处理并发送消息的完整流程：
## 复制历史 → 插入 System Prompt → 追加用户消息 → 发送给 LLM
func process_message_to_send(message: String):
	# 复制 message_array，不污染原始历史记录
	var send_array = message_array.duplicate()

	# 根据 message_config 插入预设消息到发送数组
	for entry in message_config:
		if not entry is Dictionary:
			continue
		var position = entry.get("POSITION", "")
		var content = entry.get("MESSAGE", "")
		if content.is_empty():
			continue
		match position:
			"SYSTEM":
				send_array.push_front({"role": "system", "content": content})

	# 构造用户消息，同时追加到原始数组（本地历史）和发送数组
	var user_msg = {"role": "user", "content": message}
	message_array.append(user_msg)
	send_array.append(user_msg)

	# 将复制的数组发给 LLM
	LlmRequest.send_message(send_array)

## 保存消息历史到文件
func save_message():
	var file = FileAccess.open(MESSAGE_DIR, FileAccess.WRITE)
	if file == null:
		push_error("MessageManage: 无法保存消息历史 - ", MESSAGE_DIR, " (错误: ", FileAccess.get_open_error(), ")")
		return
	var json_str = JSON.stringify(message_array, '\t')
	file.store_string(json_str)
	file.close()
	print("MessageManage: 已保存消息历史，共 ", message_array.size(), " 条记录")

## 程序退出时自动保存历史
func _exit_tree():
	save_message()

## 追加消息到历史数组（由 response_complete 信号触发）
func add_message(message):
	message_array.append(message)

## 按索引删除消息（由 chat_dialog 气泡删除触发）
func delete_message(index: int):
	if index >= 0 and index < message_array.size():
		message_array.remove_at(index)
