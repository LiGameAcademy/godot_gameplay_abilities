extends GameplayAbilityFeature
class_name CooldownFeature

## 冷却特性 (享元模式版)
## 状态存储在 GameplayAbilityInstance 的 Blackboard 中

## 黑板 Key 常量 (为了避免魔法字符串，建议定义常量)
## 由于 Feature 是单例的，为了避免不同特性的数据冲突，
## 最好加上 feature_name 前缀，或者如果你确定一个技能只有一个 CD 逻辑，可以用固定 Key
const KEY_COOLDOWN_TIMER = "cooldown_timer"

@export_group("Cooldown Settings")
## 冷却时间（秒）
@export var cooldown_duration: float = 0.0

func _init() -> void:
	super("CooldownFeature")

func can_activate(ability: GameplayAbilityInstance, context: Dictionary) -> bool:
	# 如果 context 跳过冷却，直接返回 true
	if context.get("skip_cooldown", false):
		return true
	
	# 2. 从黑板读取剩余时间
	var remaining = _get_timer(ability)
	return remaining <= 0.0

func update(ability: GameplayAbilityInstance, delta: float) -> void:
	var remaining = _get_timer(ability)
	if remaining > 0.0:
		remaining -= delta
		if remaining <= 0.0:
			remaining = 0.0
		_set_timer(ability, remaining)

func get_description() -> String:
	if cooldown_duration <= 0.0:
		return "无冷却"
	return "冷却时间: %.1f秒" % cooldown_duration

## 开始冷却
func start_cooldown(ability: GameplayAbilityInstance, duration: float = cooldown_duration) -> void:
	if duration > 0.0:
		_set_timer(ability, duration)

## 检查冷却是否就绪
## [return] bool 冷却是否就绪
func is_cooldown_ready(ability: GameplayAbilityInstance) -> bool:
	return _get_timer(ability) <= 0.0

## 获取冷却剩余时间
## [return] float 冷却剩余时间（秒）
func get_cooldown_remaining(ability: GameplayAbilityInstance) -> float:
	return _get_timer(ability)

## 获取冷却进度（0.0-1.0，0.0 表示冷却完成，1.0 表示刚开始冷却）
## [return] float 冷却进度
func get_cooldown_progress(ability: GameplayAbilityInstance) -> float:
	if cooldown_duration <= 0.0:
		return 0.0
	return _get_timer(ability) / cooldown_duration

func _get_timer(ability: GameplayAbilityInstance) -> float:
	# 为了防止 Key 冲突，可以使用 feature_name 组合 Key
	# var unique_key = feature_name + "_" + KEY_COOLDOWN_TIMER
	# 但对于基础 CD，直接用 "cooldown_timer" 可能更方便 UI 读取
	return ability.get_blackboard_var(KEY_COOLDOWN_TIMER, 0.0)

func _set_timer(ability: GameplayAbilityInstance, value: float) -> void:
	ability.set_blackboard_var(KEY_COOLDOWN_TIMER, value)
