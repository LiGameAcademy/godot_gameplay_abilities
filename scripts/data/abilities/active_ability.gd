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
@export var cast_duration: float = 1.0  ## 施法/引导的总时长
@export var cast_point: float = 0.5  ## 施法前摇时间 (动画关键帧)
@export var cast_range: float = 8.0  ## 施法距离
@export var channel_duration: float = 0.0  ## 引导持续时间
@export var autocast: bool = false  ## 技能是否可以自动施法
@export var animation_name: StringName = &"cast_spell_default"  ## 动画名称
@export var target_filters: Array[GameplayFilterData] = []  ## 技能目标过滤器
@export var indicator_data: TargetIndicatorData = null  ## 目标指示器数据

@export_group("Targeting & Effects")
## [新增] 施法者效果：技能施放成功时，立即对施法者应用的效果
## 适用：自身Buff、消耗生命值、后坐力、冲锋位移
@export var caster_effects: Array[GameplayEffect] = []

## [重命名] 目标效果：对筛选出的目标应用的效果
## 适用：伤害、控制、Debuff
## 注意：为了向后兼容，如果 target_effects 为空，会回退使用基类的 effects
@export var target_effects: Array[GameplayEffect] = []

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

func toggle_autocast() -> void:
	_is_autocast = not _is_autocast

func get_cast_duration() -> float:
	return cast_duration

func get_cast_point() -> float:
	return cast_point

func get_cast_range() -> float:
	return cast_range

func get_channel_duration() -> float:
	return channel_duration

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
	
	if not caster_effects.is_empty():
		descriptions.append("[自身]")
		for effect in caster_effects:
			if is_instance_valid(effect):
				descriptions.append(effect.get_description())
	
	# 获取目标效果（向后兼容）
	var effects_to_show = target_effects if not target_effects.is_empty() else effects
	if not effects_to_show.is_empty():
		descriptions.append("[目标]")
		for effect in effects_to_show:
			if is_instance_valid(effect):
				descriptions.append(effect.get_description())
	
	# 状态效果
	if is_instance_valid(status_to_apply):
		descriptions.append("[状态] %s" % status_to_apply.status_display_name)
	
	return "\n".join(descriptions)

func _on_learned(_ability_comp: Node, _status_comp: Node) -> void:
	pass

func _on_forgotten(_ability_comp: Node, _status_comp: Node) -> void:
	pass

## 检查是否可以施法
func _can_cast(ability_comp: Node, target: Node = null, context: Dictionary = {}) -> bool:
	if not is_instance_valid(ability_comp): 
		push_error("ActiveAbility: Ability %s can not cast." % ability_id)
		return false
	
	var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
	if not is_instance_valid(instigator):
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
## 逻辑流：支付消耗 -> 对己效果 -> 获取目标 -> 对敌效果
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	var instigator = ability_comp.get_parent()
	if not is_instance_valid(instigator):
		push_warning("ActiveAbility: Cannot cast, instigator is not valid")
		return
	
	# 1. 立即应用施法者效果 (Caster Effects)
	# 比如：冲锋技能在这里触发 GE_PhysicsMotion，或者获得一个"施法中"的Tag
	_apply_caster_effects(instigator, context)
	
	# 2. 解析目标 (Resolve Targets)
	# 将复杂的 if-else 逻辑封装出去
	# 将 hit_detector 传递到 context 中，供策略使用
	if hit_detector:
		context["hit_detector"] = hit_detector
	var final_targets = _resolve_targets(instigator, input_target, context)
	
	# 3. 如果没有目标且必须要有目标，则不再继续执行目标效果
	# (视具体设计而定，有时候没打中人也算释放成功)
	if final_targets.is_empty():
		# 如果有回调，不仅要在这里结束，可能还需要处理空放的逻辑
		# 这里的处理比较微妙，如果是阻塞技能，没目标可能需要立即结束
		# 但通常 caster_effects 里的冲锋可能才是阻塞源
		return
	
	# 4. 应用目标效果 (Target Effects)
	var effects_to_apply = target_effects if not target_effects.is_empty() else effects
	_apply_effects_to_targets(effects_to_apply, instigator, final_targets, context)

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

## [新增] 应用施法者效果
func _apply_caster_effects(instigator: Node, context: Dictionary) -> void:
	for effect in caster_effects:
		if is_instance_valid(effect):
			# 施法者既是 instigator 也是 target
			# 注意：Effect 会自己注册/注销阻塞任务
			effect.apply(instigator, instigator, context)

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
			effect.apply(target, instigator, context)

#endregion

func _clear_cast(_ability_comp: Node, target: Node) -> void:
	if not is_instance_valid(target):
		return
	
	var instigator = _ability_comp.get_parent() if _ability_comp.has_method("get_parent") else null
	
	# 1. 移除目标效果（如果有需要移除的效果）
	var effects_to_remove = target_effects if not target_effects.is_empty() else effects
	for effect in effects_to_remove:
		if is_instance_valid(effect):
			effect.remove(target, instigator)
	
	# 2. 移除施法者效果（如果有需要移除的效果）
	for effect in caster_effects:
		if is_instance_valid(effect):
			effect.remove(instigator, instigator)
	
	# 3. 移除状态（可选，向后兼容）
	if is_instance_valid(status_to_apply):
		var target_status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if is_instance_valid(target_status_comp) and target_status_comp.has_method("remove_status"):
			target_status_comp.remove_status(status_to_apply.status_id)
