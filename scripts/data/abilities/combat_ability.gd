extends ActiveAbility
class_name CombatAbility

## 连击技能
## 管理多段连击，每次触发时根据当前连击索引执行对应的能力

@export_group("Combo Settings")
## 连击段数数组（每段对应一个 ActiveAbility）
## 例如：[attack_1, attack_2, attack_3] 表示三段连击
@export var _combo_abilities: Array[ActiveAbility] = []
## 连击重置时间（秒）
## 如果在此时间内没有继续连击，则重置到第一段
@export var _combo_reset_time: float = 1

## 当前连击索引（运行时数据，不序列化）
var _current_combo_index: int = 0
## 连击重置计时器
var _combo_reset_timer: float = 0.0

## 重写：每帧更新（更新连击计时器和冷却时间）
func update(delta: float) -> void:
	# 调用父类方法更新冷却时间
	super(delta)
	
	# 更新连击重置计时器
	_combo_reset_timer += delta
	if _combo_reset_timer >= _combo_reset_time:
		_reset_combo()

## 获取施法前摇时间
func get_cast_point() -> float:
	var current_ability = _get_current_combo_ability()
	if is_instance_valid(current_ability):
		return current_ability.get_cast_point()
	return super()

## 重写：获取动画名称
## 返回当前连击段对应的动画名称
func get_animation_name() -> StringName:
	var current_ability = _get_current_combo_ability()
	if is_instance_valid(current_ability):
		return current_ability.animation_name
	return animation_name

## 重写：获取冷却时间
## 返回连击技能自身冷却和当前子技能冷却的最大值
## 这样可以确保更严格的冷却限制被应用
func get_cooldown_duration() -> float:
	var combo_cooldown = cooldown_duration  # 连击技能自身的冷却
	var segment_cooldown = 0.0  # 当前子技能的冷却
	
	var current_ability = _get_current_combo_ability()
	if is_instance_valid(current_ability):
		segment_cooldown = current_ability.get_cooldown_duration()
	
	# 返回两者中的最大值，确保更严格的冷却限制
	return max(combo_cooldown, segment_cooldown)

## 重写：获取效果描述
## 对于连击技能，需要遍历所有连击段并收集它们的效果描述
func get_effects_description() -> String:
	var descriptions: Array[String] = []
	
	# 遍历所有连击段
	for i in range(_combo_abilities.size()):
		var combo_ability = _combo_abilities[i]
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
		if i < _combo_abilities.size() - 1:
			descriptions.append("")
	
	return "\n".join(descriptions)

## 重写：检查是否可以施法
## CombatAbility 只检查自己的冷却和消耗
## 不检查子技能的冷却和消耗，因为子技能不会被 Component 直接调用
func _can_cast(ability_comp: Node, target: Node = null, context: Dictionary = {}) -> bool:
	# 检查是否有连击能力配置
	if _combo_abilities.is_empty():
		push_warning("CombatAbility: No combo abilities configured")
		return false
	
	# 获取当前连击对应的能力（用于验证配置）
	var current_ability = _get_current_combo_ability()
	if not is_instance_valid(current_ability):
		push_warning("CombatAbility: Current combo ability is not valid")
		return false
	
	# 只检查 CombatAbility 自己的条件（冷却、消耗等）
	# 不检查子技能，因为子技能不会被 Component 直接调用
	return super(ability_comp, target, context)

## 重写：提交施法
## CombatAbility 只检查自己的消耗
## 子技能不会经过 Component 的 commit_cast，所以不需要检查子技能的消耗
func _commit_cast(ability_comp: Node, context: Dictionary = {}) -> bool:
	# 调用父类方法检查 CombatAbility 自己的消耗
	var success = super(ability_comp, context)
	if success:
		# 重置连击计时器（开始新的连击窗口）
		_combo_reset_timer = 0.0
	
	return success

## 重写：施放技能
## CombatAbility 不执行自己的效果，而是直接执行子技能
## 子技能通过执行时间自动完成，CombatAbility 订阅完成信号推进连击
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var current_ability = _get_current_combo_ability()
	if not is_instance_valid(current_ability):
		push_warning("CombatAbility: Cannot cast, current combo ability is not valid")
		return
	
	# 将当前连击索引添加到上下文，供动画系统使用
	context["combo_index"] = _current_combo_index
	context["combo_count"] = _combo_abilities.size()
	
	# 订阅子技能的完成信号（子技能通过执行时间自动完成）
	if not current_ability.ability_completed.is_connected(_on_combo_segment_completed):
		current_ability.ability_completed.connect(_on_combo_segment_completed)

	# 使用 execute_ability_direct 直接执行子技能（跳过冷却和消耗检查）
	# 因为 CombatAbility 已经检查过冷却和消耗，子技能不需要再次检查
	# 注意：不调用父类的 _on_cast()，因为 CombatAbility 不执行自己的效果（没有 statuses）
	if ability_comp.has_method("execute_ability_direct"):
		# 标记跳过冷却和消耗，因为 CombatAbility 已经检查过了
		context["skip_cooldown"] = true
		context["skip_cost"] = true
		ability_comp.execute_ability_direct(current_ability, input_target, context)
	else:
		# 回退：直接调用子技能的 cast（但子技能可能会检查冷却和消耗）
		current_ability.cast(ability_comp, input_target, context)
	
## 连击段完成回调（在技能完成时推进连击）
## [param] completed_ability: GameplayAbility 完成的技能实例
func _on_combo_segment_completed(completed_ability: GameplayAbility) -> void:
	if not is_instance_valid(completed_ability):
		return
	
	# 检查是否是当前连击段完成
	var current_ability = _get_current_combo_ability()
	if is_instance_valid(current_ability) and completed_ability == current_ability:
		# 断开信号连接
		if completed_ability.ability_completed.is_connected(_on_combo_segment_completed):
			completed_ability.ability_completed.disconnect(_on_combo_segment_completed)
		
		# 推进连击
		_advance_combo()
		
		# 发出 CombatAbility 自己的完成信号，通知 Component
		ability_completed.emit(self)

## 获取当前连击对应的能力
func _get_current_combo_ability() -> ActiveAbility:
	if _combo_abilities.is_empty():
		return null
	if _current_combo_index < 0 or _current_combo_index >= _combo_abilities.size():
		return _combo_abilities[0]
	return _combo_abilities[_current_combo_index]

## 重置连击到第一段
func _reset_combo() -> void:
	_current_combo_index = 0
	_combo_reset_timer = 0.0

## 推进到下一段连击
func _advance_combo() -> void:
	_current_combo_index += 1
	if _current_combo_index >= _combo_abilities.size():
		_current_combo_index = 0  # 循环回到第一段
	_combo_reset_timer = 0.0

## 重写：获取技能图标
## 返回当前连击段对应的图标
## [param] ability_comp: Node 技能组件（可选，用于动态图标）
## [return] Texture 技能图标
func _get_icon() -> Texture:
	var current_ability = _get_current_combo_ability()
	if is_instance_valid(current_ability):
		# 如果当前连击段支持动态图标，传递 ability_comp
		return current_ability.icon
	return super()
