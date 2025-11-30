# 文档目录

本文档目录包含Godot Gameplay Abilities Plugin的完整文档。

## 文档列表

- [API文档](API.md) - 完整的API参考文档，包含所有组件、数据类、单例的详细API说明
- [使用示例](Examples.md) - 详细的使用示例，包含基础设置、各系统使用示例、完整示例
- [架构设计](Architecture.md) - 系统架构和设计理念，包含目录结构、设计原则、扩展性说明

## 快速开始

1. 阅读 [API文档](API.md) 了解系统API
2. 查看 [使用示例](Examples.md) 学习如何使用
3. 参考 [架构设计](Architecture.md) 了解系统设计

## 目录结构说明

插件采用清晰的目录结构组织：

```
godot_gameplay_abilities/
├── components/          # 组件（采用鸭子类型设计）
├── data/                # 数据类（Resource）
│   ├── attributes/      # 属性相关
│   ├── combat/          # 战斗相关
│   ├── statuses/        # 状态相关
│   ├── abilities/       # 技能相关
│   ├── effects/         # 效果实现
│   ├── filters/         # 过滤器实现
│   └── targeting/       # 目标相关
├── singletons/          # 单例（AutoLoad）
└── docs/               # 文档
```

## 设计理念

- **高内聚、低耦合**：系统逻辑封装在插件内部，通过API暴露功能
- **鸭子类型**：组件不继承基类，通过接口进行交互
- **数据驱动**：使用Resource系统进行数据配置
- **事件驱动**：通过事件总线进行系统间通讯

