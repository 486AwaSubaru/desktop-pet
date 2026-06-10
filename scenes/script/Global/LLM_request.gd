extends Node

## 请求成功信号，返回 AI 回复文本
signal request_success(ai_message)
## 流式传输每段文本信号
signal stream_event(chunk: String)
## 请求完成信号（流式 DONE 或非流式完成），用于保存历史
signal response_complete(message: Dictionary)
## 请求失败信号，返回错误描述
signal request_error(error_msg: String)

var api_config = []
var http_request = null
var API_KEY = null
var API_BASE_URL = null
var MODEL = null
var USE_STREAM: bool = false

# 流式传输内部状态
var _stream_sse = null
var _stream_full_text: String = ""

func _ready():
	for entry in api_config:
		if not entry is Dictionary:
			continue
		if entry.has("LLM_BASE_URL"):
			API_BASE_URL = entry["LLM_BASE_URL"]
		if entry.has("LLM_API_KEY"):
			API_KEY = entry["LLM_API_KEY"]
		if entry.has("LLM_MODEL"):
			MODEL = entry["LLM_MODEL"]
		if entry.has("USE_STREAM"):
			USE_STREAM = entry["USE_STREAM"]

func _process(_delta):
	if _stream_sse:
		_stream_sse.poll()

## 向 AI 发送消息数组
func send_message(messages: Array):
	if not API_KEY or not API_BASE_URL or not MODEL:
		var msg = "API 配置不完整，请检查 data/config.json"
		push_error("LlmRequest: ", msg)
		request_error.emit(msg)
		return

	if USE_STREAM:
		_send_stream(messages)
	else:
		_send_normal(messages)

## 非流式请求
func _send_normal(messages: Array):
	if not http_request:
		http_request = HTTPRequest.new()
		add_child(http_request)
		http_request.request_completed.connect(_on_request_completed)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + API_KEY
	]
	var request_body = {
		"model": MODEL,
		"messages": messages,
		"stream": false
	}
	var json_body = JSON.stringify(request_body)
	var url = API_BASE_URL.trim_suffix("/") + "/chat/completions"
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		var msg = "HTTP 请求发送失败，错误代码: " + str(error)
		push_error("LlmRequest: ", msg)
		request_error.emit(msg)

## 流式请求
func _send_stream(messages: Array):
	_cleanup_stream()
	_stream_full_text = ""

	_stream_sse = HTTPEventSource.new()
	_stream_sse.event.connect(_on_stream_sse_event)

	var headers = PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + API_KEY])
	var url = API_BASE_URL.trim_suffix("/") + "/chat/completions"
	var payload = JSON.stringify({
		"model": MODEL,
		"messages": messages,
		"stream": true
	})

	var err = _stream_sse.connect_to_url(url, headers, payload)
	if err != OK:
		var msg = "SSE 连接失败，错误代码: " + str(err)
		push_error("LlmRequest: ", msg)
		request_error.emit(msg)
		_cleanup_stream()

## 流式事件回调
func _on_stream_sse_event(ev):
	if ev.data == "[DONE]":
		var full_message: Dictionary = {"role": "assistant", "content": _stream_full_text}
		response_complete.emit(full_message)
		_cleanup_stream()
		return

	var json = JSON.parse_string(ev.data)
	if json and json.has("choices") and json.choices.size() > 0:
		var delta = json.choices[0].delta
		if delta and delta.has("content") and delta.content != null:
			var chunk: String = delta.content
			_stream_full_text += chunk
			stream_event.emit(chunk)

## 清理流式资源
func _cleanup_stream():
	if _stream_sse:
		_stream_sse.stop()
		_stream_sse = null
	_stream_full_text = ""

## 取消请求（流式和非流式均支持）
func cancel_request():
	if _stream_sse:
		_cleanup_stream()
		return
	if http_request:
		http_request.cancel_request()

## 处理非流式 API 响应
func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		var msg = "API 请求失败，HTTP 状态码: " + str(response_code) + " | 响应: " + body.get_string_from_utf8()
		push_error("LlmRequest: ", msg)
		request_error.emit(msg)
		return

	var response_data = JSON.parse_string(body.get_string_from_utf8())
	if response_data == null:
		var msg = "响应不是有效的 JSON: " + body.get_string_from_utf8()
		push_error("LlmRequest: ", msg)
		request_error.emit(msg)
		return

	if not response_data.has("choices") or response_data.choices.size() == 0:
		var msg = "响应中无 choices 字段: " + var_to_str(response_data)
		push_error("LlmRequest: ", msg)
		request_error.emit(msg)
		return

	var ai_message = response_data.choices[0].message
	request_success.emit(ai_message)
	response_complete.emit(ai_message)
