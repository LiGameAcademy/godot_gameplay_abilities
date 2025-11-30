extends Resource
class_name ArmorType

## 护甲类型
## 定义护甲的类型（轻甲、重甲、无甲等）

@export var armor_type_id : StringName = &""  # 修正拼写错误
@export var armor_type_display_name : String = ""
@export var armor_type_description : String = ""
@export var armor_type_icon : Texture2D = null

func get_id() -> StringName:
	return armor_type_id

