extends GameplayAbility
class_name ActiveAbility

## 主动技能数据 (v2.0 Refactored)
## 核心改进：分离了"对己效果"和"对敌效果"，解耦了目标获取逻辑

@export_group("Casting Rules")
## [推荐] 目标获取策略（优先使用，提供最大灵活性）
## 如果设置了此策略，将使用策略来获取目标，忽略 targeting_type
## 如果未设置，将回退使用 targeting_type 枚举（向后兼容）
@export var targeting_strategy: TargetingStrategy = null
@export var cooldown_duration: float = 0.0  ## 技能冷却时间
@export var costs: Array[AbilityCostBase] = []  ## 技能消耗器数组（支持多种消耗类型）
@export var cast_point: float = 0.5  ## 施法前摇时间 (动画关键帧)
@export var cast_range: float = 8.0  ## 施法距离
@export var autocast: bool = false  ## 技能是否可以自动施法
@export var animation_name: StringName = &"cast_spell_default"  ## 动画名称
@export var target_filters: Array[GameplayFilterData] = []  ## 技能目标过滤器
@export var indicator_data: TargetIndicatorData = null  ## 目标指示器数据

@export_group("Tag Requirements")
## 施法者必须拥有的标签（技能施放的前置条件）
## 如果施法者没有所有必需的标签，技能无法施放
@export var caster_required_tags: Array[StringName] = []
## 施法者不能拥有的标签（技能施放的阻止条件）
## 如果施法者拥有任意一个阻止标签，技能无法施放
@export var caster_blocked_tags: Array[StringName] = []

@export_group("Hit Detection")
## 命中检测器（用于动画关键帧触发时的目标检测）
## 如果设置了此检测器，能力系统会在动画关键帧时主动调用它来获取目标
## 适用于：普通攻击、需要精确时机检测的技能
@export var hit_detector: HitDetectorBase = null

var _is_autocast: bool = false  ## 技能是否自动施法

func can_autocast() -> bool:
	return autocast

func is_autocast() -> bool:
	return _is_autocast

func get_cast_point() -> float:
	return cast_point

func get_cast_range() -> float:
	return cast_range

func get_cooldown_duration() -> float:
	return cooldown_duration

func get_animation_name() -> StringName:
	return animation_name

## 获取消耗描述（用于UI显示）
## [return] String 消耗描述文本
func get_costs_description() -> String:
	if costs.is_empty():
		return ""
	
	var cost_descriptions: Array[String] = []
	for cost in costs:
		if is_instance_valid(cost):
			cost_descriptions.append(cost.get_cost_description())
	
	return "\n".join(cost_descriptions)

## [重写] 获取效果描述
func get_effects_description() -> String:
	var descriptions: Array[String] = []
	
	# 新架构：状态效果
	if not statuses.is_empty():
		descriptions.append("[状态]")
		for status_data in statuses:
			if is_instance_valid(status_data):
				descriptions.append("- %s" % status_data.status_display_name)
				descriptions.append("  %s" % status_data.get_effects_description())
	return "\n".join(descriptions)

## 检查是否可以施法
func _can_cast(ability_comp: Node, target: Node = null, context: Dictionary = {}) -> bool:
	if not is_instance_valid(ability_comp): 
		push_error("ActiveAbility: Ability %s can not cast." % ability_id)
		return false
	
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	if not is_instance_valid(instigator):
		return false
	
	# 检查标签要求（标签系统集成）
	# 检查必须标签
	if not caster_required_tags.is_empty():
		if not TagManager.has_all_tags(instigator, caster_required_tags):
			print("ActiveAbility: Caster required tags not found for ability %s" % ability_id)
			return false
	
	# 检查阻止标签
	if not caster_blocked_tags.is_empty():
		if TagManager.has_any_tag(instigator, caster_blocked_tags):
			print("ActiveAbility: Caster blocked tags found for ability %s" % ability_id)
			return false
	
	# 检查是否可以支付所有消耗
	for cost in costs:
		if not is_instance_valid(cost):
			continue
		if not cost.can_pay(ability_comp, instigator):
			return false
	
	#TODO 开始冷却
	#TODO 检查目标过滤器

	return true

