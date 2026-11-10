# ShyProject coding profile

一个按“续航优先”取舍的 sway + Neovim 工作环境。和 KDE 并存：登录界面选 sway，
随时切回；不新增、不修改 KDE 的配置。

全终端：编辑器、文件管理、解压、搜索、agent 都在终端里，唯一的 GUI 应用是
Firefox。

## 安装

```sh
sudo ./install.sh
```

脚本读 [packages.txt](packages.txt) 装系统包、把本目录软链到
`~/.config`、把 `bin/` 里的脚本链到 `~/.local/bin`、写 `~/.shycserver/config.toml`
（语言服务器用）。重复执行安全；已存在的真实文件会备份成
`<name>.before-shy-code.<时间戳>`。

软件清单就在 [packages.txt](packages.txt)：每行一个包，行尾注释写用途，
`install.sh` 直接读它，所以只有这一份列表。

本目录可以整体挪走（例如 `~/shy-code`），在新位置重跑 `install.sh` 即可。

回退：删掉 `~/.config/{sway,kitty,foot,nvim,lf}`、`~/.vimrc` 里的软链，
把 `*.before-shy-code.*` 改回原名。

## 键位

桌面（sway）：

| 键 | 作用 |
|---|---|
| `Ctrl+Alt+←/→` | 切换工作区 |
| `Ctrl+Shift+←/→` | 把窗口移到相邻工作区 |
| `Ctrl+Alt+t` / `Mod+Return` | 终端 |
| `Ctrl+Shift+X` | 关窗口 |
| `Ctrl+f` | 文件搜索（浮动窗口里的 fzf） |
| `Ctrl+Shift+F` | 工作区内容搜索 |
| `Ctrl+Shift+c/v` | 终端里复制/粘贴（kitty 自己处理，sway 不绑） |
| `Mod+r` | 应用启动器（fuzzel） |
| `Mod+Shift+R` / `Mod+Escape` | 重载配置 / 锁屏 |
| `Ctrl+Shift+P` | 截图：原生框选（slurp）→ 剪贴板 |
| `Mod+方向键` | 切换焦点 |
| `Mod+Shift+方向键` | 在当前工作区内移动窗口（换位置） |
| `Mod+Ctrl+方向键` | 移动分界线（方向与按键一致，不随焦点在哪侧翻转） |
| `Mod+拖动` / `Mod+右键拖` / `Mod+中键` | 鼠标移动 / 缩放 / 浮动 |
| `Mod+w` / `Mod+s` | 当前工作区改成标签 / 堆叠布局 |
| `Mod+b` / `Mod+v` / `Mod+e` | 左右切 / 上下切 / 切换切分方向 |

`Mod` 是 Super。新窗口默认**上下切分**（`default_orientation vertical`），不会把旁边的
窗口横向越挤越窄；要并排就 `Mod+b`，要标签就 `Mod+w`。
内置屏幕 `eDP-1` 默认 1.5 倍缩放，可在 sway 配置中调整。
`Ctrl+f`、`Ctrl+Shift+f`、`Ctrl+x` 是全局键，所以编辑器里刻意
不用这几个键：搜索用 `Ctrl+p` / `Ctrl+g`，关窗用 `:q`。

编辑器（Neovim，`vim` 也是它）：

| 键 | 作用 |
|---|---|
| `Ctrl+p` / `Ctrl+g` | 文件搜索 / 内容搜索（浮动 fzf，选中即打开） |
| `Ctrl+s` | 保存（`~/.zshrc` 里关了 XOFF，否则会被终端吃掉） |
| `Ctrl+z` / `Ctrl+y` | 撤销 / 重做 |
| `Ctrl+t` / `:Agent` | 在当前编辑器里开一个 agent 终端 |
| `Tab` | 接受 AI 补全；没有补全时就是 Tab |
| `Ctrl+Space` | LSP 补全弹窗（手动触发） |
| `gd` / `F12` / `K` / `F2` | 跳定义 / 悬停 / 符号列表 |
| `F8` / `Shift+F8` | 下一个 / 上一个诊断 |
| 方向键 | 移动（hjkl 也能用，但没有任何地方依赖它） |

相对行号默认开；退出终端模式按 `Esc`。

## 省电是从哪省出来的

每一条都是可验证的“少一次定时器 / 少一次重绘 / 少一次编译”：

- **时钟只到分钟**：`bin/shybar` 对齐整分 `sleep`，一天唤醒 1440 次而不是 86400 次；
  bar 上只有时间和电量，没有秒。
- **光标不闪**：foot 默认光标每 ~500 ms 重绘一次，kitty 也一样；两边都关掉了闪烁。
- **终端是 kitty**：选它是因为 kitty 图形协议能显示全分辨率图片；
  foot 仍然装着（`$term` 改回 `foot` 即恢复），它是纯 CPU 渲染、更省的那一档。
- **合成器不做事**：纯色背景、无动画、无挂件、无 tray；窗口边框 2px。
- **空闲梯子**：5 分钟关显示器，10 分钟锁屏，睡眠前锁屏。
- **Neovim 零插件**：没有插件管理器、没有 tree-sitter 常驻解析，实测启动
  ~35 ms；node/perl/ruby/python provider 全部关掉。
- **LSP 不抢输入**：补全弹窗改成手动（`Ctrl+Space`），不在每个 `.`/`:`/`>` 上
  弹；诊断只在停手后跑一次编译探针。
- **AI 补全按停顿触发**：700 ms 防抖、同时只允许一个请求在飞、`max_tokens=48`、
  `reasoning_effort=none`（deepseek-flash 默认会先思考，实测 24 token 全花在
  reasoning 上、正文为空）。
