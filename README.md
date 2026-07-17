# TaptapSpotlight

这是一个使用 [TapTap Maker](https://maker.taptap.cn/) 制作的项目，创作于 2026 年 7 月 17 日的“背景聚光灯”GameJam。

## 项目初始化

在一个空白的本地目录中，依次执行以下命令：

```powershell
npx -y @taptap/maker install --ide codex,cursor,claude
npx -y @taptap/maker init
```

完成 Maker 登录后，按照命令行提示选择或创建 Maker 项目即可。

## 双仓库说明

本项目同时关联了两个用途不同的 Git 远端：

| 远端 | 用途 | 何时使用 |
| --- | --- | --- |
| `origin` | TapTap Maker 项目仓库 | 提交游戏改动并触发 Maker 远程构建、预览或发布流程时使用。 |
| `github` | 个人 GitHub 仓库 | 备份、协作、代码浏览与 GitHub 上的版本管理时使用。 |

Maker 的构建提交只会推送到 `origin`，不会自动同步到 GitHub。因此每次通过 Maker 提交或构建后，还需要把同一分支推送到 GitHub：

```powershell
git push github main
```

可以用以下命令确认两个远端及同步状态：

```powershell
git remote -v
git status --short --branch
```

在提交游戏功能时，先使用 Maker 工作流提交并构建；需要同步个人 GitHub 仓库时，再执行 `git push github main`。两个远端均应保持在同一条 `main` 分支历史上。