func _commit_cast(ability_comp: Node, context: Dictionary = {}) -> bool:
	# 检查是否跳过消耗（用于技能链式调用）
	if context.get("skip_cost", false):
		return true
	
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	if not is_instance_valid(instigator):
		push_warning("ActiveAbility: Cannot get instigator for ability %s" % ability_id)
		return false
	
	# 遍历所有消耗器，检查并消耗资源
	for cost in costs:
		if not is_instance_valid(cost):
			continue
		
		# 检查是否可以支付
		if not cost.can_pay(ability_comp, instigator):
			push_warning("ActiveAbility: Cannot pay cost for ability %s: %s" % [ability_id, cost.get_cost_description()])
			return false
		
		# 尝试支付消耗
		if not cost.try_pay(ability_comp, instigator):
			push_warning("ActiveAbility: Failed to pay cost for ability %s: %s" % [ability_id, cost.get_cost_description()])
			return false
	
	return true

## [核心重构] 施放技能
## 逻辑流：支付消耗 -> 对己状态/效果 -> 对敌状态/效果
## [新架构] 优先使用 Status 系统，回退到 Effect 系统（向后兼容）
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("ActiveAbility: Cannot cast, instigator is not valid")
		return
	
	# 传递上下文信息（包括 input_target，供 Status 的目标检测使用）
	var status_context = context.duplicate()
	status_context["input_target"] = input_target
	status_context["ability_id"] = ability_id
	if hit_detector:
		status_context["hit_detector"] = hit_detector
	
	# 1. 应用状态（新架构）
	# 优先使用基类的 statuses，Status 系统会自己处理目标检测和筛选
	if not statuses.is_empty():
		for status_data in statuses:
			if is_instance_valid(status_data):
				_apply_status(instigator, status_data, status_context)
		# 检查是否所有效果都已完成
		_check_ability_completion()
		return

	# 3. 检查是否所有效果都已完成
	# 注意：Status 系统是异步的，但瞬时 Status（duration = 0）会立即完成
	# Effect 系统会通过信号通知完成
	_check_ability_completion()

## 应用状态（新架构）
## [param] instigator: Node 施法者
## [param] status_data: GameplayStatusData 状态数据
## [param] context: Dictionary 上下文信息
func _apply_status(instigator: Node, status_data: GameplayStatusData, context: Dictionary) -> void:
	if not is_instance_valid(status_data):
		return
	
	# 获取施法者的状态组件
	var status_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayStatusComponent")
	if not is_instance_valid(status_comp):
		push_warning("ActiveAbility: Instigator %s has no GameplayStatusComponent, cannot apply status %s" % [instigator.name, status_data.status_id])
		return
	
	# 应用状态（状态系统会处理目标检测、筛选和应用效果）
	# Status 通过 target_mode 决定应用到自己、检测到的目标，或两者
	status_comp.apply_status(status_data, instigator, 1, context)

## 应用效果到目标列表（带基础过滤）
## [param] effects_to_apply: Array[GameplayEffect]
## [param] instigator: Node 施法者
## [param] targets: Array[Node] 目标列表
## [param] context: Dictionary 上下文
func _apply_effects_to_targets(effects_to_apply: Array, instigator: Node, targets: Array, context: Dictionary) -> void:
	if effects_to_apply.is_empty():
		return
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		# 阵营或自我过滤可在调用前或这里扩展
		for effect in effects_to_apply:
			if not is_instance_valid(effect):
				continue
			
			_apply_single_effect_to_target(effect, target, instigator, context)

