# iterative-improve

[English](README.md) | 中文

一个用于循环优化工作的受控 Agent Skill：先计划，隔离高风险改动，用真实命令验证，记录结果，谨慎提交，合并，清理，然后再决定是否继续下一轮。

它不绑定具体仓库。适合重构、迁移、策略实验、报告生成流程、数据工作流、质量改进循环，以及任何不希望 AI coding agent 一路跑偏的任务。

## 快速开始

告诉你的 AI coding agent：

> “Clone https://github.com/Heller2333/iterative-improve into this project. Install the iterative-improve skill for my coding agent and set up the optional Claude Code gate hooks so iterative-improve requests must plan first, use worktree or branch isolation, verify changes, write result artifacts, commit, merge, and clean up. Read the AGENTS.md for the full technical reference on how everything works.”

Agent 会执行：

1. 将这个仓库克隆到当前项目中，通常命名为 `.iterative-improve/`。
2. 将 `SKILL.md` 安装到你的 agent skills 目录。
3. 将 `scripts/claude-code-gate.sh` 复制到 `.claude/hooks/`。
4. 把 hook 配置合并进 `.claude/settings.json`。
5. 把项目特定规则保留在目标项目自己的说明文件中。

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
- `scripts/claude-code-gate.sh` 是可选 Claude Code hook，会在工具调用前阻断常见跑偏行为。
- gate 的临时状态保存在目标项目的 `.scratch/agent-state/` 下。
- gate 是通用脚本，可通过环境变量配置；项目特定规则应写在目标项目自己的说明文件中。

## Gate 会约束什么

安装可选 Claude Code hook 后，它可以阻断：

- 没有计划前修改代码。
- 计划未批准前执行改动或验证命令。
- 计划批准后仍在主 worktree 直接编辑。
- 在非允许的优化分支或 worktree 模式下执行 merge/cleanup。
- 计划缺少目标、轮次、worktree 或分支隔离、验证、结果文件、提交、合并、清理等关键项时退出 Plan Mode。

也可以只使用 Markdown Skill，不安装 hook。此时 Agent 仍会按同样流程工作，只是依赖指令而不是工具层阻断。

## 手动安装

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

### 可选 Claude Code Hook

在目标项目中执行：

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

## 关键文件

```text
iterative-improve/
├── SKILL.md                       # Agent Skill 主体
├── AGENTS.md                      # 给 coding agent 的技术参考
├── README.md                      # 英文说明
├── README.zh-CN.md                # 中文说明
├── scripts/
│   └── claude-code-gate.sh        # 可选 Claude Code hook 模板
└── LICENSE                        # MIT License
```

## 技术参考

见 [AGENTS.md](AGENTS.md)，其中包含 hook 配置、安装细节、环境变量、状态文件、计划要求和排错说明。

## 隐私

这个仓库面向公开发布，不包含私人项目路径、凭据、API key、数据文件或个人运行状态。发布前仍建议扫描本地路径和敏感信息。

## 许可证

MIT。见 [LICENSE](LICENSE)。
