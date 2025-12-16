# 技能上下文类设计提案

## 当前 Dictionary 方案的问题

### 1. 类型不安全
```gdscript
# 当前方式：没有类型检查
var damage = context.get("final_damage", 0.0)  # 可能是任何类型
var ability = context.get("ability", null)      # 类型未知
```

### 2. 容易拼写错误
```gdscript
# 拼写错误不会在编译时发现
context["damage_multiplier_modifier"]  # 如果拼错，运行时才会发现
```

### 3. 没有 IDE 自动补全
- 无法通过 `.` 访问属性
- 需要手动输入字符串键名

### 4. 难以重构
- 重命名键需要全局搜索替换
- 容易遗漏某些使用位置

### 5. 没有文档
- 不知道有哪些键可用
- 不知道每个键的类型和用途

## 上下文类设计方案

### 方案 A：单一上下文类（推荐）

```gdscript
# scripts/core/ability_context.gd
extends RefCounted
class_name AbilityContext

## 技能执行上下文
## 用于在技能执行过程中传递数据和状态

# ========== 核心数据 ==========
## 施法者
var instigator: Node = null
## 输入目标（用户指定的目标）
var input_target: Node = null
## 当前技能数据
var ability: GameplayAbility = null
## 技能组件
var ability_comp: GameplayAbilityComponent = null
## 技能ID
var ability_id: StringName = &""

# ========== 效果相关 ==========
## 最终伤害值（由 GE_ApplyDamage 设置）
var final_damage: float = 0.0
## 伤害倍率修改器（由 Modifier 设置）
var damage_multiplier_modifier: float = 1.0
## 额外效果列表（由 Modifier 追加）
var extra_effects: Array[GameplayEffect] = []
## 是否将额外效果应用到所有目标
var apply_extra_effects_to_all_targets: bool = true

# ========== 投射物相关 ==========
## 额外投射物数量（由 Modifier 设置）
var extra_projectiles: int = 0
## 枪口变换（用于投射物生成）
var muzzle_transform: Transform3D = Transform3D.IDENTITY

# ========== 冷却相关 ==========
## 冷却缩减（由 Modifier 设置，0.0-1.0）
var cooldown_reduction: float = 0.0
## 是否跳过冷却检查
var skip_cooldown: bool = false

# ========== 消耗相关 ==========
## 是否跳过消耗检查
var skip_cost: bool = false

# ========== 碰撞相关 ==========
## 命中位置
var hit_position: Vector3 = Vector3.ZERO
## 命中方向
var hit_direction: Vector3 = Vector3.ZERO
## 投射物实例（用于传递投射物信息）
var projectile: Node = null

# ========== 伤害相关 ==========
## 伤害信息（用于伤害修改）
var damage_info: DamageInfo = null

# ========== 通用数据 ==========
## 通用数值（用于飘字等）
var value: float = 0.0
## 通用文本（用于飘字等）
var text: String = ""

# ========== 扩展数据（向后兼容） ==========
## 扩展数据字典（用于存储自定义数据，保持向后兼容）
var custom_data: Dictionary = {}

## 创建上下文实例
static func create() -> AbilityContext:
	return AbilityContext.new()

## 复制上下文（用于传递到子效果）
func duplicate() -> AbilityContext:
	var new_context = AbilityContext.new()
	# 复制所有属性
	new_context.instigator = instigator
	new_context.input_target = input_target
	new_context.ability = ability
	new_context.ability_comp = ability_comp
	new_context.ability_id = ability_id
	new_context.final_damage = final_damage
	new_context.damage_multiplier_modifier = damage_multiplier_modifier
	new_context.extra_effects = extra_effects.duplicate()
	new_context.apply_extra_effects_to_all_targets = apply_extra_effects_to_all_targets
	new_context.extra_projectiles = extra_projectiles
	new_context.muzzle_transform = muzzle_transform
	new_context.cooldown_reduction = cooldown_reduction
	new_context.skip_cooldown = skip_cooldown
	new_context.skip_cost = skip_cost
	new_context.hit_position = hit_position
	new_context.hit_direction = hit_direction
	new_context.projectile = projectile
	new_context.damage_info = damage_info
	new_context.value = value
	new_context.text = text
	new_context.custom_data = custom_data.duplicate()
	return new_context

## 从 Dictionary 创建（向后兼容）
static func from_dict(dict: Dictionary) -> AbilityContext:
	var context = AbilityContext.new()
	if dict.has("instigator"):
		context.instigator = dict["instigator"]
	if dict.has("input_target"):
		context.input_target = dict["input_target"]
	if dict.has("ability"):
		context.ability = dict["ability"]
	if dict.has("ability_comp"):
		context.ability_comp = dict["ability_comp"]
	if dict.has("ability_id"):
		context.ability_id = dict["ability_id"]
	if dict.has("final_damage"):
		context.final_damage = dict["final_damage"]
	if dict.has("damage_multiplier_modifier"):
		context.damage_multiplier_modifier = dict["damage_multiplier_modifier"]
	if dict.has("extra_effects"):
		context.extra_effects = dict["extra_effects"]
	if dict.has("apply_extra_effects_to_all_targets"):
		context.apply_extra_effects_to_all_targets = dict["apply_extra_effects_to_all_targets"]
	if dict.has("extra_projectiles"):
		context.extra_projectiles = dict["extra_projectiles"]
	if dict.has("muzzle_transform"):
		context.muzzle_transform = dict["muzzle_transform"]
	if dict.has("cooldown_reduction"):
		context.cooldown_reduction = dict["cooldown_reduction"]
	if dict.has("skip_cooldown"):
		context.skip_cooldown = dict["skip_cooldown"]
	if dict.has("skip_cost"):
		context.skip_cost = dict["skip_cost"]
	if dict.has("hit_position"):
		context.hit_position = dict["hit_position"]
	if dict.has("hit_direction"):
		context.hit_direction = dict["hit_direction"]
	if dict.has("projectile"):
		context.projectile = dict["projectile"]
	if dict.has("damage_info"):
		context.damage_info = dict["damage_info"]
	if dict.has("value"):
		context.value = dict["value"]
	if dict.has("text"):
		context.text = dict["text"]
	# 其他未识别的键存入 custom_data
	for key in dict:
		if not context.has(key):
			context.custom_data[key] = dict[key]
	return context

## 转换为 Dictionary（向后兼容）
func to_dict() -> Dictionary:
	var dict: Dictionary = {}
	if is_instance_valid(instigator):
		dict["instigator"] = instigator
	if is_instance_valid(input_target):
		dict["input_target"] = input_target
	if is_instance_valid(ability):
		dict["ability"] = ability
	if is_instance_valid(ability_comp):
		dict["ability_comp"] = ability_comp
	if not ability_id.is_empty():
		dict["ability_id"] = ability_id
	if final_damage != 0.0:
		dict["final_damage"] = final_damage
	if damage_multiplier_modifier != 1.0:
		dict["damage_multiplier_modifier"] = damage_multiplier_modifier
	if not extra_effects.is_empty():
		dict["extra_effects"] = extra_effects
	if not apply_extra_effects_to_all_targets:
		dict["apply_extra_effects_to_all_targets"] = apply_extra_effects_to_all_targets
	if extra_projectiles != 0:
		dict["extra_projectiles"] = extra_projectiles
	if muzzle_transform != Transform3D.IDENTITY:
		dict["muzzle_transform"] = muzzle_transform
	if cooldown_reduction != 0.0:
		dict["cooldown_reduction"] = cooldown_reduction
	if skip_cooldown:
		dict["skip_cooldown"] = skip_cooldown
	if skip_cost:
		dict["skip_cost"] = skip_cost
	if hit_position != Vector3.ZERO:
		dict["hit_position"] = hit_position
	if hit_direction != Vector3.ZERO:
		dict["hit_direction"] = hit_direction
	if is_instance_valid(projectile):
		dict["projectile"] = projectile
	if is_instance_valid(damage_info):
		dict["damage_info"] = damage_info
	if value != 0.0:
		dict["value"] = value
	if not text.is_empty():
		dict["text"] = text
	# 合并 custom_data
	for key in custom_data:
		dict[key] = custom_data[key]
	return dict
```

