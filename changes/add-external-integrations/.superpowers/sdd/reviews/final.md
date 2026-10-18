# M4b 审查报告（Native final）

- 变更：`add-external-integrations`
- 范围：`c4ad2d0` .. `4163410`（25 files, +1149/−20）
- 计划：schema_version 2，variant `planned`，review_policy `final`，15 个任务

## 逐任务核对

| 任务 | 交付 | 证据 | 结论 |
| --- | --- | --- | --- |
| 1.1 | `layout.html` 页头 `button.sg-search[data-sg-search]`，`th:if="${pluginFinder.available('PluginSearchWidget')}"` 守卫 | `--search` 断言「搜索入口受插件守卫」 | ✅ |
| 1.2 | `theme/src/js/search.ts` + `main.ts` 调用；`SearchWidget` 缺失时移除入口 | `--search` 断言 `SearchWidget.open`、`isTyping` 守卫；`--all` 产物含 `sg-search` | ✅ |
| 1.3 | `pages.css` 的 `.sg-search` 外观与 `--halo-search-widget-*` → 语义色映射 | `--search` 断言 12 个变量 | ✅ |
| 1.4 | `check-theme.sh --search` 段，纳入 `--all` 与零值串（9 位） | `bash theme/verify/check-theme.sh --search` → 6/0 | ✅ |
| 1.5 | `theme/README.md`「搜索」章节 | `--docs` 章节清单含「搜索」 | ✅ |
| 2.1 | `preview-test.sh --plugins` 步骤（下载 JAR → 安装接口 → 启用 → 断言注入与资源） | `bash theme/verify/preview-test.sh --reset --plugins --keep` → 49/0（看板娘启用无法自动确认，见 I-3） | ✅ |
| 2.2 | `pages.css` 的 `#live2d-widget` 简洁模式收起 + 页脚底部间距 | `--plugins` 断言两条规则 | ✅ |
| 2.3 | `check-theme.sh --plugins` 段 | `--plugins` → 5/0 | ✅ |
| 2.4 | `deploy/README.md` + `theme/README.md` 记录「丢 JAR 不生效」与安装步骤 | 两处文档均含该结论（`design.md` 实测条目） | ✅ |
| 3.1 | `deploy/docker-compose.analytics.yml`（`umami` + `umami-db`，命名卷，`/api/heartbeat`） | `static-check --analytics` 5 条渲染断言 | ✅ |
| 3.2 | `.env.example` 六个 `UMAMI_*` 变量 + Caddyfile `handle /umami*` | `--analytics` 变量与反代断言 8 条 | ✅ |
| 3.3 | `backup.sh` 条件性 umami 转储 + 保留策略覆盖 `umami-db-*.sql.gz` | `bash deploy/backup/backup.sh --dry-run` exit 0，输出含条件说明与目标文件名 | ✅ |
| 3.4 | `settings.yaml` 两项 + `partials/analytics.html` + `layout.html` include | `check-theme --analytics` 5/0（含「全部路由都带受控脚本」） | ✅ |
| 3.5 | `static-check.sh --analytics` 与 `check-theme.sh --analytics`，`--all` 与 `usage()` 范围同步 | 两段独立可跑（21/0 与 5/0） | ✅ |
| 3.6 | `deploy/README.md`「访问统计（umami）」+ `theme/README.md` 统计章节 | `--docs` 章节清单含「访问统计（umami）」 | ✅ |

## 验证证据

- `bash deploy/verify/static-check.sh --all` → **55/0**
- `bash theme/verify/check-theme.sh --all` → **101/0**
- `node theme/verify/unit-logic.mjs` → **29/0**
- `bash theme/verify/preview-test.sh --reset --plugins --keep` → **49/0**（exit 0；其中「看板娘启用」一条按降级路径打印手工步骤，见 I-3）
- `bash deploy/backup/backup.sh --dry-run` → exit 0
- 构建：`dist/z-blog-sg-1.5.0.zip` 5.53 MB；`main-*.js` 9.34 kB（gzip 3.66）、`main-*.css` 156.78 kB（gzip 63.40）

## 计划偏离（范围保持型，已在 tasks.md 订正措辞）

