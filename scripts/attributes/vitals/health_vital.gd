extends GameplayVital
class_name HealthVital

## 生命值 Vital
## 处理伤害、治疗、死亡等逻辑

const DEATH_GROUP_NAME: String = "death"

var _recoverable_zero: bool = false

## 是否存活
var is_alive: bool:
	get:
		return current_value > 0

func _init(p_comp: GameplayAttributeComponent = null) -> void:
	# 设置 HealthVital 的默认值（在调用 super 之前设置）
	vital_id = &"health"
	display_name = "生命值"
	max_value_attribute = &"max_health"  # 依赖 "health" 属性作为上限
	#regen_rate_attribute = &"health_regen"  # 可选：自动回复

## 生命值恢复信号
signal health_restored()
## 生命值耗尽信号
signal health_depleted(instigator: Node)
## 接受伤害时发出（在计算减免之前）
signal damage_received(damage_info: DamageInfo)
## 受到伤害时发出（在计算减免之后）
signal damage_applied(damage_info: DamageInfo, final_damage: float)

func initialize(component: GameplayAttributeComponent) -> void:
	super(component)
	_recoverable_zero = get_max_value() == 0.0

func modify_value(amount: float, is_regen: bool = false) -> void:
	if amount >= 0:
		heal(amount, is_regen)
	else:
		_modify_value(amount, is_regen)

## 核心伤害应用接口
## [param] damage_info: DamageInfo 伤害信息（必须包含已计算的 final_damage）
## [param] owner_entity: Node 拥有者实体
## [return] float 最终伤害值（用于 Cue 系统）
func apply_damage(damage_info: DamageInfo, owner_entity: Node) -> float:
	if not _can_receive_damage():
		return 0.0
	
	if not is_instance_valid(damage_info):
		push_error("HealthVital.apply_damage: damage_info is invalid")
		return 0.0
	if not is_finite(damage_info.final_damage):
		return 0.0
	
	# 发出伤害接收信号（允许其他系统修改伤害，如护盾、减伤等）
	damage_received.emit(damage_info)
	# A synchronous listener may replace this Vital before the hit is committed.
	if not _can_receive_damage() or not is_finite(damage_info.final_damage):
		return 0.0
	AbilityEventBus.trigger_game_event(&"damage_received", {
		"damage_info": damage_info,
		"target": owner_entity
	})
	if not _can_receive_damage() or not is_finite(damage_info.final_damage):
		return 0.0
	
	# 获取最终伤害（可能已被 damage_received 监听者修改）
	damage_info.final_damage = max(0.0, damage_info.final_damage)
	var final_damage: float = damage_info.final_damage
	var instigator: Node = damage_info.instigator
	var lethal_hit: bool = _modify_value(-final_damage)
	if not is_instance_valid(_owner_comp):
		return 0.0
	
	# 发出伤害应用信号（UI系统可以监听这个信号来显示伤害飘字）
	damage_applied.emit(damage_info, final_damage)
	if not is_instance_valid(_owner_comp):
		return final_damage
	AbilityEventBus.trigger_game_event(&"damage_applied", {
		"damage_info": damage_info,
		"target": owner_entity
	})

	# 处理死亡
	if lethal_hit and is_instance_valid(_owner_comp):
		var valid_instigator: Node = instigator if is_instance_valid(instigator) else null
		var valid_owner: Node = owner_entity if is_instance_valid(owner_entity) else null
		_die(valid_instigator, valid_owner)

	# 返回最终伤害值（供 Cue 系统使用）
	return final_damage

## Returns true when positive healing raises health. A zero caused by the maximum
## can recover once capacity returns, while damage and payments cannot revive it.
func heal(amount: float, is_regen: bool = false) -> bool:
	if not is_instance_valid(_owner_comp) or not is_finite(amount) or amount <= 0.0:
		return false
	if not is_alive and not _recoverable_zero:
		return false
	var before: float = current_value
	var maximum: float = get_max_value()
	if before >= maximum or minf(before + amount, maximum) <= before:
		return false
	_recoverable_zero = false
	_modify_value(amount, is_regen)
	health_restored.emit()
	return true

func _refresh_maximum() -> bool:
	var was_alive: bool = is_alive
	var changed: bool = super()
	if was_alive and current_value == 0.0:
		_recoverable_zero = true
	return changed

func _can_receive_damage() -> bool:
	return is_instance_valid(_owner_comp) and is_alive

## 死亡处理
## [param] instigator: Node 造成死亡的实体
## [param] owner_entity: Node 拥有者实体
func _die(instigator: Node, owner_entity: Node) -> void:
	if is_instance_valid(owner_entity):
		owner_entity.add_to_group(DEATH_GROUP_NAME)
	# 发出死亡信号
	health_depleted.emit(instigator)
