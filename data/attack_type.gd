extends Resource
class_name AttackType

## 攻击类型
## 定义攻击的类型（物理、魔法、真实伤害等）

@export var attack_type_id : StringName = &""
@export var attack_type_display_name : String = ""
@export var attack_type_description : String = ""
@export var attack_type_icon : Texture2D = null

func get_id() -> StringName:
	return attack_type_id

