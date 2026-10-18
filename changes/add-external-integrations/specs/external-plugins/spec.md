# external-plugins 规格

## Purpose

定义主题与 Halo 插件、以及自托管统计服务之间的接入边界：什么条件下出现入口、什么条件下隐藏、脚本什么时候才输出，以及部署侧必须提供哪些可变与服务。

## ADDED Requirements

### Requirement: 搜索入口按插件可用性渲染

主题 SHALL 仅在 `pluginFinder.available('PluginSearchWidget')` 为真时渲染页头搜索按钮，并在点击时调用插件提供的 `SearchWidget.open()`；插件不可用时 SHALL 不输出任何搜索相关标记。

#### Scenario: 搜索插件已启用

- **WHEN** 访客打开任意路由且 `PluginSearchWidget` 处于启用状态
- **THEN** 页头出现搜索按钮，点击后唤起插件自带搜索框，且页面已加载 `search-widget.iife.js`

#### Scenario: 搜索插件未启用

- **WHEN** 站点未安装或未启用 `PluginSearchWidget`
- **THEN** 页头不出现搜索按钮，页面不含 `data-sg-search` 标记

### Requirement: 简洁模式收起看板娘

主题 SHALL 在简洁模式生效时（`:root[data-motion="off"]`）隐藏看板娘根节点 `#live2d-widget`，并保证页脚内容不被固定定位的装饰遮挡。

#### Scenario: 开启简洁模式

- **WHEN** 访客开启简洁模式，页面根节点带上 `data-motion="off"`
- **THEN** `#live2d-widget` 不再显示，页脚链接仍可点击

#### Scenario: 关闭简洁模式

- **WHEN** 访客关闭简洁模式
- **THEN** 看板娘按其自身配置恢复显示，主题不额外干预其位置与行为

### Requirement: 统计脚本按站点 ID 输出

主题 SHALL 仅在 `umami_website_id` 非空时输出统计脚本标签，脚本地址取自 `umami_script_url`（默认同源 `/umami/script.js`），并把站点 ID 写到 `data-website-id`；未配置时 SHALL 不产生任何统计请求。

#### Scenario: 已配置站点 ID

- **WHEN** 站长在主题设置里填入 website-id
- **THEN** 每个页面输出一个带 `data-website-id` 的 defer 脚本标签，且不重复输出

#### Scenario: 未配置站点 ID

- **WHEN** website-id 为空
- **THEN** 页面不输出统计脚本，也不请求 `/umami/*`

### Requirement: 统计服务以独立叠加层提供

部署编排 SHALL 把 umami 与其数据库放在独立的可选叠加层中，数据库数据 SHALL 落在命名卷上，且 SHALL 通过反向代理提供同源脚本地址。

#### Scenario: 启用统计叠加层

- **WHEN** 运维在基础编排之上叠加 analytics 编排并启动
- **THEN** `umami` 与 `umami_db` 正常启动，`/umami/script.js` 可经反向代理取到

#### Scenario: 不启用统计叠加层

- **WHEN** 只启动基础编排
- **THEN** 站点其余功能不受影响，页面不产生统计请求

### Requirement: 插件安装必须经安装接口

文档与验证脚本 SHALL 只通过 Halo 的插件安装接口（或 Console 等价操作）安装插件，并且 SHALL 明确记录「仅把 JAR 放入 plugins 目录不会生效」这一约束。

#### Scenario: 按文档安装看板娘

- **WHEN** 站长按文档执行安装步骤
- **THEN** 页面注入 `plugin-live2d-config`，其静态资源返回 200

#### Scenario: 只放 JAR 文件

- **WHEN** 只把 JAR 放入 `deploy/data/halo2/plugins/` 并重启容器
- **THEN** 该插件的静态资源仍为 404，文档已提前说明这一结果
