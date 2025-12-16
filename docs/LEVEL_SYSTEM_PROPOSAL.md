# 等级系统设计提案

## 当前系统分析

### ✅ 已支持等级的系统

#### 1. **属性系统（Attribute System）**
- ✅ `GameplayAttributeInstance` 有 `current_level: int`
- ✅ `ScalableValue` 支持基于 `Curve` 的等级成长
- ✅ `GameplayAttributeComponent` 有 `current_level` 属性
- ✅ 属性值可以随等级自动增长

**结论**：属性系统已经完整支持等级概念，设计良好。

### ❌ 未支持等级的系统

#### 2. **技能系统（Ability System）**
- ❌ `GameplayAbility` 没有 `level` 属性
- ❌ 技能效果是固定的，无法随等级变化
- ❌ 技能冷却、消耗等无法随等级变化

**现状**：技能系统目前不支持等级，所有技能效果都是固定的。

#### 3. **状态系统（Status System）**
- ✅ 有层数（stacks）概念：`max_stacks`, `stacking_policy`
- ❌ 没有等级（level）概念
- ❌ 状态效果无法随等级变化

**现状**：状态系统支持层数叠加，但不支持等级成长。

#### 4. **效果系统（Effect System）**
- ❌ `GameplayEffect` 没有等级概念
- ❌ 效果数值是固定的

**现状**：效果系统不支持等级，所有效果都是固定数值。

## 是否需要支持等级？

### 技能等级（Ability Level）

**推荐：✅ 应该支持**

**理由**：
1. **RPG 游戏标准功能**：几乎所有 RPG 游戏都有技能升级系统
2. **玩家成长感**：技能升级是玩家重要的成长路径
3. **数值平衡**：通过等级控制技能强度，便于平衡

**常见需求**：
- 技能等级 1：伤害 100，冷却 10 秒
- 技能等级 5：伤害 200，冷却 8 秒
- 技能等级 10：伤害 300，冷却 6 秒，额外效果

**实现方式**：
```gdscript
# GameplayAbility 添加等级支持
@export var max_level: int = 10
var current_level: int = 1

# 效果使用 ScalableValue 或 LevelData
@export var damage_scalable: ScalableValue
@export var cooldown_scalable: ScalableValue
```

### 状态等级（Status Level）

**推荐：⚠️ 可选支持**

**理由**：
1. **层数 vs 等级**：大多数游戏用层数（stacks）表示状态强度
2. **特殊需求**：某些游戏需要"状态等级"（如中毒等级 1-5）
3. **复杂度**：层数和等级是不同概念，同时支持会增加复杂度

**建议**：
- **默认使用层数**：大多数情况用 `stacks` 就够了
- **特殊需求用等级**：如果需要"状态等级"概念，可以添加 `level` 属性
- **两者可共存**：层数用于叠加，等级用于成长

**实现方式**：
```gdscript
# GameplayStatusData 添加等级支持（可选）
@export var use_level_scaling: bool = false
@export var max_level: int = 5
var current_level: int = 1

# 效果使用 ScalableValue
@export var effect_scalable: ScalableValue
```

### 效果等级（Effect Level）

**推荐：❌ 不需要**

**理由**：
1. **效果是数据**：效果是技能/状态的配置，不应该有独立等级
2. **继承等级**：效果应该从技能/状态继承等级
3. **避免重复**：如果技能有等级，效果就不需要单独等级

**建议**：
- 效果通过 `context` 获取技能/状态等级
- 效果使用 `ScalableValue` 根据等级计算数值
- 不需要在 `GameplayEffect` 中添加 `level` 属性

## 设计方案

### 方案 A：技能等级 + 效果继承（推荐）

```gdscript
# GameplayAbility 添加等级支持
extends Resource
class_name GameplayAbility

@export var max_level: int = 10
var current_level: int = 1

# 使用 ScalableValue 定义等级成长
@export var cooldown_scalable: ScalableValue
@export var cost_scalable: ScalableValue

# 效果通过 context 获取技能等级
func _on_cast(ability_comp: Node, target: Node, context: Dictionary) -> void:
    context["ability_level"] = current_level
    # ... 应用效果
```

```gdscript
# GameplayEffect 从 context 获取等级
extends GameplayEffect
class_name GE_ApplyDamage

@export var damage_scalable: ScalableValue

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
    var level = context.get("ability_level", 1)
    var damage = damage_scalable.get_value_at_level(level)
    # ... 应用伤害
```

