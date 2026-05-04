<div align="center">
  <h1>AI API Stack 一键部署脚本</h1>
  <p><strong>Docker / new-api / cli-proxy-api / nginx / PostgreSQL / Redis</strong></p>
  <p>一个交互式 Shell 脚本，从 Docker 环境准备到服务部署、证书、更新和 Nginx 运维都集中到一个入口。</p>
  <p>
    <img src="https://img.shields.io/badge/Debian-12-A81D33?style=for-the-badge&logo=debian&logoColor=white" alt="Debian 12" />
    <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Bash" />
    <img src="https://img.shields.io/badge/Docker-Engine-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker Engine" />
    <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker Compose" />
  </p>
  <p>
    <img src="https://img.shields.io/badge/Nginx-Reverse_Proxy-009639?style=for-the-badge&logo=nginx&logoColor=white" alt="Nginx" />
    <img src="https://img.shields.io/badge/PostgreSQL-Database-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
    <img src="https://img.shields.io/badge/Redis-Cache-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis" />
    <img src="https://img.shields.io/badge/acme.sh-Let's_Encrypt-003A70?style=for-the-badge&logo=letsencrypt&logoColor=white" alt="acme.sh" />
  </p>
</div>

---

## 1. 脚本说明

`one-click/deploy.sh` 是一个面向 Docker Compose 的一键部署和运维脚本，主要用于部署 `new-api`、`cli-proxy-api` 和 `nginx`。

- Debian 12 一键安装/检查 Docker
- 自动生成 `generated-stack/` 部署目录
- 自动生成 `docker-compose.yml`、`.env`、`nginx/conf.d/default.conf`
- `new-api` 自动带 PostgreSQL 和 Redis
- 支持局域网部署和公网域名部署
- 支持公网 HTTPS、80 跳转 443、共用证书
- 支持 acme.sh + 阿里云 DNS 签发泛域名证书
- 支持按需配置 Docker 国内镜像源
- 支持更新镜像、重建容器、Nginx 测试/重载/重启/日志

## 2. 推荐顺序

全新的 Debian 12 服务器建议按这个顺序来：

```text
1. 安装/检查 Docker
2. 申请 HTTPS 证书，公网 HTTPS 才需要
3. 一键部署服务
4. 后续按需更新、管理 Nginx 或卸载
```

对应命令：

```bash
bash one-click/deploy.sh docker
bash one-click/deploy.sh cert
bash one-click/deploy.sh deploy
```

如果服务器已经装好 Docker，可以直接从证书或部署步骤开始。

Docker 国内镜像源不是必须步骤，只有拉取镜像慢或失败时再配置。

## 3. 快速开始

### 3.1 在线一键执行

如果服务器能访问 GitHub，可以直接拉取最新脚本执行：

```bash
curl -fsSL https://raw.githubusercontent.com/JunWan666/quick-docker-script-deploy/main/one-click/deploy.sh -o /tmp/deploy.sh && chmod +x /tmp/deploy.sh && /tmp/deploy.sh
```

也可以直接进入指定功能，例如先安装 Docker：

```bash
curl -fsSL https://raw.githubusercontent.com/JunWan666/quick-docker-script-deploy/main/one-click/deploy.sh -o /tmp/deploy.sh && chmod +x /tmp/deploy.sh && /tmp/deploy.sh docker
```

如果你在局域网里临时提供脚本文件，也可以使用局域网地址：

```bash
curl -fsSL http://192.168.11.6:7878/one-click/deploy.sh -o /tmp/deploy.sh && chmod +x /tmp/deploy.sh && /tmp/deploy.sh
```

### 3.2 本地执行

进入你想生成部署文件的目录，然后运行：

```bash
bash one-click/deploy.sh
```

### 3.3 主菜单

主菜单会显示：

```text
1  Debian 12 安装/检查 Docker
2  SSL 证书 / acme.sh
3  一键部署
4  更新服务镜像/容器
5  Nginx 管理
6  Docker 国内镜像源
7  卸载部署
8  退出
```

也可以直接指定功能：

```bash
bash one-click/deploy.sh docker
bash one-click/deploy.sh cert
bash one-click/deploy.sh deploy
bash one-click/deploy.sh update
bash one-click/deploy.sh nginx
bash one-click/deploy.sh mirror
bash one-click/deploy.sh uninstall
```

## 4. 功能教程

### 4.1 Debian 12 安装 Docker

运行：

```bash
bash one-click/deploy.sh docker
```

这个菜单会：

- 检查当前 Docker 和 Docker Compose 状态
- 仅在 Debian 12 上执行自动安装流程
- 使用 Docker 官方 Debian 仓库安装 Docker Engine
- 安装 `docker-ce`、`docker-ce-cli`、`containerd.io`
- 安装 `docker-buildx-plugin` 和 `docker-compose-plugin`
- 启动并设置 Docker 开机自启
- 如果通过 sudo 执行，可选择把当前用户加入 `docker` 组

该步骤需要 `root` 或 `sudo` 权限。

### 4.2 申请 HTTPS 证书

公网 HTTPS 推荐先申请证书，再部署服务。运行：

```bash
bash one-click/deploy.sh cert
```

推荐流程：

