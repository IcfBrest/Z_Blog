# 实现审查报告（final，Native 策略）

- 变更：`add-theme-skeleton`（M1 主题骨架）
- 审查范围：`44119dbc0cf6912f2051e535415301a4ae61f780..ec722256b8ad5d08267fa31ae113277704f2524a`（35 个文件、+3721 行）
- 执行计划：revision 2，单个 wave `implementation`（1.1–3.1），`review_policy: final`
- 审查方式：由当前执行者本地审查完整 diff（Native `final` 不派子代理）

## 一、交付物是否覆盖任务

| 任务 | 交付物 | 结论 |
|---|---|---|
| 1.1 工程初始化 | `theme/package.json`、`vite.config.ts`、`theme.yaml`、`settings.yaml`、`.gitignore` | 齐备；`pnpm build` 产出 `dist/z-blog-sg-1.0.0.zip` |
| 1.2 配色 token | `theme/src/css/tokens.css` | DR-1 八个 token + 语义层；构建 CSS 内可见，其余样式无色值字面量 |
| 1.3 自托管字体 | `theme/src/css/fonts.css` | `@fontsource` 三个字族；产物 105 woff + 104 woff2，无外部字体 URL，`font-display: swap` |
| 1.4 统一骨架 | `theme/src/partials/layout.html` + `src/css/main.css` | slot 占位骨架；三档断点与窄屏折叠导航 |
| 1.5 路由模板 | `src/` 下 10 个模板（含 `error/error.html`） | 构建产物齐全，均套用同一骨架 |
| 1.6 静态校验 | `theme/verify/check-theme.sh` | 断言对象是构建产物；`--all` 25 项通过 |
| 1.7 开发说明 | `theme/README.md` | 6 个必需章节齐备 |
| 2.1 本地预览验证 | `theme/verify/preview-test.sh` | 端到端 16/16 通过（含自动初始化、安装、激活、六类路由断言） |
| 2.2 人工走查清单 | `theme/README.md`「人工走查清单」10 行表 | 覆盖导航/页脚/对比度/横向溢出/字体 |
| 3.1 CI | `.github/workflows/ci.yml` | 两个 job：部署底座静态校验 + 主题构建与静态校验 |

## 二、正确性与健壮性核查

1. **主题渲染链路**：`preview-test.sh` 在全新实例上跑通「初始化 → RSA 登录 → 安装 → 激活 → 6 条路由」，实测每页均含 `sg-header` 与 DR-5 页脚声明，404 由主题错误页渲染（3516 字节，非 JSON）。
2. **幂等性**：第二次运行跳过初始化（302 判定），安装返回 400「已存在」被识别为非致命并继续激活，整体仍 15/15 通过。
3. **脚本可移植性**：`set -uo pipefail` 且不用 `-e`，每条断言显式控制退出码；`bash -n` 语法通过；路径保持 POSIX（不依赖 PowerShell）。
4. **破坏性操作**：`--purge` 先确认 `REPO_ROOT` 存在 `deploy/` 再 `rm -rf`，避免变量异常时误删。
5. **CI 可执行性**：主题 job 使用已提交的 `theme/pnpm-lock.yaml`（`pnpm install --frozen-lockfile`），`defaults.run.working-directory: theme` 与 `cache-dependency-path` 一致。
6. **职责边界**：`preview-test.sh` 只用于本地（需要 Docker 与完整起站），CI 只跑静态校验与构建——这是有意的取舍，已写进 README。

## 三、发现的问题

- **M-1（已修）** `--purge` 分支的 `rm -rf "$REPO_ROOT/deploy/data"` 缺少路径守卫。修复：删除前断言 `REPO_ROOT` 非空且 `deploy/` 存在，否则判失败退出。
- **M-2（已修）** 登录失败时只报 HTTP 与 Location，未提示「实例可能已用别的密码初始化」。修复：补一行处置提示（`HALO_ADMIN_PASS` 或 `--purge`）。
- **M-3（记录，不改）** 预览脚本内置默认口令 `SgPreviewPass1` 并写进仓库。这是本地一次性预览实例，且 README 已说明可用环境变量覆盖；线上凭据走 `deploy/.env`，两者不共用。
- **M-4（记录，不改）** CI 未运行 `preview-test.sh`。它需要 Docker、镜像拉取与数分钟起站时间，放在每次 push 上性价比低；渲染回归靠本地执行 + 人工走查。

以上均为 Minor，无 Critical/Important。

## 四、未覆盖的验证（剩余风险）

- **R-1** 真实浏览器视觉未自动化：断点、吸顶页头、焦点环、对比度只能按 README 的 10 行走查清单人工确认。当前只能保证 CSS 规则与 DOM 结构正确。
- **R-2** `.github/workflows/ci.yml` 未在 GitHub Actions 上真实跑过；本地用与 CI 完全相同的命令（`static-check.sh --all`、`check-theme.sh`）验证通过，但 runner 环境差异（pnpm 11、Node 22、Docker Compose 版本）尚未实测。
- **R-3** 主题仅覆盖空站点的路由渲染；有内容时的分页、置顶、分类树层级等形态尚未造数据验证（属 M2/M3 范围）。

## 五、判定

**pass**。交付物与任务清单一致，渲染链路端到端验证通过，两个 Minor 已在同一范围内修复并复验；R-1/R-2/R-3 作为已知缺口带入后续里程碑。