**优点**：
- 技能有等级，效果继承等级
- 使用现有的 `ScalableValue` 系统
- 通过 `context` 传递等级，解耦设计

### 方案 B：技能等级 + 状态等级（完整支持）

```gdscript
# GameplayAbility 添加等级
extends Resource
class_name GameplayAbility
@export var max_level: int = 10
var current_level: int = 1

# GameplayStatusData 添加等级（可选）
extends Resource
class_name GameplayStatusData
@export var use_level_scaling: bool = false
@export var max_level: int = 5
var current_level: int = 1

# GameplayStatusInstance 管理等级
extends RefCounted
class_name GameplayStatusInstance
var level: int = 1
```

**优点**：
- 完整支持技能和状态等级
- 灵活性最高

**缺点**：
- 复杂度较高
- 大多数游戏不需要状态等级

### 方案 C：仅技能等级（最小改动）

```gdscript
# 只在 GameplayAbility 添加等级
extends Resource
class_name GameplayAbility
@export var max_level: int = 10
var current_level: int = 1

# 效果通过 context 获取等级
# 状态不支持等级（继续使用层数）
```

**优点**：
- 改动最小
- 满足大多数需求

**缺点**：
- 不支持状态等级（如果需要）

## 推荐方案

**推荐使用方案 A（技能等级 + 效果继承）**

### 实现步骤

#### 1. 在 `GameplayAbility` 添加等级支持

```gdscript
extends Resource
class_name GameplayAbility

@export_group("Level System")
## 最大等级
@export var max_level: int = 10
## 当前等级（运行时）
var current_level: int = 1

## 设置技能等级
func set_level(level: int) -> void:
    current_level = clamp(level, 1, max_level)
    _on_level_changed()

## 等级改变时的回调
func _on_level_changed() -> void:
    pass  # 子类可重写
```

#### 2. 在 `ActiveAbility` 添加等级相关的 ScalableValue

```gdscript
extends GameplayAbility
class_name ActiveAbility

@export_group("Level Scaling")
## 冷却时间随等级变化（可选）
@export var cooldown_scalable: ScalableValue = null
## 消耗随等级变化（可选）
@export var cost_scalable: ScalableValue = null

func _on_level_changed() -> void:
    # 重新计算冷却和消耗
    if is_instance_valid(cooldown_scalable):
        cooldown = cooldown_scalable.get_value_at_level(current_level)
    # ... 其他等级相关计算
```

#### 3. 在 `context` 中传递技能等级

```gdscript
# GameplayAbilityComponent.commit_cast
func commit_cast(ability_id: StringName, target: Node = null, context: Dictionary = {}) -> void:
    var ability_data = get_ability_data(ability_id)
    if not is_instance_valid(ability_data):
        return
    
    # 将技能等级添加到 context
    context["ability_level"] = ability_data.current_level
    # ... 其他逻辑
```

#### 4. 效果使用 ScalableValue 根据等级计算

```gdscript
extends GameplayEffect
class_name GE_ApplyDamage

@export var damage_scalable: ScalableValue

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
    var level = context.get("ability_level", 1)
    var damage = damage_scalable.get_value_at_level(level)
    # ... 应用伤害
```

## 状态等级支持（可选）

如果需要状态等级，可以这样实现：

```gdscript
extends Resource
class_name GameplayStatusData

@export_group("Level System (Optional)")
## 是否启用等级成长
@export var use_level_scaling: bool = false
## 最大等级
@export var max_level: int = 5

# 在 GameplayStatusInstance 中
extends RefCounted
class_name GameplayStatusInstance

var level: int = 1

func apply(status_data: GameplayStatusData, instigator: Node, stacks: int, context: Dictionary) -> void:
    # 从 context 获取等级（如果状态支持等级）
    if status_data.use_level_scaling:
        level = context.get("status_level", 1)
    # ... 应用状态
```

## 总结

### 推荐实现优先级

1. **✅ 技能等级（高优先级）**
   - 几乎所有 RPG 游戏都需要
   - 使用 `ScalableValue` 系统
   - 通过 `context` 传递等级

2. **⚠️ 状态等级（低优先级）**
   - 大多数游戏用层数就够了
   - 特殊需求时再添加

3. **❌ 效果等级（不推荐）**
   - 效果应该从技能/状态继承等级
   - 不需要独立等级系统

### 迁移建议

1. **阶段 1**：在 `GameplayAbility` 添加等级支持
2. **阶段 2**：在 `context` 中传递等级
3. **阶段 3**：效果使用 `ScalableValue` 根据等级计算
4. **阶段 4**（可选）：状态等级支持

