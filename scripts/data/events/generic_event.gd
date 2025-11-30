extends CombatEvent
class_name GenericEvent

## 通用事件（用于未定义的事件类型）
## 此类不发出细粒度信号，只触发统一事件

func _init(p_event_type: StringName, p_context: Dictionary) -> void:
	super(p_event_type, p_context)

func emit_gameplay_signal(_event_bus: CombatEventBus) -> void:
	# 通用事件不发出细粒度信号，只通过统一事件系统处理
	pass

