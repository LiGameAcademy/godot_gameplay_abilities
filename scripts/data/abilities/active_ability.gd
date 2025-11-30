extends GameplayAbility
class_name ActiveAbility

## 主动技能数据

@export_group("Casting Rules")
@export var targeting_type: TargetingType = TargetingType.UNIT_TARGET  ## 目标类型
@export var mana_cost: float = 0.0  ## 技能消耗法力值
@export var cooldown_duration: float = 0.0  ## 技能冷却时间
@export var cast_duration: float = 1.0  ## 施法/引导的总时长
@export var cast_point: float = 0.5  ## 施法前摇时间 (动画关键帧)
@export var cast_range: float = 8.0  ## 施法距离
@export var channel_duration: float = 0.0  ## 引导持续时间
@export var autocast: bool = false  ## 技能是否可以自动施法
@export var animation_name: StringName = &"cast_spell_default"  ## 动画名称
@export var target_filters: Array[GameplayFilterData] = []  ## 技能目标过滤器
@export var indicator_data: TargetIndicatorData = null  ## 目标指示器数据

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

func _on_learned(_ability_comp: Node, _status_comp: Node) -> void:
	pass

func _on_forgotten(_ability_comp: Node, _status_comp: Node) -> void:
	pass

func _can_cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> bool:
	if not is_instance_valid(ability_comp) or not is_instance_valid(target): 
		return false
	
	# 检查魔法值（使用鸭子类型）
	if ability_comp.has_method("get_mana"):
		if ability_comp.get_mana() < mana_cost: 
			return false
	
	# 检查技能冷却（使用鸭子类型）
	if ability_comp.has_method("is_cooldown_ready"):
		if not ability_comp.is_cooldown_ready(ability_id): 
			return false
	
	# 检查目标过滤器
	for filter in target_filters:
		if not filter.check(target, ability_comp.get_parent() if ability_comp.has_method("get_parent") else null, context): 
			return false
	
	return true

func _commit_cast(ability_comp: Node) -> bool:
	# 消耗资源（使用鸭子类型）
	if ability_comp.has_method("try_spend_mana"):
		if not ability_comp.try_spend_mana(mana_cost):
			return false
	
	# 开始冷却（使用鸭子类型）
	if ability_comp.has_method("start_cooldown"):
		ability_comp.start_cooldown(ability_id, cooldown_duration)
	
	# 播放动画（可选，由业务层实现）
	_play_animation(ability_comp.get_parent() if ability_comp.has_method("get_parent") else null)
	
	return true

func _on_cast(ability_comp: Node, target: Node, _context: Dictionary = {}) -> void:
	if not is_instance_valid(target):
		return
	
	# 使用鸭子类型查询GameplayStatusComponent
	var target_status_comp = CombatSystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not is_instance_valid(target_status_comp): 
		return
	
	# 应用状态
	if is_instance_valid(status_to_apply) and target_status_comp.has_method("apply_status"):
		var instigator = ability_comp.get_parent() if ability_comp.has_method("get_parent") else null
		target_status_comp.apply_status(status_to_apply, instigator)

func _clear_cast(_ability_comp: Node, target: Node) -> void:
	if not is_instance_valid(target):
		return
	
	# 使用鸭子类型查询GameplayStatusComponent
	var target_status_comp = CombatSystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not is_instance_valid(target_status_comp): 
		return
	
	# 移除状态
	if is_instance_valid(status_to_apply) and target_status_comp.has_method("remove_status"):
		target_status_comp.remove_status(status_to_apply.status_id)

func _play_animation(owner_entity: Node) -> void:
	# 动画播放由业务层实现，这里只提供接口
	# 业务层可以监听技能事件来播放动画
	if not is_instance_valid(owner_entity): 
		return
	
	# 发送技能施放事件
	CombatEventBus.emit_ability_activated(owner_entity, ability_id)

