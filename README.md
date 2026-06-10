# Desktop Pet — Godot 桌面宠物

一个基于 Godot 4.6 的桌面宠物项目，角色是猫娘，支持 AI 对话（流式 / 非流式）、窗口拖拽、右键菜单等功能。

---

## 项目结构

```
desktop-pet/
├── addons/
│   └── http_event_source/        # SSE 流式传输插件（第三方）
├── Character/
│   └── idle/                     # 猫娘待机动画帧（122 帧 PNG）
├── data/
│   ├── config.json               # 全局配置（API、System Prompt）
│   └── message_history.json      # 对话历史存档
├── scenes/
│   ├── character/
│   │   └── character.tscn        # 主窗口场景（桌面宠物本体）
│   ├── chat_dialog/
│   │   ├── chat_window.tscn      # 聊天子窗口
│   │   ├── chat_dialog.tscn      # 聊天界面 UI
│   │   └── bubble.tscn           # 聊天气泡
│   └── script/
│       ├── character.gd          # 主窗口脚本
│       ├── chat_dialog.gd        # 聊天界面脚本
│       ├── bubble.gd             # 聊天气泡脚本
│       └── Global/
│           ├── global_init.gd    # 全局初始化（加载配置）
│           ├── message_manage.gd # 消息管理（历史、发送组装）
│           └── LLM_request.gd    # LLM API 请求（流式+非流式）
└── project.godot
```

---

## 已实现的功能

### 1. 桌面宠物窗口
- **无边框透明窗口**，始终置顶，300×500 尺寸
- **右键菜单**：退出 / 设置（设置尚未实现）
- **动画**：AnimatedSprite2D 播放猫娘待机动画

### 2. 窗口拖拽
- 鼠标左键拖拽移动窗口
- 15px 拖拽阈值防误触
- 窗口限定在屏幕范围内（基于 `screen_size`）
- 右键点击弹出菜单（`PopupMenu`）

### 3. 聊天子窗口
- 点击宠物 → 弹出/隐藏聊天窗口（toggle）
- 子窗口为 `transient`，不在任务栏显示独立图标
- 根据主窗口位置自动选择放在左侧或右侧
- 纵向与主窗口居中对齐

### 4. AI 对话（DeepSeek API）
- **双模式支持**：流式（SSE）和非流式（HTTP POST）
- 通过配置 `USE_STREAM` 开关切换
- 流式使用 `HTTPEventSource` 插件解析 SSE
- 每条消息自动保存历史

### 5. 对话历史
- 消息存储在 `data/message_history.json`
- 启动时自动加载历史
- 每次发送用户消息时追加到历史
- AI 回复通过 `response_complete` 信号自动存入
- 程序退出时自动保存

### 6. System Prompt
- 从 `config.json` 读取 `MESSAGE_CONFIG`
- 支持 `POSITION: SYSTEM` 的消息插入到消息数组开头
- 其他位置预留接口

---

## 信号体系

| 信号 | 所属 | 参数 | 用途 | 连接方 |
|------|------|------|------|--------|
| `request_success` | `LlmRequest` | `ai_message` | 非流式响应完成 | `chat_dialog.get_message_from_res` |
| `stream_event` | `LlmRequest` | `chunk: String` | 流式每段文本 | `chat_dialog.get_stream_chunk` |
| `response_complete` | `LlmRequest` | `message: Dictionary` | 请求彻底完成（两种模式） | `message_manage.add_message`、`chat_dialog.stream_complete` |
| `request_error` | `LlmRequest` | `error_msg: String` | 请求失败 | 未连接 |

## 数据流

```
用户输入 → _send_message()
  ├─ _push_message_to_chat_box(user_msg, true)    ← 显示用户气泡
  ├─ _push_message_to_chat_box("... ...", false)   ← 显示 AI 占位气泡
  └─ MessageManage.process_message_to_send(msg)
       ├─ message_array.append(user_msg)           ← 存用户消息
       ├─ send_array = message_array.duplicate()
       ├─ send_array.push_front(system prompt)      ← 插入 System Prompt
       └─ LlmRequest.send_message(send_array)
            ├─ USE_STREAM = true → SSE 流式
            │    ├─ stream_event(chunk) → get_stream_chunk → 逐字更新气泡
            │    └─ [DONE] → response_complete → add_message 存盘
            └─ USE_STREAM = false → HTTP POST
                 └─ _on_request_completed
                      ├─ request_success → get_message_from_res → 更新气泡
                      └─ response_complete → add_message 存盘
```

---

## 配置说明 (`data/config.json`)

```json
// API_CONFIG
LLM_BASE_URL    // DeepSeek API 地址
LLM_API_KEY     // API Key
LLM_MODEL       // 模型名
USE_STREAM      // true=流式, false=非流式

// MESSAGE_CONFIG
POSITION        // 消息位置：SYSTEM（插入开头）
MESSAGE         // 消息内容，如 System Prompt
```

---

## 空函数 / 未使用

| 文件 | 函数/信号 | 状态 |
|------|----------|------|
| `chat_dialog.gd` | `stream_complete(_message)` | 只恢复 `send_stop_state`，未做其他处理 |
| `chat_dialog.gd` | `get_error_from_res(error)` | 空函数 (`pass`) |
| `LLM_request.gd` | `request_error` 信号 | 未被任何对象连接 |
| `character.gd` | `_on_menu_item_pressed` menu_id=1 | "设置"菜单项无处理 |
| `event_source_plugin.gd` | `_enter_tree()` / `_exit_tree()` | 编辑器插件钩子为空 |
| `message_manage.gd` | `add_message(message)` | 只有 `message_array.append(message)` |

---

## 接下来计划

### 1. TTS 语音 🗣️
- 接入 TTS API（如 Edge TTS 或本地引擎）
- AI 回复文本转语音播放
- 需要：新的 TTS 模块 / 信号

### 2. 记忆持久化 🧠
- 长期记忆（跨会话总结 + 存储）
- 短期记忆（当前对话上下文）
- 需要：记忆文件读写、定期摘要

### 3. 设置界面 ⚙️
- API 配置可视化编辑
- System Prompt 自定义
- TTS 开关 / 音量 / 语速
- 主题切换

### 4. 请求错误处理，对话界面停止按钮配置，对话界面消息删除按钮


---

## 技术栈

- **Godot** 4.6（.NET 不可用，纯 GDScript）
- **DeepSeek API**（兼容 OpenAI 格式）
- **HTTPEventSource** 插件（SSE 流式传输）
- **Jolt Physics**（3D 物理引擎，项目启用但未使用）

## 运行方式

1. 确保 `data/config.json` 中 API Key 有效
2. 按 F5 运行项目（独立 OS 窗口）
3. 点击猫娘弹出聊天窗口
4. 输入文字开始对话
