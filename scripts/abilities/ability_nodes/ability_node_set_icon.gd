extends BTAction
class_name AbilityNodeSetIcon

## 设置技能图标节点
## 职责：更新黑板中的 UI 图标数据，供 AbilityButton 读取
## 用途：
## - 连击技能：设置下一段连击的图标
## - 切换技能：设置激活时的图标（或清除图标恢复默认）

## [配置] 要显示的纹理（如果为 null，则清除图标，恢复默认）
@export var icon_texture: Texture = null
## [配置] 黑板变量名（用于存储图标）
## 可选值：
## - "combo_next_icon": 连击技能使用
## - "toggle_active_icon": 切换技能使用
## - 自定义：其他用途
@export var icon_key: String = "combo_next_icon"

func _tick(instance: BTInstance, delta: float) -> int:
    var blackboard = instance.blackboard
    var ability = blackboard.get_var("ability_instance")
    
    # 1. 将纹理写入黑板（如果为 null，则清除）
    if is_instance_valid(icon_texture):
        blackboard.set_var(icon_key, icon_texture)
    else:
        blackboard.erase_var(icon_key)
    
    # 2. 通知 UI 刷新
    if is_instance_valid(ability):
        ability.ability_data_changed.emit(ability)
        
    return Status.SUCCESS
