## 桌面宠物主窗口脚本
## 负责：窗口拖拽、右键菜单、聊天子窗口/弹出框的显隐与位置管理
extends Node2D

# 点击区域（透明 Panel，覆盖整个窗口用于接收鼠标事件）
var click_area = null
# 主窗口引用（即系统窗口）
var character_win: Window = null
# 聊天子窗口（全功能对话界面）
var chat_win: Window = null
# 弹出框窗口（快速输入/显示的简易气泡）
var popup_win = null
# 屏幕尺寸，用于窗口边界约束
var screen_size: Vector2i = Vector2i.ZERO

# 拖拽相关状态
var mouse_move_last_pos = Vector2.ZERO  # 上一次鼠标位置
var mouse_move_len = 0                   # 鼠标移动累计距离（用于阈值判断）
var is_drag: bool = false                # 是否正在拖拽
var is_click: bool = false               # 是否纯点击（无拖拽）

# 右键菜单
var popup_menu = null
# 是否允许发送（防重复提交，response_complete 后恢复）
var can_send: bool = true

func _ready() -> void:
	screen_size = DisplayServer.screen_get_size()

	# 获取主窗口引用
	character_win = self.get_window()
	# 点击区域覆盖全窗口
	click_area = $click_area
	click_area.gui_input.connect(_process_mouse_event)
	var win_size = character_win.size
	click_area.size = win_size

	# 创建聊天子窗口并挂载
	var chat_win_scn = preload("res://scenes/chat_dialog/chat_window.tscn")
	chat_win = chat_win_scn.instantiate()
	chat_win.transient = true  # 不在任务栏显示独立图标
	add_child(chat_win)

	# 创建弹出框窗口并挂载
	var popup_win_scn = preload("res://scenes/chat_dialog/popup_chat_box.tscn")
	popup_win = popup_win_scn.instantiate()
	add_child(popup_win)

	# 等一帧让布局稳定后，根据主窗口位置定位子窗口
	await get_tree().process_frame
	_update_chat_win_position()
	_update_popupchat_position()
	chat_win.hide()
	popup_win.hide()

	# 右键菜单
	popup_menu = $click_area/PopupMenu
	popup_menu.id_pressed.connect(_on_menu_item_pressed)

	# LLM 响应完成后恢复发送状态
	LlmRequest.response_complete.connect(_on_response_complete)

## 鼠标事件处理入口（来自 click_area.gui_input）
func _process_mouse_event(event: InputEvent):
	# 左键按下/抬起
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			mouse_move_last_pos = character_win.get_mouse_position()
			mouse_move_len = 0
			is_drag = true
			is_click = true
		else:
			is_drag = false
			if is_click:
				_mouse_click()
	# 左键拖拽中
	elif is_drag and event is InputEventMouseMotion:
		mouse_move_len += (character_win.get_mouse_position() - mouse_move_last_pos).length()
		if mouse_move_len > 15:  # 超过 15px 阈值才视为拖拽
			_mouse_move()
		mouse_move_last_pos = character_win.get_mouse_position()
	# 右键弹出菜单
	elif  event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		popup_menu.position = DisplayServer.mouse_get_position()
		popup_menu.popup()

## 拖拽移动主窗口，同时跟随移动子窗口/弹出框
func _mouse_move():
	var delta = character_win.get_mouse_position() - mouse_move_last_pos
	var delta_i = Vector2i(delta)

	# 限制主窗口不超出屏幕
	var new_pos = character_win.position + delta_i
	new_pos.x = clamp(new_pos.x, 0, screen_size.x - character_win.size.x)
	new_pos.y = clamp(new_pos.y, 0, screen_size.y - character_win.size.y)
	character_win.position = new_pos

	# 同步更新子窗口和弹出框的位置
	if chat_win and chat_win.visible:
		_update_chat_win_position()
	if popup_win and popup_win.visible:
		_update_popupchat_position()
	is_click = false

## 左键点击主窗口，切换聊天子窗口的显隐
func _mouse_click():
	if chat_win.visible:
		chat_win.hide()
	else:
		chat_win.show()
		_update_chat_win_position()

## 根据主窗口在屏幕上的位置，将聊天子窗口放在左侧或右侧
func _update_chat_win_position():
	if not chat_win or not chat_win.is_inside_tree():
		return

	# 主窗口靠左 → 子窗口放右侧；靠右 → 放左侧
	if character_win.position.x > screen_size.x / 2:
		chat_win.position.x = character_win.position.x - chat_win.size.x
	else:
		chat_win.position.x = character_win.position.x + character_win.size.x
	# 纵向与主窗口居中对齐
	var new_y = character_win.position.y - (chat_win.size.y - character_win.size.y) / 2
	new_y = clamp(new_y, 0, screen_size.y - chat_win.size.y)
	chat_win.position.y = new_y

## 右键菜单项点击处理
func _on_menu_item_pressed(menu_id: int):
	match menu_id:
		0:
			get_tree().quit()

## 快速输入框提交事件（来自 EventBus 信号）
func _on_quick_edit_text_submitted(new_text: String) -> void:
	if can_send:
		# 通过 EventBus 转发给 chat_dialog
		EventBus.character_quick_edit_to_chatdialog.emit(new_text)
		# 显示用户消息弹出框
		popup_win.is_user = true
		popup_win.set_chat_text(new_text)
		_update_popupchat_position()
		popup_win.show()
		$quick_edit_box/quick_edit.text = ''
		can_send = false

## 更新弹出框的位置（根据主窗口位置决定左右）
func _update_popupchat_position():
	await get_tree().process_frame
	await get_tree().process_frame
	var cx = character_win.position.x
	var cy = character_win.position.y
	var cwx = character_win.size.x
	if character_win.position.x > screen_size.x / 2:
		popup_win.position.x = cx - popup_win.size.x
	else:
		popup_win.position.x = cx + cwx
	popup_win.position.y = cy

## LLM 响应完成后的回调，恢复发送状态
func _on_response_complete(_message):
	can_send = true
