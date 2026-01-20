extends GameplayAbilityFeature
class_name DynamicIconFeature

@export_group("Icon Settings")
## 图标映射（图标ID -> 图标纹理）
@export var icon_map: Dictionary[StringName, Texture] = {}
## 黑板变量名（用于读取当前图标ID）
@export var icon_id_key: String = "current_icon_id"

func _init() -> void:
	super("DynamicIconFeature")

## 获取当前图标
func get_current_icon(ability: GameplayAbilityInstance) -> Texture:
	if not is_instance_valid(ability):
		return null
	
	# 从黑板读取图标ID
	var icon_id : StringName = ability.get_blackboard_var(icon_id_key, &"")
	if icon_id.is_empty():
		return null

	# 从映射中获取图标
	if icon_map.has(icon_id):
		var icon = icon_map[icon_id]
		return icon
	
	return null
