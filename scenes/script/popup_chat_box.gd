extends Window
var is_user: bool = false

var user_box
var ai_box
var user_label: Label
var ai_label: Label

var _fade_tween: Tween
func _ready() -> void:
	user_label = $user/chat_text_bac/MarginContainer/chat_text
	ai_label = $ai/chat_text_bac/MarginContainer/chat_text
	user_box = $user
	ai_box = $ai
	user_box.visible = false
	ai_box.visible = false
	LlmRequest.request_success.connect(_on_llm_response)
	LlmRequest.stream_event.connect(_on_stream_chunk)
	LlmRequest.response_complete.connect(_on_response_complete)

func set_chat_text(text: String) -> void:
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

func _show_with_fade():
	var target = user_box if is_user else ai_box
	var other = ai_box if is_user else user_box
	other.visible = false
	other.modulate.a = 0
	var was_visible = target.visible
	target.visible = true
	if is_user:
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.set_trans(Tween.TRANS_SINE)
		target.modulate.a = 0.0
		_fade_tween.tween_property(target, "modulate:a", 1.0, 0.2)
		_fade_tween.tween_interval(4.0)
		_fade_tween.tween_property(target, "modulate:a", 0.0, 0.3)

	elif not is_user and not was_visible:
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
			
		_fade_tween = create_tween()
		_fade_tween.set_trans(Tween.TRANS_SINE)
		target.modulate.a = 0.0
		_fade_tween.tween_property(target, "modulate:a", 1.0, 0.2)

func _on_stream_chunk(chunk: String):
	is_user = false
	var current = ai_label.text
	set_chat_text(current + chunk)

func _on_llm_response(ai_message):
	is_user = false
	var content = ai_message.content
	set_chat_text(content)
	
func _on_response_complete(_message):
	if _fade_tween == null or not _fade_tween.is_valid():
		_fade_tween = create_tween()
		_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_interval(4.0)
	_fade_tween.tween_property(ai_box, "modulate:a", 0.0, 0.3)
