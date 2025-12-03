extends ActiveAbility
class_name CombatAbility

## 连击技能
## 管理多段连击，每次触发时根据当前连击索引执行对应的能力

@export_group("Combo Settings")
## 连击段数数组（每段对应一个 ActiveAbility）
## 例如：[attack_1, attack_2, attack_3] 表示三段连击
@export var combo_abilities: Array[ActiveAbility] = []
## 连击重置时间（秒）
## 如果在此时间内没有继续连击，则重置到第一段
@export var combo_reset_time: float = 1

## 当前连击索引（运行时数据，不序列化）
var _current_combo_index: int = 0
## 连击重置计时器
var _combo_reset_timer: float = 0.0
## 是否正在连击冷却中
var _is_combo_cooldown: bool = false

func _init() -> void:
	# 连击技能默认不需要目标
	targeting_type = TargetingType.NO_TARGET

## 获取当前连击段数
func get_current_combo_index() -> int:
	return _current_combo_index

## 获取最大连击段数
func get_max_combo_count() -> int:
	return combo_abilities.size()

## 获取当前连击对应的能力
func get_current_combo_ability() -> ActiveAbility:
	if combo_abilities.is_empty():
		return null
	if _current_combo_index < 0 or _current_combo_index >= combo_abilities.size():
		return combo_abilities[0]
	return combo_abilities[_current_combo_index]

## 重置连击到第一段
func reset_combo() -> void:
	_current_combo_index = 0
	_combo_reset_timer = 0.0
	_is_combo_cooldown = false

## 推进到下一段连击
func advance_combo() -> void:
	_current_combo_index += 1
	# 打印调试信息
	print("Combo Debug: Index advanced to ", _current_combo_index, " | Array Size: ", combo_abilities.size())
	
	if _current_combo_index >= combo_abilities.size():
		_current_combo_index = 0
		print("Combo Debug: Reset to 0")

	var next_ability = get_current_combo_ability()
	print("Combo Debug: Next Ability ID is: ", next_ability.ability_id)

## 重写：每帧更新（更新连击计时器）
func update(delta: float) -> void:
	if _is_combo_cooldown:
		return
	
	_combo_reset_timer += delta
	if _combo_reset_timer >= combo_reset_time:
		reset_combo()

## 检查是否可以继续连击
func can_continue_combo() -> bool:
	return not _is_combo_cooldown and _combo_reset_timer < combo_reset_time

## 重写：获取动画名称
## 返回当前连击段对应的动画名称
func get_animation_name() -> StringName:
	var current_ability = get_current_combo_ability()
	if is_instance_valid(current_ability):
		return current_ability.animation_name
	return animation_name

## 重写：获取施法持续时间
func get_cast_duration() -> float:
	var current_ability = get_current_combo_ability()
	if is_instance_valid(current_ability):
		return current_ability.get_cast_duration()
	return super()

## 重写：获取施法前摇时间
func get_cast_point() -> float:
	var current_ability = get_current_combo_ability()
	if is_instance_valid(current_ability):
		return current_ability.get_cast_point()
	return super()

## 重写：获取冷却时间
func get_cooldown_duration() -> float:
	# 连击技能通常不需要冷却（由连击重置时间控制）
	# 但可以返回当前段的冷却时间（如果需要）
	var current_ability = get_current_combo_ability()
	if is_instance_valid(current_ability):
		return current_ability.get_cooldown_duration()
	return 0.0

## 重写：获取效果描述
## 对于连击技能，需要遍历所有连击段并收集它们的效果描述
func get_effects_description() -> String:
	var descriptions: Array[String] = []
	
	# 遍历所有连击段
	for i in range(combo_abilities.size()):
		var combo_ability = combo_abilities[i]
		if not is_instance_valid(combo_ability):
			continue
		
		# 添加连击段标题
		var combo_title = "第 %d 段:" % (i + 1)
		descriptions.append(combo_title)
		
		# 获取当前段的效果描述
		var combo_effects_desc = combo_ability.get_effects_description()
		if combo_effects_desc != "":
			# 为每行效果描述添加缩进
			var effect_lines = combo_effects_desc.split("\n")
			for line in effect_lines:
				if line.strip_edges() != "":
					descriptions.append("  %s" % line.strip_edges())
		else:
			descriptions.append("  (无效果)")
		
		# 如果不是最后一段，添加空行分隔
		if i < combo_abilities.size() - 1:
			descriptions.append("")
	
	return "\n".join(descriptions)

## 重写：检查是否可以施法
func _can_cast(ability_comp: Node, target: Node = null, context: Dictionary = {}) -> bool:
	# 检查是否有连击能力配置
	if combo_abilities.is_empty():
		push_warning("CombatAbility: No combo abilities configured")
		return false
	
	# 获取当前连击对应的能力
	var current_ability = get_current_combo_ability()
	if not is_instance_valid(current_ability):
		push_warning("CombatAbility: Current combo ability is not valid")
		return false
	
	# 检查当前连击能力是否可以施放
	return current_ability.can_cast(ability_comp, target, context)

## 重写：提交施法
func _commit_cast(ability_comp: Node) -> bool:
	var current_ability := get_current_combo_ability()
	if not is_instance_valid(current_ability):
		return false
	
	# 提交当前连击能力的施法
	var success = current_ability.commit_cast(ability_comp)
	if success:
		# 进入连击冷却（等待动画完成或超时）
		_is_combo_cooldown = true
		_combo_reset_timer = 0.0
		print("CombatAbility: Entering combo cooldown %s" % current_ability.ability_name)
	
	return success

## 重写：施放技能
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var current_ability = get_current_combo_ability()
	if not is_instance_valid(current_ability):
		push_warning("CombatAbility: Cannot cast, current combo ability is not valid")
		return
	
	# 将当前连击索引添加到上下文，供动画系统使用
	context["combo_index"] = _current_combo_index
	context["combo_count"] = combo_abilities.size()
	
	# 执行当前连击能力
	current_ability.cast(ability_comp, input_target, context)
	
	# 推进到下一段（在动画事件触发后，由外部调用 advance_combo）
	# 这里不自动推进，等待动画事件或超时

## 重写：技能完成回调（在效果应用后调用）
## 用于推进到下一段连击
func _on_ability_complete() -> void:
	advance_combo()
