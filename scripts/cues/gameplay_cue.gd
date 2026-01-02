extends Resource
class_name GameplayCue

## 游戏提示（Cue）资源
## 用于逻辑与表现分离，定义"当某个逻辑事件发生时，应该播放什么表现"
## 采用组合模式，可以包含多个 Cue 组件（飘字、特效、音效等）

@export_group("Cue Components")
## Cue 组件数组（组合模式）
## 可以包含多个不同类型的 Cue，例如同时播放特效、音效和飘字
@export var cues: Array[GameplayCueBase] = []
