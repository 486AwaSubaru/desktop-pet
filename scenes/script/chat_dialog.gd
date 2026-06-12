## 聊天对话界面脚本
## 负责：气泡显示、消息发送、流式/非流式 AI 回复展示、历史消息加载
extends Control

const BUBBLE_SEN = preload("res://scenes/chat_dialog/bubble.tscn")
# 当前最后一个气泡引用（用于流式更新或替换占位符）
var last_bubble = null
# 发送/停止状态：'send' 可发送，'stop' 可停止
var send_stop_state = 'send'

func _ready() -> void:
	# 连接 LLM 相关信号
	LlmRequest.request_success.connect(get_message_from_res)   # 非流式响应
	LlmRequest.stream_event.connect(get_stream_chunk)          # 流式逐段文本
	LlmRequest.response_complete.connect(stream_complete)      # 请求完成

	# 接收来自 character 快捷输入框的消息
	EventBus.character_quick_edit_to_chatdialog.connect(_send_message)

	# 加载并显示历史消息
	var messages = MessageManage.message_array
	if messages == null or not messages is Array or messages.is_empty():
		print("ChatDialog: 无历史消息")
		return

	for msg in messages:
		if not msg is Dictionary:
			continue
		if not msg.has("role") or not msg.has("content"):
			continue
		var role: String = msg["role"]
		var content: String = msg["content"]
		if content.is_empty():
			continue
		var is_user := (role == "user")
		_push_message_to_chat_box(content, is_user)

	print("ChatDialog: 已加载 ", messages.size(), " 条历史消息")

## 发送/停止按钮点击
func _on_send_stop_btn_pressed() -> void:
	var message_node = $"container/VC/edit_box/VC/edit_line/edit background/HBoxContainer/chat_edit"
	var message = message_node.text
	if send_stop_state == 'send' and message:
		_send_message(message)
		message_node.text = ''
	elif send_stop_state == 'stop':
		LlmRequest.cancel_request()
		send_stop_state = 'send'

## 回车提交输入
func _on_chat_edit_text_submitted(message: String) -> void:
	if send_stop_state == 'send' and message:
		_send_message(message)
		var message_node = $"container/VC/edit_box/VC/edit_line/edit background/HBoxContainer/chat_edit"
		message_node.text = ''

## 创建气泡并添加到聊天框，滚动到底部
func _push_message_to_chat_box(message: String, _is_user: bool):
	var bubble : MarginContainer = BUBBLE_SEN.instantiate()
	last_bubble = bubble
	bubble.is_user = _is_user
	var container_list = $container/VC/chat_box/ScrollContainer/VBoxContainer
	container_list.add_child(bubble)
	# 连接气泡删除信号
	bubble.delete_requested.connect(_on_bubble_delete)
	bubble.set_chat_text(message)

	# 等待两帧让气泡布局完成后再滚动（bubble._ready 会等一帧）
	await get_tree().process_frame
	await get_tree().process_frame
	var sc = $container/VC/chat_box/ScrollContainer
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)

## 发送消息完整流程：显示用户气泡 → 显示 AI 占位符 → 传给 LLM
func _send_message(message: String) -> void:
	send_stop_state = 'stop'           # 切换按钮为"停止"
	_push_message_to_chat_box(message, true)    # 用户消息气泡
	_push_message_to_chat_box('... ...', false) # AI 占位气泡
	MessageManage.process_message_to_send(message)

## 非流式响应回调：更新 AI 气泡文本并滚动
func get_message_from_res(message):
	send_stop_state = 'send'
	var content = message.content
	if last_bubble:
		last_bubble.set_chat_text(content)
		await get_tree().process_frame
		var sc = $container/VC/chat_box/ScrollContainer
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)

## 流式传输逐段文本回调：追加到 AI 气泡，实时滚动
func get_stream_chunk(chunk: String):
	if last_bubble:
		var org_text = last_bubble.bubble_text.text
		if org_text.begins_with('... ...'):
			last_bubble.set_chat_text(chunk)          # 首次替换占位符
		else:
			org_text += chunk
			last_bubble.set_chat_text(org_text)        # 后续追加文本
		await get_tree().process_frame
		var sc = $container/VC/chat_box/ScrollContainer
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)

## 请求完成（流式 DONE 或非流式完成），恢复按钮状态
func stream_complete(_message = null):
	send_stop_state = 'send'

## 气泡删除请求处理：从界面和历史中同步删除
func _on_bubble_delete(bubble_node):
	var idx = bubble_node.get_index()      # 获取在 VBoxContainer 中的索引
	bubble_node.queue_free()
	MessageManage.delete_message(idx)       # 同步删除历史消息

## 错误回调（预留）
func get_error_from_res(error):
	pass
