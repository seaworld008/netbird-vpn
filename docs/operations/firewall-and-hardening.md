# 防火墙与安全加固（可直接复用）

## 一、基础端口

```text
TCP 80   (HTTP/ACME)
TCP 443  (HTTPS)
UDP 3478 (STUN)
UDP 443  (HTTP/3，可选，按反向代理配置)
```

## 二、UFW 示例（最小暴露）

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3478/udp
sudo ufw allow 443/udp comment 'Optional HTTP/3'
sudo ufw enable
```

> 生产环境建议再增加来源 IP 白名单：只允许办公网段访问管理/管理 API。

## 三、安全基线建议

- 强制控制台管理员启用双因子
- 对外日志集中采集（控制面、客户端、网关）
- 变更必须走审批流程（尤其是策略变更）
- 对关键脚本与证书文件设置严格权限（root 归属）
