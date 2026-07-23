# Orbit 后端部署文档

## 目录

1. [服务器要求](#1-服务器要求)
2. [安装 Docker](#2-安装-docker)
3. [部署服务](#3-部署服务)
4. [配置 Nginx 反向代理](#4-配置-nginx-反向代理)
5. [申请 HTTPS 证书](#5-申请-https-证书)
6. [iOS 客户端接入](#6-ios-客户端接入)
7. [日常维护](#7-日常维护)
8. [故障排查](#8-故障排查)

---

## 1. 服务器要求

| 项目 | 最低配置 | 推荐配置 |
|------|----------|----------|
| CPU  | 1 核     | 2 核     |
| 内存 | 1 GB     | 2 GB     |
| 硬盘 | 20 GB SSD | 40 GB SSD |
| 系统 | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |
| 端口 | 80、443、3000 | 80、443 |

> 阿里云、腾讯云、Vultr、DigitalOcean 均可，选最近区域降低延迟。

---

## 2. 安装 Docker

```bash
# 更新包列表
sudo apt update && sudo apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 把当前用户加入 docker 组（免 sudo）
sudo usermod -aG docker $USER
newgrp docker

# 验证安装
docker --version
docker compose version
```

---

## 3. 部署服务

### 3.1 上传代码

**方式 A — Git（推荐）**
```bash
git clone https://github.com/你的用户名/Orbit.git
cd Orbit/backend
```

**方式 B — SCP 上传**
```bash
# 本地执行
scp -r /Users/zhangxiaoye/Desktop/Orbit/backend root@你的服务器IP:/opt/jagat
ssh root@你的服务器IP
cd /opt/jagat
```

### 3.2 配置环境变量

```bash
cp .env.example .env
nano .env
```

填写以下内容：

```env
# 数据库（docker-compose 内部地址，不需要改）
DATABASE_URL=postgres://jagat:jagat_pass@db:5432/jagat

# Redis（docker-compose 内部地址，不需要改）
REDIS_URL=redis://redis:6379

# ⚠️ 必须修改：生成一个随机 64 位字符串
JWT_SECRET=在这里填写随机字符串

# 生产环境
NODE_ENV=production

PORT=3000
```

**生成 JWT_SECRET：**
```bash
openssl rand -hex 32
# 把输出结果粘贴到 .env 的 JWT_SECRET=
```

### 3.3 启动服务

```bash
# 构建并后台启动
docker compose up -d --build

# 查看启动日志
docker compose logs -f app
```

看到以下输出说明启动成功：
```
✅ Redis connected
✅ Migration applied
🚀 Orbit backend running on :3000
```

### 3.4 验证服务正常

```bash
curl http://localhost:3000/health
# 返回：{"ok":true,"ts":"2024-..."}
```

---

## 4. 配置 Nginx 反向代理

Nginx 负责把域名请求转发给 Docker 容器，并处理 HTTPS。

```bash
# 安装 Nginx
sudo apt install nginx -y

# 创建站点配置
sudo nano /etc/nginx/sites-available/jagat
```

写入以下内容（先用 HTTP，后面再改 HTTPS）：

```nginx
server {
    listen 80;
    server_name api.你的域名.com;   # ← 改成你的域名或服务器 IP

    # SSE 长连接：禁用缓冲
    proxy_buffering off;
    proxy_cache off;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;

        # WebSocket / SSE 支持
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # SSE 超时设置（好友实时位置流需要长连接）
        proxy_read_timeout  3600s;
        proxy_send_timeout  3600s;
    }
}
```

```bash
# 启用站点
sudo ln -s /etc/nginx/sites-available/jagat /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重载
sudo systemctl reload nginx
```

---

## 5. 申请 HTTPS 证书

> **前提**：域名已解析到服务器 IP（DNS 生效需要几分钟到几小时）。

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx -y

# 自动申请并配置证书（替换为你的域名和邮箱）
sudo certbot --nginx -d api.你的域名.com --email 你的邮箱 --agree-tos -n

# 验证自动续期
sudo systemctl status certbot.timer
```

Certbot 会自动修改 Nginx 配置，添加 SSL 并将 HTTP 重定向到 HTTPS。

完成后访问 `https://api.你的域名.com/health` 确认返回 `{"ok":true}`。

---

## 6. iOS 客户端接入

打开 [Orbit/App/AppEnvironment.swift](../Orbit/App/AppEnvironment.swift)，找到后端初始化的位置，把 Mock 替换为真实后端：

```swift
// 修改前（Mock）
static let backend: BackendService = MockBackendService()

// 修改后（自定义后端）
static let backend: BackendService = CustomBackendService(
    baseURL: "https://api.你的域名.com"   // 或 http://服务器IP:3000（内网测试用）
)
```

**注意**：如果用 IP 地址而非 HTTPS 域名，需要在 `Info.plist` 添加 App Transport Security 例外：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>你的服务器IP</key>
        <dict>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

> 生产环境必须使用 HTTPS，不要把 IP + HTTP 发布到 App Store。

---

## 7. 日常维护

### 查看日志

```bash
# 实时日志
docker compose logs -f app

# 最近 100 行
docker compose logs --tail=100 app

# 数据库日志
docker compose logs db
```

### 更新代码

```bash
git pull
docker compose up -d --build app
```

### 备份数据库

```bash
# 导出
docker compose exec db pg_dump -U jagat jagat > backup_$(date +%Y%m%d).sql

# 恢复
docker compose exec -T db psql -U jagat jagat < backup_20240101.sql
```

### 查看资源占用

```bash
docker stats
```

### 重启服务

```bash
# 重启某个服务
docker compose restart app

# 全部重启
docker compose restart
```

### 停止 / 删除

```bash
# 停止（保留数据）
docker compose down

# 停止并删除所有数据（⚠️ 不可恢复）
docker compose down -v
```

---

## 8. 故障排查

### 服务启动失败

```bash
docker compose logs app
```

常见原因：
- `JWT_SECRET` 未设置 → 检查 `.env` 文件
- 数据库连接失败 → 等待 db 容器健康检查通过（约 10 秒）

### 无法从外网访问

```bash
# 检查防火墙（需放行 80 和 443）
sudo ufw status
sudo ufw allow 80
sudo ufw allow 443

# 阿里云/腾讯云还需在控制台的「安全组」放行对应端口
```

### SSE 实时位置不更新

Nginx 默认开启缓冲会截断 SSE。确认配置中有：
```nginx
proxy_buffering off;
proxy_cache off;
proxy_read_timeout 3600s;
```

### 证书过期

Let's Encrypt 证书 90 天自动续期，手动触发：
```bash
sudo certbot renew --dry-run   # 测试
sudo certbot renew             # 实际续期
```

---

## API 接口速查

| 方法 | 路径 | 说明 | 需要 Token |
|------|------|------|-----------|
| POST | `/auth/request-code` | 请求验证码 | 否 |
| POST | `/auth/verify` | 验证码登录，返回 JWT | 否 |
| GET  | `/users/me` | 获取当前用户 | 是 |
| PATCH | `/users/me` | 更新资料 | 是 |
| PATCH | `/users/me/ghost-mode` | 开关隐身 | 是 |
| GET  | `/friends` | 好友列表（含位置） | 是 |
| POST | `/friends/add` | 通过邀请码添加好友 | 是 |
| GET  | `/friends/stream` | SSE 实时位置流 | 是 |
| POST | `/location` | 上报位置和电量 | 是 |
| GET  | `/conversations` | 会话列表 | 是 |
| GET  | `/conversations/:id/messages` | 消息列表 | 是 |
| POST | `/conversations/:id/messages` | 发送消息 | 是 |
| GET  | `/places` | 足迹列表 | 是 |
| GET  | `/health` | 健康检查 | 否 |

**开发模式说明**：`NODE_ENV=development` 时，`/auth/verify` 响应会包含 `debug_code` 字段（验证码明文），且任意 4 位以上验证码都能通过验证。生产环境务必设置 `NODE_ENV=production`。
