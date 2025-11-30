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
- `GameplayAttribute` - 游戏属性定义
- `GameplayAttributeModifier` - 属性修改器
- `DamageInfo` - 伤害信息
- `AttackType` - 攻击类型
- `ArmorType` - 护甲类型
- `DamageMatrix` - 伤害矩阵
- `GameplayEffect` - 效果基类（抽象类）
- `GameplayFilterData` - 过滤器基类（抽象类）

### 效果实现（data/effects/）
- `GE_ModifyHealth` - 修改生命值效果（伤害/治疗）
- `GE_ModifyMana` - 修改法力值效果
- `GE_AttributeModifier` - 属性修改器效果（状态型）
- `GE_DamageModification` - 伤害修改效果（事件监听型）
- `GE_ApplyStatus` - 应用状态效果（依赖StatusComponent）

### 过滤器实现（data/filters/）
- `FilterTargetIsAlive` - 检查目标是否存活
- `FilterTargetHasComponent` - 检查目标是否有指定组件

### 组件（components/）
- `AttributeComponent` - 属性组件（采用鸭子类型，不继承基类）
- `VitalComponent` - 资源组件基类（生命值、法力值等）
- `HealthComponent` - 生命值组件
- `ManaComponent` - 法力值组件

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

# 监听事件
CombatEventBus.entity_died.connect(_on_entity_died)
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

🚧 **开发中：**
- GameplayAbility系统（技能系统）
- GameplayAbilityStatus系统（状态系统）
- StatusComponent组件
- 更多Effect实现（位移、召唤、弹道等）

## 文档

详细文档请参考课程教程：`_tutorials/godot架构实战：即时战斗核心与技能系统篇.md`

## 许可证

MIT License

## 作者

老李（玩物不丧志的老李）

