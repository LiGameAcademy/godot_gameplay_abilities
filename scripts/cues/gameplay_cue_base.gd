@abstract
extends Resource
class_name GameplayCueBase

## Cue 基类（抽象类）
## 所有具体的 Cue 组件都继承此类，实现 execute 方法

## 挂点名（用于定位特效播放位置）
## 常见挂点名：
## - "root": 根节点位置（默认）
## - "head": 头顶
## - "foot": 脚下
## - "body": 身体中心
## - "weapon": 武器位置
## - "muzzle": 枪口位置
@export var attachment_point: StringName = &"root"

## 挂点偏移量（相对于挂点位置的偏移）
@export var offset: Vector3 = Vector3.ZERO

## 执行 Cue
## [param] target: Node 目标节点
## [param] location: Vector3 播放位置（已根据挂点计算）
## [param] context: Dictionary 上下文信息（可选，如伤害值、治疗值等）
func execute(target: Node, location: Vector3, context: Dictionary = {}) -> void:
	_execute(target, location, context)

## 停止 Cue（用于持续效果，如拖尾、持续特效等）
func stop(target: Node) -> void:
	_stop(target)

func update(_delta: float) -> void: pass

## [子类重写] 执行 Cue 的具体实现
@abstract func _execute(_target: Node, _location: Vector3, _context: Dictionary) -> void
## [子类重写] 停止 Cue 的具体实现
func _stop(_target: Node) -> void: pass
