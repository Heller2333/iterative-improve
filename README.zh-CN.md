# iterative-improve

[English](README.md) | 中文

一个用于循环优化工作的强制 gate Agent Skill：先激活 gate，再计划，隔离高风险改动，用真实命令验证，记录结果，谨慎提交，合并，清理，然后再决定是否继续下一轮。

它不绑定具体仓库。适合重构、迁移、策略实验、报告生成流程、数据工作流、质量改进循环，以及任何不希望 AI coding agent 一路跑偏的任务。

## 快速开始

告诉你的 AI coding agent：

> “Install https://github.com/Heller2333/iterative-improve in this project. Set up the required Claude Code gate hooks so iterative-improve requests must plan first, use worktree or branch isolation, verify changes, write result artifacts, commit, merge, and clean up. Read the AGENTS.md for the full technical reference on how everything works.”

Agent 会执行：

1. 在目标项目根目录运行 `install.sh`。
2. 将 `scripts/claude-code-gate.sh` 复制到 `.claude/hooks/`。
3. 把必需的 hook 配置合并进 `.claude/settings.json`。
4. 将 `.scratch/agent-state/` 加入 `.gitignore`。
5. 如果 gate 不能安装或激活，就拒绝继续执行 `/iterative-improve` 的实施步骤。

在目标项目中直接安装：

```bash
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/main/install.sh | bash
```

或者从本地 clone 安装：

```bash
git clone https://github.com/Heller2333/iterative-improve.git /tmp/iterative-improve
bash /tmp/iterative-improve/install.sh
```

后续检查更新：

```bash
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/main/install.sh | bash -s -- --check
```

更新项目 hook：

```bash
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/main/install.sh | bash -s -- --update
```

之后可以这样启动循环：

```text
Use /iterative-improve to improve the report generation pipeline.
Goal: reduce noisy output and improve verification.
Max rounds: 3.
```

中文提示也可以：

```text
使用 /iterative-improve 对数据处理模块做循环优化。
目标：提升稳定性和可验证性。
最多 3 轮。
```

## 工作方式

```text
触发提示
  -> 读取项目规则
  -> 激活必需 gate
  -> 分析上一轮结果，首轮除外
  -> 规划一轮任务
  -> 批准计划/退出计划阶段
  -> 创建隔离 worktree 或分支
  -> 实施计划中的改动
  -> 用真实命令验证
  -> 写结果文件
  -> 提交、合并、清理
  -> 决定是否继续
```

- `SKILL.md` 教 Agent 按循环优化流程工作。
- `scripts/claude-code-gate.sh` 是这个流程在 Claude Code 中必需的 gate hook。
- gate 的临时状态保存在目标项目的 `.scratch/agent-state/` 下。
- gate 是通用脚本，可通过环境变量配置；项目特定规则应写在目标项目自己的说明文件中。

## 强制 Gate 合约

使用这个 Skill 时，流程必须运行在 gate 约束下。在 Claude Code 中，需要安装并启用 `scripts/claude-code-gate.sh`。在其他环境中，也必须先使用等价的阻断机制，然后才能执行任何会修改项目的循环优化步骤。

gate 会阻断：

- 没有计划前修改代码。
- 计划未批准前执行改动或验证命令。
- 计划批准后仍在主 worktree 直接编辑。
- 在非允许的优化分支或 worktree 模式下执行 merge/cleanup。
- 计划缺少目标、轮次、worktree 或分支隔离、验证、具体结果文件路径、提交、合并、清理等关键项时退出 Plan Mode。
- 第 2 轮及以后，如果计划没有分析并引用上一轮 result 文件，则阻止退出 Plan Mode。

公开默认命名策略使用 `improve/*` 分支和 `<repo>-improve-*` worktree，同时兼容旧的 `opt/*` 分支和 `<repo>-opt-*` worktree。

如果 gate 不能安装或激活，Agent 可以检查文件并说明缺少的设置，但不能继续进入循环优化实施阶段。

## 手动安装

安装 skill 目录只会让 agent 能发现这套说明。真正执行 `/iterative-improve` 前，项目级 gate hook 仍然必须安装。

### Codex

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/Heller2333/iterative-improve.git ~/.codex/skills/iterative-improve
```

后续更新：

```bash
git -C ~/.codex/skills/iterative-improve pull
```

### Claude Code

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/Heller2333/iterative-improve.git ~/.claude/skills/iterative-improve
```

后续更新：

```bash
git -C ~/.claude/skills/iterative-improve pull
```

### 必需 Claude Code Hook

推荐的项目级安装方式：

```bash
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/main/install.sh | bash
```

installer 会：

- 依赖 `jq`；缺少 `jq` 时停止并提示安装。
- 只修改当前项目。
- 写入前备份 `.claude/settings.json`。
- 用 `jq` 非破坏性合并 hook 配置。
- 安装 `.claude/hooks/iterative-improve-gate.sh`。
- 将安装元数据写入 `.claude/iterative-improve.json`。
- 按需追加 `.scratch/agent-state/` 到 `.gitignore`。

也可以手动安装 hook：

```bash
mkdir -p .claude/hooks
cp ~/.codex/skills/iterative-improve/scripts/claude-code-gate.sh .claude/hooks/iterative-improve-gate.sh
chmod +x .claude/hooks/iterative-improve-gate.sh
```

然后将 [AGENTS.md](AGENTS.md) 中的 hooks 配置加入 `.claude/settings.json`。

需要取消循环时重置 gate：

```bash
bash .claude/hooks/iterative-improve-gate.sh --reset
```

卸载项目 hook：

```bash
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/main/install.sh | bash -s -- --uninstall
```

固定使用某个 release 或分支：

```bash
ITERATIVE_IMPROVE_REF=v0.3.1 \
curl -fsSL https://raw.githubusercontent.com/Heller2333/iterative-improve/v0.3.1/install.sh | bash
```

## 关键文件

```text
iterative-improve/
├── SKILL.md                       # Agent Skill 主体
├── AGENTS.md                      # 给 coding agent 的技术参考
├── README.md                      # 英文说明
├── README.zh-CN.md                # 中文说明
├── VERSION                        # 当前发布版本
├── install.sh                     # 项目级安装/卸载脚本
├── scripts/
│   └── claude-code-gate.sh        # 必需 Claude Code gate hook 模板
└── LICENSE                        # MIT License
```

## 技术参考

见 [AGENTS.md](AGENTS.md)，其中包含 hook 配置、安装细节、环境变量、状态文件、计划要求和排错说明。

## 隐私

这个仓库面向公开发布，不包含私人项目路径、凭据、API key、数据文件或个人运行状态。发布前仍建议扫描本地路径和敏感信息。

## 许可证

MIT。见 [LICENSE](LICENSE)。
