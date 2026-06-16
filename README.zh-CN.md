# iterative-improve

[English](README.md) | 中文

`iterative-improve` 是一个通用的、支持 gate 的 Agent Skill，用于约束 AI Agent 的循环优化流程。它会引导 Agent 先发现项目规则，再按轮次进行计划、隔离开发、执行、验证、审查、记录结果，并决定继续、转向或停止。

这个 Skill 不绑定任何具体项目、指标、分支名、目录结构或工具厂商。

## 功能

它会引导 Agent 执行以下闭环：

1. 发现本地项目规则和 gate。
2. 在修改文件前先写计划。
3. 按项目要求使用隔离机制，例如 Git worktree。
4. 每轮只实现当前计划中的改动。
5. 用真实命令和真实输出进行验证。
6. 审查结果并记录发现。
7. 决定继续、调整方向或停止。

适合用于重构、迁移、策略实验、报告生成流程、数据处理流程、质量改进循环等任务，尤其适合那些不适合让 Agent “一路乱修”的复杂工作。

## 安装

### Codex

将仓库克隆到 Codex skills 目录：

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/Heller2333/iterative-improve.git ~/.codex/skills/iterative-improve
```

后续更新：

```bash
git -C ~/.codex/skills/iterative-improve pull
```

### Claude Code

将仓库克隆到 Claude Code skills 目录：

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/Heller2333/iterative-improve.git ~/.claude/skills/iterative-improve
```

后续更新：

```bash
git -C ~/.claude/skills/iterative-improve pull
```

### 手动复制

也可以直接复制到你的 Agent 支持的 skills 目录：

```bash
cp -R iterative-improve ~/.codex/skills/iterative-improve
```

## 使用方式

可以这样要求 Agent：

```text
Use /iterative-improve to improve the report generation pipeline.
Goal: reduce noisy output and improve verification.
Max rounds: 3.
```

中文示例：

```text
使用 /iterative-improve 对数据处理模块做循环优化。
目标：提升稳定性和可验证性。
最多 3 轮。
```

或者：

```text
开始循环优化：认证模块稳定性改进
目标：遵守项目规则，每轮写 plan 和 result，最多 2 轮。
```

## 项目约定

这个 Skill 不要求固定目录结构。它会要求 Agent 先检查当前项目已有规则，例如：

- `AGENTS.md`、`CLAUDE.md` 或其他 Agent 指令。
- 项目中的 hooks、gate 或 wrapper 脚本。
- 已有的 `plans/`、`results/` 或报告目录。
- README、CI、包配置或脚本中的测试命令。
- Git worktree、分支、提交、合并、清理规则。

如果项目本地规则比这个 Skill 更严格，应优先遵守项目本地规则。

## Gate 机制

有些项目会通过 hooks 或 wrapper 脚本强制执行流程 gate。这个 Skill 会要求 Agent 尊重这些 gate，而不是绕过它们。

常见 gate 行为包括：

- 没有计划前不允许改代码。
- 没有成功退出 Plan Mode 前不允许执行。
- 计划批准后不允许在主 worktree 直接改代码。
- 没有验证和结果文件前不允许合并或清理。

如果项目没有 gate，Agent 也应该手动遵守同样的纪律。

## 仓库结构

```text
iterative-improve/
├── SKILL.md          # Agent Skill 主体
├── README.md         # 英文说明
├── README.zh-CN.md   # 中文说明
└── LICENSE           # MIT License
```

## 隐私

这个仓库面向公开发布。Skill 不包含私人项目路径、凭据、API key、数据文件或个人运行状态。发布前仍建议扫描本地路径和敏感信息。

## 许可证

MIT。见 [LICENSE](LICENSE)。
