extends Node2D

var click_area = null
var character_win: Window = null
var chat_win: Window = null
var screen_size: Vector2i = Vector2i.ZERO 

var mouse_move_last_pos = Vector2.ZERO
var mouse_move_len = 0
var is_drag: bool = false
var is_click: bool = false

var popup_menu = null
var popup_win = null
var can_send: bool = true

func _ready() -> void:
	screen_size = DisplayServer.screen_get_size()
	
	character_win = self.get_window()
	click_area = $click_area
	click_area.gui_input.connect(_process_mouse_event)
	var win_size = character_win.size
	click_area.size = win_size
	
	var chat_win_scn = preload("res://scenes/chat_dialog/chat_window.tscn")
	chat_win = chat_win_scn.instantiate()
	chat_win.transient = true
	add_child(chat_win)
	
	var popup_win_scn = preload("res://scenes/chat_dialog/popup_chat_box.tscn")
	popup_win = popup_win_scn.instantiate()
	add_child(popup_win)
	
	# 等一帧让布局稳定后，根据主窗口位置决定子窗口方位
	await get_tree().process_frame
	_update_chat_win_position()
	_update_popupchat_position()
	chat_win.hide()
	popup_win.hide()
	
	popup_menu = $click_area/PopupMenu
	popup_menu.id_pressed.connect(_on_menu_item_pressed)

	LlmRequest.response_complete.connect(_on_response_complete)
	
func _process_mouse_event(event: InputEvent):
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
	elif is_drag and event is InputEventMouseMotion:
		mouse_move_len += (character_win.get_mouse_position() - mouse_move_last_pos).length()
		if mouse_move_len > 15:
			_mouse_move()
		mouse_move_last_pos = character_win.get_mouse_position()
	elif  event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		popup_menu.position = DisplayServer.mouse_get_position()
		popup_menu.popup()
func _mouse_move():
	var delta = character_win.get_mouse_position() - mouse_move_last_pos
	var delta_i = Vector2i(delta)

	# 限制主窗口不超出屏幕可用区域
	var new_pos = character_win.position + delta_i
	new_pos.x = clamp(new_pos.x, 0, screen_size.x - character_win.size.x)
	new_pos.y = clamp(new_pos.y, 0, screen_size.y - character_win.size.y)
	character_win.position = new_pos
	# 子窗口跟随主窗口移动
	if chat_win and chat_win.visible:
		_update_chat_win_position()
	if popup_win and popup_win.visible:
		_update_popupchat_position()
	is_click = false

func _mouse_click():
	if chat_win.visible:
		chat_win.hide()
	else:
		chat_win.show()
		_update_chat_win_position()

# 根据主窗口在屏幕上的位置，决定子窗口放在左侧还是右侧，并确保不超出屏幕
func _update_chat_win_position():
	if not chat_win or not chat_win.is_inside_tree():
		return
	
	if character_win.position.x > screen_size.x / 2:
		chat_win.position.x = character_win.position.x - chat_win.size.x
	else:
		chat_win.position.x = character_win.position.x + character_win.size.x
	var new_y = character_win.position.y - (chat_win.size.y - character_win.size.y) / 2
	new_y = clamp(new_y, 0, screen_size.y - chat_win.size.y)
	chat_win.position.y = new_y

func _on_menu_item_pressed(menu_id: int):
	match menu_id:
		0:
			get_tree().quit()


func _on_quick_edit_text_submitted(new_text: String) -> void:
	if can_send:
		EventBus.character_quick_edit_to_chatdialog.emit(new_text)
		popup_win.is_user = true
		popup_win.set_chat_text(new_text)
		_update_popupchat_position()
		popup_win.show()
		$quick_edit_box/quick_edit.text = ''
		can_send = false
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

func _on_response_complete(_message):
	can_send = true
		
