# 变更提案

## 背景（Why）

需求文档把项目拆到 M0–M5，但仓库现在只有《技术方案》《需求文档》和 `CONTEXT.md` 三份文档，没有任何可运行的部署定义：没有容器编排、没有数据库、没有反向代理与备份脚本，也还没有纳入版本控制。这意味着主题开发（M3）无处落地——没有可复现的本地预览环境，服务器买回来也无法在十分钟内起站，后续每一次改动都缺少统一的验证底座。因此先把这块底座做出来，让后面所有变更都建立在它之上。

## 变更内容（What Changes）

- 新增 `deploy/` 目录，承载 Halo 2.27.0 + PostgreSQL 15 的 Compose 编排、反向代理配置、备份脚本与运维手册。
- 新增 `.gitignore`，确保数据目录、`.env` 与备份产物不会进入版本库。
- 新增两条可复现的验证入口：静态校验（不依赖 Docker 守护进程）与启动校验（起站、健康检查、重启后数据留存）。
- 本地开发与线上部署共用同一份编排定义，线上差异通过叠加层追加 Caddy 反向代理与端口暴露。
- 既有三份文档保持原样，不改动内容。

## 范围（Scope）

### 范围内（In Scope）

- Git 仓库初始化与 `.gitignore`。
- `deploy/docker-compose.yml`：`halo` 与 `halodb` 两个服务、健康检查、`service_healthy` 依赖顺序、数据目录绑定挂载、环境变量外置。
- `deploy/.env.example`：域名、外部访问地址、数据库凭据、镜像版本、JVM 参数。
- `deploy/docker-compose.prod.yml`：生产叠加层，追加 Caddy 服务与 80/443 暴露。
- `deploy/caddy/Caddyfile`：按 `{$DOMAIN}` 申请证书、压缩并反代到 `halo:8090`。
- `deploy/backup/backup.sh`：`pg_dump`、附件打包、30 天保留策略、对象存储上传钩子。
- `deploy/README.md`：本地起停、服务器部署、备份恢复、故障排查。
- `deploy/verify/static-check.sh` 与 `deploy/verify/boot-test.sh`。
- `changes/add-halo-deploy-base/specs/deployment-baseline.md`：部署基线的持久行为规格。

### 范围外（Out of Scope）

- 主题（`halo-theme-sg`）开发与任何前端页面：属于 M3。
- Artalk 评论、搜索插件、umami 统计的安装与配置：属于 M4。
- 腾讯云 COS 桶创建、密钥签发与定时任务实际启用：需要账号侧操作，本次只交付脚本与上传钩子。
- 域名购买、DNS 解析、ICP 备案、服务器购买与安全组放行：属于人工事项，本次只给出清单。
- 线上真实部署与 HTTPS 证书签发：需要服务器与域名就位。

## 影响与验证

- **影响区域**：仓库根新增 `deploy/` 与 `.gitignore`；首次引入容器编排与数据库依赖；既有文档不改动。
- **完成证明**：`bash deploy/verify/static-check.sh` 通过（含生产叠加层）；本机 Docker 守护进程可用时，`bash deploy/verify/boot-test.sh` 能起站、`/actuator/health/readiness` 返回可用、容器重建后数据仍在；`bash deploy/backup/backup.sh --dry-run` 能校验参数与保留策略并产出被 `pg_restore --list` 读取过的转储。
