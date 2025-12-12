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

## 目标应用模式
## 决定状态效果应该应用到哪些目标
enum TargetApplicationMode {
	SELF,              ## 应用到自己（默认，适用于Buff、Debuff等）
	DETECTED_TARGETS,  ## 应用到检测到的目标（适用于范围伤害、AOE技能等）
	BOTH               ## 同时应用到自己和检测到的目标（适用于治疗术等）
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

@export_group("Visual Feedback")
## 游戏提示（Cue），用于逻辑与表现分离
## 当状态应用时，会执行此 Cue 来播放表现（特效、音效等）
## 状态移除时，会自动停止持续 Cue（如附加粒子特效）
@export var cue: GameplayCue = null

@export_group("Target Detection")
## 命中检测器（用于检测目标）
## 如果设置了，Status 会在应用时使用此检测器检测目标
## 如果未设置，Status 会应用到自己（target = instigator）
## 适用于：范围伤害、AOE技能等需要检测周围目标的场景
@export var hit_detector: HitDetectorBase = null

## 目标筛选策略（用于筛选检测到的目标）
## 如果设置了，Status 会使用此策略进一步筛选目标
## 适用于：需要特定筛选逻辑的场景（如只对敌人、只对友军等）
@export var targeting_strategy: TargetingStrategy = null

## 目标应用模式
## SELF: 应用到自己（默认）
## DETECTED_TARGETS: 应用到检测到的目标
## BOTH: 同时应用到自己和检测到的目标
@export var target_mode: TargetApplicationMode = TargetApplicationMode.SELF

## 检查此状态是否可以被指定事件触发
func can_trigger_on_event(event_type: StringName) -> bool:
	return trigger_on_events.has(event_type)

func get_effects_description() -> String:
	var descriptions = []
	for effect in effects:
		descriptions.append(effect.get_description())
	#return descriptions.join("\n")
	return ""