## 为单个单位应用单个效果（内部方法）
## 负责：克隆 Effect 实例、订阅信号、应用效果
## [param] effect: GameplayEffect 要应用的效果模板
## [param] target: Node 目标单位
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文
func _apply_single_effect_to_target(effect: GameplayEffect, target: Node, instigator: Node, context: Dictionary) -> void:
	if not is_instance_valid(effect):
		push_warning("ActiveAbility: Effect is not valid for ability %s" % ability_id)
		return
	
	if not is_instance_valid(target):
		return
	
	# 1. 克隆 Effect 实例（避免运行时状态共享）
	var effect_inst = effect.duplicate(true) as GameplayEffect
	if not is_instance_valid(effect_inst):
		push_warning("ActiveAbility: Effect instance is not valid for ability %s" % ability_id)
		return
	
	# 2. 订阅完成信号（在应用前订阅，避免信号丢失）
	_subscribe_effect_completion(effect_inst)
	
	# 3. 应用效果
	effect_inst.apply(target, instigator, context)

#region ========== 目标筛选与应用（供子类/其他能力复用）==========

## 使用策略对目标进行筛选，并与原始目标求交集
## [param] targets: Array 原始目标列表（比如检测器或信号给出的）
## [param] instigator: Node 施法者
## [param] context: Dictionary 上下文
## [param] strategy: TargetingStrategy 可选策略
## [param] input_target: Node 可选的直接输入目标（单体命中时使用）
## [return] Array 筛选后的目标
func _filter_targets_with_strategy(targets: Array, instigator: Node, context: Dictionary, strategy: TargetingStrategy, input_target: Node = null) -> Array:
	if targets.is_empty():
		print("ActiveAbility: No targets detected for ability %s" % ability_id)
		return []
	if not is_instance_valid(strategy):
		print("ActiveAbility: Strategy is not valid for ability %s" % ability_id)
		return targets
	
	var resolved = strategy.resolve_targets(instigator, input_target, context)
	var filtered: Array[Node] = []
	for target in resolved:
		if target in targets:
			filtered.append(target)
	return filtered

## 封装目标获取逻辑
## 【重构】优先使用 TargetingStrategy，回退到枚举（向后兼容）
func _resolve_targets(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]:
	# 优先级1: 使用 TargetingStrategy（推荐方式）
	if is_instance_valid(targeting_strategy):
		return targeting_strategy.resolve_targets(instigator, input_target, context)
	
	# 优先级2: 回退到枚举（向后兼容）
	# 注意：这里保留了原有的逻辑，但建议迁移到策略模式
	return _resolve_targets_by_enum(instigator, input_target, context)

## [已弃用] 使用枚举解析目标（向后兼容）
## 建议：使用 TargetingStrategy 替代
func _resolve_targets_by_enum(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]:
	var targets: Array[Node] = []
	
	# 策略 A: 命中检测器 (优先)
	# 适用于：近战挥砍、周围 AOE
	if hit_detector and instigator is Node3D:
		targets = hit_detector.get_targets(instigator as Node3D, context)
		if not targets.is_empty():
			return targets
	
	# 策略 B: 指定目标 (Fallback)
	# 适用于：指向性法术、远程锁定
	if is_instance_valid(input_target):
		targets.append(input_target)
		return targets

	return targets
#endregion

func _clear_cast(_ability_comp: Node, target: Node) -> void:
	if not is_instance_valid(target):
		return
	
	var instigator = _ability_comp.get_parent() if _ability_comp.has_method("get_parent") else null
	
	# 1. 移除效果（向后兼容，基类属性）
	var base_effects = get("effects")
	if base_effects:
		for effect in base_effects:
			if is_instance_valid(effect):
				effect.remove(target, instigator)
	
	# 2. 移除状态（向后兼容：status_to_apply，基类属性）
	var base_status = get("status_to_apply")
	if is_instance_valid(base_status):
		var target_status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if is_instance_valid(target_status_comp) and target_status_comp.has_method("remove_status"):
			target_status_comp.remove_status(base_status.status_id)
