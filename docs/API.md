# Godot Gameplay Abilities Plugin - API文档

## 目录

- [概述](#概述)
- [核心概念](#核心概念)
- [组件API](#组件api)
- [数据类API](#数据类api)
- [单例API](#单例api)
- [事件系统](#事件系统)
- [使用示例](#使用示例)

## 概述

Godot Gameplay Abilities Plugin 是一个高内聚、低耦合的插件化战斗系统。它采用**鸭子类型**设计，不依赖继承关系，实现了终极解耦。

### 设计原则

1. **高内聚**：战斗系统的所有逻辑封装在插件内部，对外只暴露必要的API
2. **低耦合**：业务层通过组件、单例、事件与战斗系统交互，不直接依赖内部实现
3. **鸭子类型**：采用鸭子类型设计而非继承，实现终极解耦
4. **通用性**：可适配不同架构的游戏项目（ARPG、RTS等）

## 核心概念

### 组件系统

所有组件都采用鸭子类型设计，不继承基类。组件通过接口方法进行交互：

- `AttributeComponent` - 属性组件
- `HealthComponent` - 生命值组件
- `ManaComponent` - 法力值组件
- `GameplayStatusComponent` - 状态组件
- `GameplayAbilityComponent` - 技能组件

### 数据驱动

系统使用Godot的Resource系统进行数据驱动设计：

- **属性系统**：`GameplayAttribute`、`GameplayAttributeModifier`
- **战斗系统**：`DamageInfo`、`AttackType`、`ArmorType`、`DamageMatrix`
- **状态系统**：`GameplayStatusData`、`GameplayStatusInstance`
- **技能系统**：`GameplayAbility`、`ActiveAbility`、`PassiveAbility`、`ToggleAbility`
- **效果系统**：`GameplayEffect`及其子类

### 事件驱动

通过`CombatEventBus`单例进行系统间通讯，实现解耦。事件系统采用**多态和策略模式**，符合开闭原则：添加新事件类型只需创建新的事件类并注册，无需修改核心代码。

## 组件API

### CombatSystem（单例）

提供组件查询接口，采用鸭子类型设计。

```gdscript
# 查询组件（通过类名）
var health_comp = CombatSystem.get_component_by_interface(entity, "HealthComponent")

# 检查是否有组件
if CombatSystem.has_component(entity, "HealthComponent"):
    # 处理逻辑
```

### AttributeComponent

管理实体的属性（攻击力、防御力等）。

```gdscript
# 获取属性值
var attack = attribute_comp.get_value("attack")

# 设置属性值
attribute_comp.set_value("attack", 100.0)

# 改变属性值
attribute_comp.change_value("attack", 10.0)

# 添加属性修改器
var modifier = GameplayAttributeModifier.new()
modifier.attribute_id = "attack"
modifier.value = 20.0
modifier.modifier_type = GameplayAttributeModifier.ModifierType.ADDITIVE
attribute_comp.add_modifier(modifier)

# 移除属性修改器
attribute_comp.remove_modifier(modifier)

# 监听属性变化
attribute_comp.attribute_value_changed.connect(_on_attribute_changed)
```

### HealthComponent

管理实体的生命值。

```gdscript
# 应用伤害
var damage_info = DamageInfo.new()
damage_info.base_damage = 50.0
damage_info.attack_type = attack_type_resource
damage_info.instigator = attacker
health_comp.apply_damage(damage_info, DamageCalculator, owner_entity)

# 治疗
health_comp.heal(30.0, owner_entity)

# 获取当前生命值
var current_hp = health_comp.get_current_value()

# 获取最大生命值
var max_hp = health_comp.get_max_value()

# 获取生命值比例（0.0-1.0）
var ratio = health_comp.get_ratio()

# 监听生命值变化
health_comp.value_changed.connect(_on_health_changed)
health_comp.health_depleted.connect(_on_entity_died)
```

### ManaComponent

管理实体的法力值。

```gdscript
# 尝试消耗法力
if mana_comp.try_spend_mana(50.0):
    # 法力足够，已消耗
    pass
else:
    # 法力不足
    pass

# 获取当前法力值
var current_mana = mana_comp.get_current_value()

# 监听法力值变化
mana_comp.value_changed.connect(_on_mana_changed)
```

### GameplayStatusComponent

管理实体的状态（Buff/Debuff）。

```gdscript
# 应用状态
var status_data = preload("res://data/statuses/poison.tres")
status_comp.apply_status(status_data, instigator, stacks=1, context={})

# 移除状态
status_comp.remove_status("poison")

# 按标签移除状态
status_comp.remove_statuses_by_tags(["magic", "debuff"])

# 获取状态
var status = status_comp.get_status("poison")

# 检查是否有状态
if status_comp.has_status("poison"):
    pass

# 获取所有激活的状态
var all_statuses = status_comp.get_active_statuses()

# 获取随机状态
var random_debuff = status_comp.get_random_status(is_debuff=true)

# 监听状态变化
status_comp.status_applied.connect(_on_status_applied)
status_comp.status_removed.connect(_on_status_removed)
```

### GameplayAbilityComponent

管理实体的技能。

```gdscript
# 学习技能
var ability_data = preload("res://data/abilities/fireball.tres")
ability_comp.learn_ability(ability_data)

# 遗忘技能
ability_comp.forget_ability("fireball")

# 检查是否可以施法
if ability_comp.can_cast("fireball", target):
    # 提交施法（消耗资源、开始冷却）
    if ability_comp.commit_cast("fireball"):
        # 应用技能效果
        ability_comp.apply_ability_effect("fireball", target)

# 检查冷却是否就绪
if ability_comp.is_cooldown_ready("fireball"):
    pass

# 获取技能数据
var ability = ability_comp.get_ability_data("fireball")

# 获取所有技能
var all_abilities = ability_comp.get_all_abilities()

# 禁用/启用技能
ability_comp.disable_ability("fireball")
ability_comp.enable_ability("fireball")

# 自动施法
if ability_comp.can_autocast("fireball"):
    ability_comp.toggle_autocast("fireball")
    if ability_comp.is_autocast_active("fireball"):
        # 正在自动施法
        pass

# 获取法力值
var mana = ability_comp.get_mana()

# 监听技能事件
ability_comp.ability_learned.connect(_on_ability_learned)
ability_comp.ability_cast.connect(_on_ability_cast)
ability_comp.cooldown_ready.connect(_on_cooldown_ready)
```

## 数据类API

### GameplayAttribute

定义游戏属性。

```gdscript
var attribute = GameplayAttribute.new()
attribute.attribute_id = "attack"
attribute.attribute_display_name = "攻击力"
attribute.base_value = 100.0
attribute.min_value = 0.0
attribute.max_value = 999.0
```

### GameplayAttributeModifier

属性修改器。

```gdscript
var modifier = GameplayAttributeModifier.new()
modifier.attribute_id = "attack"
modifier.value = 20.0
modifier.modifier_type = GameplayAttributeModifier.ModifierType.ADDITIVE  # 或 MULTIPLICATIVE, PERCENTAGE
```

### DamageInfo

伤害信息。

```gdscript
var damage_info = DamageInfo.new()
damage_info.instigator = attacker
damage_info.source_component = attacker_component
damage_info.base_damage = 100.0
damage_info.attack_type = attack_type_resource
damage_info.is_crit = false
```

### GameplayStatusData

状态数据（Buff/Debuff定义）。

```gdscript
var status_data = GameplayStatusData.new()
status_data.status_id = "poison"
status_data.status_display_name = "中毒"
status_data.duration = 10.0  # -1为永久，0为瞬时
status_data.is_debuff = true
status_data.tags = ["magic", "debuff"]
status_data.stacking_policy = GameplayStatusData.StackingPolicy.STACK_INTENSITY
status_data.max_stacks = 5
status_data.effects = [poison_effect]  # GameplayEffect数组
```

### GameplayAbility

技能数据基类。

```gdscript
# ActiveAbility（主动技能）
var ability = ActiveAbility.new()
ability.ability_id = "fireball"
ability.ability_name = "火球术"
ability.targeting_type = GameplayAbility.TargetingType.UNIT_TARGET
ability.mana_cost = 50.0
ability.cooldown_duration = 5.0
ability.cast_duration = 1.0
ability.cast_range = 10.0
ability.status_to_apply = fireball_status_data

# PassiveAbility（被动技能）
var passive = PassiveAbility.new()
passive.ability_id = "regeneration"
passive.status_to_apply = regen_status_data

# ToggleAbility（切换技能）
var toggle = ToggleAbility.new()
toggle.ability_id = "shield"
toggle.status_to_apply = shield_on_status_data
toggle.toggled_off_status_to_apply = shield_off_status_data
```

## 单例API

### DamageCalculator

伤害计算中心。

```gdscript
# 初始化（需要设置伤害矩阵）
DamageCalculator.initialize(damage_matrix_resource)

# 计算最终伤害
var final_damage = DamageCalculator.calculate_final_damage(damage_info, target_health_comp)
```

### CombatSystem

战斗系统管理器。

```gdscript
# 查询组件（鸭子类型）
var component = CombatSystem.get_component_by_interface(entity, "HealthComponent")

# 检查是否有组件
if CombatSystem.has_component(entity, "HealthComponent"):
    pass

# 注册/注销实体（可选）
CombatSystem.register_entity(entity)
CombatSystem.unregister_entity(entity)
```

### CombatEventBus

战斗事件总线。

#### 统一游戏事件系统（推荐）

插件提供了统一的事件触发接口，状态系统可以配置监听多个事件类型：

```gdscript
# 触发统一游戏事件
CombatEventBus.trigger_game_event(&"damage_received", {
    "source": attacker,
    "target": target,
    "damage_info": damage_info
})

CombatEventBus.trigger_game_event(&"ability_completed", {
    "entity": caster,
    "ability_id": &"fireball"
})

# 监听统一游戏事件
CombatEventBus.game_event_occurred.connect(_on_game_event)

func _on_game_event(event_type: StringName, context: Dictionary) -> void:
    match event_type:
        &"damage_received":
            var target = context.get("target")
            var damage_info = context.get("damage_info")
            # 处理伤害事件
        &"ability_completed":
            var entity = context.get("entity")
            var ability_id = context.get("ability_id")
            # 处理技能完成事件
```

#### 细粒度事件信号（向后兼容）

```gdscript
# 监听事件
CombatEventBus.damage_dealt.connect(_on_damage_dealt)
CombatEventBus.entity_died.connect(_on_entity_died)
CombatEventBus.status_applied.connect(_on_status_applied)
CombatEventBus.ability_completed.connect(_on_ability_completed)

# 发送事件（通常由系统内部调用）
CombatEventBus.emit_damage_dealt(instigator, target, damage_info, final_damage)
CombatEventBus.emit_entity_died(entity, instigator)
CombatEventBus.emit_status_applied(entity, status_id)
CombatEventBus.emit_ability_completed(entity, ability_id)
```

#### 常用事件类型

- `"damage_received"`: 受到伤害时触发，context包含 `{source: Node, target: Node, damage_info: DamageInfo}`
- `"damage_dealt"`: 造成伤害时触发，context包含 `{instigator: Node, target: Node, damage_info: DamageInfo, final_damage: float}`
- `"entity_died"`: 实体死亡时触发，context包含 `{entity: Node, instigator: Node}`
- `"healing_applied"`: 受到治疗时触发，context包含 `{target: Node, amount: float}`
- `"ability_completed"`: 技能完成时触发（所有逻辑执行完毕），context包含 `{entity: Node, ability_id: StringName}`
- `"status_applied"`: 状态应用时触发，context包含 `{entity: Node, status_id: StringName}`
- `"status_removed"`: 状态移除时触发，context包含 `{entity: Node, status_id: StringName}`

### EffectExecutor

效果执行器。

```gdscript
# 执行效果
var effect = GE_ModifyHealth.new()
effect.amount = 50.0
EffectExecutor.execute_effect(effect, target, instigator)

# 移除效果（用于状态型效果）
EffectExecutor.remove_effect(effect, target, instigator)

# 批量执行效果
var effects = [effect1, effect2, effect3]
EffectExecutor.execute_effects(effects, target, instigator)
```

## 事件系统

### 可用事件

**伤害相关：**
- `damage_dealt(instigator, target, damage_info, final_damage)`
- `damage_received(target, damage_info)`
- `entity_died(entity, instigator)`

**治疗相关：**
- `healing_applied(target, amount)`
- `health_restored(entity)`

**属性相关：**
- `attribute_changed(entity, attribute_id, new_value)`

**技能相关：**
- `ability_completed(entity, ability_id)`
- `ability_failed(entity, ability_id, reason)`
- `ability_learned(entity, ability_id)`
- `ability_forgotten(entity, ability_id)`
- `ability_cooldown_ready(entity, ability_id)`

**状态相关：**
- `status_applied(entity, status_id)`
- `status_removed(entity, status_id)`

## 使用示例

详细使用示例请参考 [Examples.md](Examples.md)

