# 能力规格

## Purpose

定义博客主题工程的基础能力：主题可构建并打包成可安装产物，颜色只有一个来源，字体全部随包分发，所有路由都由统一骨架渲染并声明版权，布局在三档宽度下可用。

## ADDED Requirements

### Requirement: 主题工程可构建并打包

系统 SHALL 提供一次构建即可产出的可安装主题包，包内包含主题元数据、模板与静态资源。

#### Scenario: 执行构建

- **WHEN** 在 `theme/` 下执行 `pnpm build`
- **THEN** 构建成功退出
- **AND** `theme/dist/` 中出现命名为 `<主题名>-<版本>.zip` 的主题包
- **AND** 包内包含 `theme.yaml`、`templates/` 与 `assets/`

### Requirement: 颜色只有一个来源

系统 SHALL 在 CSS 中把 DR-1 的八个配色 token 定义为变量，其余样式只通过语义变量引用颜色。

#### Scenario: 构建产物包含全部 token

- **WHEN** 执行 `bash theme/verify/check-theme.sh --tokens`
- **THEN** 校验通过
- **AND** 构建后的 CSS 中能找到全部八个 `--sg-*` 变量

#### Scenario: 组件不写死色值

- **WHEN** 检查 `theme/src/css/` 下除 token 文件之外的样式
- **THEN** 不存在十六进制或 `rgba(` 形式的色值字面量

### Requirement: 字体全部自托管

系统 SHALL 把字体文件随主题包一起分发，不在页面中引用任何外部字体服务。

#### Scenario: 构建产物不含外部字体引用

- **WHEN** 执行 `bash theme/verify/check-theme.sh --fonts`
- **THEN** 构建后的 CSS 与模板中不含 `fonts.googleapis.com` 或 `fonts.gstatic.com`
- **AND** 主题包内存在 `.woff2` 字体文件

### Requirement: 所有路由由统一骨架渲染

系统 SHALL 为首页、文章、独立页、归档、分类、标签、作者与 404 提供模板，使每个页面都包含页头导航、内容区与页脚。

#### Scenario: 本地预览覆盖全部路由

- **WHEN** 执行 `bash theme/verify/preview-test.sh`
- **THEN** 首页、归档、分类、标签与一个不存在的路径均返回成功响应或预期的 404 页面
- **AND** 每个响应都包含页头导航与页脚标记
- **AND** 文章详情页在存在示例文章时同样通过断言

#### Scenario: 模板齐全

- **WHEN** 执行 `bash theme/verify/check-theme.sh --templates`
- **THEN** 构建产物中同时存在 10 个路由模板

### Requirement: 响应式布局在移动端可用

系统 SHALL 在至少三档宽度下提供可用布局，并在窄屏折叠导航。

#### Scenario: 构建产物包含响应式规则

- **WHEN** 执行 `bash theme/verify/check-theme.sh --layout`
- **THEN** 构建后的 CSS 中至少存在三个 `@media` 断点
- **AND** 存在窄屏下隐藏并展开导航的规则

### Requirement: 页脚声明版权

系统 SHALL 在每个页面的页脚展示非官方粉丝作品声明。

#### Scenario: 页面包含声明文本

- **WHEN** 任意页面被渲染
- **THEN** 页脚包含 `非官方粉丝作品` 与 `MAGES./Nitroplus` 字样
