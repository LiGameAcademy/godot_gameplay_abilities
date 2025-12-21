extends BTAction
class_name AbilityNodePlayAnimation

## 播放动画节点
## 
## 原理：
## 该节点并不直接操作 AnimationPlayer，而是向 AbilityInstance 发送请求。
## 这允许 AbilityInstance 内部决定具体由谁来播放（比如转发给 Owner 的 VisualComponent）。
##
## 注意：
## 此节点是【即发即弃 (Fire-and-Forget)】的。
## 它触发播放请求后会立即返回 SUCCESS。
## 如果你需要等待动画播放完毕，请在此节点后接一个 BTWait。

@export var animation_name: StringName = ""
@export var animation_speed: float = 1.0
@export var wait_for_finish: bool = false
@export var override_duration: float = 0.0
@export var play_animation_method: StringName = "play_animation"

## [生命周期] 节点激活时调用（只跑一次）
## 这就是防止动画被重复调用的关键！
func _enter(instance: BTInstance) -> void:
	var ability = instance.blackboard.get_var("ability_instance")
	if not is_instance_valid(ability):
		push_warning("AbilityNodePlayAnimation: AbilityInstance 不存在。动画 '%s' 播放失败。" % animation_name)
		return

	var duration = override_duration
	
	# 1. 执行播放
	if not ability.has_method(play_animation_method):
		push_warning("AbilityNodePlayAnimation: 方法 '%s' 在 AbilityInstance 上不存在。动画 '%s' 播放失败。" % [play_animation_method, animation_name])
		return

	var result = ability.call(play_animation_method, animation_name, animation_speed)
	if result is float:
		duration = result
	else:
		push_warning("AbilityNodePlayAnimation: 方法 '%s' 返回的时长不是 float。动画 '%s' 播放失败。" % [play_animation_method, animation_name])
		return
			
	# 2. 如果需要等待，初始化计时器
	if wait_for_finish:
		# 如果获取到的时长无效（比如动画系统没返回时长），这会导致立即结束
		if duration <= 0.0:
			push_warning("AbilityNodePlayAnimation: 等待模式开启，但未获取到有效的动画时长。")
		
		# 将剩余时间存入节点的私有内存区
		_set_storage(instance, duration)

## [生命周期] 每帧更新
func _tick(instance: BTInstance, delta: float) -> int:
	# 1. 如果不需要等待，直接成功
	if not wait_for_finish:
		return Status.SUCCESS
		
	# 2. 获取剩余时间
	var time_left = _get_storage(instance, 0.0)
	
	# 3. 扣减时间
	time_left -= delta
	
	# 4. 判断结果
	if time_left <= 0:
		return Status.SUCCESS # 时间到，动画播完了
	else:
		# 存回黑板，下一帧继续
		_set_storage(instance, time_left)
		return Status.RUNNING
