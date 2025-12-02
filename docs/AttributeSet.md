# 属性集（GameplayAttributeSet）使用指南

## 概述

`GameplayAttributeSet` 是一个抽象属性集类，用于维护若干属性，业务层可派生重写。通过钩子函数重写来实现属性依赖关系（例如1点力量转换为10点生命值）。

## 核心概念

### 属性集的作用

属性集用于：
1. **组织属性**：将相关属性组织在一起（例如：一级属性集包含力量、体力、敏捷、智力）
2. **管理依赖**：通过钩子函数实现属性间的依赖关系（例如：力量影响攻击力和生命值）
3. **生命周期管理**：在属性值变化前后进行处理

### 设计理念

- **抽象基类**：`GameplayAttributeSet` 是抽象基类，业务层应派生重写
- **钩子函数**：通过重写钩子函数来实现自定义逻辑
- **解耦设计**：属性集与属性组件解耦，可以灵活组合使用

## 钩子函数

### `_on_resolve_initial_value_dependencies(attribute_component)`

解析属性间的初始值依赖关系。

**使用场景**：
- 设置初始值依赖（例如：当前生命值初始值 = 最大生命值初始值）

**示例**：
```gdscript
func _on_resolve_initial_value_dependencies(attribute_component: GameplayAttributeComponent) -> void:
    if attribute_component.has_attribute(&"current_health") and attribute_component.has_attribute(&"max_health"):
        var max_health = attribute_component.get_value(&"max_health")
        attribute_component.set_value(&"current_health", max_health)
```

### `_pre_base_value_change(attribute_id, old_base_value, proposed_new_base_value, source)`

在基础值变化前进行验证和修改。

**使用场景**：
- 限制属性值的范围
- 修改提议的值

**返回值**：实际要设置的基础值

**示例**：
```gdscript
func _pre_base_value_change(attribute_id: StringName, old_base_value: float, proposed_new_base_value: float, source: Variant = null) -> Variant:
    # 限制最大生命值不超过10000
    if attribute_id == &"max_health" and proposed_new_base_value > 10000.0:
        return 10000.0
    return proposed_new_base_value
```

### `_post_current_value_change(attribute_id, old_current_value, new_current_value, source)`

在当前值变化后处理。

**使用场景**：
- 触发副作用（例如：生命值降为0时触发死亡）
- 同步其他属性

**示例**：
```gdscript
func _post_current_value_change(attribute_id: StringName, old_current_value: float, new_current_value: float, source: Variant = null) -> void:
    if attribute_id == &"current_health" and new_current_value <= 0:
        # 触发死亡逻辑
        pass
```

### `_on_attribute_dependency_changed(changed_attribute_id, new_value, attribute_component)`

当依赖的属性变化时，更新派生属性。

**使用场景**：
- 实现属性依赖关系（例如：1点力量转换为10点生命值）

**示例**：
```gdscript
func _on_attribute_dependency_changed(changed_attribute_id: StringName, new_value: float, attribute_component: GameplayAttributeComponent) -> void:
    # 只处理一级属性的变化
    if changed_attribute_id not in [&"strength", &"constitution"]:
        return
    
    var strength = attribute_component.get_value(&"strength", 0.0)
    var health_from_strength = strength * 10.0  # 1点力量 = 10点生命值
    var base_max_health = 100.0
    var new_max_health = base_max_health + health_from_strength
    
    if attribute_component.has_attribute(&"max_health"):
        attribute_component.set_value(&"max_health", new_max_health)
```

## 使用示例

### 1. 创建自定义属性集

```gdscript
extends GameplayAttributeSet
class_name MyCustomAttributeSet

func _init():
    attribute_ids = [
        &"strength",
        &"constitution",
        &"agility",
        &"intelligence"
    ]

func _on_attribute_dependency_changed(changed_attribute_id: StringName, new_value: float, attribute_component: GameplayAttributeComponent) -> void:
    # 实现自定义依赖关系
    pass
```

### 2. 在属性组件中使用属性集

```gdscript
# 创建属性组件
var attribute_comp = GameplayAttributeComponent.new()
add_child(attribute_comp)

# 定义初始属性值
var attributes = {
    "strength": 10.0,
    "constitution": 8.0,
    "agility": 12.0,
    "intelligence": 15.0,
    "max_health": 100.0,
    "attack": 20.0,
    "defense": 10.0
}

# 创建属性集
var primary_set = PrimaryAttributeSet.new()
var secondary_set = SecondaryAttributeSet.new()

# 使用属性集初始化
attribute_comp.initialize_with_attribute_sets(attributes, [primary_set, secondary_set])
```

### 3. 完整示例：单位属性系统

```gdscript
extends CharacterBody3D

@onready var attribute_comp = GameplayAttributeComponent.new()
@onready var health_comp = HealthComponent.new()

func _ready():
    # 添加组件
    add_child(attribute_comp)
    add_child(health_comp)
    
    # 初始化属性
    var attributes = {
        # 一级属性
        "strength": 10.0,
        "constitution": 8.0,
        "agility": 12.0,
        "intelligence": 15.0,
        # 二级属性（初始值，会被属性集自动计算）
        "max_health": 100.0,
        "max_mana": 50.0,
        "attack": 20.0,
        "defense": 10.0,
        # 当前值
        "current_health": 100.0
    }
    
    # 创建属性集
    var primary_set = PrimaryAttributeSet.new()
    var secondary_set = SecondaryAttributeSet.new()
    
    # 使用属性集初始化
    attribute_comp.initialize_with_attribute_sets(attributes, [primary_set, secondary_set])
    
    # 初始化生命值组件
    health_comp._attribute_comp = attribute_comp
    health_comp.max_value_id = &"max_health"
    
    # 当力量变化时，生命值会自动更新
    # 例如：增加5点力量，最大生命值会增加50点（5 * 10）
    attribute_comp.change_value(&"strength", 5.0)
```

## 示例属性集

### PrimaryAttributeSet（一级属性集）

包含基础属性：力量、体力、敏捷、智力。

### SecondaryAttributeSet（二级属性集）

包含派生属性：攻击、防御、最大生命值、最大法力值。

实现属性依赖关系：
- 1点力量 = 10点最大生命值
- 1点力量 = 2点攻击力
- 1点体力 = 5点最大生命值
- 1点体力 = 1点防御力
- 1点敏捷 = 1点攻击力
- 1点智力 = 5点最大法力值

## 最佳实践

1. **属性集职责单一**：每个属性集应该只管理一组相关的属性
2. **避免循环依赖**：确保属性依赖关系不会形成循环
3. **性能考虑**：在 `_on_attribute_dependency_changed` 中只处理必要的属性变化
4. **错误处理**：在更新派生属性前，检查属性是否存在

## 注意事项

1. 属性集会在属性组件初始化时自动注册，并监听属性变化
2. 钩子函数会在属性值变化时自动调用
3. 在钩子函数中修改属性值时，要注意避免无限循环
4. 属性集的 `attribute_ids` 应该在 `_init()` 中初始化

