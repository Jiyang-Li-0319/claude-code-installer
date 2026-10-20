# Claude Code Windows 一键安装（国内可用）

在 Windows 10/11 上安装 [Claude Code](https://claude.com/claude-code)，并把它配置成调用国内可直接访问的
**Anthropic 兼容端点**（DeepSeek / Kimi / 智谱 GLM / 通义千问 / MiniMax / OpenRouter）。

适用于这类报错：

```
Unable to connect to Anthropic services
Failed to connect to api.anthropic.com: Status 403
```

这不是网络故障，而是 Anthropic 对部分地区的服务端限制。把请求指向第三方兼容端点即可正常使用。

> **非官方项目**：本项目与 Anthropic 无关联，未获得其授权或认可。项目不包含、不分发任何
> Anthropic 的软件或源代码；Claude Code 由使用者自己的电脑通过 npm 获取。
> 使用本项目即表示你理解并自行承担遵守 Anthropic 服务条款、所用模型厂商条款
> 及所在地法律法规的责任。

## 快速开始

1. 下载并解压 [`ClaudeCode-Installer.zip`](ClaudeCode-Installer.zip)
   到一个普通目录，例如 `C:\ClaudeCode-Installer`
   （**不要**在压缩包预览窗口或微信/QQ 接收文件目录里直接运行）
2. 双击 `install-claude-code.bat`
3. 按提示选择模型厂商（默认 DeepSeek），粘贴该厂商的 API Key
4. 看到 `Success! Claude Code is ready.` 即完成
5. 新开一个 cmd 窗口，运行 `claude`

以后只想换模型，双击 `switch-provider.bat`，不必重装。

## 支持的厂商

| 厂商 | Base URL | 备注 |
|---|---|---|
| DeepSeek | `https://api.deepseek.com/anthropic` | 国内直连，推荐 |
| Kimi / Moonshot | `https://api.moonshot.cn/anthropic` | |
| 智谱 GLM | `https://open.bigmodel.cn/api/anthropic` | |
| 通义千问 | `https://dashscope.aliyuncs.com/apps/anthropic` | `sk-` / `sk-sp-` 对应不同端点 |
| MiniMax | `https://api.minimax.cn/anthropic` | |
| OpenRouter | `https://openrouter.ai/api` | 一个 Key 调多家模型 |
| Anthropic 官方 | — | 需 Claude 账号，国内需代理 |

模型 ID 和端点会变化，使用前请以厂商官方文档为准。完整说明见
[`使用说明.md`](使用说明.md)。

## 出问题时

双击 `diagnose.bat`。它会打印：

- `claude` 的实际路径和版本
- `settings.json` 里生效的 `ANTHROPIC_BASE_URL` / 模型（Key 已打码）
- 系统环境变量是否覆盖了配置
- 各厂商端点的连通性
- 一条真实测试请求
- 完整报告保存为 `diagnose-report-*.txt`

两个最常见的问题：

- **编译报错 `apply-settings.ps1 不存在`**：`.bat` 运行目录里缺少配套脚本，
  把整个文件夹解压到普通目录再运行。
- **仍然 403 `api.anthropic.com`**：没有配置第三方端点，重新运行
  `switch-provider.bat`，选 1 并粘贴 Key，然后**新开**终端。

## 安全

- 脚本本身**不包含任何 API Key**。
- Key 只会写入 `%USERPROFILE%\.claude\settings.json`，明文保存，请勿提交到 Git 或发到群里。
- `apply-settings.ps1` 在修改前会自动备份原 `settings.json`。

## 文件说明

| 文件 | 用途 |
|---|---|
| `install-claude-code.bat` | 安装 + 选择厂商 + 写配置 + 连通性测试 |
| `switch-provider.bat` | 只改模型配置，不重装 |
| `apply-settings.ps1` | 合并写入 `settings.json`，自动备份 |
| `install-node.ps1` | 自动安装 Node.js LTS |
| `test-connection.ps1` | 带硬超时的连通性测试 |
| `diagnose.bat` / `diagnose.ps1` | 只读诊断 |
| `使用说明.md` | 完整文档 |
| `ClaudeCode-Installer.zip` | 上述文件的打包，方便直接发给别人 |

## 免责声明

- 本项目是个人编写的非官方配置工具，与 Anthropic 不存在隶属、合作、赞助或授权关系，
  也不代表 Anthropic 的立场。
- 仓库不包含、不分发 Claude Code 或其他 Anthropic 软件、源代码、账号或密钥。
  安装过程中的下载行为发生在使用者自己的电脑上。
- Claude Code 由 Anthropic 提供并受其服务条款约束；各地区是否可用以 Anthropic 官方公布的
  [supported countries](https://anthropic.com/supported-countries) 为准。
- 各模型厂商的 API 端点、模型名称、可用性与计费由对应厂商负责，使用时请遵守其条款。
- 本项目按 MIT 协议"按原样"（AS IS）提供，不对可用性、合规性或使用结果作任何担保。

## License

[MIT](LICENSE)
