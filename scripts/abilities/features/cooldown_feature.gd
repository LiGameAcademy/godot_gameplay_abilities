extends GameplayAbilityFeature
class_name CooldownFeature

const KEY_COOLDOWN_TIMER = "cooldown_timer"

@export_group("Cooldown Settings")
## 冷却时间（秒）
@export var cooldown_duration: float = 0.0

func _init() -> void:
	super("CooldownFeature")

#func on_activate(ability: GameplayAbilityInstance, context: Dictionary) -> void:
	#start_cooldown(ability)

func can_activate(ability: GameplayAbilityInstance, context: Dictionary) -> bool:
	# 如果 context 跳过冷却，直接返回 true
	if context.get("skip_cooldown", false):
		return true

	# 从黑板读取剩余时间
	var remaining = _get_timer(ability)
	return remaining <= 0.0

func update(ability: GameplayAbilityInstance, delta: float) -> void:
	var remaining = _get_timer(ability)
	if remaining > 0.0:
		remaining -= delta
		if remaining <= 0.0:
			remaining = 0.0
		_set_timer(ability, remaining)

## 开始冷却
func start_cooldown(ability: GameplayAbilityInstance, duration: float = cooldown_duration) -> void:
	if duration > 0.0:
		_set_timer(ability, duration)

## 获取冷却剩余时间
func get_cooldown_remaining(ability: GameplayAbilityInstance) -> float:
	return _get_timer(ability)

## 获取冷却进度（0.0-1.0）
func get_cooldown_progress(ability: GameplayAbilityInstance) -> float:
	if cooldown_duration <= 0.0:
		return 0.0
	return _get_timer(ability) / cooldown_duration

func _get_timer(ability: GameplayAbilityInstance) -> float:
	return _get_data(ability, KEY_COOLDOWN_TIMER, 0.0)

func _set_timer(ability: GameplayAbilityInstance, value: float) -> void:
	_set_data(ability, KEY_COOLDOWN_TIMER, value)
