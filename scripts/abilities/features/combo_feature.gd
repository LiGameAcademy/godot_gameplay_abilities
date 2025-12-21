extends GameplayAbilityFeature
class_name ComboFeature

## 连击特性
## 管理多段连击，每次触发时根据当前连击索引执行对应的能力
##
## 使用方式：
## ```gdscript
## var ability = ActiveAbility.new()
## var combo_feature = ComboFeature.new()
## combo_feature.combo_abilities = [attack_1, attack_2, attack_3]
## ability.features.append(combo_feature)
## ```

@export_group("Combo Settings")
## 连击段数数组（每段对应一个 ActiveAbility）
## 例如：[attack_1, attack_2, attack_3] 表示三段连击
@export var combo_abilities: Array[ActiveAbility] = []
## 连击重置时间（秒）
## 如果在此时间内没有继续连击，则重置到第一段
@export var combo_reset_time: float = 1.0

## 当前连击索引（运行时数据，不序列化）
var _current_combo_index: int = 0
## 连击重置计时器
var _combo_reset_timer: float = 0.0

func _init() -> void:
	super("ComboFeature")

## [重写] 每帧更新（更新连击计时器）
func update(ability: GameplayAbility, delta: float) -> void:
	_combo_reset_timer += delta
	if _combo_reset_timer >= combo_reset_time:
		_reset_combo()

## [重写] 检查是否可以施法
func can_activate(ability: GameplayAbility, context: AbilityContext) -> bool:
	# 检查是否有连击能力配置
	if combo_abilities.is_empty():
		push_warning("ComboFeature: No combo abilities configured")
		return false
	
	# 获取当前连击对应的能力（用于验证配置）
	var current_ability = _get_current_combo_ability()
	if not is_instance_valid(current_ability):
		push_warning("ComboFeature: Current combo ability is not valid")
		return false
	
	# 【关键】如果连击技能正在执行，检查连击窗口是否还在有效期内
	# 如果连击窗口已超时，重置连击索引，允许重新开始连击
	if _combo_reset_timer >= combo_reset_time:
		# 连击窗口已超时，重置连击索引
		_reset_combo()
	
	return true

## [重写] 提交施法时的处理
func commit_cast(ability: GameplayAbility, context: AbilityContext) -> bool:
	# 重置连击计时器（开始新的连击窗口）
	_combo_reset_timer = 0.0
	return true

## [重写] 技能实际生效时的处理
func on_cast(ability: GameplayAbility, context: AbilityContext) -> void:
	var ability_comp = context.ability_comp
	var input_target = context.input_target
	var instigator = context.instigator
	
	if not is_instance_valid(ability_comp) or not is_instance_valid(instigator):
		push_warning("ComboFeature: Cannot cast, invalid ability_comp or instigator")
		return
	
	var current_ability = _get_current_combo_ability()
	if not is_instance_valid(current_ability):
		push_warning("ComboFeature: Cannot cast, current combo ability is not valid")
		return
	
	# 1. 应用连击技能自己的直接效果（如连击开始时给自己加buff）
	# 注意：只在第一段连击时应用，避免重复应用
	if _current_combo_index == 0:
		# 应用基类的效果（如果有）
		# 注意：这里不直接调用基类方法，而是让基类自己处理
		# 特性只负责连击逻辑
		pass
	
	# 2. 将当前连击索引添加到上下文，供动画系统使用
	context.custom_data["combo_index"] = _current_combo_index
	context.custom_data["combo_count"] = combo_abilities.size()
	
	# 3. 订阅子技能的完成信号（子技能通过执行时间自动完成）
	if not current_ability.ability_completed.is_connected(_on_combo_segment_completed):
		current_ability.ability_completed.connect(_on_combo_segment_completed.bind(ability))
	
	# 4. 直接调用子技能的 cast（但子技能可能会检查冷却和消耗）
	# 注意：子技能使用自己的上下文，但需要传递连击信息
	var combo_context = context.duplicate()
	current_ability.cast(ability_comp, input_target, combo_context)

## [重写] 获取特性描述
func get_description() -> String:
	if combo_abilities.is_empty():
		return "连击特性（未配置）"
	return "连击特性（%d 段）" % combo_abilities.size()

## 获取当前连击对应的能力
func _get_current_combo_ability() -> ActiveAbility:
	if combo_abilities.is_empty():
		return null
	if _current_combo_index < 0 or _current_combo_index >= combo_abilities.size():
		return combo_abilities[0]
	return combo_abilities[_current_combo_index]

## 重置连击到第一段
func _reset_combo() -> void:
	_current_combo_index = 0
	_combo_reset_timer = 0.0

## 推进到下一段连击
func _advance_combo() -> void:
	_current_combo_index += 1
	if _current_combo_index >= combo_abilities.size():
		_current_combo_index = 0  # 循环回到第一段
	_combo_reset_timer = 0.0

## 连击段完成回调（在技能完成时推进连击）
## [param] completed_ability: GameplayAbility 完成的技能实例
## [param] owner_ability: ActiveAbility 拥有此特性的技能
func _on_combo_segment_completed(completed_ability: GameplayAbility, owner_ability: ActiveAbility) -> void:
	if not is_instance_valid(completed_ability) or not is_instance_valid(owner_ability):
		return
	
	# 检查是否是当前连击段完成
	var current_ability = _get_current_combo_ability()
	if is_instance_valid(current_ability) and completed_ability == current_ability:
		# 断开信号连接
		if completed_ability.ability_completed.is_connected(_on_combo_segment_completed):
			completed_ability.ability_completed.disconnect(_on_combo_segment_completed)
		
		# 推进连击
		_advance_combo()
		
		# 发出拥有技能的完成信号，通知 Component
		owner_ability.ability_completed.emit(owner_ability)