1. 在阿里云 RAM 创建用于 DNS 的用户。
2. 给该用户授权 `AliyunDNSFullAccess` 或等价 DNS 解析权限。
3. 在证书菜单中选择阿里云 DNS 签发。
4. 输入主域名，例如 `774966.xyz`。
5. 选择是否同时签发泛域名 `*.774966.xyz`。
6. 将证书安装到 `generated-stack/nginx/certs/`。
7. 部署公网 HTTPS 时填写生成的证书文件名。

DNS 方式签发证书不依赖 Nginx 是否已经启动，所以可以先申请证书再部署项目。已经部署过也可以后补证书，然后通过 Nginx 管理菜单重载。

### 4.3 一键部署服务

运行：

```bash
bash one-click/deploy.sh deploy
```

按提示填写基础信息：

- 生成目录：默认是当前目录下的 `generated-stack`
- Compose 项目名：默认 `ai-api-stack`
- 时区：默认 `Asia/Shanghai`
- 是否加入外部 Docker 网络 `app-net`
- 如果 `app-net` 不存在，是否自动创建

服务选择支持下面这些写法：

```text
all
1
2
12
1 2
1,2
new-api nginx
```

服务编号含义：

```text
1 = new-api，自动带 PostgreSQL + Redis
2 = cli-proxy-api
3 = nginx
```

常用选择：

- `all`：部署全部服务
- `1`：只部署 New API
- `2`：只部署 CPA / CLIProxyAPI
- `12`：部署 New API + CPA，不启用 Nginx
- `3`、`13`、`23`、`123`：启用 Nginx 统一代理

### 4.4 局域网部署

选择 Nginx 后，部署模式输入：

```text
1 = 局域网
2 = 公网
```

默认是 `1`，也就是局域网模式。

局域网模式不需要域名，部署完成后脚本会自动输出类似：

```text
New API: http://服务器局域网IP:端口
CPA:     http://服务器局域网IP:端口
```

### 4.5 公网 HTTPS 部署

公网模式适合已经准备好域名和证书的服务器。选择：

```text
Nginx 部署模式: 2
是否启用 HTTPS: y
是否 80 端口 301 重定向到 443: y
```

然后填写：

- New API 绑定域名，例如 `774966.xyz www.774966.xyz api.774966.xyz`
- CPA 绑定域名，例如 `admin.774966.xyz`
- 是否共用同一张证书
- 证书文件名和私钥文件名

生成的 Nginx 配置文件在：

```text
generated-stack/nginx/conf.d/default.conf
```

证书文件默认放在：

```text
generated-stack/nginx/certs/
```

### 4.6 更新服务

更新镜像并重建容器：

```bash
bash one-click/deploy.sh update
```

可以选择全部服务，也可以只更新某几个服务。脚本会执行：

```bash
docker compose pull
docker compose up -d
```

更新完成后可选择是否清理未使用的旧镜像。

### 4.7 Nginx 管理

进入 Nginx 管理菜单：

```bash
bash one-click/deploy.sh nginx
```

支持：

- 测试 Nginx 配置
- 重载 Nginx 配置
- 重启 Nginx 容器
- 启动/拉起 Nginx
- 查看 Nginx 状态
- 查看 Nginx 日志

修改 `generated-stack/nginx/conf.d/default.conf` 后，可以进入该菜单执行测试和重载。

### 4.8 Docker 国内镜像源

这一步不是必须的。只有拉取 Docker 镜像很慢、超时或失败时再配置。

运行：

```bash
bash one-click/deploy.sh mirror
```

这个菜单会修改：

```text
/etc/docker/daemon.json
```

按提示输入一个或多个 Docker Hub 加速地址，多个地址支持空格或逗号分隔。

```text
https://你的镜像源地址1 https://你的镜像源地址2
```

脚本会写入 `registry-mirrors`，并询问是否立即重启 Docker 使配置生效。

如果想恢复默认源，选择清空镜像源即可。

### 4.9 卸载部署

卸载：

```bash
bash one-click/deploy.sh uninstall
```

脚本会尝试执行：

```bash
docker compose down -v --remove-orphans
```

然后询问是否删除生成目录和配置文件。

## 5. 生成目录结构

部署后会生成：

```text
generated-stack/
├── docker-compose.yml
├── .env
├── acme-reload-nginx.sh   # 证书菜单生成，可选
├── new-api/
│   ├── data/
│   └── logs/
├── cliproxyapi/
│   ├── auths/
│   ├── logs/
│   └── config.yaml
└── nginx/
    ├── certs/
    └── conf.d/
        └── default.conf
```

## 6. 注意事项

- Debian 12 Docker 安装菜单只自动支持 Debian 12。
- 配置 Docker 镜像源会修改 `/etc/docker/daemon.json`。
- 选择 Nginx 后，New API 和 CPA 默认不暴露宿主机端口，只通过 Nginx 代理访问。
- PostgreSQL 和 Redis 是 New API 的依赖，不需要在服务选择里单独选择。
- `SESSION_SECRET` 和 `CRYPTO_SECRET` 是 New API 内部密钥，不是后台登录密码。
- 阿里云 `Ali_Key` / `Ali_Secret` 不要公开，泄露后请立即禁用或轮换。
- 公网 HTTPS 推荐使用泛域名证书，New API 和 CPA 可以共用同一张证书。
