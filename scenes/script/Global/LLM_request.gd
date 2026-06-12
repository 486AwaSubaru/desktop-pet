## LLM API 请求管理脚本（Autoload 单例）
## 负责：向 DeepSeek API 发送聊天请求，支持流式（SSE）和非流式（HTTP）两种模式
extends Node

## 非流式响应信号（返回 message dict: {role, content}）
signal request_success(ai_message)
## 流式传输每段文本信号
signal stream_event(chunk: String)
## 请求完成信号（流式 DONE 或非流式完成），用于保存历史、恢复状态
signal response_complete(message: Dictionary)
## 请求失败信号
signal request_error(error_msg: String)

# API 配置（由 GlobalInit 从 config.json 注入）
var api_config = []

# 非流式请求使用的节点（懒初始化）
var http_request = null

# 解析后的 API 参数
var API_KEY = null
var API_BASE_URL = null
var MODEL = null
var USE_STREAM: bool = false

# 流式传输内部状态
var _stream_sse = null       # HTTPEventSource 实例（RefCounted，非 Node）
var _stream_full_text: String = ""  # 流式累计的完整回复文本

func _ready():
	# 从 api_config 中解析配置字段
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
	# 每帧轮询 SSE 连接，驱动流式数据传输
	if _stream_sse:
		_stream_sse.poll()

## 向 AI 发送消息数组（根据配置自动选择流式或非流式）
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

## 非流式请求：使用 HTTPRequest 发送标准 POST 请求
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

## 流式请求：使用 HTTPEventSource 建立 SSE 连接
func _send_stream(messages: Array):
	_cleanup_stream()
	_stream_full_text = ""

	# 创建 SSE 客户端
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

## 流式事件回调：解析 SSE data，处理文本增量
func _on_stream_sse_event(ev):
	# DeepSeek 用 [DONE] 标记流结束
	if ev.data == "[DONE]":
		var full_message: Dictionary = {"role": "assistant", "content": _stream_full_text}
		response_complete.emit(full_message)
		_cleanup_stream()
		return

	# 解析每个 SSE 事件的 data 字段，提取 delta 增量文本
	var json = JSON.parse_string(ev.data)
	if json and json.has("choices") and json.choices.size() > 0:
		var delta = json.choices[0].delta
		# 注意：delta 可能无 content（如 role 字段单独出现），需判空
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

## 非流式 API 响应回调：校验响应并发送信号
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

	# 提取 AI 回复消息并发出信号
	var ai_message = response_data.choices[0].message
	request_success.emit(ai_message)
	response_complete.emit(ai_message)