- **Firefox**：关动画/平滑滚动/遥测/prefetch，保留硬件视频解码，内容进程限制 4 个。
- 电源配置本身用 `power-profiles-daemon` 的 `power-saver`（你原来就在用）。

## ShyC 支持

- 文件类型：`.shyc` / `.shyh` → `shyc`，`.shy` → `shyasm`。
- 高亮两层：`syntax/shyc.vim` 正则（关键字、类型、字符串、注释、预处理、属性），
  加上 `shyc-lsp` 的**语义 token**（按符号着色，只算可见区）。
- 语言服务器：跳定义、悬停、符号列表、补全、诊断。配置在
  `~/.shycserver/config.toml`（`libshy_path`）。
- AI 补全的上下文：先放固定指令，再放本文件 `#include` / `use` 到的头文件全文
  （各最多 120 行、总量 12k 字符），最后才是光标附近的代码。头文件块放在
  **最前面**是有意的——作为稳定前缀复用 provider 的 prompt cache。实测同一
  前缀第二次请求 `prompt_cache_hit_tokens=1024/1245`。

## Agent

默认 `codex`。`ai` 是统一包装器，编辑器里的 `:Agent` 和 shell 里都调它：

```sh
ai                      # 默认 agent（codex）
ai -a crush             # 换一个跑一次
SHY_AGENT=crush ai      # 整个会话换掉
```

实测（同一句“回 ok”，本机）：

| agent | 运行时 | 单轮 CPU | 峰值内存 | 安装体积 |
|---|---|---|---|---|
| crush | Go | 0.43 s | 101 MB | 129 MB |
| codex | Rust（node 壳启动） | 1.6 s | 327 MB | 411 MB |
| dsh | Node | 3.9 s | 214 MB | 496 MB |
| claude | 原生二进制 | 1.7 s | 351 MB | — |

crush 最省，codex 最熟；默认取 codex，需要抠续航时 `ai -a crush`。

codex 两个 provider 都配在 `~/.codex/config.toml`：默认 `deepseek` 官方，`codex -p go`
走 OpenCode Go（`~/.codex/go.config.toml`，base URL 是 `/inference/go/openai/v1` 的
Responses 接口，key 读 `OPENCODE_GO_API_KEY`）。provider 的显示名设成了
`opencode/deepseek-flash`，所以切换后界面上看到的就是这个名字。

Go 的 key 已实测可用（`codex -p go` 回话正常）。`/model` 里只有 codex 自带的 11 个模型（`codex debug models` 输出的静态目录），
自定义 provider 的模型不会进那个列表；切 provider 用 `-p`/profile，不是 `/model`。

`AGENTS.md`（编程标准）在本目录留了一份版本化副本，`install.sh` 把它链到
`~/.codex/AGENTS.md`，也就是 codex 的全局指令文件。dsh 读的仍是
`~/.dsh/AGENTS.md`；想让两个 agent 只用一份，把后者也链到
`profile/AGENTS.md` 即可。

`crush` 也支持 OpenCode Go（配置项 `extra_headers` 能带 `x-opencode-session`）：

```json
{
  "providers": {
    "opencode-go": {
      "type": "openai",
      "base_url": "https://opencode.ai/inference/go/openai/v1",
      "api_key": "<console 里的 key>",
      "extra_headers": { "x-opencode-session": "shy-profile" },
      "models": [{ "id": "deepseek-v4.1-flash" }]
    }
  },
  "models": {
    "large": { "provider": "opencode-go", "model": "deepseek-v4.1-flash" },
    "small": { "provider": "opencode-go", "model": "deepseek-v4.1-flash" }
  }
}
```

## 搜索、文件、解压

- `Ctrl+f` / `Ctrl+Shift+F`：浮动 kitty 里的 fzf + fd / ripgrep，选中后在新窗口用
  Neovim 打开（搜索窗口不会连带关掉编辑器）。搜索目录取**当前焦点终端里 shell 的
  工作目录**，在该目录是 git 仓库时向上取仓库根；设 `SHY_SEARCH_ROOT` 可固定到一个
  目录（见 `environment.d/90-shycode.conf`）。
- `lf`：终端文件管理器（方向键、`Enter` 打开、`e` 编辑、`x` 解压、`q` 退出）。
- `x ARCHIVE...`：`bin/shy-extract`，覆盖 tar.{gz,xz,zst,bz2}、zip、7z、rar、gz、
  xz、zst。
## 解锁后看到的样子

- 顶部 bar：左边工作区号，右边 `15:14  64%`。
- 背景 `#101014`，编辑器背景同色，切换窗口不闪。

## 已知限制

- `Ctrl+f` 抢走了终端的 readline 前移键，`Ctrl+x` 是全局关窗。编辑器里已避让；
  如果你更想要 readline 行为，把 sway 配置里那三行 `Control+f` / `Control+x`
  换到 `$mod` 上即可。
- fcitx5 走 text-input-v3 / input-method-v2：sway 1.12 + wlroots 0.20 已提供
  `zwp_input_method_manager_v2`（`wayland-info` 实测），kitty 与 foot 都走 text-input，
  所以 Wayland 原生窗口（kitty、foot、Firefox）可直接输入；XWayland 应用靠
  `XMODIFIERS`。候选框位置如果飘，调 fcitx5 的 `Wayland` 输入法设置。
- AI 补全依赖 DeepSeek API（`~/.config/shy-code/llm.env`，权限 600，已被
  `.gitignore` 排除）。
