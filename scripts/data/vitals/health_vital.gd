extends VitalBaseResource
class_name HealthVital

## 生命值 Vital
## 处理伤害、治疗、死亡等逻辑

const DEATH_GROUP_NAME: String = "death"

## 额外配置
var is_invincible: bool = false ## 是否无敌
var armor_type: ArmorType = null
var armor_attribute_id: StringName = "armor"
var corpse_duration: float = 30.0 ## 尸体在场景中停留的时间（秒）

## 护甲值（从属性组件获取）
var armor_value: float:
	get:
		if not is_instance_valid(attribute_component):
			return 0.0
		return attribute_component.get_value(armor_attribute_id)
	set(value):
		if is_instance_valid(attribute_component):
			attribute_component.set_value(armor_attribute_id, value)

## 是否存活
var is_alive: bool:
	get:
		return _current_value > 0

signal health_restored() ## 生命值恢复
signal health_depleted(instigator: Node) ## 生命值耗尽
signal damage_received(damage_info: DamageInfo) ## 接受伤害时发出（在计算减免之前）
signal damage_applied(damage_info: DamageInfo, final_damage: float) ## 受到伤害时发出（在计算减免之后）

func _init(p_attribute_component: GameplayAttributeComponent, p_max_value_id: StringName = &"max_health", p_regen_rate_id: StringName = &"health_regen") -> void:
	super(&"health", p_attribute_component, p_max_value_id, p_regen_rate_id)

## 核心伤害应用接口
func apply_damage(damage_info: DamageInfo, owner_entity: Node) -> void:
	if not is_alive or is_invincible:
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
	var final_damage = DamageCalculator.calculate_final_damage(damage_info, self)
	
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
		set_current_value(_current_value - final_damage)
	
	# 处理死亡
	if not is_alive:
		_die(damage_info.instigator, owner_entity)

## 受到治疗
## [param] amount: float 要增加的生命值数量
func heal(amount: float, owner_entity: Node) -> void:
	if not is_alive:
		return
	
	add_health(amount)
	
	# 触发统一游戏事件：healing_applied
	AbilityEventBus.trigger_game_event(&"healing_applied", {
		"target": owner_entity,
		"amount": amount
	})
	
	# 同时发出细粒度信号（向后兼容）
	health_restored.emit()

## 增加生命值（用于治疗、建造等）
## [param] amount: float 要增加的生命值数量
func add_health(amount: float) -> void:
	if _current_value >= max_value:
		push_warning("HealthVital: current health is greater than max health!")
		return
	set_current_value(_current_value + amount)

## 按比例设置生命值
## [param] ratio: float 生命值比例
func set_health_ratio(ratio: float) -> void:
	set_current_value(max_value * ratio)

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
