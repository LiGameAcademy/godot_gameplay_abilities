extends Resource
class_name GameplayStatusData

## 状态数据（Buff/Debuff定义）
## 定义状态的所有属性，包括效果、持续时间、叠加策略等

## 定义重复施加时的处理策略
enum StackingPolicy {
	STACK_INTENSITY,       ## 增加层数, 并刷新持续时间。 (例如: 中毒, 怒火)
	REFRESH_DURATION,      ## (默认) 刷新持续时间。 (例如: 心灵之火, 减速)
	ACCUMULATE_DURATION,   ## 累加持续时间 (不刷新)。 (例如: RPG中的 HoT)
	IGNORE                 ## 忽略, (例如: 变形术, 无法被刷新)
}

@export var status_id: StringName
@export var status_display_name: String = ""
@export var status_description: String = ""
@export var duration: float = -1.0  ## -1 为永久/切换, 0 为瞬时, >0 为持续时间
@export var icon: Texture2D
@export var is_debuff: bool = false
@export var tags: Array[StringName] = []

@export_group("Effects")
## 这个状态所包含的所有效果
@export var effects: Array[GameplayEffect] = []

@export_group("Effect Timing")
## 周期性效果的周期时间，如果为0，则不周期性触发
## 当 period > 0 时，所有效果会按此周期重复触发
@export var period: float = 0.0
## 监听的事件，如果为空，则不监听事件
## 当 event_to_listen 不为空时，所有效果会在该事件发生时触发
@export var event_to_listen: StringName = &""

@export_group("Event Triggers")
## 此状态可以响应的游戏事件类型
## 例如: [&"damage_received", &"turn_start", &"ability_activated"]
## 当这些事件发生时，状态会触发对应的效果
## 注意：效果需要设置 event_to_listen 字段才能被触发
@export var trigger_on_events: Array[StringName] = []

@export_group("Stacking")
@export var stacking_policy: StackingPolicy = StackingPolicy.REFRESH_DURATION
@export var max_stacks: int = 1

## 检查此状态是否可以被指定事件触发
func can_trigger_on_event(event_type: StringName) -> bool:
	return trigger_on_events.has(event_type)

func get_effects_description() -> String:
	var descriptions = []
	for effect in effects:
		descriptions.append(effect.get_description())
	return descriptions.join("\n")
