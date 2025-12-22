extends GameplayAbilityFeature
class_name DynamicIconFeature

## 动态图标特性
## 
## 职责：
## 提供统一的图标获取接口，根据黑板中的图标ID从配置的图标映射中获取图标。
## 行为树节点通过设置黑板变量（如 "current_icon_id"）来切换图标。
##
## 设计理念：
## - Feature 配置图标资源，Node 通过黑板参数通信
## - 完全解耦：Node 不需要知道 Feature 的存在，只需要设置黑板变量
## - 符合"逻辑在树中"的原则：图标切换逻辑由行为树控制
##
## 工作流程：
## 1. Feature 配置图标映射（icon_map: Dictionary[String, Texture]）
## 2. 行为树节点设置黑板变量（如 "current_icon_id" = "active"）
## 3. Feature 读取黑板中的 icon_id，从映射中获取对应图标
##
## 使用场景：
## - 切换技能：行为树节点设置 "current_icon_id" = "active" 或 "inactive"
## - 连击技能：行为树节点根据连击段设置 "current_icon_id" = "combo_1", "combo_2" 等
## - 自定义技能：用户可以在行为树中使用 BTSetVar 设置任意图标ID
##
## 使用方式：
## ```gdscript
## var ability = GameplayAbilityDefinition.new()
## var icon_feature = DynamicIconFeature.new()
## icon_feature.icon_map = {
##     "default": default_icon,
##     "active": active_icon,
##     "combo_1": combo_1_icon,
##     "combo_2": combo_2_icon
## }
## icon_feature.icon_id_key = "current_icon_id"  # 黑板变量名
## ability.features.append(icon_feature)
## ```

@export_group("Icon Settings")
## 图标映射（图标ID -> 图标纹理）
## 行为树节点通过设置黑板变量来切换图标
## 例如：{"default": default_icon, "active": active_icon, "combo_1": combo_1_icon}
@export var icon_map: Dictionary = {}
## 黑板变量名（用于读取当前图标ID）
## 行为树节点（如 BTSetVar）会设置此变量来切换图标
## 例如：设置 "current_icon_id" = "active" 会显示 icon_map["active"]
@export var icon_id_key: String = "current_icon_id"

func _init() -> void:
	super("DynamicIconFeature")

## 获取当前图标
## 从黑板中读取图标ID，然后从 icon_map 中获取对应的图标
## 
## [param] ability: GameplayAbilityInstance 技能实例
## [return] Texture 当前图标，如果未配置则返回 null
##
## 逻辑：
## 1. 从黑板读取 icon_id_key 的值（图标ID）
## 2. 从 icon_map 中查找对应的图标
## 3. 如果找不到，返回 null（回退到 Definition 的默认图标）
func get_current_icon(ability: GameplayAbilityInstance) -> Texture:
	if not is_instance_valid(ability):
		return null
	
	var blackboard = ability.get_blackboard()
	if not is_instance_valid(blackboard):
		return null
	
	# 从黑板读取图标ID
	var icon_id = blackboard.get_var(icon_id_key)
	if icon_id == null:
		return null
	
	# 从映射中获取图标
	if icon_map.has(icon_id):
		var icon = icon_map[icon_id]
		if icon is Texture:
			return icon as Texture
	
	return null
