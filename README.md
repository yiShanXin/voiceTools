# VoiceHub

一个基于 Swift / macOS 14+ 的 menu-bar 语音输入应用：按住 `Fn` 录音，松开后自动将转录文本注入当前聚焦输入框。

## 核心特性

- 全局 `Fn` 键监听（`CGEvent tap`）
  - 按下开始录音
  - 松开结束录音并注入文本
  - 吞掉 `Fn` 事件，避免触发系统 emoji 选择器
  - 支持触发键配置：`Fn` / `Fn or Right Command` / `Right Command`
- Apple Speech Recognition 流式转录
  - 默认语言 `zh-CN`（开箱即用中文）
  - 支持语言切换：English / 简体中文 / 繁体中文 / 日本语 / 한국어
  - 语言配置保存在 `UserDefaults`
- 底部居中胶囊悬浮窗（`NSPanel + NSVisualEffectView`）
  - 无边框、无 titlebar、56px 高、圆角 28px
  - 左侧 5 条实时波形（RMS 音量驱动，非假动画）
  - 右侧实时转录文本，宽度弹性扩展（160-560px）
  - 入场/宽度变化/退场动画
  - 支持浅色/深色主题自适应，提升白天页面可读性
- 文本注入策略
  - 剪贴板写入 + 模拟 `Cmd+V`
  - 注入前检测输入法，若为 CJK 输入法先切到 ASCII（ABC/US）
  - 注入后恢复原输入法与原剪贴板内容
- LLM Refinement（OpenAI 兼容 API）
  - 菜单栏支持启用/禁用
  - Settings 可配置 `API Base URL / API Key / Model`
  - `Test` 按钮可快速验证
  - 使用“极度保守纠错”提示词，只修明显误识别

## 运行要求

- macOS 14+
- Xcode Command Line Tools（含 Swift）
- 首次运行需授权：
  - 麦克风权限
  - 语音识别权限
  - 辅助功能/输入监听权限（用于全局按键监听和模拟粘贴）

## 构建与运行

```bash
cp Makefile.local.example Makefile.local  # 首次配置本机签名（只需一次）
# 编辑 Makefile.local，将 CODE_SIGN_IDENTITY 改成你的证书名
make build    # 默认读取 Makefile.local 的签名身份
make run      # 构建后启动 app
make install  # 安装到 ~/Applications/VoiceHub.app
make clean    # 清理构建产物
```

如果你只是临时测试，也可以显式使用 ad-hoc：

```bash
make build ALLOW_ADHOC=1
```

也可临时覆盖本地配置：

```bash
make build CODE_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
```

产物路径：

- `build/VoiceHub.app`

## 使用方式

1. 启动应用后，menu-bar 出现麦克风图标。
2. 将光标聚焦到任意可输入文本的位置。
3. 按住 `Fn` 开始说话，松开 `Fn` 完成转录并自动注入文本。
4. 如启用 LLM 且配置完成，松开 `Fn` 后会先显示 `Refining...`，完成后再注入。

## LLM 设置说明

在菜单栏 `LLM Refinement -> Settings...` 中配置：

- `API Base URL`（例如 `https://api.openai.com/v1` 或兼容服务地址）
- `API Key`
- `Model`（例如 `gpt-4o-mini`）

说明：

- API Key 输入框支持清空。
- 若未启用或未完成配置，系统会直接使用原始转录文本注入。

## 项目结构

```text
Sources/VoiceToolsApp/
  main.swift
  AppController.swift
  FnKeyMonitor.swift
  AudioTranscriber.swift
  OverlayPanelController.swift
  WaveformView.swift
  TextInjector.swift
  InputSourceManager.swift
  LLMRefiner.swift
  SettingsWindowController.swift
  AppConfig.swift
  LanguageOption.swift
Package.swift
Info.plist
Makefile
```

## 备注

- 应用以 `LSUIElement` 模式运行（仅菜单栏图标，无 Dock 图标）。
- 当前全局 `Fn` 监听依赖系统辅助功能相关权限；若未授权，功能会受限。
