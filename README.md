# Godot Gameplay Abilities Plugin

**高内聚、低耦合的插件化战斗系统**

## 简介

这是一个通用的、插件化的战斗系统，采用高内聚、低耦合的架构设计。战斗系统作为独立插件，通过组件、单例和事件通讯暴露API，可被不同类型的游戏项目（ARPG、RTS等）使用。

## 核心设计理念

1. **高内聚：** 战斗系统的所有逻辑封装在插件内部，对外只暴露必要的API
2. **低耦合：** 业务层通过组件、单例、事件与战斗系统交互，不直接依赖内部实现
3. **鸭子类型：** 采用鸭子类型设计而非继承，实现终极解耦
4. **通用性：** 可适配不同架构的游戏项目，展示其通用性

## 核心系统

### 数据类（data/）

**属性相关（data/attributes/）：**
- `GameplayAttribute` - 游戏属性定义
- `GameplayAttributeModifier` - 属性修改器

**战斗相关（data/combat/）：**
- `DamageInfo` - 伤害信息
- `AttackType` - 攻击类型
- `ArmorType` - 护甲类型
- `DamageMatrix` - 伤害矩阵

**状态相关（data/status/）：**
- `GameplayStatusData` - 状态数据（Buff/Debuff定义）
- `GameplayStatusInstance` - 状态实例（状态生命周期管理）

**技能相关（data/abilities/）：**
- `GameplayAbility` - 技能数据基类（抽象类）
- `ActiveAbility` - 主动技能数据
- `PassiveAbility` - 被动技能数据
- `ToggleAbility` - 切换技能数据

**目标相关（data/targeting/）：**
- `TargetingScorer` - 目标评分器基类（抽象类）
- `TargetIndicatorData` - 目标指示器数据

**效果基类（data/effects/）：**
- `GameplayEffect` - 效果基类（抽象类）

**过滤器基类（data/filters/）：**
- `GameplayFilterData` - 过滤器基类（抽象类）

### 效果实现（data/effects/）
- `GE_ModifyHealth` - 修改生命值效果（伤害/治疗）
- `GE_ModifyMana` - 修改法力值效果
- `GE_AttributeModifier` - 属性修改器效果（状态型）
- `GE_DamageModification` - 伤害修改效果（事件监听型）
- `GE_ApplyStatus` - 应用状态效果
- `GE_DispelStatus` - 驱散状态效果
- `GE_StealStatus` - 窃取状态效果

### 过滤器实现（data/filters/）
- `FilterTargetIsAlive` - 检查目标是否存活
- `FilterTargetHasComponent` - 检查目标是否有指定组件

### 组件（components/）
- `AttributeComponent` - 属性组件（采用鸭子类型，不继承基类）
- `VitalComponent` - 资源组件基类（生命值、法力值等）
- `HealthComponent` - 生命值组件
- `ManaComponent` - 法力值组件
- `GameplayStatusComponent` - 状态组件（Buff/Debuff管理，采用鸭子类型）
- `GameplayAbilityComponent` - 技能组件（技能管理、冷却、法力消耗，采用鸭子类型）

### 单例（singletons/）
- `DamageCalculator` - 伤害计算中心
- `CombatSystem` - 战斗系统管理器（提供组件查询接口）
- `CombatEventBus` - 战斗事件总线
- `EffectExecutor` - 效果执行器

## 安装

此插件已作为Git子模块添加到项目中：

```bash
# 如果需要在其他项目中使用
git submodule add <repository-url> addons/godot_gameplay_abilities
```

## 使用

1. 在Godot编辑器中启用插件（已在project.godot中配置）
2. 单例已自动加载：`DamageCalculator`、`CombatSystem`、`CombatEventBus`
3. 在项目中使用组件、单例和事件与战斗系统交互

### 基础使用示例

