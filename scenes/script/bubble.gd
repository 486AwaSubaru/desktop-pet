extends Control

const MAX_BUBBLE_LENGTH = 350
var is_user: bool = false
var bubble_text = null

signal delete_requested(bubble_node)

func _ready() -> void:
	bubble_text = $VBoxContainer/HBoxContainer/chat_text_bac/MarginContainer/chat_text
	var chat_bac = $VBoxContainer/HBoxContainer/chat_text_bac
	var bubble_tool = $VBoxContainer/bubble_tool
	if is_user:
		var panel_styles = chat_bac.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		panel_styles.corner_radius_bottom_right = 0
		panel_styles.bg_color = "#FFC107"
		chat_bac.add_theme_stylebox_override("panel", panel_styles)
		chat_bac.size_flags_horizontal = SIZE_SHRINK_END | SIZE_EXPAND
		
		bubble_tool.size_flags_horizontal = SIZE_SHRINK_END
	else:
		var panel_styles = chat_bac.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		panel_styles.corner_radius_bottom_left = 0
		panel_styles.bg_color = "#FF5722"
		chat_bac.add_theme_stylebox_override("panel", panel_styles)
		chat_bac.size_flags_horizontal = SIZE_SHRINK_BEGIN | SIZE_EXPAND
		
		bubble_tool.size_flags_horizontal = SIZE_SHRINK_BEGIN

	# 让所有子节点忽略鼠标事件，事件直达根节点 Bubble_box
	#for child in find_children("*"):
		#child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	await get_tree().process_frame
	set_chat_text_autowrap()

func set_chat_text(message: String):
	bubble_text.text = message
	set_chat_text_autowrap()

func set_chat_text_autowrap():
	var text_width = bubble_text.get_combined_minimum_size().x
	if text_width > MAX_BUBBLE_LENGTH:
		bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bubble_text.custom_minimum_size.x = MAX_BUBBLE_LENGTH


func _on_delete_btn_pressed() -> void:
	delete_requested.emit(self)
