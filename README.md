# Map & Quest Authoring

Godot 地图与任务编辑工具，已在 Godot 4.7.2 验证。

## 安装

1. [下载 v0.3.0 插件包](https://github.com/ReMonet-rua/MapAndQuestAuthoring/releases/download/v0.3.0/MapAndQuestAuthoring-0.3.0.zip)，解压到 Godot 项目根目录。
2. 保留 `addons/level_authoring` 和 `addons/quest_authoring` 两个目录。
3. 在 **Project > Project Settings > Plugins** 中按需启用 **Map Editor**、**Quest Editor**，可以单独开关。

Quest Editor 使用共享目录中的任务资源代码，但不要求启用 Map Editor。需要运行跨地图传送时，再将 `addons/level_authoring/runtime/level_authoring_world_manager.gd` 以 `LevelWorldManager` 名称添加到 **Project Settings > Globals > Autoload**。

## 功能介绍

- **Map Editor**：创建地图；搜索、筛选并拖放素材；绘制瓦片；编辑传送点；查看地图连接图并检查地图配置。
- **Quest Editor**：用节点和连线编辑任务；配置条件、动作和对话引用；检查流程断链和不可达节点。
- **NPC 对话**：编辑 CSV 对话文件，可使用 Excel、LibreOffice 或文本编辑器。

任务条件和动作的实际游戏效果需由宿主游戏接入。

## 使用方式

**搭建地图：** 打开或新建地图，在“关卡搭建”Dock 的“素材”页选择素材并拖到 2D 视图。用“地图连接图”查看地图间传送关系，在“校验”页检查地图设置。

**编辑任务：** 启用 Quest Editor，在右侧“任务编辑器”Dock 新建或打开任务，添加节点并连接端口。选中节点填写条件、动作或对话引用，完成后点击“检查流程”。

**编辑 NPC 对话：** 在 Map Editor 的“对话”页选择 NPC，点击“编辑选中 NPC 对话”，再用表格软件编辑生成的 CSV 文件。
