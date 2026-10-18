# 规格：评论接入与 SEO 元信息

## Purpose

为一篇已经能读的博客补上"能讨论、能分享、能被订阅与抓取"的三件事：评论区由自托管 Artalk 提供并被主题改造成 RINE 聊天气泡；每页输出 canonical 与分享卡片元信息；RSS / sitemap / robots 在主题侧可达。评论数据同时纳入既有每日备份。

## ADDED Requirements

### Requirement: 评论服务随站点一起起停

站点编排 SHALL 包含一个 Artalk 服务，使 `docker compose -f deploy/docker-compose.yml up -d` 之后评论后端与 Halo 一并就绪，且评论数据落在 `deploy/data/artalk/`。

#### Scenario: 本地起站后评论后端可用

- **WHEN** 在仓库根执行 `docker compose -f deploy/docker-compose.yml up -d`
- **THEN** `artalk` 容器的健康检查为 healthy，`http://127.0.0.1:23366/api/v2/conf` 返回 200，且 `deploy/data/artalk/` 下出现 SQLite 数据库文件

#### Scenario: 生产叠加层把评论后端收进同一域名

- **WHEN** 用 `docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d` 起站
- **THEN** Caddyfile 含 `/artalk/*` 到 `artalk:23366` 的反代规则，且 `caddy validate` 通过

#### Scenario: 变量有模板兜底

- **WHEN** 仓库里没有 `deploy/.env`
- **THEN** 编排仍能渲染通过，且 `deploy/.env.example` 覆盖 Artalk 相关的全部变量

### Requirement: 评论渲染可切换提供方

主题 SHALL 提供一个设置项选择评论提供方：`artalk` 时渲染 Artalk 容器与脚本，`halo` 时回退到内置 `<halo:comment>`。

#### Scenario: 默认使用 Artalk

- **WHEN** 访问任意一篇文章的详情页且未改过设置
- **THEN** 页面包含 Artalk 的评论挂载容器、`Artalk.js` 与 `Artalk.css` 引用，以及含站点名与服务地址的初始化脚本

#### Scenario: 回退到 Halo 内置评论

- **WHEN** 把评论提供方设置为 `halo`
- **THEN** 页面不再引用 Artalk 的脚本与样式，改回输出 `<halo:comment>` 占位

#### Scenario: 评论区使用 RINE 聊天气泡

- **WHEN** 主题样式表被打包
- **THEN** 产物中出现针对 `.atk-comment` / `.atk-comment-wrap` / `.atk-avatar` / `.atk-content` 的规则，其中站长评论有独立高亮，且气泡在窄屏下退化为单列

### Requirement: 评论数据进入每日备份

备份脚本 SHALL 在打包附件的同时打包 Artalk 的数据目录，使恢复流程能同时还原文章与评论。

#### Scenario: 演练时列出两份产物

- **WHEN** 执行 `bash deploy/backup/backup.sh --dry-run`
- **THEN** 脚本说明里同时出现 Halo 附件目录与 Artalk 数据目录，且保留策略对两者生效

### Requirement: 每页输出分享元信息

主题 SHALL 在每一类页面的 `<head>` 输出 canonical 与 Open Graph / Twitter Card 元信息，描述在文章摘要缺失时回退到站点描述。

#### Scenario: 首页与文章页都有卡片信息

- **WHEN** 请求 `/` 与任意一篇文章
- **THEN** 响应包含 `rel="canonical"`、`og:title`、`og:description`、`og:url`、`og:type` 与 `twitter:card`，且 `og:url` 指向该页自身

#### Scenario: 描述有回退

- **WHEN** 某篇文章没有摘要
- **THEN** `og:description` 取站点描述而不是空字符串

### Requirement: 订阅与索引入口可达

站点 SHALL 让读者与爬虫能发现 RSS 与 sitemap：页脚提供入口，三个端点均可访问。

#### Scenario: 页脚有订阅入口

- **WHEN** 打开任意页面
- **THEN** 页脚包含指向 `/rss.xml` 的链接与 `<link rel="alternate" type="application/rss+xml">`

#### Scenario: 三个端点均可用

- **WHEN** 请求 `/rss.xml`、`/sitemap.xml`、`/robots.txt`
- **THEN** 三者均返回 200，且 `/rss.xml` 的内容类型是 RSS
