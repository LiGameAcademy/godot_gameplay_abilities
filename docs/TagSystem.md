# 📘 游戏标签系统使用指南 (Gameplay Tag System)

**Version:** 1.0

**Author:** 老李 (Game Academy)

## 1. 概述

游戏标签系统提供了一种**轻量级、数据驱动、高度解耦**的实体状态管理方案。它取代了传统的布尔值状态标志（如 `is_stunned`, `is_silenced`），允许开发者通过配置资源来定义无限种游戏状态，并自动处理状态的叠加（引用计数）与互斥逻辑。

### 核心特性

- **去组件化**: 不在实体上挂载专用节点，降低场景树复杂度
- **原生性能**: 利用 Godot 底层的 `Groups` 系统进行极速查询（O(1)）
- **引用计数**: 利用 `Object Metadata` 解决 Group 无法处理多重状态叠加的问题
- **表现分离**: 利用 `Resource` 定义标签的 UI 表现（图标、描述），实现逻辑与表现分离

## 2. 快速开始

### 2.1 创建标签资源

1. 在 `res://data/tags/` 目录下创建新的 `GameplayTag` 资源
2. 设置 `id`（必须全局唯一，建议使用 snake_case）
3. 配置 UI 表现（显示名称、描述、图标等）

示例：创建 `stun.tres`

```
id: "stun"
display_name: "眩晕"
description: "目标无法移动和攻击"
category: "Status"
```

### 2.2 使用标签

```gdscript
# 添加标签
TagManager.add_tag(target, &"stun")

# 检查标签
if TagManager.has_tag(target, &"stun"):
    print("目标被眩晕了")

# 移除标签
TagManager.remove_tag(target, &"stun")
```

## 3. API 参考

### 3.1 状态管理

#### `add_tag(target: Node, tag_id: StringName)`

添加标签（引用计数 +1）

```gdscript
TagManager.add_tag(player, &"stun")
```

#### `remove_tag(target: Node, tag_id: StringName)`

移除标签（引用计数 -1）

```gdscript
TagManager.remove_tag(player, &"stun")
```

#### `force_remove_tag(target: Node, tag_id: StringName)`

强制移除标签（忽略引用计数，直接移除）

```gdscript
TagManager.force_remove_tag(player, &"stun")
```

#### `clear_all_tags(target: Node)`

清除目标的所有标签

```gdscript
TagManager.clear_all_tags(player)
```

### 3.2 查询接口

#### `has_tag(target: Node, tag_id: StringName) -> bool`

检查是否有特定标签（O(1) 复杂度）

```gdscript
if TagManager.has_tag(player, &"stun"):
    # 处理眩晕逻辑
```

#### `has_any_tag(target: Node, tag_list: Array[StringName]) -> bool`

检查是否有列表中的任意标签（用于互斥/免疫检查）

```gdscript
var blocked_tags = [&"stun", &"silence", &"root"]
if TagManager.has_any_tag(player, blocked_tags):
    print("玩家被控制了")
```

#### `has_all_tags(target: Node, tag_list: Array[StringName]) -> bool`

检查是否有列表中的所有标签

```gdscript
var required_tags = [&"wet", &"burning"]
if TagManager.has_all_tags(target, required_tags):
    # 触发蒸发反应
```

#### `get_tag_count(target: Node, tag_id: StringName) -> int`

获取标签的引用计数

```gdscript
var count = TagManager.get_tag_count(player, &"stun")
print("眩晕层数: %d" % count)
```

#### `get_all_tags(target: Node) -> Array[StringName]`

获取目标的所有标签ID列表

```gdscript
var tags = TagManager.get_all_tags(player)
for tag_id in tags:
    print("标签: %s" % tag_id)
```

### 3.3 资源查询

#### `get_tag_resource(tag_id: StringName) -> GameplayTag`

获取标签的详细资源（用于 UI 渲染）

```gdscript
var tag_resource = TagManager.get_tag_resource(&"stun")
if tag_resource:
    print("标签名称: %s" % tag_resource.display_name)
    print("描述: %s" % tag_resource.description)
```

#### `get_all_tag_resources() -> Dictionary[StringName, GameplayTag]`

获取所有已注册的标签资源

```gdscript
var all_tags = TagManager.get_all_tag_resources()
for tag_id in all_tags:
    var tag = all_tags[tag_id]
    print("%s: %s" % [tag_id, tag.display_name])
```

### 3.4 调试工具

#### `print_debug_status(target: Node)`

打印目标的标签状态（用于调试）

```gdscript
TagManager.print_debug_status(player)
# 输出:
# TagManager: Debug status for [Player]:
#   - [stun] (眩晕): count=2
#   - [silence] (沉默): count=1
```

## 4. 系统集成

### 4.1 技能系统集成

在技能资源中配置标签需求，作为施法的**前置条件**。

