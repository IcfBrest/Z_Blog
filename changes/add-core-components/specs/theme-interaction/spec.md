# theme-interaction

## Purpose

定义博客主题的交互层能力：访客可以在 α 与 β 世界线之间切换、一键进入简洁模式，首页用辉光管显示 Divergence Meter，全站动效受统一开关控制，并且这些默认值都能由主题设置项配置。

## ADDED Requirements

### Requirement: 世界线可在 α 与 β 之间切换

系统 SHALL 通过 `<html>` 上的 `data-worldline` 属性在 `alpha` 与 `beta` 之间切换全站强调色，并记住访客的选择。

#### Scenario: 访客切换世界线

- **WHEN** 访客点击导航栏的世界线切换控件
- **THEN** `<html>` 的 `data-worldline` 在两个取值之间翻转
- **AND** 强调色、链接色与边框色随之改变
- **AND** 选择写入 `localStorage`，刷新页面后保持

#### Scenario: 首次访问使用设置项默认值

- **WHEN** 访客没有已保存的世界线选择
- **THEN** 页面按主题设置项「默认世界线」渲染
- **AND** 服务端返回的 HTML 中已包含对应的 `data-worldline` 属性

### Requirement: 简洁模式一键关闭全部动效

系统 SHALL 提供简洁模式，开启后使扫描线、辉光、打字机、粒子与滚动数字全部停止。

#### Scenario: 手动开启简洁模式

- **WHEN** 访客点击导航栏的简洁模式开关
- **THEN** `<html>` 的 `data-motion` 变为 `off`
- **AND** 扫描线层与粒子画布不再产生动画
- **AND** 选择写入 `localStorage`，刷新页面后保持

#### Scenario: 系统偏好减少动效

- **WHEN** 操作系统设置了 `prefers-reduced-motion: reduce`
- **THEN** 即使访客没有手动选择，页面也按 `data-motion="off"` 渲染
- **AND** 访客手动打开动效后，其选择覆盖系统偏好

### Requirement: 首页显示 Divergence Meter

系统 SHALL 在首页 hero 区渲染辉光管样式的 Divergence Meter，显示六位小数与百分号，并支持两种数据源。

#### Scenario: 默认显示世界线变动率

- **WHEN** 访客打开首页且数据源为 `attractor`
- **THEN** 页面显示 `1.048596%`
- **AND** 数字按位拆分为独立辉光管单元，小数点与百分号同样按位出现

#### Scenario: 切换到站点真实数据

- **WHEN** 访客点击 Divergence Meter 的数据源切换控件
- **THEN** 数值过渡到站点真实文章数
- **AND** 过渡使用滚动数字动画；简洁模式下直接显示终值，不播放滚动

### Requirement: 动效只用 transform 与 opacity

系统 SHALL 只用 `transform` 与 `opacity` 承载动画，避免触发布局与大面积重绘。

#### Scenario: 检查动画属性

- **WHEN** 执行 `bash theme/verify/check-theme.sh --components`
- **THEN** 构建后的 CSS 中不存在针对 `top`、`left`、`width`、`height`、`margin` 的 `transition` 或 `animation` 声明
- **AND** 所有 `transition`/`animation` 的时长引用 `--motion-*` 变量

### Requirement: 交互默认值可由主题设置项配置

系统 SHALL 在主题设置中提供默认世界线、默认简洁模式、Divergence Meter 数据源、粒子开关与鼠标辉光开关五项。

#### Scenario: 设置项齐备

- **WHEN** 执行 `bash theme/verify/check-theme.sh --components`
- **THEN** `theme/settings.yaml` 含上述五个设置项
- **AND** 每个设置项的默认值都落在合法取值集合内

#### Scenario: 修改默认值后生效

- **WHEN** 管理员把「默认简洁模式」改为开启并重新加载页面
- **THEN** 未保存过偏好的访客看到 `data-motion="off"`

### Requirement: 无 JavaScript 时页面仍完整可读

系统 SHALL 在禁用 JavaScript 时保留内容、导航与默认外观，只失去交互能力。

#### Scenario: 禁用脚本后浏览

- **WHEN** 浏览器禁用 JavaScript 后打开首页
- **THEN** 页面显示服务端默认世界线、静态 Divergence Meter 数值与全部文章条目
- **AND** 世界线与简洁模式控件仍然可见
