# M3a 审查报告（final）

- 变更：`add-page-layouts`（M3a 页面铺开）
- 审查范围：`e0fcacabb683b0791a73099d7429ccd495974bbf..7018590f60a737b2e3e2150771639fdc86582962`
- 规模：27 个文件，+1511 / −84（其中 `theme/src/css/pages.css` 519 行、`check-theme.sh` +159、`preview-test.sh` +141）
- 策略：Native `final`（由执行者本地审查完整范围，未派子代理）
- 判定：**pass**

## 逐任务核对

| 任务 | 要求 | 实际 | 证据 |
|---|---|---|---|
| 1.1 | 首页世界线横幅，节点来自分类、上限 5、首节点高亮 | `partials/worldline-banner.html` 内联 SVG，`categoryFinder.listAsTree()` + `stat.index lt 5` + `is-current` | `--pages` 第 1 条；实站首页 4 个节点（含 Halo 自带「默认分类」） |
| 1.2 | 文章详情 CRT 容器 + D-Mail 元信息 | `post.html` 的 `section.sg-terminal`（bar/led/name/stamp + body 局部扫描线）+ `partials/post-meta.html`（时间/发信人/世界线，「未观测」兜底） | `--pages` 第 2、3 条；`/archives/tech-1` 实测 D-Mail 三行 = 2026-01-05 08:00 / 站长 / 技术 |
| 1.3 | 归档改世界线时间轴 + 空状态 | `archives.html` 的 `ol.sg-timeline` → `__year` → `__month` → `__posts`，分页留在时间轴外 | `--pages` 第 4、5 条；`/archives` 实测同时出现 2026 与 2025 |
| 1.4 | 独立页面：终端容器 + 成员卡 + 友链网格，按 slug 区分 | `page.html` 用 `isMember` / `isFriends`（`#strings.endsWith(permalink, '/' + slug)`），互斥渲染 | `--pages` 第 8、9 条；`/about` 有成员卡且无 `class="sg-friend-grid"`，`/friends` 反之 |
| 1.5 | 列表与分类终端化 + 分支徽章 | `post-card.html` 加 `sg-card__marker` 与 `sg-card__branch` 芯片；`categories.html` 用 `sg-branch-list`；`category.html` 内联徽章；`tags.html` 套终端面板 | `--pages` 第 6、7 条；首页 4 张卡片各自带分类芯片 |
| 1.6 | 错误页统一为 CRT 错误终端 | `error/error.html` 改 `section.sg-error.sg-terminal`，保留「未找到该世界线」 | `--pages` 第 10 条；404 实测 6180 字节且含终端外壳 |
| 1.7 | 补三个设置项、升版本、写组件样式 | `settings.yaml` 加 `master_name` / `member_page_slug` / `friends_page_slug`（均默认值）；`theme.yaml` → 1.2.0；新增 `pages.css` 并 import | `--pages` 第 11–13 条；`--tokens` 仍 0 裸色值 |
| 1.8 | `check-theme.sh` 加 `--pages` 并纳入 `--all` | 新增 18 条断言；`--all` 计数串改 7 位 | `--pages` 18/0、`--all` 60/0 |
| 2.1 | 探针确认造数据端点 | 临时 `_probe-content.sh` 实测后删除，结论写进 `design.md` 已知事实与 `theme/README.md` | 探针输出：分类 201、文章 200、页面 200、重复分类 400、普通 `/posts` 500 |
| 2.2 | 预览验证自动造数据（幂等） | `preview-test.sh` 新增 `3b/6` 步骤 + `mk_category` / `mk_post` / `mk_page`（先 GET 后 POST） | `--reset` 首轮 8 个资源全部创建成功 |
| 2.3 | 页面级结构断言 | 新增 `5c/6` 步骤，`detail` 支持期望状态码与 `!needle` 反向断言 | 45/45 通过 |
| 2.4 | 重复执行幂等 | 同一实例二跑：8 条「已存在，跳过」，36/0 | 已留输出 |
| 3.1 | 主题文档补页面结构与造数据说明 | `README.md` 新增「页面结构」（六类页面表 + 改 about/friends 步骤）、「预览验证会造哪些数据」（端点表 + 断言清单）、走查清单 +6 行；`--docs` 章节清单加「页面结构」 | `--docs` 9/0 |
| 3.2 | 复核体积与全量回归 | 体积表换 M3a 实测（js 7.19 kB / css 153.53 kB / zip 5.51 MB）；`deploy` 与 `theme` 两套校验均通过 | `static-check --all` 25/0、`check-theme --all` 60/0 |

## 验证证据

```
bash theme/verify/check-theme.sh --pages      -> 通过 18 项，失败 0 项
bash theme/verify/check-theme.sh --docs       -> 通过  9 项，失败 0 项
bash theme/verify/check-theme.sh --all        -> 通过 60 项，失败 0 项
bash deploy/verify/static-check.sh --all      -> 通过 25 项，失败 0 项
bash theme/verify/preview-test.sh --reset --keep -> 通过 45 项，失败 0 项（exit 0）
bash theme/verify/preview-test.sh --keep      -> 通过 36 项，失败 0 项（8 条「已存在，跳过」）
node theme/verify/unit-logic.mjs              -> 29/0（M2 逻辑未回归）
```

`--reset` 首轮关键读数：首页 200 / 13448 B、归档 8397 B、分类 7848 B、标签 7103 B、作者 9128 B、文章详情 9170 B、关于 8145 B、友链 7878 B、404 6180 B；静态资源 `main-*.js|cSS` 均 200。

## 发现

**无 Critical / 无 Important。**

### Minor（记录不改）

- **M-1 造数据先于装主题**：`preview-test.sh` 的 `3b/6` 在 `4/6` 之前，若装主题失败会留下探针内容。只影响本地预览实例，且 `--reset` 会重建。
- **M-2 静态断言多以源模板为对象**：`--pages` 多数条目 grep 的是 `templates/*.html`，真正“渲染出来对不对”由 `preview-test.sh` 的 `5c/6` 保证。两层分工已写进 README，但阅读断言时容易误以为静态检查覆盖了渲染。
- **M-3 `--pages` 的计数类断言故意放宽**：横幅写「不少于 3」而不是等于分类数，因为 Halo 初始化自带「默认分类」与一篇默认文章，精确等值会长期误报（已写进 design.md 已知事实）。
- **M-4 4xx 断言写法**：`detail` 用「期望状态码列表」而不是要求 200，错误页因此能断言 404 且仍检查外壳，代价是每个调用点都要显式写状态码。

## 剩余风险

| 风险 | 说明 |
|---|---|
| R-1 视觉未自动化 | 终端外壳、时间轴折线、友链卡片只验证了 DOM 与类名，观感仍需按 README 走查清单人眼看 |
| R-2 CI 未实跑 | `.github/workflows/ci.yml` 仍未在 GitHub Actions 上跑过（沿用 M2 的已知限制） |
| R-3 数据形态单一 | 只用 3 篇短文、2 个独立页面验证；长文、代码块、多页归档未覆盖 |
| R-4 窄屏未真机 | 480px 断点只有 CSS 断言，未在真机确认节点收敛与卡片换行 |

## 判定

**pass**。14 个任务逐条落地并有可复现命令；两套校验与端到端预览全绿；`about` / `friends` 两种外壳的互斥关系在被发现是「注释造成的假阳性」后已改用 `class="sg-friend-grid"` 正向断言加固。遗留问题均为记录类 Minor 与需人工确认的视觉风险，不阻塞合并。
