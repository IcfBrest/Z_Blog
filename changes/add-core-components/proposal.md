# 变更提案

## 背景（Why）

M1 交付的主题只有样式骨架：页面能渲染，但没有任何《命运石之门》的辨识度——没有辉光管数字、没有 CRT 扫描线、没有 α/β 世界线切换，也没有一键关闭动效的简洁模式。需求文档 M2 明确要求这四项核心组件，DR-3 要求动效可整体关闭、NFR-1 要求动画只用 `transform`/`opacity` 保持 60fps、NFR-4 要求这些能力通过主题设置项可配置。缺少这些组件，M3 的页面铺开（首页布局、文章详情 CRT 容器、归档时间轴）就没有可复用的积木，动效逻辑只能散落到每个模板里重复实现。

## 变更内容（What Changes）

- **世界线双主题**：`<html>` 上增加 `data-worldline="alpha|beta"`，在 token 语义层重映射强调色；导航栏提供切换控件，选择记忆在 `localStorage`，无 JS 时按设置项默认值渲染。
- **简洁模式**：`<html>` 上增加 `data-motion="on|off"`，一键关闭扫描线、辉光、打字机、粒子、滚动数字等全部动效；`prefers-reduced-motion: reduce` 时自动进入；状态记忆在 `localStorage`。
- **Divergence Meter**：辉光管样式的数字组件（小数点与 `%` 按位拆分），支持 `attractor`（固定 `1.048596`）与 `live`（站点真实文章数）两种数据源，点击/悬停切换并带滚动数字动画；放在首页 hero 区。
- **CRT 动效**：全屏扫描线伪元素、荧光绿与辉光橙发光、`El Psy Kongroo.` 打字机、Canvas 粒子星空、鼠标跟随辉光（移动端关闭）。
- **主题设置项**：新增世界线默认值、简洁模式默认值、Divergence Meter 数据源、粒子开关、鼠标辉光开关五项。
- **可测试的运行时逻辑**：世界线与动效的决策逻辑抽成纯函数模块，用 `node` 直接单测，不引入浏览器自动化。

## 范围（Scope）

### 范围内（In Scope）

- `theme/src/css/tokens.css`、`theme/src/css/main.css`：世界线映射、动效规则、简洁模式禁用规则
- `theme/src/partials/layout.html`：属性、切换控件、扫描线层、粒子画布容器、首屏 boot 脚本
- `theme/src/index.html`：hero 区改为 Divergence Meter + 打字机文本
- `theme/src/js/`：`logic.mjs`（纯函数）与各动效模块
- `theme/settings.yaml`、`theme/theme.yaml`（版本 1.0.0 → 1.1.0）
- `theme/verify/check-theme.sh` 新增 `--components`、`theme/verify/unit-logic.mjs`、`theme/verify/preview-test.sh` 的 DOM 断言
- `theme/README.md` 的组件与开关说明

### 范围外（Out of Scope）

- M3 的页面铺开：首页完整布局、文章详情 CRT 容器与 D-Mail 元信息、归档世界线时间轴、D-Mail 密码解锁
- M4 的集成：umami 真实访客数、评论数、搜索、看板娘
- 浏览器视觉回归自动化（Playwright 等），视觉仍由人工走查清单覆盖
- DR-1 配色 token 数值的调整（已定稿）

## 影响与验证

**影响区域**

- 已发布基线 `specs/theme-foundation/spec.md` 不变；新能力写入 `specs/theme-interaction/spec.md`
- 主题包体积增加（Canvas 粒子与动效代码，目标 JS/CSS 增量 < 25 KB）
- 所有页面多出扫描线与粒子两个固定层，渲染路径变长
- `theme.yaml` 版本升到 1.1.0，已安装的实例需要重新上传主题包才生效

**完成证明**

- `bash theme/verify/check-theme.sh --all`（含新增 `--components`）全部通过
- `node theme/verify/unit-logic.mjs` 通过：世界线解析、动效模式解析、数字拆分、补零
- `bash theme/verify/preview-test.sh` 端到端通过，首页含 `data-worldline`、`sg-divergence`、`sg-scanline` 与动效开关控件
- `bash deploy/verify/static-check.sh --all` 仍通过（部署底座未被破坏）
