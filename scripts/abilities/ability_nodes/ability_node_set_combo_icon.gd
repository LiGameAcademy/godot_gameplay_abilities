extends BTAction
class_name AbilityNodeSetComboIcon

## 设置连击图标节点
## 职责：更新黑板中的 UI 图标数据，供 AbilityButton 读取

## [核心] 直接配置要显示的纹理
@export var icon_texture: Texture2D

func _tick(instance: BTInstance, delta: float) -> int:
    var blackboard = instance.blackboard
    var ability = blackboard.get_var("ability_instance")
    
    # 1. 将纹理直接写入黑板 (UI 只需要读这个变量)
    # 我们约定 key 为 "combo_next_icon"
    blackboard.set_var("combo_next_icon", icon_texture)
    
    # 2. 通知 UI 刷新
    if is_instance_valid(ability):
        ability.ability_data_changed.emit(ability)
        
    return Status.SUCCESS