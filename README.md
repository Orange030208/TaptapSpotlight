# TaptapSpotlight

这是一个使用 [TapTap Maker](https://maker.taptap.cn/) 制作的项目，创作于 2026 年 7 月 17 日的“背景聚光灯”GameJam。

## 房间版面

游戏采用类似《以撒的结合》的房间图：每个房间是独立的战斗或探索空间，使用 `scripts/Data/RoomData.lua` 中的 `mapX`、`mapY` 排列在小地图上，并由 `connections` 决定可通过的门。房间内的玩法坐标为 `0..1` 的归一化空间，渲染层会将它映射到实际屏幕区域。

第一版面为出生房“初醒之间”。它没有敌人，玩家从房间下方进入；中央的温暖祭台光、两盏壁灯和浅色符纹建立安全但神秘的氛围。玩家需要先完成 W/A/S/D 移动，再用鼠标左键释放一次格挡，北/东门才会开启。两步各有一张透明 PNG 地面贴图引导，完成当前操作后会平滑淡出。出生房通过 `isBirthRoom = true` 标记，因此不会计入清理房间数，也不会触发战斗。

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

在提交游戏功能时，先使用 Maker 工作流提交并构建；需要在个人 GitHub 中保留同一游戏版本时，再执行 `git push github main`。README 等仅用于代码托管的文档更新不需要单独触发 Maker 构建。
