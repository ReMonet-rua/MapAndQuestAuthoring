# Quest Editor

Quest Editor is the task and dialogue-flow plugin in the **Map & Quest Authoring** suite (version 0.3.1).

## Installation

Install both `addons/quest_authoring` and the shared `addons/level_authoring` folder from the release bundle. Enable or disable **Quest Editor** independently in **Project > Project Settings > Plugins**. The Map Editor plugin does not need to be enabled.

Quest Editor stores resources in `res://data/quests` and checks dialogue CSV files in `res://data/dialogues`. These directories are created when needed.

The editor supports start, dialogue, objective, condition, action, and complete nodes. Condition nodes have true/false branches. Flow checks report duplicate or missing IDs, dangling links, unreachable nodes, and missing condition, action, or dialogue configuration.

Quest nodes are authoring data. Runtime quest execution and state/action dispatch must be provided by the host game.
