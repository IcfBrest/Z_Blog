# 实现任务

## 交付与证明

| 批次 | 交付结果 | 依赖 | 证明 |
|---|---|---|---|
| 1 | 仓库受版本控制，Halo + PostgreSQL 可在本地一键起停且数据落盘 | 无 | `bash deploy/verify/static-check.sh` |
| 2 | 生产叠加层与运维能力就位（反向代理、备份、手册） | 批次 1 | `bash deploy/verify/static-check.sh --prod` |

## 任务

- [ ] **1.1 建立版本控制与忽略规则**：新建 `.gitignore`（排除 `deploy/data/`、`.env`、`deploy/backup/out/` 与 `*.log`）与 `.gitattributes`（`*.sh` 与 `Caddyfile` 强制 `eol=lf`，否则 Windows 检出后脚本带 CRLF，在 Linux 服务器上会以 `\r: command not found` 失败）；证明：`bash deploy/verify/static-check.sh --eol`。
- [ ] **1.2 编写本地编排定义**：新建 `deploy/docker-compose.yml`，声明 `halodb`（`postgres:15`）与 `halo`（`registry.fit2cloud.com/halo/halo:2.27.0`）两个服务、`depends_on` 的 `service_healthy` 条件、`/actuator/health/readiness` 健康检查、`./data/halo2` 与 `./data/db` 绑定挂载；完成后只读宿主机目录即可看到站点数据；证明：`docker compose -f deploy/docker-compose.yml config -q`。
- [ ] **1.3 外置运行参数**：新建 `deploy/.env.example`，集中域名、外部访问地址、数据库名/用户/密码、镜像版本与 `JVM_OPTS`，并在编排定义中以 `${VAR}` 引用；完成后同一份编排可通过换 `.env` 切换环境；证明：`bash deploy/verify/static-check.sh --vars`。
- [ ] **1.4 编写验证入口**：新建 `deploy/verify/static-check.sh`（校验编排语法与变量替换，`--prod` 覆盖生产叠加层，`--vars` 检查未替换变量）与 `deploy/verify/boot-test.sh`（起站、轮询健康接口、重建容器后校验数据留存、结束时清理）；完成后任何人 clone 仓库都能自行复现验证；证明：`bash deploy/verify/static-check.sh`。
- [ ] **1.5 记录本地起停手册**：新建 `deploy/README.md`，给出首次启动、进入 Console 初始化、查看日志、停止与数据目录位置；证明：`bash deploy/verify/static-check.sh --docs`。
- [ ] **2.1 追加生产叠加层**：新建 `deploy/docker-compose.prod.yml`，以 profile 方式加入 `caddy` 服务、暴露 80/443、把外部访问地址切到 `https://${DOMAIN}`；完成后线上与本地共用基础定义，差异只在叠加层；证明：`docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.prod.yml --env-file deploy/.env.example config -q`。
- [ ] **2.2 编写反向代理配置**：新建 `deploy/caddy/Caddyfile`，按 `{$DOMAIN}` 自动申请证书、开启 gzip 并反代到 `halo:8090`；完成后更换域名只需改 `.env`；证明：`docker run --rm -e DOMAIN=blog.example.com -v "$PWD/deploy/caddy:/etc/caddy:ro" caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`。
- [ ] **2.3 编写备份脚本**：新建 `deploy/backup/backup.sh`，执行 `pg_dump` 与附件目录打包、按 30 天保留策略清理旧产物、预留对象存储上传钩子；完成后数据库与附件都在同一次备份中；证明：`bash deploy/backup/backup.sh --dry-run`。
- [ ] **2.4 补齐部署与恢复手册**：在 `deploy/README.md` 追加服务器部署、域名与备案清单、备份恢复演练、故障排查四节；证明：`bash deploy/verify/static-check.sh --docs --prod`。

## 实施备注

- 线上与本地共用批次 1 的编排定义，差异全部收敛到 `.env` 与 `docker-compose.prod.yml`，避免两份配置漂移。
- 镜像版本写在 `.env` 中（`HALO_IMAGE` / `POSTGRES_IMAGE`），升级只需改这一处并重跑 `docker compose up -d`。
- 备份脚本的保留策略按文件名日期前缀计算，因此产物命名格式是脚本的一部分，不要手工改名。
