extends RefCounted
class_name AbilityContext

## 技能执行上下文
## 用于在技能执行过程中传递数据和状态
## 支持继承扩展，业务层可以通过继承此类添加自定义属性

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
## 技能等级（用于等级成长计算）
var ability_level: int = 1

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

## 创建上下文实例（可被子类重写）
static func create() -> AbilityContext:
	return AbilityContext.new()

## 复制上下文（虚方法，子类可重写）
## 子类应该重写此方法，调用 super.duplicate() 然后复制自己的属性
## 或者重写 _create_duplicate_instance() 和 _copy_base_properties()
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
	target.ability_level = ability_level
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
## 或者重写 _load_from_dict() 和 _is_base_property()
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
	if dict.has("ability_level"):
		ability_level = dict["ability_level"]
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
		"instigator", "input_target", "ability", "ability_comp", "ability_id", "ability_level",
		"final_damage", "damage_multiplier_modifier", "extra_effects",
		"apply_extra_effects_to_all_targets", "extra_projectiles", "muzzle_transform",
		"cooldown_reduction", "skip_cooldown", "skip_cost",
		"hit_position", "hit_direction", "projectile", "damage_info",
		"value", "text", "custom_data"
	]

## 转换为 Dictionary（虚方法，子类可重写）
## 子类应该重写此方法，调用 super.to_dict() 然后添加自己的属性
## 或者重写 _save_to_dict()
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
	if ability_level != 1:
		dict["ability_level"] = ability_level
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
