## 弹出框窗口脚本
## 负责：主窗口上的快速消息弹出（用户消息/AI 回复），带淡入淡出动画
extends Window

# 是否为用户消息
var is_user: bool = false

# 用户/AI 消息框及其内部的 Label 节点
var user_box
var ai_box
var user_label: Label
var ai_label: Label

# 淡入淡出动画控制器
var _fade_tween: Tween

func _ready() -> void:
	# 初始化节点引用
	user_label = $user/chat_text_bac/MarginContainer/chat_text
	ai_label = $ai/chat_text_bac/MarginContainer/chat_text
	user_box = $user
	ai_box = $ai
	user_box.visible = false
	ai_box.visible = false

	# 连接 LLM 信号
	LlmRequest.request_success.connect(_on_llm_response)   # 非流式响应
	LlmRequest.stream_event.connect(_on_stream_chunk)       # 流式逐段文本
	LlmRequest.response_complete.connect(_on_response_complete)  # 完成回调

## 设置文本并触发显示动画
func set_chat_text(text: String) -> void:
	# 重置窗口大小后根据内容重新计算
	size = Vector2.ZERO
	if is_user:
		user_label.text = text
		ai_label.text = ''
		size = user_box.size
	else:
		ai_label.text = text
		user_label.text = ''
		size = ai_box.size
	_show_with_fade()

## 淡入淡出动画核心逻辑
func _show_with_fade():
	var target = user_box if is_user else ai_box
	var other = ai_box if is_user else user_box
	other.visible = false
	other.modulate.a = 0
	var was_visible = target.visible
	target.visible = true

	if is_user:
		# 用户消息：完整淡入 → 停留 4s → 淡出
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.set_trans(Tween.TRANS_SINE)
		target.modulate.a = 0.0
		_fade_tween.tween_property(target, "modulate:a", 1.0, 0.2)
		_fade_tween.tween_interval(4.0)
		_fade_tween.tween_property(target, "modulate:a", 0.0, 0.3)

	elif not is_user and not was_visible:
		# AI 消息首次显示：仅淡入，4s 淡出由 _on_response_complete 触发
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.set_trans(Tween.TRANS_SINE)
		target.modulate.a = 0.0
		_fade_tween.tween_property(target, "modulate:a", 1.0, 0.2)

## 流式逐段文本回调：追加到 AI 文本框
func _on_stream_chunk(chunk: String):
	is_user = false
	var current = ai_label.text
	set_chat_text(current + chunk)

## 非流式 AI 响应回调：显示完整回复
func _on_llm_response(ai_message):
	is_user = false
	var content = ai_message.content
	set_chat_text(content)

## LLM 请求完成回调（流式 DONE 或非流式）：启动 4s 倒计时后淡出 AI 框
func _on_response_complete(_message):
	if _fade_tween == null or not _fade_tween.is_valid():
		_fade_tween = create_tween()
		_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_interval(4.0)
	_fade_tween.tween_property(ai_box, "modulate:a", 0.0, 0.3)
