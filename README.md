# Grafana for 飞牛NAS (fnOS)

本项目用于将 [Grafana OSS](https://github.com/grafana/grafana) 打包为飞牛NAS应用商店的安装包。

## 简介

Grafana 是一个开源的数据可视化平台，可配合 Prometheus、Loki 等数据源展示监控指标和日志，并通过仪表盘集中查看。

## 支持架构

两种架构对应的飞牛平台名称如下：

| 实际架构 | 飞牛叫法 |
| --- | --- |
| x86_64 (amd64) | x86 |
| aarch64 (arm64) | arm |

## 安装要求

- 飞牛NAS 系统版本 >= 1.2.0
- 端口 `3000` 可用

## 目录结构

以下是主要目录：

```text
.
├── .github/workflows/             # GitHub Actions 打包流程
│   ├── main.yml                   # 主工作流
│   ├── pack_amd64.yml             # amd64 架构打包工作流
│   └── pack_arm64.yml             # arm64 架构打包工作流
├── app/
│   ├── grafana.ini.template       # Grafana 默认配置模板
│   ├── datasources.yaml.template  # 本机数据源配置模板
│   └── ui/                        # 桌面入口和图标
├── package/                       # 应用包预制文件
│   ├── manifest                   # 应用清单
│   ├── cmd/                       # 启动、停止及生命周期脚本
│   ├── config/                    # 权限与共享存储配置
│   └── i18n/                      # 应用描述
└── scripts/
    └── build.sh                   # 打包脚本
```

## 安装与使用

1. 在 [Releases](https://github.com/fnnas/appstore.grafana/releases) 下载对应架构的 `.fpk` 安装包。
2. 在飞牛应用中心手动安装，选择存储空间。
3. 启动应用后，从应用入口打开 Grafana，或访问 `http://<NAS_IP>:3000/`。
4. 首次使用 `admin / admin` 登录，按提示修改密码。

## 安装后配置

### 默认配置

| 配置项 | 默认值 |
| --- | --- |
| HTTP 端口 | `3000` |
| 用户名 | `admin` |
| 初始密码 | `admin` |
| 数据库 | SQLite |
| 默认数据源 | Prometheus Local |

### 数据存储路径

所有配置和持久化数据存储在：

```text
/volX/@appshare/grafana/
```

`X` 对应安装时选择的存储空间序号。在文件管理器的「应用文件 → grafana」中也能找到这个目录。

应用通过以下路径访问同一目录：

```text
/var/apps/grafana/shares/grafana/
```

目录内容：

- `grafana.ini` - Grafana 配置文件
- `data/grafana.db` - 用户、仪表盘、数据源等数据
- `plugins/` - 用户安装的插件
- `provisioning/` - 数据源、仪表盘等预置配置
- `log/grafana.log` - 运行日志

### 修改配置

首次启动时自动从模板复制配置文件。如需修改配置，编辑：

```text
/var/apps/grafana/shares/grafana/grafana.ini
```

修改后重启应用生效。升级时会保留已有配置、数据库和插件。备份时先停止应用，再备份整个共享目录。

如需更改安装包的默认端口，同步修改 `app/grafana.ini.template`、`package/manifest` 的 `service_port` 和 `app/ui/config` 的入口端口后重新打包。

### 默认数据源

全新安装时会预置以下两个本机数据源，Prometheus Local 设为默认：

| 数据源 | URL |
| --- | --- |
| Prometheus Local | `http://127.0.0.1:9090` |
| Loki Local | `http://127.0.0.1:3100` |

安装时不检查 Prometheus 和 Loki 是否已运行，启动对应服务后即可使用。升级、重装时如已有 Grafana 配置、数据库或数据源配置文件，会跳过初始化。

这两个数据源通过以下文件管理：

```text
/var/apps/grafana/shares/grafana/provisioning/datasources/default.yaml
```

如需修改地址或配置 Basic Auth，编辑该文件后重启 Grafana。其他数据源可以在 Grafana 页面中自行添加。

## 构建打包

本项目使用 GitHub Actions 自动构建，从 [Grafana Releases](https://github.com/grafana/grafana/releases) 下载指定版本的官方 `.deb`，提取运行文件后通过 `tar` 打包为 `.fpk`。

下载的 `.deb` 按 Grafana 版本和架构缓存在 GitHub Actions 中。同一版本重复打包时复用缓存，并重新校验 SHA256。

### 手动触发构建

1. 进入 GitHub Actions 页面，选择 **Test Release** 工作流。
2. 点击 **Run workflow**。
3. 如需创建预发布版本，勾选 `make_release`。

构建完成后，可在工作流产物中下载两个架构的安装包和 `SHA256SUMS.txt`。勾选发布时，产物也会上传到对应的 Release。

### 版本更新

修改 `.github/workflows/main.yml` 中的版本号：

```yaml
env:
  target_version: "13.2.4"               # Grafana 版本
  this_pack_manifest_version: "13.2.4-1" # 安装包版本
```

`target_version` 对应上游 Release tag，填写时去掉 `v` 前缀。同一个 Grafana 版本只调整启动脚本或打包流程时，递增安装包版本的后缀即可。

## 相关链接

- [Grafana 官方文档](https://grafana.com/docs/grafana/latest/)
- [Grafana GitHub](https://github.com/grafana/grafana)
- [Grafana 许可证](https://github.com/grafana/grafana/blob/main/LICENSE)
- [飞牛NAS 官网](https://www.fnnas.com/)
