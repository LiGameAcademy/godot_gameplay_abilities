# GameplayVitalAttributeComponent 使用指南

## 概述

`GameplayVitalAttributeComponent` 继承自 `GameplayAttributeComponent`，在属性系统的基础上扩展了 Vitals（生命值系统）管理功能。它提供了完整的属性系统和生命值系统集成。

## 架构设计

### 组件关系

```
GameplayAttributeComponent (基础组件)
  └─ 管理属性系统（攻击力、防御力等）

GameplayVitalAttributeComponent (扩展组件)
  └─ 继承自 GameplayAttributeComponent
  └─ 扩展 Vitals 管理功能
      ├─ HealthVital
      ├─ ManaVital
      └─ 其他自定义 Vital...
```

### 设计优势

1. **职责清晰**：基础组件专注于属性，扩展组件添加 Vitals 功能
2. **灵活选择**：业务层可以选择使用基础组件或扩展组件
3. **代码复用**：通过继承复用属性系统的所有功能
4. **统一接口**：所有功能通过一个组件提供

## 使用方式

### 方式一：使用 GameplayVitalAttributeComponent（推荐）

```gdscript
extends CharacterBody3D

@onready var vital_attr_comp: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()

func _ready():
	# 添加组件
	add_child(vital_attr_comp)
	
	# 初始化组件（同时传入属性集和 Vitals）
	var primary_set = preload("res://data/attribute_set/primary_attribute_set.tres")
	var secondary_set = preload("res://data/attribute_set/secondary_attribute_set.tres")
	var health_vital = preload("res://data/vitals/health_vital.tres")
	var mana_vital = preload("res://data/vitals/mana_vital.tres")
	
	vital_attr_comp.initialize([primary_set, secondary_set], [health_vital, mana_vital])
	
	# 监听信号
	vital_attr_comp.attribute_value_changed.connect(_on_attribute_changed)
	vital_attr_comp.vital_value_changed.connect(_on_vital_changed)
	vital_attr_comp.vital_depleted.connect(_on_vital_depleted)

func _on_attribute_changed(attr_id: StringName, new_val: float):
	print("属性 [%s] 变化: %.1f" % [attr_id, new_val])

func _on_vital_changed(vital_id: StringName, current: float, max: float, percent: float):
	print("Vital [%s]: %.1f / %.1f (%.1f%%)" % [vital_id, current, max, percent * 100])

func _on_vital_depleted(vital_id: StringName):
	if vital_id == &"health":
		print("角色死亡！")
```

### 方式二：只使用基础属性组件

```gdscript
extends CharacterBody3D

@onready var attr_comp: GameplayAttributeComponent = GameplayAttributeComponent.new()

func _ready():
	add_child(attr_comp)
	
	# 只初始化属性系统
	var primary_set = preload("res://data/attribute_set/primary_attribute_set.tres")
	var secondary_set = preload("res://data/attribute_set/secondary_attribute_set.tres")
	attr_comp.initialize([primary_set, secondary_set])
	
	# 监听属性变化
	attr_comp.attribute_value_changed.connect(_on_attribute_changed)
```

## API 参考

### 初始化

```gdscript
## 初始化组件
## [param] sets: Array[GameplayAttributeSet] 属性集数组
## [param] vitals: Array[GameplayVital] Vital 模板数组（可选）
func initialize(sets: Array[GameplayAttributeSet], vitals: Array[GameplayVital] = []) -> void
```

### 属性 API（继承自 GameplayAttributeComponent）

```gdscript
## 获取属性值
func get_value(id: StringName, default: float = 0.0) -> float

## 获取属性实例
func get_attribute(id: StringName) -> GameplayAttributeInstance

## 设置基础值
func set_base_value(id: StringName, val: float)

## 添加修改器
func add_modifier(mod: GameplayAttributeModifier)

## 移除修改器
func remove_modifier(mod: GameplayAttributeModifier)

## 检查是否有属性
func has_attribute(id: StringName) -> bool
```

### Vital API

