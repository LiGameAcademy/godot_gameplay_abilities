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
## 状态应用时触发的效果（一次性效果）
## 这些效果在状态被应用时立即触发，包括：
## - 瞬时效果（如初始伤害、治疗）
## - 属性修改器（需要存储以便移除时清理）
## - 视觉效果（如状态图标、粒子特效）
@export var effects: Array[GameplayEffect] = []

## 周期性触发的效果（DoT、HoT等）
## 这些效果会在状态的每个周期触发，不会在状态应用时触发
## 注意：周期性效果不会存储到 stateful_effects，每次触发时直接应用
@export var periodic_effects: Array[GameplayEffect] = []

@export_group("Effect Timing")
## 周期性效果的周期时间，如果为0，则不周期性触发
## 当 period > 0 时，periodic_effects 会按此周期重复触发
@export var period: float = 0.0
## 监听的事件，如果为空，则不监听事件
## 当 event_to_listen 不为空时，所有效果会在该事件发生时触发
@export var event_to_listen: StringName = &""

@export_group("Event Triggers")
## 此状态可以响应的游戏事件类型
## 例如: [&"damage_received", &"turn_start", &"ability_completed"]
## 当这些事件发生时，状态会触发对应的效果
## 注意：效果需要设置 event_to_listen 字段才能被触发
@export var trigger_on_events: Array[StringName] = []

@export_group("Stacking")
@export var stacking_policy: StackingPolicy = StackingPolicy.REFRESH_DURATION
@export var max_stacks: int = 1

@export_group("Status Relations")
## 状态优先级（数字越大优先级越高）
## 当新状态与旧状态冲突时，优先级高的状态会替换优先级低的状态
@export var priority: int = 0

@export_group("Targeting")
## 目标选择策略（可选）
## 如果设置了此策略，状态的效果会应用到策略选择的目标，而不是状态被应用到的实体
## 例如：状态应用到自己，但效果通过策略应用到周围敌人
## 
## 如果未设置策略，效果会直接应用到状态被应用到的实体（默认行为）
## 
## 推荐策略：
## - HitDetectorTargetingStrategy: 简单的目标检测（范围伤害、AOE效果等）
## - AreaTargetingStrategy: 区域目标检测（AOE技能）
## - UnitTargetingStrategy: 单位目标检测（指向性效果）
## - SelfTargetingStrategy: 只对自己生效（显式指定）
## - NoTargetingStrategy: 无目标（通常不需要）
@export var targeting_strategy: TargetingStrategy = null

@export_group("Visual Feedback")
## 游戏提示（Cue），用于逻辑与表现分离
## 当状态应用时，会执行此 Cue 来播放表现（特效、音效等）
## 状态移除时，会自动停止持续 Cue（如附加粒子特效）
@export var cue: GameplayCue = null

## 检查此状态是否可以被指定事件触发
func can_trigger_on_event(event_type: StringName) -> bool:
	return trigger_on_events.has(event_type)

func get_effects_description() -> String:
	var descriptions = []
	for effect in effects:
		descriptions.append(effect.get_description())
	#return descriptions.join("\n")
	return ""