### 方案 B：分层上下文类

```gdscript
# 基础上下文
class_name BaseContext extends RefCounted

# 技能上下文（继承基础上下文）
class_name AbilityContext extends BaseContext

# 效果上下文（继承技能上下文）
class_name EffectContext extends AbilityContext

# 状态上下文（继承技能上下文）
class_name StatusContext extends AbilityContext
```

**不推荐方案 B**：过度设计，增加复杂度，当前系统不需要这么细的层级。

## 迁移策略

### 阶段 1：创建上下文类，保持向后兼容
- 创建 `AbilityContext` 类
- 提供 `from_dict()` 和 `to_dict()` 方法
- 现有代码继续使用 Dictionary，新代码使用 Context

### 阶段 2：逐步迁移
- 优先迁移核心路径（Ability → Effect → Cue）
- 保持 Dictionary 和 Context 的双向转换

### 阶段 3：完全迁移
- 移除 Dictionary 支持
- 统一使用 Context

## 使用示例

### 迁移前（Dictionary）
```gdscript
func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var damage = context.get("final_damage", 0.0)
	var multiplier = context.get("damage_multiplier_modifier", 1.0)
	context["final_damage"] = damage * multiplier
```

### 迁移后（Context）
```gdscript
func _apply(target: Node, instigator: Node, context: AbilityContext) -> void:
	var damage = context.final_damage
	var multiplier = context.damage_multiplier_modifier
	context.final_damage = damage * multiplier
```