```gdscript
# 在实体节点上添加组件
var health_comp = HealthComponent.new()
add_child(health_comp)
health_comp._attribute_comp = attribute_comp  # 需要先有AttributeComponent

# 应用伤害
var damage_info = DamageInfo.new()
damage_info.base_damage = 10.0
health_comp.apply_damage(damage_info)

# 使用Effect系统
var heal_effect = GE_ModifyHealth.new()
heal_effect.amount = 50.0
EffectExecutor.execute_effect(heal_effect, target, instigator)

# 使用状态系统
var status_comp = GameplayStatusComponent.new()
add_child(status_comp)
var status_data = preload("res://data/statuses/poison.tres")  # 示例状态数据
status_comp.apply_status(status_data, self, 1)

# 使用技能系统
var ability_comp = GameplayAbilityComponent.new()
add_child(ability_comp)
var ability_data = preload("res://data/abilities/fireball.tres")  # 示例技能数据
ability_comp.learn_ability(ability_data)
if ability_comp.can_cast(ability_data.ability_id, target):
    ability_comp.commit_cast(ability_data.ability_id)
    ability_comp.apply_ability_effect(ability_data.ability_id, target)

# 监听事件
CombatEventBus.entity_died.connect(_on_entity_died)
CombatEventBus.status_applied.connect(_on_status_applied)
```

## API文档

### 组件查询（鸭子类型）

```gdscript
# 通过接口查询组件（不依赖类型检查）
var health_comp = CombatSystem.get_component_by_interface(entity, "HealthComponent")
if health_comp:
    health_comp.apply_damage(damage_info)
```

### 事件通讯

```gdscript
# 监听战斗事件
CombatEventBus.damage_dealt.connect(_on_damage_dealt)
CombatEventBus.entity_died.connect(_on_entity_died)

# 发送事件
CombatEventBus.emit_damage_dealt(instigator, target, damage_info, final_damage)
```

## 当前状态

✅ **已完成：**
- 基础数据类（GameplayAttribute、DamageInfo、AttackType、ArmorType、DamageMatrix等）
- 核心组件（AttributeComponent、VitalComponent、HealthComponent、ManaComponent）
- 伤害计算系统（DamageCalculator）
- 战斗系统管理（CombatSystem）
- 事件总线（CombatEventBus）
- **Effect层抽象**（GameplayEffect基类、Effect执行器、常用Effect实现）
- 过滤器系统（GameplayFilterData基类、常用过滤器）
- **GameplayAbilityStatus系统**（状态系统）
  - StatusComponent组件（采用鸭子类型）
  - GameplayStatusData（状态数据定义）
  - GameplayStatusInstance（状态实例，支持层数、持续时间、周期性效果、事件监听）
  - 状态叠加策略（刷新持续时间、增加层数、累加持续时间、忽略）
  - 状态相关Effect（应用、驱散、窃取）
- **GameplayAbility系统**（技能系统）
  - GameplayAbilityComponent组件（采用鸭子类型）
  - GameplayAbility基类（抽象类）
  - ActiveAbility（主动技能，支持冷却、法力消耗、目标过滤）
  - PassiveAbility（被动技能，学会时自动应用状态）
  - ToggleAbility（切换技能，可在开启/关闭状态切换）
  - TargetingScorer（目标评分器）
  - TargetIndicatorData（目标指示器数据）

🚧 **开发中：**
- 更多Effect实现（位移、召唤、弹道等）
- 更多TargetingScorer实现（最近目标、最低血量等）

## 文档

- [API文档](docs/API.md) - 完整的API参考
- [使用示例](docs/Examples.md) - 详细的使用示例
- [架构设计](docs/Architecture.md) - 系统架构和设计理念
- [事件系统设计](docs/EventSystem.md) - 事件系统完整文档（优势、缺点、最佳实践、外部通信）

详细课程教程：`_tutorials/godot架构实战：即时战斗核心与技能系统篇.md`

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
│   │   ├── combat/          # 战斗相关
│   │   ├── status/          # 状态相关
│   │   ├── abilities/       # 技能相关
│   │   ├── effects/         # 效果实现
│   │   ├── filters/         # 过滤器实现
│   │   └── targeting/       # 目标相关
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

## 许可证

MIT License

## 作者

老李（玩物不丧志的老李）

