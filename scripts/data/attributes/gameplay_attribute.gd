extends Resource
class_name GameplayAttribute

## 游戏属性数据
## 定义游戏中的各种属性（生命值、攻击力、防御力等）

@export var attribute_id : StringName = &""
@export var attribute_display_name : String = &""
@export var attribute_description : String = &""
@export var attribute_icon : Texture2D = null
@export var base_value: float = 0
@export var min_value: float = -INF
@export var max_value: float = INF

func get_id() -> StringName:
	return attribute_id
