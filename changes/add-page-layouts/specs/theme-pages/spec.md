## Purpose

把 `DR-2` 的六行页面视觉映射变成主题里真实存在的模板结构，并让预览验证从「空站点」升级为「有数据」，使页面级结构可以被自动断言。

## ADDED Requirements

### Requirement: 首页世界线横幅

系统 SHALL 在首页渲染一条由内联 SVG 绘制的世界线横幅，节点来自已发布分类，当前页所属分类高亮，且不依赖任何 JavaScript 或外部图片资源。

#### Scenario: 有分类时渲染节点

- **WHEN** 站点存在分类且访客访问首页
- **THEN** 首屏出现 `svg.sg-worldline` 元素，其中节点数量等于分类数量（上限 5），每个节点包含指向对应分类页的链接
- **THEN** 当前页没有分类上下文时，第一个节点被标记为高亮

#### Scenario: 窄屏收敛

- **WHEN** 视口宽度小于 480px
- **THEN** 横幅只保留圆点与折线，节点文字隐藏，节点数量上限降为 3

#### Scenario: 简洁模式下静止

- **WHEN** `<html data-motion="off">`
- **THEN** 横幅不播放任何动画（节点辉光为静态值）

### Requirement: 文章详情 CRT 终端容器与 D-Mail 元信息

系统 SHALL 把文章正文包进 CRT 终端容器，并在正文之前渲染「D-Mail 发送记录」元信息，包含发送时间、发信人与世界线三项。

#### Scenario: 渲染终端容器

- **WHEN** 访客访问一篇已发布文章
- **THEN** 页面包含 `section.sg-terminal` 容器，容器内有标题栏、局部扫描线伪元素与正文区
- **THEN** 正文 HTML 完整保留（段落、代码块、图片不被截断）

#### Scenario: 元信息三段

- **WHEN** 文章属于某个分类
- **THEN** 元信息依次展示「发送时间」（文章 `publishTime` 格式化）、「发信人」（主题设置项 `master_name`）、「世界线」（第一分类的 `displayName`）
- **WHEN** 文章没有分类
- **THEN** 世界线显示「未观测」而不是空值

### Requirement: 归档世界线时间轴

系统 SHALL 以有序列表形式渲染竖向世界线时间轴，年与月为节点、文章挂在折线上，折线在分页之外保持连续。

#### Scenario: 时间轴结构

- **WHEN** 访客访问归档页且存在文章
- **THEN** 页面包含 `ol.sg-timeline`，其中每个年份为一个 `li.sg-timeline__year`，其下每个月份为 `li.sg-timeline__month`
- **THEN** 每个月份下包含该月的文章链接列表

#### Scenario: 空归档

- **WHEN** 站点没有任何文章
- **THEN** 归档页渲染空状态提示而不是空的 `ol`

### Requirement: 列表与分类的终端形态和世界线分支

系统 SHALL 让首页列表、分类页、标签页采用统一的终端列表形态，并在分类相关位置给出「世界线分支」标识。

#### Scenario: 分类页带分支标识

- **WHEN** 访客访问某个分类页
- **THEN** 页面包含该分类的「世界线分支」徽章，徽章文本包含分类名与文章数

#### Scenario: 分类列表可辨认

- **WHEN** 访客访问分类总览页
- **THEN** 每个分类项同时显示分类名、文章数与指向该分类页的链接

### Requirement: 关于页成员卡与友链卡片

系统 SHALL 在独立页面命中配置的 slug 时渲染对应的卡片网格：命中 `member_page_slug`（默认 `about`）渲染研究所成员卡网格，命中 `friends_page_slug`（默认 `friends`）渲染友链卡片网格，正文仍完整渲染。

#### Scenario: 关于页

- **WHEN** 访客访问 slug 等于 `member_page_slug` 的独立页面
- **THEN** 正文上方出现 `ul.sg-member-grid`，且页面同时包含正文内容

#### Scenario: 友链页

- **WHEN** 访客访问 slug 等于 `friends_page_slug` 的独立页面
- **THEN** 正文上方出现 `ul.sg-friend-grid`，且页面同时包含正文内容

#### Scenario: 普通页面不受影响

- **WHEN** 独立页面的 slug 不命中任何设置项
- **THEN** 页面只渲染 CRT 容器与正文，不出现成员卡或友链网格

### Requirement: 错误页 CRT 外壳

系统 SHALL 让 404 与其它错误页使用与正文同构的 CRT 错误终端，并保留「未找到该世界线」的文案。

#### Scenario: 未知路径

- **WHEN** 访客请求不存在的路径并带上 `Accept: text/html`
- **THEN** 响应状态为 404，页面包含 `section.sg-error` 终端外壳与「未找到该世界线」文案

### Requirement: 带数据的端到端预览验证

系统 SHALL 提供可重复执行的预览验证：自动创建验证用分类、文章与独立页面，然后断言页面级结构；重复执行不得产生重复数据。

#### Scenario: 首次执行

- **WHEN** 在全新实例上运行预览验证
- **THEN** 脚本创建 3 个分类、3 篇文章、关于页与友链页，激活主题后断言文章详情、归档、分类页、关于页、友链页的结构，全部通过时退出码为 0

#### Scenario: 重复执行

- **WHEN** 在同一实例上再次运行预览验证
- **THEN** 脚本跳过已存在的资源，不产生重复分类/文章/页面，断言仍然全部通过

#### Scenario: 造数据失败可诊断

- **WHEN** 某个造数据请求返回非 2xx
- **THEN** 脚本打印失败的端点、状态码与响应片段，并以非零码退出，不静默跳过
