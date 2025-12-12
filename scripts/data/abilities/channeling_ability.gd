extends ActiveAbility
class_name ChannelingAbility

## 引导/切换技能模式
enum ChannelingMode {
	HOLD_TO_CHANNEL, ## 按住施法：松开按键时停止 (如：暴风雪、吸血)
	TOGGLE           ## 切换式：再次按下按键时停止 (如：开启光环、魔法盾)
}

#Group: Channeling Core Rules
## 技能模式
@export var channeling_mode: ChannelingMode = ChannelingMode.HOLD_TO_CHANNEL
## 最大持续时间（秒）。
## 如果 <= 0，则视为无限持续，直到被动或主动中断。
## 对于 Toggle 技能，通常设置为 0。
@export var max_duration: float = 5.0
## 周期触发间隔（秒）
@export var tick_interval: float = 0.5

#Group: Channeling Costs & Effects
## [新] 引导期间给自己打上的标签（如 State.Channeling）
## 用于动画状态机，或防止释放其他互斥技能。
@export var self_channeling_tags: Array[StringName] = []

## [新] 被动中断标签
## 如果施法者拥有数组中任意一个标签（如 Stunned, Silenced），引导将立即中断。
@export var interrupt_tags: Array[StringName] = []

## 每次 Tick 需要支付的消耗 (资源不足将导致中断)
@export var tick_costs: Array[AbilityCostBase] = []

## 每次 Tick 要应用的状态列表 (应用给目标)
## 注意：基类的 'statuses' 用于引导开始时的瞬间效果。
@export var tick_statuses: Array[GameplayStatusData] = []

## [新] 引导正常结束或被中断时应用的状态列表
@export var end_statuses: Array[GameplayStatusData] = []

#Group: Runtime State (运行时状态，不对外暴露)
var _is_active: bool = false
var _current_duration: float = 0.0
var _tick_timer: SceneTreeTimer = null

# 缓存运行时数据，用于异步 Tick 和结束处理
var _cached_ability_comp: Node = null
var _cached_input_target: Node = null
var _cached_context: Dictionary = {}

## 停止引导统一入口
## [param] reason: 停止原因调试信息
func stop_channeling(reason: String = "manual") -> void:
	if not _is_active: return
	_is_active = false
	
	# 1. 清理计时器
	if _tick_timer and is_instance_valid(_tick_timer):
		_tick_timer.timeout.disconnect(_process_tick)
		_tick_timer = null
		
	var instigator = _cached_ability_comp.get_parent()
	if is_instance_valid(instigator):
		# 2. 移除引导标签
		if not self_channeling_tags.is_empty():
			TagManager.remove_tags(instigator, self_channeling_tags)
			
		# 3. 应用结束状态 (End Statuses)
		if not end_statuses.is_empty():
			var end_context = _cached_context.duplicate()
			end_context["finish_reason"] = reason
			for status_data in end_statuses:
				_apply_status(instigator, status_data, end_context)
			
	print("Ability %s stopped channeling. Reason: %s" % [ability_id, reason])
	
	# 4. 【关键】手动通知 AbilityComponent 技能结束
	# 这会触发冷却计算并清理当前激活技能的引用
	#notify_ability_ended()

## [关键重写] 提交施法
## 我们需要接管技能的生命周期，因此不能让基类启动自动完成计时器。
func _commit_cast(ability_comp: Node, context: Dictionary = {}) -> bool:
	# 1. 执行基类的初始扣费逻辑 (复制自 ActiveAbility)
	if not context.get("skip_cost", false):
		var instigator = ability_comp.get_parent()
		if not is_instance_valid(instigator): return false
		
		# 检查并支付所有初始消耗
		for cost in costs:
			if not is_instance_valid(cost): continue
			if not cost.try_pay(ability_comp, instigator):
				# 如果支付失败（理论上 _can_cast 已经检查过了，但以防万一）
				return false
	
	# 2. 【重点】直接返回 true，表明提交成功。
	# 不调用 super._commit_cast()，也不启动 _start_execution_timer()。
	# 技能的结束将由我们自己的逻辑手动管理。
	return true

## [重写] 施法开始
func _on_cast(ability_comp: Node, input_target: Node, context: Dictionary = {}) -> void:
	# 1. 调用基类方法，应用初始的 statuses (引导开始效果)
	# 基类会处理初始 Status 的应用，这正合我意。
	super._on_cast(ability_comp, input_target, context)
	
	# 2. 缓存数据，供后续 Tick 使用
	_cached_ability_comp = ability_comp
	_cached_input_target = input_target
	_cached_context = context.duplicate()
	var instigator = ability_comp.get_parent()

	# 3. 启动引导核心逻辑
	_start_channeling(instigator)

func _start_channeling(instigator: Node) -> void:
	_is_active = true
	_current_duration = 0.0
	
	# 1. 给自己打上引导标签
	if not self_channeling_tags.is_empty():
		TagManager.add_tags(instigator, self_channeling_tags)
		
	# 2. 启动 Tick 循环
	_schedule_next_tick()
	
	print("Ability %s started channeling (%s mode)" % [ability_id, ChannelingMode.keys()[channeling_mode]])

func _schedule_next_tick() -> void:
	if not _is_active or tick_interval <= 0.0: return
	var tree = _cached_ability_comp.get_tree()
	if not is_instance_valid(tree): return
	
	# 使用 SceneTreeTimer 创建递归循环
	_tick_timer = tree.create_timer(tick_interval)
	_tick_timer.timeout.connect(_process_tick)

func _process_tick() -> void:
	if not _is_active: return
	var instigator = _cached_ability_comp.get_parent()
	if not is_instance_valid(instigator):
		stop_channeling("instigator_invalid")
		return
		
	# 1. 被动中断检查：是否拥有打断标签 (如眩晕)
	if not interrupt_tags.is_empty() and TagManager.has_any_tag(instigator, interrupt_tags):
		stop_channeling("interrupted_by_tag")
		return

	# 2. 最大持续时间检查
	_current_duration += tick_interval
	if max_duration > 0 and _current_duration >= max_duration:
		stop_channeling("duration_expired")
		return
		
	# 3. 资源检查与扣费 (Tick Cost)
	#if not _pay_tick_costs(instigator):
		#stop_channeling("out_of_resource")
		#return
		
	# 4. 应用 Tick 状态
	# 复用基类现成的 _apply_status 方法，完美兼容新架构
	if not tick_statuses.is_empty():
		var tick_context = _cached_context.duplicate()
		# TODO: 如果需要，这里可以更新 tick_context 中的目标位置
		for status_data in tick_statuses:
			 # 调用基类方法应用状态
			_apply_status(instigator, status_data, tick_context)
			
	# 5. 继续下一次循环
	_schedule_next_tick()
