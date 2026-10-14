# deployment-baseline

## Purpose

定义博客运行底座的持久行为：一套编排定义同时服务本地预览与线上部署，数据落在宿主机可备份目录，运行参数由环境变量注入，数据库与附件每日产出可恢复的备份，线上通过 HTTPS 域名对外提供服务。

## Requirements

### Requirement: 一条命令起停站点与数据库

系统 SHALL 提供单一编排定义，用一条命令同时启动 Halo 与 PostgreSQL，并在站点可服务之前保持依赖顺序。

#### Scenario: 首次本地启动

- **WHEN** 执行 `docker compose -f deploy/docker-compose.yml up -d`
- **THEN** PostgreSQL 容器先通过自身的健康检查，随后 Halo 容器启动
- **AND** `http://localhost:8090/actuator/health/readiness` 在容器健康检查周期内返回成功

#### Scenario: 停止后清理容器

- **WHEN** 执行 `docker compose -f deploy/docker-compose.yml down`
- **THEN** 两个容器被移除
- **AND** `deploy/data/` 下的数据目录保持存在

### Requirement: 数据在容器重建后仍然保留

系统 SHALL 把数据库文件与 Halo 工作目录挂载到宿主机目录，使容器重建不影响站点数据。

#### Scenario: 重建容器后仍可访问既有内容

- **WHEN** 站点已初始化并创建过内容，随后执行 `docker compose down` 与 `docker compose up -d`
- **THEN** 初始化状态与既有内容仍然存在
- **AND** 宿主机 `deploy/data/halo2` 与 `deploy/data/db` 中能看到对应数据文件

### Requirement: 运行参数通过环境变量注入

系统 SHALL 从环境变量读取域名、外部访问地址、数据库凭据、镜像版本与 JVM 参数，不在编排定义中写死任何环境相关的值。

#### Scenario: 用示例变量文件做静态校验

- **WHEN** 执行 `bash deploy/verify/static-check.sh --vars`
- **THEN** 校验通过，且渲染后的配置中不包含未替换的 `${` 片段

#### Scenario: 更换域名不需要改编排定义

- **WHEN** 修改 `.env` 中的域名后重新渲染配置
- **THEN** 外部访问地址与反向代理目标域名同步变化
- **AND** 编排定义文件本身不需要改动

### Requirement: 每日备份产出可恢复的数据库转储

系统 SHALL 提供备份脚本，在一次执行中同时导出数据库转储与附件目录，并按保留期清理过期产物。

#### Scenario: 生成一次备份

- **WHEN** 在容器运行状态下执行 `bash deploy/backup/backup.sh`
- **THEN** 输出目录中出现带日期标识的数据库转储与附件归档
- **AND** 转储可被 `pg_restore --list` 读取

#### Scenario: 清理超出保留期的产物

- **WHEN** 输出目录中存在日期早于保留天数的备份文件
- **THEN** 这些文件在本次执行的清理阶段被删除
- **AND** 保留期内的备份不受影响

### Requirement: 线上通过 HTTPS 域名对外提供服务

系统 SHALL 通过反向代理以 HTTPS 对外服务，并按域名自动申请与续期证书。

#### Scenario: 生产叠加层被渲染

- **WHEN** 执行 `docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.prod.yml --env-file deploy/.env.example config -q`
- **THEN** 渲染成功，反向代理服务监听 80 与 443
- **AND** Halo 的外部访问地址指向 `https://` 开头的域名

#### Scenario: 反向代理配置语法正确

- **WHEN** 用 Caddy 自身校验 `deploy/caddy/Caddyfile`
- **THEN** 校验通过，不产生配置语法错误
