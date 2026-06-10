# 大小500*700

extends Control

const BUBBLE_SEN = preload("res://scenes/chat_dialog/bubble.tscn")
var last_bubble = null
var send_stop_state = 'send'

func _ready() -> void:
	LlmRequest.request_success.connect(get_message_from_res)
	LlmRequest.stream_event.connect(get_stream_chunk)
	LlmRequest.response_complete.connect(stream_complete)
	
	EventBus.character_quick_edit_to_chatdialog.connect(_send_message)
	
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

func _on_send_stop_btn_pressed() -> void:
	var message_node = $"container/VC/edit_box/VC/edit_line/edit background/HBoxContainer/chat_edit"
	var message = message_node.text
	if send_stop_state == 'send' and message:
		_send_message(message)
		message_node.text = ''
	elif send_stop_state == 'stop':
		LlmRequest.cancel_request()
		send_stop_state = 'send'

func _on_chat_edit_text_submitted(message: String) -> void:
	if send_stop_state == 'send' and message:
		_send_message(message)
		var message_node = $"container/VC/edit_box/VC/edit_line/edit background/HBoxContainer/chat_edit"
		message_node.text = ''

func _push_message_to_chat_box(message: String, _is_user: bool):
	var bubble : MarginContainer = BUBBLE_SEN.instantiate()
	last_bubble = bubble 
	bubble.is_user = _is_user
	var container_list = $container/VC/chat_box/ScrollContainer/VBoxContainer
	container_list.add_child(bubble)
	bubble.delete_requested.connect(_on_bubble_delete)
	bubble.set_chat_text(message)
	
	# 在bubble的脚本里，_ready阶段等待了1帧，会导致这里等待1帧后没法获取到最大高度，多等1帧
	await get_tree().process_frame
	await get_tree().process_frame
	var sc = $container/VC/chat_box/ScrollContainer
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	
func _send_message(message: String) -> void:
	send_stop_state = 'stop'
	_push_message_to_chat_box(message, true)
	_push_message_to_chat_box('... ...', false)
	MessageManage.process_message_to_send(message)
	
func get_message_from_res(message):
	send_stop_state = 'send'
	var content = message.content
	if last_bubble:
		last_bubble.set_chat_text(content)
		await get_tree().process_frame
		var sc = $container/VC/chat_box/ScrollContainer
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
func get_stream_chunk(chunk: String):
	if last_bubble:
		var org_text = last_bubble.bubble_text.text
		if org_text.begins_with('... ...'):
			last_bubble.set_chat_text(chunk)
		else:
			org_text += chunk
			last_bubble.set_chat_text(org_text)
		await get_tree().process_frame
		var sc = $container/VC/chat_box/ScrollContainer
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
func stream_complete(_message = null):
	send_stop_state = 'send'
	
func _on_bubble_delete(bubble_node):
	var idx = bubble_node.get_index()
	bubble_node.queue_free()
	MessageManage.delete_message(idx)

func get_error_from_res(error):
	pass
