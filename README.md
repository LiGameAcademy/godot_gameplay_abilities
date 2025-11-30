# Godot Combat System Plugin

**高内聚、低耦合的插件化战斗系统**

## 简介

这是一个通用的、插件化的战斗系统，采用高内聚、低耦合的架构设计。战斗系统作为独立插件，通过组件、单例和事件通讯暴露API，可被不同类型的游戏项目（ARPG、RTS等）使用。

## 核心设计理念

1. **高内聚：** 战斗系统的所有逻辑封装在插件内部，对外只暴露必要的API
2. **低耦合：** 业务层通过组件、单例、事件与战斗系统交互，不直接依赖内部实现
3. **鸭子类型：** 采用鸭子类型设计而非继承，实现终极解耦
4. **通用性：** 可适配不同架构的游戏项目，展示其通用性

## 核心系统

- **组件化设计：** VitalComponent、HealthComponent、ManaComponent等
- **GameplayAttribute系统：** 属性计算、修改、通知
- **GameplayAbility系统：** 技能施放、冷却、消耗
- **GameplayAbilityStatus系统：** 状态效果、持续时间、叠加
- **Effect层抽象：** 伤害、治疗、状态效果等

## 安装

将此插件作为Git子模块添加到你的项目中：

```bash
git submodule add <repository-url> addons/godot-combat-system
```

## 使用

1. 在Godot编辑器中启用插件
2. 在项目中使用组件、单例和事件与战斗系统交互
3. 参考文档了解详细API

## 文档

详细文档请参考课程教程。

## 许可证

MIT License

## 作者

老李（玩物不丧志的老李）

