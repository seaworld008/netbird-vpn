# Relay 文件证书续期与单服务重载

> 配合 [QUIC 运维手册](relay-quic-runbook.md)。这里是维护示例，不是安装器。
> 先核对当前版本是否自动重读文件证书；实测 `0.78.1` 在启动时加载。

## 1. 处理原则

Caddy 自动续期只更新磁盘，不会自动刷新独立 Relay 已加载的证书。
只读挂载对应域名的证书目录，由宿主机维护任务依次检查：

1. 证书与私钥匹配、有效期、信任链与域名。
2. Docker 容器的项目/服务标签与运行状态，防止重启错误对象。
3. 通过受校验的 TLS 读取实际服务证书指纹。
4. 指纹一致不重启；有效更新只重启该 Relay，复核实际指纹后更新状态。

文件损坏、容器停止或归属不符时退出并告警。重载会让中继连接短时重连，需纳入
维护安排。任务不需要把 Docker socket 挂给网络服务，也不应跳过 TLS 验证。

## 2. 配置与维护脚本

保存以下配置到 `/etc/netbird-relay-cert-refresh.json`，权限 `0600`。项目名、
网络名、容器名均按实际部署修改；目录应由既有证书续期流程持续维护，不能只
复制一次证书。使用 Caddy 卷时，只绑定这个域名的证书子目录，不暴露整个证书库。

```json
{
  "cert": "/srv/netbird-relay-tls/netbird.example.com.crt",
  "key": "/srv/netbird-relay-tls/netbird.example.com.key",
  "hostname": "netbird.example.com",
  "container": "netbird-relay-1",
  "project": "netbird",
  "network": "netbird_default",
  "port": 33080,
  "state": "/var/lib/netbird-relay-cert-refresh/loaded.json"
}
```

需要 Linux、Python 3、OpenSSL、Docker CLI 和系统 CA。以 root 将下列代码保存为
`/usr/local/sbin/netbird-relay-cert-refresh.py`，权限 `0750`：

```python
#!/usr/bin/env python3
"""Reload only the configured Relay when Caddy renews its certificate."""
import argparse, fcntl, hashlib, json, os, pathlib, socket, ssl, subprocess, tempfile, time

def material(cfg):
    cert, key = pathlib.Path(cfg['cert']), pathlib.Path(cfg['key'])
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(str(cert), str(key))
    subprocess.run(['openssl', 'x509', '-in', str(cert), '-noout', '-checkend', '86400'], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['openssl', 'verify', '-purpose', 'sslserver', '-verify_hostname', cfg['hostname'], '-untrusted', str(cert), str(cert)], check=True, stdout=subprocess.DEVNULL)
    der = subprocess.check_output(['openssl', 'x509', '-in', str(cert), '-outform', 'DER'])
    return hashlib.sha256(der).hexdigest()

def inspect(cfg):
    obj = json.loads(subprocess.check_output(['docker', 'inspect', cfg['container']]))[0]
    labels = obj['Config'].get('Labels', {})
    if labels.get('com.docker.compose.project') != cfg['project'] or labels.get('com.docker.compose.service') != 'relay':
        raise RuntimeError('container ownership mismatch')
    if not obj['State']['Running']:
        raise RuntimeError('relay is not running; certificate job will not start stopped services')
    networks = obj['NetworkSettings']['Networks']
    return networks[cfg['network']]['IPAddress']

def served(cfg):
    address = inspect(cfg)
    context = ssl.create_default_context()
    with socket.create_connection((address, cfg['port']), timeout=5) as raw:
        with context.wrap_socket(raw, server_hostname=cfg['hostname']) as tls:
            return hashlib.sha256(tls.getpeercert(binary_form=True)).hexdigest()

def record(path, fingerprint, action):
    path = pathlib.Path(path)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.loaded-')
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump({'fingerprint': fingerprint, 'action': action, 'time': time.strftime('%Y-%m-%dT%H:%M:%S%z')}, f)
            f.flush(); os.fsync(f.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name): os.unlink(name)

def refresh(cfg, check_only=False):
    expected = material(cfg)
    current = served(cfg)
    if current == expected:
        if not pathlib.Path(cfg['state']).exists() and not check_only:
            record(cfg['state'], current, 'initialized')
        print(json.dumps({'action': 'unchanged', 'certificate_matches': True}))
        return
    if check_only:
        print(json.dumps({'action': 'restart_required', 'certificate_matches': False}))
        return
    # Validate everything before affecting the live container; never restart for a parse failure.
    subprocess.run(['docker', 'restart', '--time', '15', cfg['container']], check=True, stdout=subprocess.DEVNULL)
    for attempt in range(15):
        try:
            if served(cfg) == expected:
                record(cfg['state'], expected, 'reloaded')
                print(json.dumps({'action': 'reloaded', 'certificate_matches': True}))
                return
        except (OSError, ssl.SSLError, RuntimeError):
            pass
        time.sleep(2)
    raise RuntimeError('new certificate not observed after relay restart; state not advanced')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', default='/etc/netbird-relay-cert-refresh.json')
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args()
    cfg = json.loads(pathlib.Path(args.config).read_text())
    with open('/run/lock/netbird-relay-cert-refresh.lock', 'w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SystemExit(0)
        refresh(cfg, args.check_only)

```