## 优势总结

1. **类型安全**：编译时类型检查
2. **IDE 支持**：自动补全、类型提示
3. **易于重构**：重命名属性自动更新所有引用
4. **文档完善**：属性注释清晰
5. **性能更好**：RefCounted 比 Dictionary 更高效
6. **向后兼容**：提供转换方法，渐进式迁移

## 继承扩展支持

### 当前设计的问题

当前提案中的 `AbilityContext` 类**不完全支持继承扩展**，存在以下问题：

1. **`duplicate()` 返回类型固定**：返回 `AbilityContext`，子类继承后类型不匹配
2. **`from_dict()` 是静态方法**：子类无法重写，无法处理子类特有的属性
3. **`to_dict()` 硬编码属性**：子类的新属性无法自动序列化
4. **属性复制硬编码**：`duplicate()` 中所有属性都是硬编码，子类新属性无法复制

### 改进方案：支持继承扩展

```gdscript
# scripts/core/ability_context.gd
extends RefCounted
class_name AbilityContext

# ... 所有属性定义保持不变 ...

## 创建上下文实例（可被子类重写）
static func create() -> AbilityContext:
	return AbilityContext.new()

## 复制上下文（虚方法，子类可重写）
## 子类应该重写此方法，调用 super.duplicate() 然后复制自己的属性
func duplicate() -> AbilityContext:
	var new_context = _create_duplicate_instance()
	_copy_base_properties(new_context)
	return new_context

## 创建复制实例（子类可重写，用于返回正确的类型）
func _create_duplicate_instance() -> AbilityContext:
	return AbilityContext.new()

## 复制基础属性（供子类调用）
func _copy_base_properties(target: AbilityContext) -> void:
	target.instigator = instigator
	target.input_target = input_target
	target.ability = ability
	target.ability_comp = ability_comp
	target.ability_id = ability_id
	target.final_damage = final_damage
	target.damage_multiplier_modifier = damage_multiplier_modifier
	target.extra_effects = extra_effects.duplicate()
	target.apply_extra_effects_to_all_targets = apply_extra_effects_to_all_targets
	target.extra_projectiles = extra_projectiles
	target.muzzle_transform = muzzle_transform
	target.cooldown_reduction = cooldown_reduction
	target.skip_cooldown = skip_cooldown
	target.skip_cost = skip_cost
	target.hit_position = hit_position
	target.hit_direction = hit_direction
	target.projectile = projectile
	target.damage_info = damage_info
	target.value = value
	target.text = text
	target.custom_data = custom_data.duplicate()

## 从 Dictionary 创建（虚方法，子类可重写）
## 子类应该重写此方法，调用 super.from_dict() 然后处理自己的属性
static func from_dict(dict: Dictionary) -> AbilityContext:
	var context = AbilityContext.new()
	context._load_from_dict(dict)
	return context

## 从字典加载属性（供子类调用）
func _load_from_dict(dict: Dictionary) -> void:
	if dict.has("instigator"):
		instigator = dict["instigator"]
	if dict.has("input_target"):
		input_target = dict["input_target"]
	if dict.has("ability"):
		ability = dict["ability"]
	if dict.has("ability_comp"):
		ability_comp = dict["ability_comp"]
	if dict.has("ability_id"):
		ability_id = dict["ability_id"]
	if dict.has("final_damage"):
		final_damage = dict["final_damage"]
	if dict.has("damage_multiplier_modifier"):
		damage_multiplier_modifier = dict["damage_multiplier_modifier"]
	if dict.has("extra_effects"):
		extra_effects = dict["extra_effects"]
	if dict.has("apply_extra_effects_to_all_targets"):
		apply_extra_effects_to_all_targets = dict["apply_extra_effects_to_all_targets"]
	if dict.has("extra_projectiles"):
		extra_projectiles = dict["extra_projectiles"]
	if dict.has("muzzle_transform"):
		muzzle_transform = dict["muzzle_transform"]
	if dict.has("cooldown_reduction"):
		cooldown_reduction = dict["cooldown_reduction"]
	if dict.has("skip_cooldown"):
		skip_cooldown = dict["skip_cooldown"]
	if dict.has("skip_cost"):
		skip_cost = dict["skip_cost"]
	if dict.has("hit_position"):
		hit_position = dict["hit_position"]
	if dict.has("hit_direction"):
		hit_direction = dict["hit_direction"]
	if dict.has("projectile"):
		projectile = dict["projectile"]
	if dict.has("damage_info"):
		damage_info = dict["damage_info"]
	if dict.has("value"):
		value = dict["value"]
	if dict.has("text"):
		text = dict["text"]
	# 其他未识别的键存入 custom_data
	for key in dict:
		if not _is_base_property(key):
			custom_data[key] = dict[key]

## 检查是否是基础属性（供子类重写）
func _is_base_property(key: String) -> bool:
	return key in [
		"instigator", "input_target", "ability", "ability_comp", "ability_id",
		"final_damage", "damage_multiplier_modifier", "extra_effects",
		"apply_extra_effects_to_all_targets", "extra_projectiles", "muzzle_transform",
		"cooldown_reduction", "skip_cooldown", "skip_cost",
		"hit_position", "hit_direction", "projectile", "damage_info",
		"value", "text", "custom_data"
	]

## 转换为 Dictionary（虚方法，子类可重写）
func to_dict() -> Dictionary:
	var dict: Dictionary = {}
	_save_to_dict(dict)
	return dict

## 保存到字典（供子类调用）
func _save_to_dict(dict: Dictionary) -> void:
	if is_instance_valid(instigator):
		dict["instigator"] = instigator
	if is_instance_valid(input_target):
		dict["input_target"] = input_target
	if is_instance_valid(ability):
		dict["ability"] = ability
	if is_instance_valid(ability_comp):
		dict["ability_comp"] = ability_comp
	if not ability_id.is_empty():
		dict["ability_id"] = ability_id
	if final_damage != 0.0:
		dict["final_damage"] = final_damage
	if damage_multiplier_modifier != 1.0:
		dict["damage_multiplier_modifier"] = damage_multiplier_modifier
	if not extra_effects.is_empty():
		dict["extra_effects"] = extra_effects
	if not apply_extra_effects_to_all_targets:
		dict["apply_extra_effects_to_all_targets"] = apply_extra_effects_to_all_targets
	if extra_projectiles != 0:
		dict["extra_projectiles"] = extra_projectiles
	if muzzle_transform != Transform3D.IDENTITY:
		dict["muzzle_transform"] = muzzle_transform
	if cooldown_reduction != 0.0:
		dict["cooldown_reduction"] = cooldown_reduction
	if skip_cooldown:
		dict["skip_cooldown"] = skip_cooldown
	if skip_cost:
		dict["skip_cost"] = skip_cost
	if hit_position != Vector3.ZERO:
		dict["hit_position"] = hit_position
	if hit_direction != Vector3.ZERO:
		dict["hit_direction"] = hit_direction
	if is_instance_valid(projectile):
		dict["projectile"] = projectile
	if is_instance_valid(damage_info):
		dict["damage_info"] = damage_info
	if value != 0.0:
		dict["value"] = value
	if not text.is_empty():
		dict["text"] = text
	# 合并 custom_data
	for key in custom_data:
		dict[key] = custom_data[key]
```

