extends Resource
class_name GameplayAttribute

## 游戏属性数据
## 定义游戏中的各种属性（生命值、攻击力、防御力等）

@export var attribute_id : StringName = &"" 			## 属性ID（唯一标识）
@export var attribute_display_name : String = "" 		## 属性显示名称
@export_multiline 
var attribute_description : String = "" 				## 属性描述
@export var attribute_icon : Texture2D = null 			## 属性图标
@export var min_value: float = -INF 					## 属性最小值
@export var max_value: float = INF 						## 属性最大值
@export var is_hidden: bool = false 					## 属性是否隐藏（不在UI显示）
@export var is_percentage: bool = false 				## 是否百分比显示

func get_id() -> StringName:
	return attribute_id
