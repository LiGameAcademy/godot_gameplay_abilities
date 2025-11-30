# 架构设计文档

## 目录结构

```
godot_gameplay_abilities/
├── scripts/                 # 所有脚本代码
│   ├── components/          # 组件（采用鸭子类型设计）
│   │   ├── attribute_component.gd
│   │   ├── vital_component.gd
│   │   ├── health_component.gd
│   │   ├── mana_component.gd
│   │   ├── gameplay_status_component.gd
│   │   └── gameplay_ability_component.gd
│   │
│   ├── data/                # 数据类（Resource）
│   │   ├── attributes/      # 属性相关
│   │   │   ├── gameplay_attribute.gd
│   │   │   └── gameplay_attribute_modifier.gd
│   │   ├── combat/          # 战斗相关
│   │   │   ├── damage_info.gd
│   │   │   ├── attack_type.gd
│   │   │   ├── armor_type.gd
│   │   │   └── damage_matrix.gd
│   │   ├── status/          # 状态相关
│   │   │   ├── gameplay_status_data.gd
│   │   │   └── gameplay_status_instance.gd
│   │   ├── abilities/       # 技能相关
│   │   │   ├── gameplay_ability.gd
│   │   │   ├── active_ability.gd
│   │   │   ├── passive_ability.gd
│   │   │   └── toggle_ability.gd
│   │   ├── effects/         # 效果实现
│   │   │   ├── gameplay_effect.gd
│   │   │   ├── ge_modify_health.gd
│   │   │   ├── ge_modify_mana.gd
│   │   │   ├── ge_attribute_modifier.gd
│   │   │   ├── ge_damage_modification.gd
│   │   │   ├── ge_apply_status.gd
│   │   │   ├── ge_dispel_status.gd
│   │   │   └── ge_steal_status.gd
│   │   ├── filters/         # 过滤器实现
│   │   │   ├── gameplay_filter_data.gd
│   │   │   ├── filter_target_is_alive.gd
│   │   │   └── filter_target_has_component.gd
│   │   └── targeting/       # 目标相关
│   │       ├── targeting_scorer.gd
│   │       └── target_indicator_data.gd
│   │
│   └── singletons/          # 单例（AutoLoad）
│       ├── combat_system.gd
│       ├── damage_calculator.gd
│       ├── combat_event_bus.gd
│       └── effect_executor.gd
│
├── docs/                    # 文档
│   ├── API.md
│   ├── Examples.md
│   ├── Architecture.md
│   └── README.md
│
├── plugin.cfg
├── plugin.gd
└── README.md
```

## 核心设计理念

### 1. 高内聚、低耦合

- **高内聚**：战斗系统的所有逻辑封装在插件内部，对外只暴露必要的API
- **低耦合**：业务层通过组件、单例、事件与战斗系统交互，不直接依赖内部实现

### 2. 鸭子类型设计

所有组件采用鸭子类型设计，不继承基类：

```gdscript
# 不这样做（继承方式）
extends LogicComponent
class_name HealthComponent

# 而是这样做（鸭子类型）
extends Node
class_name HealthComponent

# 查询组件时使用接口检查
var health_comp = CombatSystem.get_component_by_interface(entity, "HealthComponent")
if health_comp and health_comp.has_method("apply_damage"):
    health_comp.apply_damage(damage_info)
```

### 3. 数据驱动

使用Godot的Resource系统进行数据驱动设计：

- 所有游戏数据（属性、技能、状态等）都是Resource
- 可以在编辑器中配置
- 支持资源继承和组合

### 4. 事件驱动

通过`CombatEventBus`单例进行系统间通讯：

```gdscript
# 发送事件
CombatEventBus.emit_damage_dealt(instigator, target, damage_info, final_damage)

# 监听事件
CombatEventBus.damage_dealt.connect(_on_damage_dealt)
```

## 系统架构

### 组件系统

```
Entity (Node3D)
├── AttributeComponent      # 属性管理
├── HealthComponent         # 生命值管理（依赖AttributeComponent）
├── ManaComponent          # 法力值管理（依赖AttributeComponent）
├── GameplayStatusComponent # 状态管理（依赖HealthComponent）
└── GameplayAbilityComponent # 技能管理（依赖ManaComponent、GameplayStatusComponent）
```

