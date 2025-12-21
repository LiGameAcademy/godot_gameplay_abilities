extends BTAction
class_name BTSetVarFromList

@export var index_key: String = "combo_index"
@export var target_key: String = "ability_icon"
@export var source_list: Array = [] # 在编辑器里填资源列表

func _tick(instance: BTInstance, delta: float) -> int:
    var idx: int = _get_var(instance, index_key, 0)
    
    # 越界检查（如果越界，可以取最后一个，或者取0，或者不设置）
    if idx >= 0 and idx < source_list.size():
        var val: Variant = source_list[idx]
        _set_var(instance, target_key, val)
    else:
        _set_var(instance, target_key, null)
    return Status.SUCCESS
