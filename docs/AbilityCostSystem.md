# 技能消耗器系统 (Ability Cost System)

## 概述

技能消耗器系统是一个可扩展的资源消耗和限制条件框架，允许技能消耗多种资源类型（魔法值、怒气、能量、生命值等），也支持限制条件（如"生命值低于50%时无法使用"）。

## 架构设计

### 核心类

1. **`AbilityCostBase`**（抽象基类）
   - 定义消耗器的通用接口
   - 提供 `can_pay()` 和 `try_pay()` 方法
   - 提供 `get_cost_description()` 用于UI显示

2. **`VitalCost`**（Vital 消耗器）
   - 消耗指定的 Vital（如魔法值、怒气、能量、生命值等）
   - 支持透支模式（`allow_overdraft`）

### 设计优势

- **开闭原则**：可以轻松扩展新的消耗类型，无需修改现有代码
- **组合模式**：一个技能可以同时消耗多种资源
- **解耦设计**：消耗逻辑独立于技能系统，易于测试和维护

## 使用方法

### 1. 创建 Vital 消耗器资源

在编辑器中：
1. 右键点击项目 → `新建资源`
2. 选择 `VitalCost`
3. 配置：
   - `vital_id`: 要消耗的 Vital ID（如 `"mana"`, `"rage"`, `"energy"`, `"health"`）
   - `amount`: 消耗数量
   - `allow_overdraft`: 是否允许透支

### 2. 在技能中配置消耗

在技能的 `.tres` 文件中：
- 将 `VitalCost` 资源添加到 `costs` 数组

### 3. 代码示例

```gdscript
# 创建 VitalCost 资源
var mana_cost = VitalCost.new()
mana_cost.vital_id = &"mana"
mana_cost.amount = 10.0
mana_cost.allow_overdraft = false

# 添加到技能
ability.costs.append(mana_cost)
```

### 4. 多消耗示例

一个技能可以同时消耗多种资源：

```gdscript
# 消耗魔法值和怒气
var mana_cost = VitalCost.new()
mana_cost.vital_id = &"mana"
mana_cost.amount = 20.0

var rage_cost = VitalCost.new()
rage_cost.vital_id = &"rage"
rage_cost.amount = 5.0

ability.costs = [mana_cost, rage_cost]
```

## 扩展新的消耗类型

### 创建自定义消耗器

继承 `AbilityCostBase` 并实现以下方法：

```gdscript
extends AbilityCostBase
class_name CustomCost

@export var custom_property: float = 0.0

func _can_pay(ability_comp: Node, instigator: Node) -> bool:
	# 检查是否可以支付消耗
	return true

func _try_pay(ability_comp: Node, instigator: Node) -> bool:
	# 实际消耗资源
	return true

func _get_cost_description() -> String:
	return "消耗: 自定义资源 %.0f" % custom_property
```

### 示例：属性消耗器

```gdscript
extends AbilityCostBase
class_name AttributeCost

## 消耗指定属性的消耗器
## 例如：消耗 10 点力量属性

@export var attribute_name: StringName = &"strength"
@export var amount: float = 10.0

func _can_pay(ability_comp: Node, instigator: Node) -> bool:
	var attr_comp = GameplayAbilitySystem.get_component_by_interface(
		instigator,
		"GameplayAttributeComponent"
	)
	if not is_instance_valid(attr_comp):
		return false
	return attr_comp.get_attribute_value(attribute_name) >= amount

func _try_pay(ability_comp: Node, instigator: Node) -> bool:
	var attr_comp = GameplayAbilitySystem.get_component_by_interface(
		instigator,
		"GameplayAttributeComponent"
	)
	if not is_instance_valid(attr_comp):
		return false
	return attr_comp.modify_attribute(attribute_name, -amount)

func _get_cost_description() -> String:
	return "消耗 %s: %.0f" % [attribute_name, amount]
```

### 示例：条件限制器

```gdscript
extends AbilityCostBase
class_name HealthPercentCondition

## 生命值百分比条件限制器
## 例如：生命值低于50%时无法使用

@export var min_health_percent: float = 0.5  ## 最低生命值百分比

func _can_pay(ability_comp: Node, instigator: Node) -> bool:
	var vital_comp = GameplayAbilitySystem.get_component_by_interface(
		instigator,
		"GameplayVitalAttributeComponent"
	)
	if not is_instance_valid(vital_comp):
		return false
	
	var health_percent = vital_comp.get_vital_percent(&"health")
	return health_percent >= min_health_percent

func _try_pay(ability_comp: Node, instigator: Node) -> bool:
	# 条件限制器不需要实际消耗资源
	return true

func _get_cost_description() -> String:
	return "需要生命值 ≥ %.0f%%" % (min_health_percent * 100)
```

## UI 集成

技能消耗描述会自动显示在技能 Tooltip 中：

```gdscript
# ability_button.gd 中已自动集成
var costs_desc = ability_data.get_costs_description()
# 输出示例：
# "消耗 魔法值: 10
#  消耗 怒气: 5"
```

## 向后兼容

旧的 `mana_cost` 属性已被移除，但可以通过以下方式迁移：

1. 创建 `VitalCost` 资源
2. 设置 `vital_id = "mana"`, `amount = 原 mana_cost 值`
3. 添加到技能的 `costs` 数组

## 注意事项

1. **消耗顺序**：消耗器按数组顺序执行，如果前面的消耗失败，后续消耗不会执行
2. **透支模式**：`allow_overdraft = true` 时，即使 Vital 不足也会消耗（可能变成负数）
3. **错误处理**：如果消耗失败，`_commit_cast` 会返回 `false`，技能不会施放

