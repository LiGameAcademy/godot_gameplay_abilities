extends GameplayVital
class_name HealthVital

## 生命值 Vital
## 处理伤害、治疗、死亡等逻辑

const DEATH_GROUP_NAME: String = "death"

func _init(p_comp: GameplayAttributeComponent = null) -> void:
	# 设置 HealthVital 的默认值（在调用 super 之前设置）
	vital_id = &"health"
	display_name = "生命值"
	max_value_attribute = &"health"
	# regen_rate_attribute = &"health_regen"
	
	# 调用父类初始化
	super(p_comp)

## 是否存活
var is_alive: bool:
	get:
		return current_value > 0

## 生命值恢复
signal health_restored() 
## 生命值耗尽
signal health_depleted(instigator: Node) 
## 接受伤害时发出（在计算减免之前）
signal damage_received(damage_info: DamageInfo) 
## 受到伤害时发出（在计算减免之后）
signal damage_applied(damage_info: DamageInfo, final_damage: float) 

## 核心伤害应用接口
func apply_damage(damage_info: DamageInfo, owner_entity: Node) -> void:
	if not is_alive:
		return
	
	# 触发统一游戏事件：damage_received（在计算减免之前）
	AbilityEventBus.trigger_game_event(&"damage_received", {
		"source": damage_info.instigator,
		"target": owner_entity,
		"damage_info": damage_info
	})
	
	# 同时发出细粒度信号（向后兼容）
	damage_received.emit(damage_info)
	
	# 在应用伤害前被BUFF修改为0或更少
	if damage_info.base_damage <= 0:
		return
	
	# 计算最终伤害（HealthVital 本身可以作为目标）
	var final_damage = DamageCalculator.calculate_final_damage(damage_info, _owner_comp)
	
	# 触发统一游戏事件：damage_dealt（在计算减免之后）
	AbilityEventBus.trigger_game_event(&"damage_dealt", {
		"instigator": damage_info.instigator,
		"target": owner_entity,
		"damage_info": damage_info,
		"final_damage": final_damage
	})
	
	# UI系统可以监听这个信号来显示伤害飘字
	damage_applied.emit(damage_info, final_damage)
	
	# 应用伤害
	if final_damage > 0:
		modify_value(-final_damage)
	
	# 处理死亡
	if not is_alive:
		_die(damage_info.instigator, owner_entity)

## 受到治疗
## [param] amount: float 要增加的生命值数量
func heal(amount: float, owner_entity: Node) -> void:
	if not is_alive:
		return

	modify_value(amount)
	
	# 触发统一游戏事件：healing_applied
	AbilityEventBus.trigger_game_event(&"healing_applied", {
		"target": owner_entity,
		"amount": amount
	})
	
	# 同时发出细粒度信号（向后兼容）
	health_restored.emit()

## 死亡处理
func _die(instigator: Node, owner_entity: Node) -> void:
	if owner_entity:
		owner_entity.add_to_group(DEATH_GROUP_NAME)
	
	# 触发统一游戏事件：entity_died
	AbilityEventBus.trigger_game_event(&"entity_died", {
		"entity": owner_entity,
		"instigator": instigator
	})
	
	# 同时发出细粒度信号（向后兼容）
	health_depleted.emit(instigator)
