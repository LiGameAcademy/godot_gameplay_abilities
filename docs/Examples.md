# 使用示例

本文档提供Godot Gameplay Abilities Plugin的详细使用示例。

## 目录

- [基础设置](#基础设置)
- [统一游戏事件系统](#统一游戏事件系统)
- [属性系统](#属性系统)
- [生命值和法力值](#生命值和法力值)
- [状态系统](#状态系统)
- [技能系统](#技能系统)
- [效果系统](#效果系统)
- [完整示例](#完整示例)

## 基础设置

### 1. 启用插件

在`project.godot`中，插件已自动配置。确保以下单例已加载：

```ini
[autoload]
DamageCalculator="*res://addons/godot_gameplay_abilities/scripts/singletons/damage_calculator.gd"
CombatSystem="*res://addons/godot_gameplay_abilities/scripts/singletons/combat_system.gd"
CombatEventBus="*res://addons/godot_gameplay_abilities/scripts/singletons/combat_event_bus.gd"
EffectExecutor="*res://addons/godot_gameplay_abilities/scripts/singletons/effect_executor.gd"
```

## 统一游戏事件系统

插件提供了统一的事件触发接口，状态系统可以配置监听多个事件类型。这是推荐的事件处理方式。

### 触发游戏事件

```gdscript
# 触发伤害事件
CombatEventBus.trigger_game_event(&"damage_received", {
    "source": attacker,
    "target": target,
    "damage_info": damage_info
})

# 触发技能激活事件
CombatEventBus.trigger_game_event(&"ability_activated", {
    "entity": caster,
    "ability_id": &"fireball"
})

# 触发状态应用事件
CombatEventBus.trigger_game_event(&"status_applied", {
    "entity": target,
    "status_id": &"burning"
})
```

### 监听统一游戏事件

```gdscript
extends Node

func _ready():
    # 连接统一游戏事件
    CombatEventBus.game_event_occurred.connect(_on_game_event)

func _on_game_event(event_type: StringName, context: Dictionary) -> void:
    match event_type:
        &"damage_received":
            var target = context.get("target")
            var damage_info = context.get("damage_info")
            if target == self:
                print("Received damage: ", damage_info.base_damage)
        
        &"ability_activated":
            var entity = context.get("entity")
            var ability_id = context.get("ability_id")
            print(entity.name, " activated ", ability_id)
        
        &"status_applied":
            var entity = context.get("entity")
            var status_id = context.get("status_id")
            if entity == self:
                print("Applied status: ", status_id)
```

### 状态配置事件监听

状态可以在配置中指定要监听的事件类型：

```gdscript
# 在GameplayStatusData资源中配置
@export var trigger_on_events: Array[StringName] = [
    &"damage_received",  # 受到伤害时触发
    &"turn_start"        # 回合开始时触发（回合制游戏）
]

# 状态会自动监听这些事件，并在事件发生时触发对应的效果
# 效果需要设置 event_to_listen 字段才能被触发
```

### 常用事件类型

- `"damage_received"`: 受到伤害时触发
- `"damage_dealt"`: 造成伤害时触发
- `"entity_died"`: 实体死亡时触发
- `"healing_applied"`: 受到治疗时触发
- `"ability_activated"`: 技能激活时触发
- `"status_applied"`: 状态应用时触发
- `"status_removed"`: 状态移除时触发
- `"turn_start"`: 回合开始时触发（回合制游戏）
- `"turn_end"`: 回合结束时触发（回合制游戏）

### 2. 创建实体节点结构

```gdscript
extends CharacterBody3D
class_name Player

@onready var attribute_comp = AttributeComponent.new()
@onready var health_comp = HealthComponent.new()
@onready var mana_comp = ManaComponent.new()
@onready var status_comp = GameplayStatusComponent.new()
@onready var ability_comp = GameplayAbilityComponent.new()

func _ready():
    # 添加组件
    add_child(attribute_comp)
    add_child(health_comp)
    add_child(mana_comp)
    add_child(status_comp)
    add_child(ability_comp)
    
    # 初始化属性组件
    var attributes = {
        "max_health": 100.0,
        "max_mana": 50.0,
        "attack": 20.0,
        "defense": 10.0,
        "armor": 5.0
    }
    attribute_comp.initialize(attributes, data_manager_ref)
    
    # 初始化生命值组件
    health_comp.initialize(attribute_comp, entity_data_ref)
    
    # 初始化法力值组件
    mana_comp.initialize(attribute_comp, entity_data_ref)
    
    # 连接事件
    health_comp.health_depleted.connect(_on_died)
    CombatEventBus.status_applied.connect(_on_status_applied)
```

## 属性系统

### 创建属性数据

```gdscript
# 在编辑器中创建 GameplayAttribute 资源
# 或通过代码创建
var attack_attr = GameplayAttribute.new()
attack_attr.attribute_id = "attack"
attack_attr.attribute_display_name = "攻击力"
attack_attr.base_value = 100.0
attack_attr.min_value = 0.0
attack_attr.max_value = 999.0
```

### 使用属性组件

```gdscript
# 获取属性值
var attack = attribute_comp.get_value("attack")

# 设置属性值
attribute_comp.set_value("attack", 150.0)

# 添加属性修改器（Buff）
var buff_modifier = GameplayAttributeModifier.new()
buff_modifier.attribute_id = "attack"
buff_modifier.value = 50.0
buff_modifier.modifier_type = GameplayAttributeModifier.ModifierType.ADDITIVE
attribute_comp.add_modifier(buff_modifier)

# 移除属性修改器
attribute_comp.remove_modifier(buff_modifier)
```

## 生命值和法力值

### 应用伤害

```gdscript
# 创建伤害信息
var damage_info = DamageInfo.new()
damage_info.instigator = attacker
damage_info.base_damage = 50.0
damage_info.attack_type = preload("res://data/combat/physical_attack.tres")
damage_info.is_crit = false

# 应用伤害
health_comp.apply_damage(damage_info, DamageCalculator, self)
```

### 治疗

```gdscript
# 直接治疗
health_comp.heal(30.0, self)

# 使用效果治疗
var heal_effect = GE_ModifyHealth.new()
heal_effect.amount = 50.0
EffectExecutor.execute_effect(heal_effect, self, self)
```

### 消耗法力

```gdscript
# 尝试消耗法力
if mana_comp.try_spend_mana(30.0):
    # 法力足够，已消耗
    cast_spell()
else:
    # 法力不足
    show_insufficient_mana_message()
```

## 状态系统

### 创建状态数据

```gdscript
# 在编辑器中创建 GameplayStatusData 资源
# 或通过代码创建
var poison_status = GameplayStatusData.new()
poison_status.status_id = "poison"
poison_status.status_display_name = "中毒"
poison_status.duration = 10.0
poison_status.is_debuff = true
poison_status.tags = ["magic", "debuff"]
poison_status.stacking_policy = GameplayStatusData.StackingPolicy.STACK_INTENSITY
poison_status.max_stacks = 5

# 创建中毒效果
var poison_effect = GE_ModifyHealth.new()
poison_effect.amount = -5.0  # 每周期造成5点伤害
poison_effect.period = 1.0   # 每秒触发一次
poison_status.effects = [poison_effect]
```

### 应用状态

```gdscript
# 应用状态
var status_data = preload("res://data/statuses/poison.tres")
status_comp.apply_status(status_data, attacker, stacks=1)

# 检查状态
if status_comp.has_status("poison"):
    var poison = status_comp.get_status("poison")
    print("中毒层数: ", poison.stacks)

# 移除状态
status_comp.remove_status("poison")

# 按标签移除状态（驱散）
status_comp.remove_statuses_by_tags(["magic", "debuff"])
```

## 技能系统

### 创建技能数据

```gdscript
# 主动技能
var fireball = ActiveAbility.new()
fireball.ability_id = "fireball"
fireball.ability_name = "火球术"
fireball.targeting_type = GameplayAbility.TargetingType.UNIT_TARGET
fireball.mana_cost = 50.0
fireball.cooldown_duration = 5.0
fireball.cast_duration = 1.0
fireball.cast_range = 10.0

# 创建火球状态（伤害效果）
var fireball_status = GameplayStatusData.new()
fireball_status.status_id = "fireball_damage"
fireball_status.duration = 0.0  # 瞬时
var fire_damage_effect = GE_ModifyHealth.new()
fire_damage_effect.amount = -100.0
fire_damage_effect.attack_type = preload("res://data/combat/fire_attack.tres")
fireball_status.effects = [fire_damage_effect]
fireball.status_to_apply = fireball_status

# 被动技能
var regeneration = PassiveAbility.new()
regeneration.ability_id = "regeneration"
var regen_status = GameplayStatusData.new()
regen_status.status_id = "regen"
regen_status.duration = -1.0  # 永久
var regen_effect = GE_ModifyHealth.new()
regen_effect.amount = 2.0
regen_effect.period = 1.0  # 每秒恢复2点生命值
regen_status.effects = [regen_effect]
regeneration.status_to_apply = regen_status
```

### 使用技能

```gdscript
# 学习技能
var ability_data = preload("res://data/abilities/fireball.tres")
ability_comp.learn_ability(ability_data)

# 检查是否可以施法
if ability_comp.can_cast("fireball", target):
    # 提交施法（消耗资源、开始冷却）
    if ability_comp.commit_cast("fireball"):
        # 应用技能效果
        ability_comp.apply_ability_effect("fireball", target)

# 检查冷却
if ability_comp.is_cooldown_ready("fireball"):
    # 冷却完成
    pass

# 自动施法
if ability_comp.can_autocast("fireball"):
    ability_comp.toggle_autocast("fireball")
```

## 效果系统

### 创建效果

```gdscript
# 治疗效果
var heal_effect = GE_ModifyHealth.new()
heal_effect.amount = 50.0

# 伤害效果
var damage_effect = GE_ModifyHealth.new()
damage_effect.amount = -30.0
damage_effect.attack_type = preload("res://data/combat/physical_attack.tres")

# 属性修改效果
var attack_buff = GE_AttributeModifier.new()
attack_buff.attribute_modifier = GameplayAttributeModifier.new()
attack_buff.attribute_modifier.attribute_id = "attack"
attack_buff.attribute_modifier.value = 20.0
attack_buff.attribute_modifier.modifier_type = GameplayAttributeModifier.ModifierType.ADDITIVE

# 应用状态效果
var apply_status_effect = GE_ApplyStatus.new()
apply_status_effect.status_data = preload("res://data/statuses/poison.tres")
apply_status_effect.stacks = 1
```

### 执行效果

```gdscript
# 单个效果
EffectExecutor.execute_effect(heal_effect, target, instigator)

# 批量效果
var effects = [heal_effect, attack_buff]
EffectExecutor.execute_effects(effects, target, instigator)
```

## 完整示例

### 创建一个完整的战斗单位

```gdscript
extends CharacterBody3D
class_name CombatUnit

@onready var attribute_comp = AttributeComponent.new()
@onready var health_comp = HealthComponent.new()
@onready var mana_comp = ManaComponent.new()
@onready var status_comp = GameplayStatusComponent.new()
@onready var ability_comp = GameplayAbilityComponent.new()

func _ready():
    # 添加组件
    add_child(attribute_comp)
    add_child(health_comp)
    add_child(mana_comp)
    add_child(status_comp)
    add_child(ability_comp)
    
    # 初始化属性
    var attributes = {
        "max_health": 100.0,
        "max_mana": 50.0,
        "attack": 20.0,
        "armor": 5.0
    }
    attribute_comp.initialize(attributes, data_manager_ref)
    
    # 初始化生命值和法力值
    health_comp.initialize(attribute_comp, entity_data_ref)
    mana_comp.initialize(attribute_comp, entity_data_ref)
    
    # 学习技能
    var fireball = preload("res://data/abilities/fireball.tres")
    ability_comp.learn_ability(fireball)
    
    # 连接事件（使用统一游戏事件系统）
    CombatEventBus.game_event_occurred.connect(_on_game_event)
    
    # 或者使用细粒度信号（向后兼容）
    health_comp.health_depleted.connect(_on_died)
    CombatEventBus.status_applied.connect(_on_status_applied)
    CombatEventBus.ability_activated.connect(_on_ability_activated)

func attack_target(target: Node):
    var damage_info = DamageInfo.new()
    damage_info.instigator = self
    damage_info.base_damage = attribute_comp.get_value("attack")
    damage_info.attack_type = preload("res://data/combat/physical_attack.tres")
    
    var target_health = CombatSystem.get_component_by_interface(target, "HealthComponent")
    if target_health:
        target_health.apply_damage(damage_info, DamageCalculator, target)

func cast_ability(ability_id: StringName, target: Node):
    if ability_comp.can_cast(ability_id, target):
        if ability_comp.commit_cast(ability_id):
            ability_comp.apply_ability_effect(ability_id, target)

# 统一游戏事件处理（推荐）
func _on_game_event(event_type: StringName, context: Dictionary) -> void:
    match event_type:
        &"entity_died":
            var entity = context.get("entity")
            if entity == self:
                print(name, " died!")
                queue_free()
        &"status_applied":
            var entity = context.get("entity")
            var status_id = context.get("status_id")
            if entity == self:
                print(name, " received status: ", status_id)
        &"ability_activated":
            var entity = context.get("entity")
            var ability_id = context.get("ability_id")
            if entity == self:
                print(name, " activated ability: ", ability_id)

# 细粒度事件处理（向后兼容）
func _on_died(instigator: Node):
    print(name, " died!")
    queue_free()

func _on_status_applied(entity: Node, status_id: StringName):
    if entity == self:
        print("Applied status: ", status_id)

func _on_ability_activated(entity: Node, ability_id: StringName):
    if entity == self:
        print("Activated ability: ", ability_id)
```

### 使用伤害矩阵

```gdscript
# 初始化伤害计算器
var damage_matrix = preload("res://data/combat/damage_matrix.tres")
DamageCalculator.initialize(damage_matrix)

# 伤害矩阵定义了不同攻击类型对不同护甲类型的伤害倍率
# 例如：火焰攻击对轻甲造成150%伤害，对重甲造成75%伤害
```

### 组合效果示例

```gdscript
# 创建一个组合效果：治疗+属性提升
var heal_effect = GE_ModifyHealth.new()
heal_effect.amount = 50.0

var attack_buff = GE_AttributeModifier.new()
attack_buff.attribute_modifier = GameplayAttributeModifier.new()
attack_buff.attribute_modifier.attribute_id = "attack"
attack_buff.attribute_modifier.value = 20.0

# 使用效果组合
var combo_effect = GameplayEffect.new()
combo_effect.effects = [heal_effect, attack_buff]

EffectExecutor.execute_effect(combo_effect, target, instigator)
```

