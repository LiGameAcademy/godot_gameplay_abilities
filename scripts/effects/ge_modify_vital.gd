extends GameplayEffect
class_name GE_ModifyVital

## 修改Vital

@export var vital_id : StringName = &""
@export var amount: float = 0.0
@export var vital_comp_name : StringName = &"GameplayAttributeComponent"

func _apply(target: Node, instigator: Node, context: AbilityContext) -> void:
    var vital_comp = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name)

    if not vital_comp:
        push_error("GE_ModifyVital: Target %s has no %s component" % [target.name, vital_comp_name])
        return
    
    vital_comp.modify_vital(vital_id, amount)
    AbilityEventBus.trigger_game_event(&"vital_modified", {
        "target": target,
        "instigator": instigator,
        "vital_id": vital_id,
        "amount": amount
    })

func _get_description() -> String:
    return "Modify %s %s by %s\n" % [vital_id, vital_comp_name, amount]