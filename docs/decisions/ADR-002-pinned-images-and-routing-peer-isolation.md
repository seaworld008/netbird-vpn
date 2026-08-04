# ADR-002: 固定生产镜像版本并隔离 Routing Peer

## Status

Accepted

## Date

2026-08-04

## Context

自建 NetBird 同时包含管理面和数据面。管理面升级会替换 Dashboard、Management、Signal、Relay 等容器；Routing Peer 则直接承载用户到 VPC、K8S 和多云资源的流量。

若生产 Compose 使用漂移标签，同一份配置在不同时间重建可能得到不同镜像。若 Routing Peer 与服务端共享 Compose 项目，服务端升级或清理 orphan 容器可能意外中断业务数据面。Setup Key 长期保留在环境文件中还会扩大凭据泄露风险。

## Decision

1. 所有生产 Compose 镜像使用经过验证的明确版本标签。
2. 官方 `releases/latest` 只用于获取首次部署脚本，不作为容器运行时版本策略。
3. Routing Peer 使用独立 Compose 项目、独立命名卷或明确 bind mount，以及固定客户端镜像。
4. Setup Key 只在首次注册时临时注入，注册成功后从环境和文件中删除。
5. 升级不使用可能跨项目清理容器的操作；核心服务与 Routing Peer 分阶段更新。
6. 每次更新保存 `docker compose config --images` 输出、备份校验和业务验收记录。
7. Routing Peer 的长期身份来自持久化的 `/var/lib/netbird`；不使用永不过期 Setup Key 代替身份目录备份。

## Alternatives Considered

### 所有镜像跟随漂移标签

配置短，但无法保证重建结果，故不采用。

### 服务端和 Routing Peer 放在同一 Compose 项目

文件数量少，但管理面变更会扩大到数据面，故不采用。

### 长期把 Setup Key 写入 `.env`

重建方便，但 Peer 身份已经持久化后无需继续保存注册凭据，故不采用。

## Consequences

- 上游发布新版本后不会自动升级，需要维护者主动核对和变更标签。
- Routing Peer 可以独立升级、回滚和做主备切换。
- 灾备必须同时覆盖管理面数据和 Routing Peer 身份目录。
- 版本清单、备份、验收成为每次升级的必做项。

## Follow-up

- 每月更新 `docs/selfhosted/upstream-version-status.md`。
- 多云环境为每个 VPC/区域维护独立 Routing Peer 项目和资源清单。
- 当官方部署模型变化时，先验证迁移工具对当前身份源和数据库拓扑的支持，再决定是否新增 ADR。
