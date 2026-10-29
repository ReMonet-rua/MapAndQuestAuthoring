# Map & Quest Authoring

Godot 地图与任务编辑工具，目前仅在 Godot 4.7.2 验证。源码采用 [MIT 许可证](LICENSE)。

## 安装

1. [下载 v0.3.0 插件包](https://github.com/ReMonet-rua/MapAndQuestAuthoring/releases/download/v0.3.0/MapAndQuestAuthoring-0.3.0.zip)。
2. 在 Godot 编辑器打开目标项目，进入 **AssetLib > Import**，选择下载的 ZIP，并在安装窗口点击 **Install**。
3. 打开 **Project > Project Settings > Plugins**，按需启用 **Map Editor**、**Quest Editor**；两者可以单独开关。

安装时请保留 `addons/level_authoring` 和 `addons/quest_authoring` 两个目录。Quest Editor 使用前者中的共享任务资源代码，但不要求启用 Map Editor。需要运行跨地图传送时，将 `addons/level_authoring/runtime/level_authoring_world_manager.gd` 以 `LevelWorldManager` 名称添加到 **Project Settings > Globals > Autoload**。

如果 AssetLib 无法导入该 ZIP，可手动解压，并将包内的 `addons` 文件夹合并到项目根目录。本包是插件包，不是完整 Godot 项目；不要从项目管理器的“导入项目”入口打开。

## 功能介绍

- **Map Editor**：创建地图；搜索、筛选并拖放素材；绘制瓦片；编辑传送点；查看地图连接图并检查地图配置。
- **Quest Editor**：用节点和连线编辑任务；配置条件、动作和对话引用；检查流程断链和不可达节点。
- **NPC 对话**：编辑 CSV 对话文件，可使用 Excel、LibreOffice 或文本编辑器。

编辑器负责地图、任务和对话内容的编辑与结构检查；任务执行、状态变化和对话分支需由宿主游戏接入。素材库以占位场景为主，战斗、移动和存档等玩法也需由游戏实现。

## 使用方式

**搭建地图：** 打开或新建地图，在“关卡搭建”Dock 的“素材”页选择素材并拖到 2D 视图。用“地图连接图”查看地图间传送关系，在“校验”页检查地图设置。

**编辑任务：** 启用 Quest Editor，在右侧“任务编辑器”Dock 新建或打开任务，添加节点并连接端口。选中节点填写条件、动作或对话引用，完成后点击“检查流程”。

**编辑 NPC 对话：** 在 Map Editor 的“对话”页选择 NPC，点击“编辑选中 NPC 对话”，再用表格软件编辑生成的 CSV 文件。

任务资源保存在 `res://data/quests`，NPC 对话 CSV 保存在 `res://data/dialogues`；目录会按需创建。