```gdscript
## 检查是否有指定的 Vital
func has_vital(vital_id: StringName) -> bool

## 获取 Vital 实例
func get_vital(vital_id: StringName) -> GameplayVital

## 获取 Vital 当前值
func get_vital_value(vital_id: StringName) -> float

## 检查是否有足够的 Vital
func has_sufficient_vital(vital_id: StringName, amount: float) -> bool

## 获取 Vital 百分比
func get_vital_percent(vital_id: StringName) -> float

## 修改 Vital 值
func modify_vital(vital_id: StringName, amount: float) -> bool

## 注册 Vital 实例（运行时动态添加）
func register_vital(vital: GameplayVital) -> bool
```

### 信号

```gdscript
## 属性值变化时发出（继承自父类）
signal attribute_value_changed(id: StringName, new_val: float)

## Vital 值变化时发出
signal vital_value_changed(vital_id: StringName, current: float, max: float, percent: float)

## Vital 耗尽时发出
signal vital_depleted(vital_id: StringName)
```

## 使用示例

### 示例 1：应用伤害

```gdscript
func take_damage(amount: float):
	var health_vital = vital_attr_comp.get_vital(&"health")
	if health_vital:
		var damage_info = DamageInfo.new()
		damage_info.base_damage = amount
		health_vital.apply_damage(damage_info, self)
```

### 示例 2：消耗法力

```gdscript
func try_cast_spell(mana_cost: float) -> bool:
	if vital_attr_comp.has_sufficient_vital(&"mana", mana_cost):
		vital_attr_comp.modify_vital(&"mana", -mana_cost)
		return true
	return false
```

### 示例 3：治疗

```gdscript
func heal(amount: float):
	vital_attr_comp.modify_vital(&"health", amount)
```

### 示例 4：运行时添加新的 Vital

```gdscript
func add_stamina_vital():
	var stamina_vital = GameplayVital.new(vital_attr_comp)
	stamina_vital.vital_id = &"stamina"
	stamina_vital.display_name = "体力"
	stamina_vital.max_value_attribute = &"stamina"
	stamina_vital.regen_rate_attribute = &"stamina_regen"
	vital_attr_comp.register_vital(stamina_vital)
```

### 示例 5：同时使用属性和 Vitals

```gdscript
func upgrade_character():
	# 增加属性
	vital_attr_comp.set_base_value(&"strength", vital_attr_comp.get_value(&"strength") + 1)
	
	# 属性变化会自动更新 Vital 的最大值（通过依赖系统）
	# 例如：strength 增加 -> max_health 增加（通过 SecondaryAttributeSet）
	
	# 治疗到满血
	var max_health = vital_attr_comp.get_vital(&"health")._cached_max
	vital_attr_comp.modify_vital(&"health", max_health)
```

## 最佳实践

1. **初始化顺序**：先初始化属性系统，再初始化 Vitals（组件内部已处理）
2. **依赖检查**：确保 Vital 依赖的属性（如 `max_health`）在属性组件中存在
3. **信号处理**：分别监听属性变化和 Vital 变化信号，处理不同的业务逻辑
4. **性能考虑**：组件会在 `_process` 中处理自动恢复，确保只在需要时使用

## 与基础组件的区别

| 功能 | GameplayAttributeComponent | GameplayVitalAttributeComponent |
|------|---------------------------|-------------------------------|
| 属性管理 | ✅ | ✅（继承） |
| Vital 管理 | ❌ | ✅ |
| 自动恢复 | ❌ | ✅（_process） |
| Vital 信号 | ❌ | ✅ |
| 使用场景 | 纯属性系统 | 属性 + 生命值系统 |

## 迁移指南

如果你之前使用 `GameplayAttributeComponent` 的内置 Vitals 功能，可以按以下步骤迁移：

1. 将组件类型从 `GameplayAttributeComponent` 改为 `GameplayVitalAttributeComponent`
2. 初始化方法保持不变：`initialize(sets, vitals)`
3. API 调用保持不变，所有方法都兼容
4. 信号监听保持不变
