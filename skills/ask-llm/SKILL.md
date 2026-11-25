---
name: ask-llm
description: 管理 LLM provider（OpenAI / Responses / Anthropic）与模型目录，并向指定 provider/model 提问。当需要配置 API、拉取模型列表、登记模型说明，或调用不同厂商的模型做问答时使用；通过 thinking 强度而非 temperature 控制推理。
---

# Ask LLM

<!-- AGENT SAFETY: 用户要求创建个人自用的 ask-llm 技能（provider/model 管理与问答） -->

## 用途

用 `scripts/ask_llm.py` 维护 `~/.config/ask-llm/config.yaml`，完成配置 provider、拉取模型列表、向 `provider/model` 提问三件事。配置路径可用 `ASK_LLM_CONFIG` 环境变量覆盖。

## 配置文件

```yaml
providers:
  deepseek:
    type: openai          # openai | response | anthropic
    base: https://api.deepseek.com
    apikey: sk-xxx
    model_list: []        # 由 models 子命令填充
models:
  deepseek/deepseek-chat:
    desc: 通用对话
```

`base` 自动补全：已经写全端点（`.../chat/completions`、`.../responses`、`.../messages`）则原样使用；否则按 `type` 补 `/v1/chat/completions`、`/v1/responses`、`/v1/messages`。非标准路径（如 `.../v4/chat/completions`）必须写全。`type=response` 走 OpenAI Responses 接口。

## 命令

脚本路径 `<skill>/scripts/ask_llm.py`，下文记作 `$S`。

- `$S list` — 查看当前配置；输出含 apikey，不要回显给用户。
- `$S provider <name> <openai|response|anthropic> <base> <apikey>` — 新增或覆盖 provider。
- `$S models <provider>` — 拉取 `/models`，写入 `model_list` 并打印模型 id。
- `$S model <provider/model> <desc>` — 登记模型说明；provider 必须已存在。
- `$S ask <provider/model> <question> [off|low|medium|high]` — 提问，默认 `medium`。

`ask` 只设置 thinking 强度，不设置 temperature：

- `openai` → `reasoning_effort`
- `response` → `reasoning.effort`
- `anthropic` → `thinking.budget_tokens`（`off` 时整个字段省略）

输出预算固定为 96k（`MAX_TOKENS = 96 * 1024`）：`openai` / `anthropic` 用 `max_tokens`，`response` 用 `max_output_tokens`；不再把输出上限绑在 thinking 预算上。

强度选择约定：`carbon` 问普通决策用 `low`，复杂决策用 `medium`；写作模型默认 `medium`。

若模型不支持推理参数而返回 400，用 `off` 重试。

## 流程

1. 拿到 API 信息后先执行 `provider` 写配置，再执行 `models` 拉取模型。
2. 从模型 id 中挑选，用 `model` 登记说明：`<provider>/<model>` 斜杠前是配置名，斜杠后是真正传给 API 的模型 id。
3. 提问用 `ask`；用户没指定强度时用 `medium`，明确要求不推理时用 `off`。
4. 参考 `config.example.yaml` 可快速手工建配置。
