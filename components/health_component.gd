extends VitalComponent
class_name HealthComponent

## 生命值组件
## 管理实体的生命值，处理伤害、治疗、死亡

const DEATH_GROUP_NAME: String = "death"

@export var is_invincible: bool = false ## 是否无敌
@export var armor_type : ArmorType = null
@export var armor_attribute_id : StringName = "armor"
@export var corpse_duration: float = 30.0	## 尸体在场景中停留的时间（秒）

var armor_value: float:
	get:
		if not is_instance_valid(_attribute_comp):
			return 0.0
		return _attribute_comp.get_value(armor_attribute_id)
	set(value):
		if is_instance_valid(_attribute_comp):
			_attribute_comp.set_value(armor_attribute_id, value)

var is_alive: bool = true:
	get:
		return _current_value > 0

signal health_restored()							## 生命值恢复
signal health_depleted(instigator: Node)			## 生命值耗尽,instigator: 造成伤害的实体
signal damage_received(damage_info: DamageInfo)		## 接受伤害时发出（在计算减免之前）
signal damage_applied(damage_info: DamageInfo, final_damage: float)		## 受到伤害时发出（在计算减免之后）

func _ready() -> void:
	super._ready()
	if not is_instance_valid(_attribute_comp):
		push_error("HealthComponent: attribute component is not valid!")
		return

## 核心伤害应用接口
func apply_damage(damage_info: DamageInfo) -> void:
	if not is_alive or is_invincible:
		return
	
	# 即将造成伤害广播
	damage_received.emit(damage_info)

	# 在应用伤害前被BUFF修改为0或更少
	if damage_info.base_damage <= 0:
		return

	var final_damage = DamageCalculator.calculate_final_damage(damage_info, self)

	# UI系统可以监听这个信号来显示伤害飘字
	damage_applied.emit(damage_info, final_damage)

	# 应用伤害
	if final_damage > 0:
		set_current_value(_current_value - final_damage)
		
	# 处理死亡
	if not is_alive:
		_die(damage_info.instigator)

## 受到治疗
## [param] amount: float 要增加的生命值数量
func heal(amount: float) -> void:
	if not is_alive:
		return
	
	add_health(amount)
	health_restored.emit()

## 增加生命值（用于治疗、建造等）
## [param] amount: float 要增加的生命值数量
func add_health(amount: float) -> void:
	if _current_value >= _max_value:
		push_warning("HealthComponent: current health is greater than max health!")
		return

	set_current_value(_current_value + amount)

## 按比例设置生命值
## [param] ratio: float 生命值比例
func set_health_ratio(ratio: float) -> void:
	set_current_value(_max_value * ratio)

## 死亡处理
func _die(instigator: Node) -> void:
	var owner_node = get_parent()
	if owner_node:
		owner_node.add_to_group(DEATH_GROUP_NAME)
	health_depleted.emit(instigator)