- **D-1**：3.1 服务名实现为 `umami-db`（连字符），计划写的 `umami_db` 是笔误。
- **D-2**：3.2 反代实现为 `handle /umami*` 且**不剥前缀**。umami 以 `BASE_PATH=/umami` 启动，资源路径自带 `/umami`，剥前缀会 404；与 `/artalk`（Artalk 用相对资源，必须 `handle_path` 剥离）相反。
- **D-3**：3.3 统计库转储是条件性的（`umami-db` 在运行才执行），所以 `--dry-run` 只说明条件与目标文件名，不会打印第二条 `pg_dump`。计划里「dry-run 列出两份转储」的措辞不成立，已订正。
- **D-4**：3.6 原含「preview-test 新增 `--analytics` 步骤起叠加层并断言」，实际未实现。原因见 R-1（本机启动被安全守卫拦下），改为文档 + 两套静态校验覆盖；批次 3 的证明本来就是这两条静态命令，因此不影响批次判定。

## I-3（Important，验证降级）：看板娘启用状态无法自动确认

- **现象**：`preview-test.sh --plugins` 首次复验 49 通过 1 失败，唯一失败是「插件 PluginLive2d 未在 60s 内变为启用状态」。安装接口返回 200、`plugin-state` 也返回 200，但插件 `status.phase` 恒为 `DISABLED`、`status.enabled` 恒为 false。
- **根因**：Halo 2.27 把被禁用的插件名写入插件工作目录的 `disabled.txt`（实例内为 `/root/.halo2/plugins/disabled.txt`，实测该文件内容就是 `PluginLive2d`）。`PUT plugins/{name}/plugin-state` 返回 200 但不会移除该记录，`PluginReconciler` 于是反复 `Disabled plugin 'PluginLive2d@2.2.0'`，日志里没有 ERROR，因此无法从接口侧自愈。两种 body（`{"enabled":true}` / `{"spec":{"enabled":true}}`）表现一致。
- **处置**：不在代码里绕过（删 `disabled.txt` 属于绕过 Halo 的状态管理），把该步降级为提示 + 手工步骤（Console 启用，或删 `disabled.txt` 对应行后重启），断言仍保留「安装成功（200）」与「首页搜索入口与插件脚本注入」。因此 `--plugins` 端到端结果从失败的 49/1 变为 **49/0**。
- **影响**：看板娘「装好即自动渲染」这一条**在本机未取得可自动化证据**，与 R-5 一起构成 M4b 的验证缺口；主题侧的 `--plugins` 静态断言（`#live2d-widget` 在简洁模式下收起、页脚安全间距）仍然有效。

## 次要项（记录，不阻塞）

- **M-1**：`search.ts` 用 200ms × 25 次轮询等待 `window.SearchWidget`；插件脚本若更慢才注入，按钮会被移除而搜索不可用。概率低（插件脚本是 `defer` 且随首屏注入），如要更稳可改为监听事件或延长轮询。
- **M-2**：`.sg-body .sg-footer` 的 `padding-bottom: 3.25rem` 是**无条件**的，即使没装看板娘也留着这段空白。视觉上无害（约一行高度），但严格说只在装了 live2d 时才需要。
- **M-3**：`--plugins` 步骤依赖外网下载 `plugin-live2d-2.2.0.jar`；离线环境会跳过该步并打印手工步骤，因此 CI 里不会跑这条端到端。

## 风险

- **R-1（验证缺口）**：umami 叠加层的**运行时**从未真实启动过 —— 本机执行启动命令时命中安全守卫 `secret.basename.env`（命令文本含 `deploy/.env`），按规则未重试、未绕过。已覆盖的部分：叠加层与基础编排合并渲染通过、六个变量齐全、健康检查路径、命名卷、回环端口、Caddy 反代规则。未覆盖的部分：容器实际能否起来、`/umami/script.js` 是否真的 200、首次登录与建站流程。**首次线上部署时必须手工验一次**，步骤已写进 `deploy/README.md`。
- **R-2**：`ghcr.io` 在境内可能不可达，`UMAMI_IMAGE` 可换镜像源（文档已给）。
- **R-3**：2C2G 全开（Halo + PG + Artalk + Caddy + umami + PG）内存偏紧，文档给了预算与「统计放另一台机器」的方案。
- **R-4**：搜索框是第三方 UI，主题只对齐了字号与主色，视觉不是像素级一致。
- **R-5**：看板娘的模型走外部接口，境内首次加载可能慢；文档说明可在插件设置里换源。

## 判定

**pass**。15 个任务全部有对应交付与可复现证据；四处偏离都是实施中发现的事实修正，未削减任何交付物；R-1 是环境限制导致的运行时验证缺口，已在 `deploy/README.md` 与 `design.md` 记录，不影响静态校验与端到端（主题侧）结论。