### 业务层继承示例

```gdscript
# scripts/business/custom_ability_context.gd
extends AbilityContext
class_name CustomAbilityContext

## 业务层自定义属性
var player_level: int = 1
var weapon_type: StringName = &""
var combo_count: int = 0

## 重写创建方法
static func create() -> CustomAbilityContext:
	return CustomAbilityContext.new()

## 重写复制方法
func duplicate() -> AbilityContext:
	var new_context = CustomAbilityContext.new()
	# 复制基础属性
	_copy_base_properties(new_context)
	# 复制自定义属性
	new_context.player_level = player_level
	new_context.weapon_type = weapon_type
	new_context.combo_count = combo_count
	return new_context

## 重写创建实例方法
func _create_duplicate_instance() -> AbilityContext:
	return CustomAbilityContext.new()

## 重写从字典加载
static func from_dict(dict: Dictionary) -> CustomAbilityContext:
	var context = CustomAbilityContext.new()
	context._load_from_dict(dict)
	# 加载自定义属性
	if dict.has("player_level"):
		context.player_level = dict["player_level"]
	if dict.has("weapon_type"):
		context.weapon_type = dict["weapon_type"]
	if dict.has("combo_count"):
		context.combo_count = dict["combo_count"]
	return context

## 重写保存到字典
func _save_to_dict(dict: Dictionary) -> void:
	# 保存基础属性
	super._save_to_dict(dict)
	# 保存自定义属性
	if player_level != 1:
		dict["player_level"] = player_level
	if not weapon_type.is_empty():
		dict["weapon_type"] = weapon_type
	if combo_count != 0:
		dict["combo_count"] = combo_count

## 重写属性检查
func _is_base_property(key: String) -> bool:
	if super._is_base_property(key):
		return true
	# 自定义属性
	return key in ["player_level", "weapon_type", "combo_count"]
```

### 使用场景

**场景 1：业务层扩展属性**
- 游戏特定的数据（如玩家等级、武器类型）
- 战斗系统特定的数据（如连击数、怒气值）

**场景 2：重写行为**
- 自定义复制逻辑
- 自定义序列化逻辑
- 添加验证逻辑

**场景 3：类型安全**
- 子类可以返回自己的类型
- 保持类型检查的优势

### 设计原则

1. **模板方法模式**：基类提供框架，子类填充细节
2. **开闭原则**：对扩展开放，对修改封闭
3. **里氏替换原则**：子类可以替换基类使用
4. **单一职责**：基类负责通用属性，子类负责业务属性

## 注意事项

1. **保持向后兼容**：提供 `from_dict()` 和 `to_dict()` 方法
2. **渐进式迁移**：不要一次性全部迁移
3. **测试覆盖**：确保迁移后功能正常
4. **文档更新**：更新所有相关文档
5. **继承扩展**：使用虚方法模式，支持业务层继承扩展