## 3. 定时运行与验证

`/etc/systemd/system/netbird-relay-cert-refresh.service`：

```ini
[Unit]
Description=Reload NetBird Relay only after certificate renewal
After=docker.service
Requires=docker.service
[Service]
Type=oneshot
User=root
UMask=0077
ExecStart=/usr/bin/python3 /usr/local/sbin/netbird-relay-cert-refresh.py
TimeoutStartSec=90
StateDirectory=netbird-relay-cert-refresh
StateDirectoryMode=0700
NoNewPrivileges=true
PrivateTmp=true
```

`/etc/systemd/system/netbird-relay-cert-refresh.timer`：

```ini
[Unit]
Description=Check NetBird Relay certificate every five minutes
[Timer]
OnCalendar=*:0/5
RandomizedDelaySec=20s
Persistent=true
[Install]
WantedBy=timers.target
```

先只读验证，再启动任务。实际重载须处于获准维护范围内。

```bash
python3 -m py_compile /usr/local/sbin/netbird-relay-cert-refresh.py
python3 /usr/local/sbin/netbird-relay-cert-refresh.py --check-only
sudo systemd-analyze verify /etc/systemd/system/netbird-relay-cert-refresh.service \
  /etc/systemd/system/netbird-relay-cert-refresh.timer
sudo systemctl daemon-reload
sudo systemctl start netbird-relay-cert-refresh.service
sudo systemctl enable --now netbird-relay-cert-refresh.timer
sudo journalctl -u netbird-relay-cert-refresh.service -n 20 --no-pager
```

`unchanged` 表示实际证书与文件一致；`restart_required` 只是 check-only 提示。
`reloaded` 须有实际 TLS 指纹复核。上线前测试未变化不重启、错误域名/密钥不
重启、有效更新只重启目标并更新状态。模拟分支不能代替自然 ACME 续期后的验收。

## 4. 失败处理与回滚

证书将到期、任务 failed 或源/服务指纹持续不一致应告警。脚本依赖当前服务证书
仍能通过系统 CA 校验；若长期停用任务导致旧证书已过期，先人工核对新证书，
再在维护窗口仅重载 Relay。不要改成跳过验证的自动恢复。

撤回时先停用 timer，保留文件与日志供排障；撤回 QUIC 则按主手册恢复端口与上游。

```bash
sudo systemctl disable --now netbird-relay-cert-refresh.timer
```

参考：[TLS 文件加载逻辑](https://github.com/netbirdio/netbird/blob/v0.78.1/encryption/cert.go)。
