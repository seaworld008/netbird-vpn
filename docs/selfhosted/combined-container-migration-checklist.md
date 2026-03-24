# 合并容器迁移核对清单（pre-v0.65.0 -> 新部署）

> 适用对象：当前使用旧 5 容器架构（dashboard、signal、relay、management、coturn）并计划迁移到 `netbird-server` 合并架构的场景。

## 适用前提

- 使用内置 IdP（Dex）
- 运行方式为旧版 `docker-compose` 结构
- 能提供一个短维护窗口（迁移后端点会重连）
- 已提前核对网关节点和 DNS 接入策略

## 一、迁移前准备

1. 备份目录与环境变量
2. 导出数据库/卷状态（快照）
3. 标记现网关键资源：
   - 公网域名
   - 管理端口与证书
   - 白名单 IP 列表
   - 重要策略与组
4. 对关键节点拍照（`docker compose ps` + 版本记录）

## 二、官方迁移脚本（官方推荐）

- 官方迁移页： https://docs.netbird.io/selfhosted/migration/combined-container
- 脚本目标：将旧配置转为 `config.yaml` + 合并部署脚本

关键提醒：

- 外部 IdP（Auth0/Keycloak/Zitadel 等）用户的旧部署，不建议直接跑迁移脚本；请按官方建议保留旧架构或先统一到支持路径。
- 如果你只做评估，可以先在测试环境演练一遍，再决定正式执行。

## 三、迁移后核对

- 登录 Dashboard 与客户端
- 检查服务是否全部可达（至少一台办公网关 + 一台资源节点）
- 检查路由/策略是否按 `docs/cases/*` 验收
- 检查 Turn/Relay/Signal 是否仍可通过新架构完成中继与 NAT 穿透

## 四、回滚建议

- 记录脚本生成的 `rollback.sh` 或备份目录
- 发现不可逆问题时按回滚脚本恢复原配置（优先保证证书与数据库一致性）

> 这份清单用于运维推进决策，不替代官方迁移脚本。正式迁移前，仍以官方迁移页与 release note 为准。