### 数据流

```
技能施放
  ↓
GameplayAbilityComponent.can_cast()
  ↓
GameplayAbilityComponent.commit_cast()  # 消耗资源、开始冷却
  ↓
GameplayAbilityComponent.apply_ability_effect()
  ↓
GameplayAbility.cast()
  ↓
GameplayStatusComponent.apply_status()
  ↓
GameplayStatusInstance.apply()
  ↓
GameplayEffect.apply()
  ↓
EffectExecutor.execute_effect()
```

### 伤害流程

```
攻击发起
  ↓
DamageInfo创建
  ↓
HealthComponent.apply_damage()
  ↓
DamageCalculator.calculate_final_damage()
  ├── 类型克制计算（DamageMatrix）
  └── 护甲减免计算
  ↓
HealthComponent.set_current_value()
  ↓
CombatEventBus.emit_damage_dealt()
```

## 扩展性

### 添加新效果

继承`GameplayEffect`并实现`_apply`和`_remove`方法：

```gdscript
extends GameplayEffect
class_name GE_Teleport

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
    var position = context.get("position", Vector3.ZERO)
    target.global_position = position

func _remove(_target: Node, _instigator: Node) -> void:
    pass
```

### 添加新过滤器

继承`GameplayFilterData`并实现`_check`方法：

```gdscript
extends GameplayFilterData
class_name FilterTargetDistance

@export var max_distance: float = 10.0

func _check(target: Node, instigator: Node, context: Dictionary) -> bool:
    var distance = instigator.global_position.distance_to(target.global_position)
    return distance <= max_distance
```

### 添加新技能类型

继承`GameplayAbility`并实现所有抽象方法：

```gdscript
extends GameplayAbility
class_name ChannelAbility

@export var channel_duration: float = 3.0

func _on_learned(_ability_comp: Node, _status_comp: Node) -> void:
    pass

func _on_forgotten(_ability_comp: Node, _status_comp: Node) -> void:
    pass

func _can_cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> bool:
    return true

func _commit_cast(ability_comp: Node) -> bool:
    return true

func _on_cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> void:
    # 引导逻辑
    pass

func _clear_cast(ability_comp: Node, target: Node) -> void:
    pass
```

## 最佳实践

### 1. 组件初始化顺序

```gdscript
# 正确的初始化顺序
1. AttributeComponent
2. HealthComponent / ManaComponent（依赖AttributeComponent）
3. GameplayStatusComponent（依赖HealthComponent）
4. GameplayAbilityComponent（依赖ManaComponent、GameplayStatusComponent）
```

### 2. 使用事件而非直接调用

```gdscript
# 不推荐：直接调用
health_comp.health_depleted.emit(instigator)

# 推荐：通过事件总线
CombatEventBus.emit_entity_died(entity, instigator)
```

### 3. 资源管理

```gdscript
# 使用preload加载资源
var status_data = preload("res://data/statuses/poison.tres")

# 或使用ResourceLoader
var ability_data = load("res://data/abilities/fireball.tres")
```

### 4. 错误处理

```gdscript
# 总是检查组件是否存在
var health_comp = CombatSystem.get_component_by_interface(entity, "HealthComponent")
if not health_comp:
    push_error("Entity has no HealthComponent!")
    return

# 检查方法是否存在（鸭子类型）
if health_comp.has_method("apply_damage"):
    health_comp.apply_damage(damage_info)
```

## 性能考虑

1. **组件查询**：使用`CombatSystem.get_component_by_interface()`缓存查询结果
2. **事件连接**：在`_ready()`中连接，在`_exit_tree()`中断开
3. **资源复用**：使用Resource的`duplicate()`方法创建实例
4. **定时器管理**：及时清理不需要的Timer节点

## 测试建议

1. **单元测试**：测试每个组件的核心功能
2. **集成测试**：测试组件间的交互
3. **性能测试**：测试大量实体时的性能
4. **边界测试**：测试极端情况（如负数、空值等）