```gdscript
# 在 SkillResource 中
@export var caster_required_tags: Array[StringName] = []  # 施法者必须有的标签
@export var caster_blocked_tags: Array[StringName] = []    # 施法者不能有的标签

# 在 try_activate_skill 中检查
func try_activate_skill(caster: Node) -> bool:
    # 检查必须标签
    if not caster_required_tags.is_empty():
        if not TagManager.has_all_tags(caster, caster_required_tags):
            return false
    
    # 检查阻止标签
    if not caster_blocked_tags.is_empty():
        if TagManager.has_any_tag(caster, caster_blocked_tags):
            return false
    
    return true
```

### 4.2 Buff 系统集成

Buff 是标签的主要**生产者**和**管理者**。

```gdscript
# 在 BuffResource 中
@export var granted_tags: Array[StringName] = []  # Buff 持续期间赋予的标签
@export var blocked_tags: Array[StringName] = []  # 此 Buff 存在时，免疫的新标签
@export var purge_tags: Array[StringName] = []    # 此 Buff 施加时，移除的旧标签

# 在 Buff 的 OnEnter 中
func on_enter(target: Node) -> void:
    for tag_id in granted_tags:
        TagManager.add_tag(target, tag_id)

# 在 Buff 的 OnExit 中
func on_exit(target: Node) -> void:
    for tag_id in granted_tags:
        TagManager.remove_tag(target, tag_id)
```

### 4.3 效果系统集成

Effect 使用标签进行**连携 (Combo)** 和 **结算判定**。

```gdscript
# 在 EffectResource 中
@export var target_required_tags: Array[StringName] = []  # 目标有此标签才生效
@export var target_blocked_tags: Array[StringName] = []    # 目标有此标签则无效

# 在 apply_effect 中
func apply_effect(target: Node, instigator: Node) -> void:
    # 检查阻止标签
    if not target_blocked_tags.is_empty():
        if TagManager.has_any_tag(target, target_blocked_tags):
            return  # 无效
    
    # 检查必须标签
    if not target_required_tags.is_empty():
        if not TagManager.has_all_tags(target, target_required_tags):
            return  # 无效
    
    # 执行效果逻辑
    # ...
```

### 4.4 UI 表现集成

UI 和动画通过查询标签状态来更新视觉。

```gdscript
# UI 状态栏示例
func update_status_icons(unit: Node) -> void:
    var tags = TagManager.get_all_tags(unit)
    for tag_id in tags:
        var tag_resource = TagManager.get_tag_resource(tag_id)
        if tag_resource and tag_resource.icon:
            draw_icon(tag_resource.icon, tag_resource.border_color)
```

## 5. 使用示例

### 示例 1: 眩晕效果

```gdscript
# 施加眩晕
TagManager.add_tag(enemy, &"stun")

# 检查眩晕
if TagManager.has_tag(enemy, &"stun"):
    enemy.can_move = false
    enemy.can_attack = false

# 移除眩晕
TagManager.remove_tag(enemy, &"stun")
```

### 示例 2: 元素反应（火 + 油 = 爆燃）

```gdscript
# 1. 技能 "泼油" -> 施加 Buff A -> 赋予目标 covered_in_oil 标签
TagManager.add_tag(target, &"covered_in_oil")

# 2. 技能 "火球" -> 命中目标
# 3. Effect 检测
if TagManager.has_tag(target, &"covered_in_oil"):
    # 触发额外 AOE 爆炸
    trigger_explosion(target)
    # 移除 Buff A (Purge)
    TagManager.remove_tag(target, &"covered_in_oil")
else:
    # 普通伤害
    apply_normal_damage(target)
```

### 示例 3: 免疫检查

```gdscript
# 检查目标是否免疫火焰伤害
var immunity_tags = [&"immune_fire", &"immune_all"]
if TagManager.has_any_tag(target, immunity_tags):
    print("目标免疫火焰伤害")
    return

# 应用火焰伤害
apply_fire_damage(target, damage)
```

## 6. 命名规范

### 状态类标签

- `stun` - 眩晕
- `silence` - 沉默
- `root` - 定身
- `disarm` - 缴械

### 免疫类标签

- `immune_fire` - 火免疫
- `immune_cc` - 控制免疫
- `immune_all` - 全免疫

### 机制类标签

- `flying` - 飞行单位
- `undead` - 亡灵属性
- `boss` - Boss 单位

### 元素类标签

- `wet` - 潮湿
- `burning` - 燃烧
- `frozen` - 冰冻

## 7. 最佳实践

1. **禁止手动调用 `add_to_group()`**: 必须通过 `TagManager` 管理标签，否则会破坏引用计数
2. **使用引用计数**: 多个 Buff 可以同时赋予同一个标签，系统会自动管理引用计数
3. **及时清理**: Buff 移除时，确保调用 `remove_tag()` 移除对应的标签
4. **资源驱动**: 所有标签必须定义为资源文件，作为系统唯一的真理来源
5. **调试工具**: 使用 `print_debug_status()` 排查标签状态问题

## 8. 注意事项

- 标签系统使用 Godot 的 Groups 系统，查询性能极高（O(1)）
- 引用计数确保多个来源可以安全地叠加同一个标签
- 标签资源必须在 `res://data/tags/` 目录下，系统会自动扫描加载
- 标签 ID 必须全局唯一，建议使用 snake_case 命名

