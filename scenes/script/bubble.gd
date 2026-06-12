## 聊天气泡脚本
## 负责：气泡样式（用户/AI 区分色）、文本自动换行、删除信号
extends Control

# 文本换行最大宽度
const MAX_BUBBLE_LENGTH = 350
# 是否为用户消息（影响样式和布局对齐方向）
var is_user: bool = false
# 缓存的 chat_text 节点引用
var bubble_text = null

## 删除请求信号，携带自身引用用于 chat_dialog 定位删除
signal delete_requested(bubble_node)

func _ready() -> void:
	bubble_text = $VBoxContainer/HBoxContainer/chat_text_bac/MarginContainer/chat_text
	var chat_bac = $VBoxContainer/HBoxContainer/chat_text_bac
	var bubble_tool = $VBoxContainer/bubble_tool

	if is_user:
		# 用户气泡：右上角圆角、黄色背景、右对齐
		var panel_styles = chat_bac.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		panel_styles.corner_radius_bottom_right = 0
		panel_styles.bg_color = "#FFC107"
		chat_bac.add_theme_stylebox_override("panel", panel_styles)
		chat_bac.size_flags_horizontal = SIZE_SHRINK_END | SIZE_EXPAND
		bubble_tool.size_flags_horizontal = SIZE_SHRINK_END
	else:
		# AI 气泡：左上角圆角、橙色背景、左对齐
		var panel_styles = chat_bac.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		panel_styles.corner_radius_bottom_left = 0
		panel_styles.bg_color = "#FF5722"
		chat_bac.add_theme_stylebox_override("panel", panel_styles)
		chat_bac.size_flags_horizontal = SIZE_SHRINK_BEGIN | SIZE_EXPAND
		bubble_tool.size_flags_horizontal = SIZE_SHRINK_BEGIN

	await get_tree().process_frame
	set_chat_text_autowrap()

## 设置气泡文本并触发换行检测
func set_chat_text(message: String):
	bubble_text.text = message
	set_chat_text_autowrap()

## 检测文本宽度是否超过限制，启用自动换行
func set_chat_text_autowrap():
	var text_width = bubble_text.get_combined_minimum_size().x
	if text_width > MAX_BUBBLE_LENGTH:
		bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bubble_text.custom_minimum_size.x = MAX_BUBBLE_LENGTH

## 删除按钮点击 → 发出删除信号
func _on_delete_btn_pressed() -> void:
	delete_requested.emit(self)
