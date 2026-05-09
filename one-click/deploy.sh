#!/usr/bin/env bash
# 交互式一键部署脚本：负责收集输入、生成配置、创建目录并启动 Docker Compose。
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIR="$(pwd)"
DEFAULT_STACK_DIR="/opt/ai-api-stack"

DOCKER_COMPOSE=()
SELECTED_SERVICES=()
COMPOSE_TARGETS=()
DEPLOY_ALL=true
ACME_SH_BIN=""

DOCKER_DAEMON_JSON_PATH="/etc/docker/daemon.json"
DOCKER_APT_KEYRING_PATH="/etc/apt/keyrings/docker.asc"
DOCKER_APT_SOURCES_PATH="/etc/apt/sources.list.d/docker.sources"

STACK_DIR="${DEFAULT_STACK_DIR}"
USE_EXTERNAL_APP_NET=true
CREATE_APP_NET=true

PROJECT_NAME_VALUE="ai-api-stack"
TZ_VALUE="Asia/Shanghai"
APP_NET_NAME_VALUE="app-net"
ADVANCED_CONFIG_VALUE=false

NEWAPI_IMAGE_VALUE="calciumion/new-api:latest"
NEWAPI_PUBLISH_HOST_PORT_VALUE=true
NEWAPI_HOST_PORT_VALUE="3000"
NEWAPI_SESSION_SECRET_VALUE=""
NEWAPI_CRYPTO_SECRET_VALUE=""
NEWAPI_ERROR_LOG_ENABLED_VALUE="true"
NEWAPI_BATCH_UPDATE_ENABLED_VALUE="true"
NEWAPI_MAX_REQUEST_BODY_MB_VALUE="10240"
NEWAPI_MAX_FILE_DOWNLOAD_MB_VALUE="10240"

POSTGRES_IMAGE_VALUE="postgres:15"
POSTGRES_USER_VALUE="newapi"
POSTGRES_PASSWORD_VALUE=""
POSTGRES_DB_VALUE="new-api"

REDIS_IMAGE_VALUE="redis:7-alpine"

CLIPROXY_IMAGE_VALUE="eceasy/cli-proxy-api:latest"
CLIPROXY_DEPLOY_VALUE=""
CLIPROXY_PUBLISH_HOST_PORTS_VALUE=true
CLIPROXY_PORT_8317_VALUE="8317"
CLIPROXY_PORT_8085_VALUE="8085"
CLIPROXY_PORT_1455_VALUE="1455"
CLIPROXY_PORT_54545_VALUE="54545"
CLIPROXY_PORT_51121_VALUE="51121"
CLIPROXY_PORT_11451_VALUE="11451"
CLIPROXY_REMOTE_SECRET_VALUE=""
CLIPROXY_API_KEY_VALUE=""

GPT_IMAGE_WEBUI_IMAGE_VALUE="tannic666/gpt-image-2-webui:latest"
GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE=true
GPT_IMAGE_WEBUI_HOST_PORT_VALUE="3001"
GPT_IMAGE_WEBUI_OPENAI_API_KEY_VALUE=""
GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL_VALUE=""
GPT_IMAGE_WEBUI_OPENAI_IMAGE_TIMEOUT_MS_VALUE="1200000"
GPT_IMAGE_WEBUI_STORAGE_MODE_VALUE="fs"
GPT_IMAGE_WEBUI_APP_PASSWORD_VALUE=""
GPT_IMAGE_WEBUI_CLEANUP_ENABLED_VALUE="true"
GPT_IMAGE_WEBUI_RETENTION_DAYS_VALUE="3"
GPT_IMAGE_WEBUI_CLEANUP_INTERVAL_HOURS_VALUE="24"
GPT_IMAGE_WEBUI_CLEANUP_RUN_ON_START_VALUE="true"
GPT_IMAGE_WEBUI_CLEANUP_DRY_RUN_VALUE="false"
GPT_IMAGE_WEBUI_CLEANUP_LOG_FILE_VALUE="/app/logs/cleanup-generated-images.log"

NGINX_IMAGE_VALUE="nginx:alpine"
NGINX_DEPLOY_MODE_VALUE="lan"
NGINX_ENABLE_HTTPS=false
NGINX_SHARE_CERT_VALUE=true
NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE=true
NGINX_HTTP_PORT_VALUE="80"
NGINX_HTTPS_PORT_VALUE="443"
NGINX_LAN_API_PORT_VALUE="80"
NGINX_LAN_ADMIN_PORT_VALUE="8080"
NGINX_LAN_WEBUI_PORT_VALUE="8081"
NGINX_HTTP_SERVER_NAMES_VALUE="example.com www.example.com api.example.com admin.example.com image.example.com"
NGINX_API_SERVER_NAMES_VALUE="example.com www.example.com api.example.com"
NGINX_ADMIN_SERVER_NAME_VALUE="admin.example.com"
NGINX_WEBUI_SERVER_NAMES_VALUE="image.example.com"
NGINX_API_CERT_VALUE="fullchain.cer"
NGINX_API_KEY_VALUE="example.com.key"
NGINX_ADMIN_CERT_VALUE="fullchain.cer"
NGINX_ADMIN_KEY_VALUE="example.com.key"
NGINX_WEBUI_CERT_VALUE="fullchain.cer"
NGINX_WEBUI_KEY_VALUE="example.com.key"
NGINX_NEWAPI_UPSTREAM_VALUE="new-api:3000"
NGINX_CLIPROXY_UPSTREAM_VALUE="cli-proxy-api:8317"
NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE="gpt-image-2-webui:3000"

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

random_hex() {
  local bytes="${1:-32}"

  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
    return
  fi

  if [[ -r /dev/urandom ]] && command -v od >/dev/null 2>&1; then
    od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
    return
  fi

  printf '%s%s%s%s' "$(date +%s)" "$RANDOM" "$RANDOM" "$RANDOM"
}

USE_COLOR=false
COLOR_RESET=""
COLOR_BOLD=""
COLOR_DIM=""
COLOR_RED=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_BLUE=""
COLOR_MAGENTA=""
COLOR_CYAN=""
ITALIC_ON=""
ITALIC_OFF=""

init_ui() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    USE_COLOR=true
    COLOR_RESET=$'\033[0m'
    COLOR_BOLD=$'\033[1m'
    COLOR_DIM=$'\033[2m'
    COLOR_RED=$'\033[31m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_BLUE=$'\033[34m'
    COLOR_MAGENTA=$'\033[35m'
    COLOR_CYAN=$'\033[36m'
    ITALIC_ON=$'\033[3m'
    ITALIC_OFF=$'\033[23m'
  fi
}

color_text() {
  local color="$1"
  shift

  if [[ "$USE_COLOR" == "true" ]]; then
    printf '%b%s%b' "$color" "$*" "$COLOR_RESET"
  else
    printf '%s' "$*"
  fi
}

banner_line() {
  local line="$1"

  if [[ "$USE_COLOR" == "true" ]]; then
    printf '%b%b%s%b\n' "${COLOR_BOLD}${COLOR_CYAN}" "$ITALIC_ON" "$line" "${ITALIC_OFF}${COLOR_RESET}"
  else
    printf '%b%s%b\n' "$ITALIC_ON" "$line" "$ITALIC_OFF"
  fi
}

rule() {
  local char="${1:-=}"
  local width="${2:-72}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

banner() {
  local art=""
  local banner_text="AI   API   Stack"

  rule "=" 72
  if command -v figlet >/dev/null 2>&1; then
    art="$(figlet -f smslant -w 120 "$banner_text" 2>/dev/null || true)"
  elif command -v toilet >/dev/null 2>&1; then
    art="$(toilet -f smslant -w 120 "$banner_text" 2>/dev/null || true)"
  fi

  if [[ -n "$art" ]]; then
    while IFS= read -r line; do
      banner_line "$line"
    done <<< "$art"
  else
    banner_line '   ___   ____    ___   ___  ____    ______           __'
    banner_line '  / _ | /  _/   / _ | / _ \/  _/   / __/ /____ _____/ /__'
    banner_line ' / __ |_/ /    / __ |/ ___// /    _\ \/ __/ _ `/ __/  '"'"'_/ '
    banner_line '/_/ |_/___/   /_/ |_/_/  /___/   /___/\__/\_,_/\__/_/\_\'
  fi
  printf '%s\n' "$(color_text "${COLOR_BOLD}${COLOR_GREEN}" "AI API Stack 一键部署脚本")"
  printf '%s\n' "$(color_text "$COLOR_DIM" "Nginx + New API + CLIProxyAPI + GPT Image WebUI + PostgreSQL + Redis")"
  printf '%s\n' "$(color_text "$COLOR_DIM" "Docker / 证书 / 部署 / 更新 / Nginx 管理 / 镜像源 / 杂项 / 卸载")"
  rule "=" 72
}

section_title() {
  printf '\n%s\n' "$(color_text "${COLOR_BOLD}${COLOR_GREEN}" "$1")"
  rule "-" 72
}

subtle_note() {
  printf '%s\n' "$(color_text "$COLOR_DIM" "$1")"
}

menu_option() {
  printf '  %s %s\n' "$(color_text "$1" "$2")" "$3"
}

field_line() {
  printf '  %s %s\n' "$(color_text "$COLOR_CYAN" "$1")" "$2"
}

show_main_menu() {
  section_title "主菜单"
  menu_option "$COLOR_GREEN" "[1]" "Debian 12 安装/检查 Docker"
  menu_option "$COLOR_MAGENTA" "[2]" "SSL 证书 / acme.sh"
  menu_option "$COLOR_BLUE" "[3]" "一键部署"
  menu_option "$COLOR_GREEN" "[4]" "更新服务镜像/容器"
  menu_option "$COLOR_YELLOW" "[5]" "Nginx 管理"
  menu_option "$COLOR_CYAN" "[6]" "Docker 国内镜像源"
  menu_option "$COLOR_RED" "[7]" "卸载部署"
  menu_option "$COLOR_BLUE" "[8]" "杂项"
  menu_option "$COLOR_DIM" "[9]" "退出"
}

detect_lan_ip() {
  local ip=""

  if command -v ip >/dev/null 2>&1; then
    ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')"
  fi

  if [[ -z "$ip" ]] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi

  printf '%s' "$ip"
}

read_line() {
  local __var="$1"
  local label="$2"
  local default="${3-}"
  local input_value=""
  local prompt=""

  if [[ -n "$default" ]]; then
    prompt="${label} [${default}]: "
  else
    prompt="${label}: "
  fi

  if [[ -t 0 ]]; then
    read -e -r -p "$prompt" input_value
  else
    printf '%s' "$prompt"
    read -r input_value
  fi

  input_value="${input_value%$'\r'}"

  if [[ -z "$input_value" && -n "$default" ]]; then
    input_value="$default"
  fi

  printf -v "$__var" '%s' "$input_value"
}

read_yes_no() {
  local __var="$1"
  local label="$2"
  local default_bool="$3"
  local default_text="n"
  local answer=""

  if [[ "$default_bool" == "true" ]]; then
    default_text="y"
  fi

  while true; do
    read_line answer "$label (y/n)" "$default_text"
    case "$(lower "$answer")" in
      y|yes|true|1)
        printf -v "$__var" '%s' "true"
        return
        ;;
      n|no|false|0)
        printf -v "$__var" '%s' "false"
        return
        ;;
      *)
        printf '请输入 y 或 n。\n'
        ;;
    esac
  done
}

port_in_use() {
  local port="${1:-}"

  [[ "$port" =~ ^[0-9]+$ ]] || return 1

  if command -v ss >/dev/null 2>&1; then
    ss -H -ltn 2>/dev/null | awk -v port="$port" '
      {
        split($4, parts, ":")
        if (parts[length(parts)] == port) {
          found = 1
        }
      }
      END { exit found ? 0 : 1 }
    '
    return
  fi

  if command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | awk -v port="$port" '
      {
        split($4, parts, ":")
        if (parts[length(parts)] == port) {
          found = 1
        }
      }
      END { exit found ? 0 : 1 }
    '
    return
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
    return
  fi

  return 1
}

find_available_port() {
  local start="$1"
  local skip="${2:-}"
  local port="$start"

  while (( port <= 65535 )); do
    if [[ -z "$skip" || "$port" != "$skip" ]]; then
      if ! port_in_use "$port"; then
        printf '%s' "$port"
        return
      fi
    fi
    ((port++))
  done

  return 1
}

ensure_available_port() {
  local __var="$1"
  local label="$2"
  local fallback_start="$3"
  local skip="${4:-}"
  local current="${!__var}"
  local new_port=""

  if [[ ! "$current" =~ ^[0-9]+$ ]] || (( current < 1 || current > 65535 )); then
    new_port="$(find_available_port "$fallback_start" "$skip")" || die "没有找到可用于 ${label} 的端口。"
    printf '%s 端口值无效，已自动改为 %s。\n' "$label" "$new_port"
    printf -v "$__var" '%s' "$new_port"
    return
  fi

  if [[ -n "$skip" && "$current" == "$skip" ]] || port_in_use "$current"; then
    new_port="$(find_available_port "$fallback_start" "$skip")" || die "没有找到可用于 ${label} 的端口。"
    printf '%s 端口 %s 不可用，已自动改为 %s。\n' "$label" "$current" "$new_port"
    printf -v "$__var" '%s' "$new_port"
  fi
}

resolve_publish_ports() {
  if [[ "$NEWAPI_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
    ensure_available_port NEWAPI_HOST_PORT_VALUE "New API 直连" 3000
  fi

  if [[ "$CLIPROXY_PUBLISH_HOST_PORTS_VALUE" == "true" ]]; then
    ensure_available_port CLIPROXY_PORT_8317_VALUE "CLIProxyAPI 8317 直连" 8317
    ensure_available_port CLIPROXY_PORT_8085_VALUE "CLIProxyAPI 8085 直连" 8085 "$CLIPROXY_PORT_8317_VALUE"
    ensure_available_port CLIPROXY_PORT_1455_VALUE "CLIProxyAPI 1455 直连" 1455
    ensure_available_port CLIPROXY_PORT_54545_VALUE "CLIProxyAPI 54545 直连" 54545
    ensure_available_port CLIPROXY_PORT_51121_VALUE "CLIProxyAPI 51121 直连" 51121
    ensure_available_port CLIPROXY_PORT_11451_VALUE "CLIProxyAPI 11451 直连" 11451
  fi

  if [[ "$GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
    ensure_available_port GPT_IMAGE_WEBUI_HOST_PORT_VALUE "GPT Image WebUI 直连" 3001 "$NEWAPI_HOST_PORT_VALUE"
  fi

  if ! needs_nginx_config; then
    return
  fi

  if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
    ensure_available_port NGINX_LAN_API_PORT_VALUE "Nginx 局域网 API 入口" 18080
    ensure_available_port NGINX_LAN_ADMIN_PORT_VALUE "Nginx 局域网管理端入口" 18081 "$NGINX_LAN_API_PORT_VALUE"
    ensure_available_port NGINX_LAN_WEBUI_PORT_VALUE "Nginx 局域网 GPT Image WebUI 入口" 18082 "$NGINX_LAN_ADMIN_PORT_VALUE"
  else
    ensure_available_port NGINX_HTTP_PORT_VALUE "Nginx 公网 HTTP 入口" 18080
    if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
      ensure_available_port NGINX_HTTPS_PORT_VALUE "Nginx 公网 HTTPS 入口" 18443 "$NGINX_HTTP_PORT_VALUE"
    fi
  fi
}

normalize_nginx_mode() {
  local mode="$(lower "$1")"

  case "$mode" in
    1|lan|local|intranet|内网|局域网)
      printf 'lan'
      ;;
    2|public|pub|internet|外网|公网)
      printf 'public'
      ;;
    *)
      return 1
      ;;
  esac
}

read_nginx_mode() {
  local __var="$1"
  local default="${2:-lan}"
  local default_choice="1"
  local answer=""
  local mode=""

  if [[ "$default" == "public" ]]; then
    default_choice="2"
  fi

  while true; do
    subtle_note "Nginx 部署模式：1=局域网，2=公网。"
    read_line answer "请选择 Nginx 部署模式" "$default_choice"
    if mode="$(normalize_nginx_mode "$answer")"; then
      printf -v "$__var" '%s' "$mode"
      return
    fi

    printf '请输入 1 或 2。1=局域网不需要域名，2=公网可配置域名和 HTTPS。\n'
  done
}

expand_path() {
  local path="$1"

  case "$path" in
    "~")
      printf '%s' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s' "$HOME" "${path#"~/"}"
      ;;
    *)
      printf '%s' "$path"
      ;;
  esac
}

use_fixed_stack_dir() {
  STACK_DIR="$(expand_path "$DEFAULT_STACK_DIR")"
}

show_stack_dir_notice() {
  field_line "固定安装目录：" "$STACK_DIR"
  subtle_note "脚本会始终在该目录生成和读取 docker-compose.yml、.env、Nginx 配置、证书和数据目录。"
}

ensure_stack_dir_writable() {
  local parent=""

  parent="$(dirname "$STACK_DIR")"

  if [[ -d "$STACK_DIR" ]]; then
    [[ -w "$STACK_DIR" ]] || die "部署目录不可写：$STACK_DIR。固定安装到 /opt 时通常需要使用 root 或 sudo 执行脚本。"
    return
  fi

  [[ -d "$parent" ]] || die "父目录不存在：$parent"
  [[ -w "$parent" ]] || die "无法在 $parent 下创建部署目录。固定安装到 /opt 时通常需要使用 root 或 sudo 执行脚本。"
}

join_list() {
  local output=""
  local item=""

  for item in "$@"; do
    if [[ -n "$output" ]]; then
      output="${output}, ${item}"
    else
      output="$item"
    fi
  done

  printf '%s' "$output"
}

dotenv_get() {
  local file="$1"
  local key="$2"
  local line=""
  local value=""

  [[ -f "$file" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" == "$key="* ]] || continue

    value="${line#*=}"
    if [[ "${#value}" -ge 2 ]]; then
      if [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
        value="${value:1:${#value}-2}"
      elif [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
        value="${value:1:${#value}-2}"
      fi
    fi

    printf '%s' "$value"
    return 0
  done < "$file"

  return 1
}

load_env_default() {
  local env_file="$1"
  local key="$2"
  local __var="$3"
  local value=""

  if value="$(dotenv_get "$env_file" "$key")"; then
    printf -v "$__var" '%s' "$value"
  fi
}

load_existing_env_defaults() {
  local env_file="$STACK_DIR/.env"

  [[ -f "$env_file" ]] || return 0

  subtle_note "检测到已有 .env，将复用其中的默认值，避免重置数据库密码和应用密钥。"
  load_env_default "$env_file" "COMPOSE_PROJECT_NAME" PROJECT_NAME_VALUE
  load_env_default "$env_file" "TZ" TZ_VALUE
  load_env_default "$env_file" "APP_NET_NAME" APP_NET_NAME_VALUE

  load_env_default "$env_file" "NEWAPI_IMAGE" NEWAPI_IMAGE_VALUE
  load_env_default "$env_file" "NEWAPI_PUBLISH_HOST_PORT" NEWAPI_PUBLISH_HOST_PORT_VALUE
  load_env_default "$env_file" "NEWAPI_HOST_PORT" NEWAPI_HOST_PORT_VALUE
  load_env_default "$env_file" "NEWAPI_SESSION_SECRET" NEWAPI_SESSION_SECRET_VALUE
  load_env_default "$env_file" "NEWAPI_CRYPTO_SECRET" NEWAPI_CRYPTO_SECRET_VALUE
  load_env_default "$env_file" "NEWAPI_ERROR_LOG_ENABLED" NEWAPI_ERROR_LOG_ENABLED_VALUE
  load_env_default "$env_file" "NEWAPI_BATCH_UPDATE_ENABLED" NEWAPI_BATCH_UPDATE_ENABLED_VALUE
  load_env_default "$env_file" "NEWAPI_MAX_REQUEST_BODY_MB" NEWAPI_MAX_REQUEST_BODY_MB_VALUE
  load_env_default "$env_file" "NEWAPI_MAX_FILE_DOWNLOAD_MB" NEWAPI_MAX_FILE_DOWNLOAD_MB_VALUE

  load_env_default "$env_file" "POSTGRES_IMAGE" POSTGRES_IMAGE_VALUE
  load_env_default "$env_file" "POSTGRES_USER" POSTGRES_USER_VALUE
  load_env_default "$env_file" "POSTGRES_PASSWORD" POSTGRES_PASSWORD_VALUE
  load_env_default "$env_file" "POSTGRES_DB" POSTGRES_DB_VALUE
  load_env_default "$env_file" "REDIS_IMAGE" REDIS_IMAGE_VALUE

  load_env_default "$env_file" "CLIPROXY_IMAGE" CLIPROXY_IMAGE_VALUE
  load_env_default "$env_file" "CLIPROXY_DEPLOY" CLIPROXY_DEPLOY_VALUE
  load_env_default "$env_file" "CLIPROXY_PUBLISH_HOST_PORTS" CLIPROXY_PUBLISH_HOST_PORTS_VALUE
  load_env_default "$env_file" "CLIPROXY_PORT_8317" CLIPROXY_PORT_8317_VALUE
  load_env_default "$env_file" "CLIPROXY_PORT_8085" CLIPROXY_PORT_8085_VALUE
  load_env_default "$env_file" "CLIPROXY_PORT_1455" CLIPROXY_PORT_1455_VALUE
  load_env_default "$env_file" "CLIPROXY_PORT_54545" CLIPROXY_PORT_54545_VALUE
  load_env_default "$env_file" "CLIPROXY_PORT_51121" CLIPROXY_PORT_51121_VALUE
  load_env_default "$env_file" "CLIPROXY_PORT_11451" CLIPROXY_PORT_11451_VALUE
  load_env_default "$env_file" "CLIPROXY_REMOTE_SECRET" CLIPROXY_REMOTE_SECRET_VALUE
  load_env_default "$env_file" "CLIPROXY_API_KEY" CLIPROXY_API_KEY_VALUE

  load_env_default "$env_file" "GPT_IMAGE_WEBUI_IMAGE" GPT_IMAGE_WEBUI_IMAGE_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT" GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_HOST_PORT" GPT_IMAGE_WEBUI_HOST_PORT_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_OPENAI_API_KEY" GPT_IMAGE_WEBUI_OPENAI_API_KEY_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL" GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_OPENAI_IMAGE_TIMEOUT_MS" GPT_IMAGE_WEBUI_OPENAI_IMAGE_TIMEOUT_MS_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_STORAGE_MODE" GPT_IMAGE_WEBUI_STORAGE_MODE_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_APP_PASSWORD" GPT_IMAGE_WEBUI_APP_PASSWORD_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_CLEANUP_ENABLED" GPT_IMAGE_WEBUI_CLEANUP_ENABLED_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_RETENTION_DAYS" GPT_IMAGE_WEBUI_RETENTION_DAYS_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_CLEANUP_INTERVAL_HOURS" GPT_IMAGE_WEBUI_CLEANUP_INTERVAL_HOURS_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_CLEANUP_RUN_ON_START" GPT_IMAGE_WEBUI_CLEANUP_RUN_ON_START_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_CLEANUP_DRY_RUN" GPT_IMAGE_WEBUI_CLEANUP_DRY_RUN_VALUE
  load_env_default "$env_file" "GPT_IMAGE_WEBUI_CLEANUP_LOG_FILE" GPT_IMAGE_WEBUI_CLEANUP_LOG_FILE_VALUE

  load_env_default "$env_file" "NGINX_IMAGE" NGINX_IMAGE_VALUE
  load_env_default "$env_file" "NGINX_DEPLOY_MODE" NGINX_DEPLOY_MODE_VALUE
  load_env_default "$env_file" "NGINX_ENABLE_HTTPS" NGINX_ENABLE_HTTPS
  load_env_default "$env_file" "NGINX_SHARE_CERT" NGINX_SHARE_CERT_VALUE
  load_env_default "$env_file" "NGINX_HTTP_TO_HTTPS_REDIRECT" NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE
  load_env_default "$env_file" "NGINX_HTTP_PORT" NGINX_HTTP_PORT_VALUE
  load_env_default "$env_file" "NGINX_HTTPS_PORT" NGINX_HTTPS_PORT_VALUE
  load_env_default "$env_file" "NGINX_LAN_API_PORT" NGINX_LAN_API_PORT_VALUE
  load_env_default "$env_file" "NGINX_LAN_ADMIN_PORT" NGINX_LAN_ADMIN_PORT_VALUE
  load_env_default "$env_file" "NGINX_LAN_WEBUI_PORT" NGINX_LAN_WEBUI_PORT_VALUE
  load_env_default "$env_file" "NGINX_HTTP_SERVER_NAMES" NGINX_HTTP_SERVER_NAMES_VALUE
  load_env_default "$env_file" "NGINX_API_SERVER_NAMES" NGINX_API_SERVER_NAMES_VALUE
  load_env_default "$env_file" "NGINX_ADMIN_SERVER_NAME" NGINX_ADMIN_SERVER_NAME_VALUE
  load_env_default "$env_file" "NGINX_WEBUI_SERVER_NAMES" NGINX_WEBUI_SERVER_NAMES_VALUE
  load_env_default "$env_file" "NGINX_API_CERT" NGINX_API_CERT_VALUE
  load_env_default "$env_file" "NGINX_API_KEY" NGINX_API_KEY_VALUE
  load_env_default "$env_file" "NGINX_ADMIN_CERT" NGINX_ADMIN_CERT_VALUE
  load_env_default "$env_file" "NGINX_ADMIN_KEY" NGINX_ADMIN_KEY_VALUE
  load_env_default "$env_file" "NGINX_WEBUI_CERT" NGINX_WEBUI_CERT_VALUE
  load_env_default "$env_file" "NGINX_WEBUI_KEY" NGINX_WEBUI_KEY_VALUE
  load_env_default "$env_file" "NGINX_NEWAPI_UPSTREAM" NGINX_NEWAPI_UPSTREAM_VALUE
  load_env_default "$env_file" "NGINX_CLIPROXY_UPSTREAM" NGINX_CLIPROXY_UPSTREAM_VALUE
  load_env_default "$env_file" "NGINX_GPT_IMAGE_WEBUI_UPSTREAM" NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE
}

first_word() {
  local value="$1"

  set -- $value
  printf '%s' "${1:-}"
}

url_with_port() {
  local scheme="$1"
  local host="$2"
  local port="$3"
  local default_port="80"

  if [[ "$scheme" == "https" ]]; then
    default_port="443"
  fi

  if [[ -z "$host" ]]; then
    printf '%s://域名未设置' "$scheme"
    return
  fi

  if [[ "$port" == "$default_port" ]]; then
    printf '%s://%s' "$scheme" "$host"
  else
    printf '%s://%s:%s' "$scheme" "$host" "$port"
  fi
}

contains_service() {
  local needle="$1"
  shift || true
  local item=""

  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done

  return 1
}

selected_or_all() {
  local service="$1"

  if [[ "$DEPLOY_ALL" == "true" ]]; then
    return 0
  fi

  contains_service "$service" "${SELECTED_SERVICES[@]}"
}

service_from_token() {
  local token=""
  token="$(lower "$1")"

  case "$token" in
    1|nginx|proxy|gateway)
      printf 'nginx'
      ;;
    2|newapi|new-api|api)
      printf 'new-api'
      ;;
    postgres|postgresql|pg|db|redis|cache)
      printf 'new-api'
      ;;
    3|cliproxy|cliproxyapi|cli-proxy-api|cli|cpa)
      printf 'cli-proxy-api'
      ;;
    4|gpt-image-2-webui|gpt-image-webui|gptimage|gpt-image|image-webui|webui|image)
      printf 'gpt-image-2-webui'
      ;;
    *)
      return 1
      ;;
  esac
}

append_selected_service() {
  local service="$1"

  if ! contains_service "$service" "${SELECTED_SERVICES[@]}"; then
    SELECTED_SERVICES+=("$service")
  fi
}

select_services() {
  local raw=""
  local token=""
  local service=""

  section_title "服务选择"
  menu_option "$COLOR_GREEN" " 1)" "nginx"
  menu_option "$COLOR_GREEN" " 2)" "new-api"
  menu_option "$COLOR_GREEN" " 3)" "cli-proxy-api"
  menu_option "$COLOR_GREEN" " 4)" "gpt-image-2-webui"
  subtle_note "postgres 和 redis 是 new-api 的内置依赖，不单独选择。"
  subtle_note "输入 all、1234、1 2、1,2 或服务名都可以；选 1 会启用 Nginx。"

  while true; do
    read_line raw "要部署的服务" "all"
    raw="$(lower "$raw")"
    raw="${raw//,/ }"
    raw="${raw//;/ }"

    if [[ -z "$raw" || "$raw" == "all" || "$raw" == "*" ]]; then
      DEPLOY_ALL=true
      SELECTED_SERVICES=()
      printf '已选择：全部服务\n'
      return
    fi

    DEPLOY_ALL=false
    SELECTED_SERVICES=()

    for token in $raw; do
      if [[ "$token" =~ ^[1234]+$ && "${#token}" -gt 1 ]]; then
        local index=0
        local char=""
        for ((index = 0; index < ${#token}; index++)); do
          char="${token:index:1}"
          if service="$(service_from_token "$char")"; then
            append_selected_service "$service"
          fi
        done
      elif service="$(service_from_token "$token")"; then
        append_selected_service "$service"
      else
        printf '无法识别的服务：%s\n' "$token"
      fi
    done

    if [[ "${#SELECTED_SERVICES[@]}" -gt 0 ]]; then
      printf '已选择：%s\n' "$(join_list "${SELECTED_SERVICES[@]}")"
      return
    fi

    printf '没有选到有效服务，请重新输入。\n'
  done
}

needs_newapi_config() {
  selected_or_all "new-api" && return 0
  selected_or_all "nginx" && return 0
  return 1
}

needs_postgres_config() {
  needs_newapi_config && return 0
  return 1
}

needs_cliproxy_config() {
  selected_or_all "cli-proxy-api" && return 0
  selected_or_all "nginx" && return 0
  return 1
}

needs_gpt_image_webui_config() {
  selected_or_all "gpt-image-2-webui" && return 0
  selected_or_all "nginx" && return 0
  return 1
}

needs_nginx_config() {
  selected_or_all "nginx"
}

last_certificate_metadata_file() {
  printf '%s' "$STACK_DIR/nginx/certs/.last-cert.env"
}

write_last_certificate_metadata() {
  local base_domain="$1"
  local cert_file="$2"
  local key_file="$3"
  local include_wildcard="$4"
  local metadata_file=""

  metadata_file="$(last_certificate_metadata_file)"
  mkdir -p "$(dirname "$metadata_file")"
  {
    write_env_line "ACME_BASE_DOMAIN" "$base_domain"
    write_env_line "ACME_CERT_FILE" "$cert_file"
    write_env_line "ACME_KEY_FILE" "$key_file"
    write_env_line "ACME_INCLUDE_WILDCARD" "$include_wildcard"
    write_env_line "ACME_UPDATED_AT" "$(date +%Y-%m-%dT%H:%M:%S%z)"
  } > "$metadata_file"
}

load_last_certificate_pair() {
  local __cert_var="$1"
  local __key_var="$2"
  local __domain_var="$3"
  local metadata_file=""
  local cert_file=""
  local key_file=""
  local base_domain=""

  metadata_file="$(last_certificate_metadata_file)"
  [[ -f "$metadata_file" ]] || return 1

  cert_file="$(dotenv_get "$metadata_file" "ACME_CERT_FILE" || true)"
  key_file="$(dotenv_get "$metadata_file" "ACME_KEY_FILE" || true)"
  base_domain="$(dotenv_get "$metadata_file" "ACME_BASE_DOMAIN" || true)"

  [[ -n "$cert_file" && -n "$key_file" ]] || return 1
  [[ "$cert_file" != /* && "$cert_file" != *".."* ]] || return 1
  [[ "$key_file" != /* && "$key_file" != *".."* ]] || return 1
  [[ -f "$STACK_DIR/nginx/certs/$cert_file" ]] || return 1
  [[ -f "$STACK_DIR/nginx/certs/$key_file" ]] || return 1

  printf -v "$__cert_var" '%s' "$cert_file"
  printf -v "$__key_var" '%s' "$key_file"
  printf -v "$__domain_var" '%s' "$base_domain"
}

read_nginx_certificate_files() {
  local share_cert="$NGINX_SHARE_CERT_VALUE"
  local last_cert=""
  local last_key=""
  local last_domain=""
  local use_last_cert="true"

  if load_last_certificate_pair last_cert last_key last_domain; then
    subtle_note "检测到上次签发并安装的证书，可直接用于本次 Nginx HTTPS 配置。"
    if [[ -n "$last_domain" ]]; then
      field_line "证书域名：" "$last_domain"
    fi
    field_line "证书文件：" "$last_cert"
    field_line "私钥文件：" "$last_key"
    read_yes_no use_last_cert "是否直接用于所有 Nginx HTTPS 站点" "$use_last_cert"
    if [[ "$use_last_cert" == "true" ]]; then
      NGINX_SHARE_CERT_VALUE=true
      NGINX_API_CERT_VALUE="$last_cert"
      NGINX_API_KEY_VALUE="$last_key"
      NGINX_ADMIN_CERT_VALUE="$last_cert"
      NGINX_ADMIN_KEY_VALUE="$last_key"
      NGINX_WEBUI_CERT_VALUE="$last_cert"
      NGINX_WEBUI_KEY_VALUE="$last_key"
      printf '已设置：所有 Nginx HTTPS 站点共用证书 %s / %s。\n' "$last_cert" "$last_key"
      return
    fi
  fi

  read_yes_no share_cert "New API、CPA 和 GPT Image WebUI 是否共用同一个证书" "$NGINX_SHARE_CERT_VALUE"
  NGINX_SHARE_CERT_VALUE="$share_cert"

  if [[ "$NGINX_SHARE_CERT_VALUE" == "true" ]]; then
    read_line NGINX_API_CERT_VALUE "nginx/certs 里的证书文件名" "$NGINX_API_CERT_VALUE"
    read_line NGINX_API_KEY_VALUE "nginx/certs 里的私钥文件名" "$NGINX_API_KEY_VALUE"
    NGINX_ADMIN_CERT_VALUE="$NGINX_API_CERT_VALUE"
    NGINX_ADMIN_KEY_VALUE="$NGINX_API_KEY_VALUE"
    NGINX_WEBUI_CERT_VALUE="$NGINX_API_CERT_VALUE"
    NGINX_WEBUI_KEY_VALUE="$NGINX_API_KEY_VALUE"
    printf '已设置：New API、CPA 和 GPT Image WebUI 共用证书 %s / %s。\n' "$NGINX_API_CERT_VALUE" "$NGINX_API_KEY_VALUE"
    return
  fi

  read_line NGINX_API_CERT_VALUE "nginx/certs 里的 New API 证书文件名" "$NGINX_API_CERT_VALUE"
  read_line NGINX_API_KEY_VALUE "nginx/certs 里的 New API 私钥文件名" "$NGINX_API_KEY_VALUE"
  read_line NGINX_ADMIN_CERT_VALUE "nginx/certs 里的 CPA 证书文件名" "$NGINX_ADMIN_CERT_VALUE"
  read_line NGINX_ADMIN_KEY_VALUE "nginx/certs 里的 CPA 私钥文件名" "$NGINX_ADMIN_KEY_VALUE"
  read_line NGINX_WEBUI_CERT_VALUE "nginx/certs 里的 GPT Image WebUI 证书文件名" "$NGINX_WEBUI_CERT_VALUE"
  read_line NGINX_WEBUI_KEY_VALUE "nginx/certs 里的 GPT Image WebUI 私钥文件名" "$NGINX_WEBUI_KEY_VALUE"
}

uses_nginx_frontend() {
  selected_or_all "nginx"
}

default_gpt_image_webui_base_url() {
  if needs_newapi_config; then
    printf 'http://new-api:3000/v1'
  fi
}

try_detect_compose() {
  command -v docker >/dev/null 2>&1 || return 1

  if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE=(docker compose)
    return 0
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE=(docker-compose)
    return 0
  fi

  return 1
}

detect_compose() {
  command -v docker >/dev/null 2>&1 || die "未检测到 Docker，请先使用主菜单 [1] 安装 Docker。"
  try_detect_compose && return
  die "未找到 Docker Compose，请安装 Docker Compose v2 或 docker-compose。"
}

ensure_docker_ready() {
  docker info >/dev/null 2>&1 || die "Docker 未运行，或者当前用户没有访问 Docker 的权限。请先确认 Docker 服务已启动。"
}

run_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return
  fi

  command -v sudo >/dev/null 2>&1 || die "此操作需要 root 权限，且当前系统未检测到 sudo。"
  sudo "$@"
}

is_debian12() {
  local id=""
  local version_id=""

  [[ -r /etc/os-release ]] || return 1

  # shellcheck disable=SC1091
  . /etc/os-release
  id="${ID:-}"
  version_id="${VERSION_ID:-}"

  [[ "$id" == "debian" && "${version_id%%.*}" == "12" ]]
}

show_docker_versions() {
  if command -v docker >/dev/null 2>&1; then
    field_line "Docker：" "$(docker --version 2>/dev/null || printf '已安装')"
    field_line "Compose：" "$(docker compose version 2>/dev/null || printf '未检测到 compose plugin')"
    if docker info >/dev/null 2>&1; then
      field_line "Docker 状态：" "运行中"
    else
      field_line "Docker 状态：" "未运行或当前用户无权限"
    fi
  else
    field_line "Docker：" "未安装"
  fi
}

install_docker_debian12() {
  local reinstall="false"
  local add_user_to_group="true"
  local target_user="${SUDO_USER:-}"

  section_title "Debian 12 安装/检查 Docker"
  show_docker_versions

  if command -v docker >/dev/null 2>&1; then
    read_yes_no reinstall "Docker 已存在，是否重新执行安装/修复流程" "$reinstall"
    [[ "$reinstall" == "true" ]] || return 0
  fi

  if ! is_debian12; then
    die "此菜单只自动支持 Debian 12。如果是其它系统，请先手动安装 Docker。"
  fi

  subtle_note "将使用 Docker 官方 Debian 仓库安装 docker-ce、compose plugin、buildx plugin。"
  run_root bash -s <<'ROOT'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

source /etc/os-release

apt-get update
apt-get install -y ca-certificates curl gnupg

conflicting_packages=()
for pkg in docker.io docker-compose docker-doc podman-docker containerd runc; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    conflicting_packages+=("$pkg")
  fi
done

if [[ "${#conflicting_packages[@]}" -gt 0 ]]; then
  apt-get remove -y "${conflicting_packages[@]}" || true
fi

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
ROOT

  if [[ -n "$target_user" && "$target_user" != "root" ]]; then
    read_yes_no add_user_to_group "是否将用户 ${target_user} 加入 docker 组" "$add_user_to_group"
    if [[ "$add_user_to_group" == "true" ]]; then
      run_root usermod -aG docker "$target_user" || subtle_note "加入 docker 组失败，可稍后手动执行 usermod。"
      subtle_note "用户组变更需要重新登录 SSH 后生效。"
    fi
  fi

  section_title "Docker 安装完成"
  show_docker_versions
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

json_array_from_values() {
  local first="true"
  local item=""
  local escaped=""

  printf '['
  for item in "$@"; do
    [[ -n "$item" ]] || continue
    escaped="$(json_escape "$item")"
    if [[ "$first" == "true" ]]; then
      first="false"
    else
      printf ', '
    fi
    printf '"%s"' "$escaped"
  done
  printf ']'
}

write_docker_registry_mirrors() {
  local mirrors_json="$1"
  local backup_file=""

  if command -v python3 >/dev/null 2>&1; then
    run_root python3 - "$DOCKER_DAEMON_JSON_PATH" "$mirrors_json" <<'PY'
import json
import os
import sys

path = sys.argv[1]
mirrors = json.loads(sys.argv[2])
data = {}

os.makedirs(os.path.dirname(path), exist_ok=True)

if os.path.exists(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            loaded = json.load(f)
        if isinstance(loaded, dict):
            data = loaded
    except Exception:
        data = {}

if mirrors:
    data["registry-mirrors"] = mirrors
else:
    data.pop("registry-mirrors", None)

tmp_path = path + ".tmp"
with open(tmp_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
os.replace(tmp_path, path)
PY
    return
  fi

  if [[ -f "$DOCKER_DAEMON_JSON_PATH" ]]; then
    backup_file="${DOCKER_DAEMON_JSON_PATH}.bak.$(date +%Y%m%d%H%M%S)"
    run_root cp "$DOCKER_DAEMON_JSON_PATH" "$backup_file"
    subtle_note "当前系统未检测到 python3，已备份原配置：$backup_file"
  fi

  run_root bash -s -- "$DOCKER_DAEMON_JSON_PATH" "$mirrors_json" <<'ROOT'
set -Eeuo pipefail
daemon_json="$1"
mirrors_json="$2"

mkdir -p "$(dirname "$daemon_json")"

if [[ "$mirrors_json" == "[]" ]]; then
  cat > "$daemon_json" <<'JSON'
{}
JSON
else
  cat > "$daemon_json" <<JSON
{
  "registry-mirrors": $mirrors_json
}
JSON
fi
ROOT
}

restart_docker_if_possible() {
  if command -v systemctl >/dev/null 2>&1; then
    run_root systemctl daemon-reload || true
    if systemctl list-unit-files docker.service 2>/dev/null | grep -q '^docker\.service'; then
      run_root systemctl restart docker || subtle_note "Docker 重启失败，请检查服务状态。"
      return
    fi
  fi

  subtle_note "未能自动重启 Docker，请稍后手动重启 Docker 服务。"
}

configure_docker_mirror() {
  local raw=""
  local clear_mirrors="false"
  local restart_now="true"
  local token=""
  local mirrors=()
  local mirrors_json=""

  section_title "Docker 国内镜像源"
  field_line "配置文件：" "$DOCKER_DAEMON_JSON_PATH"
  if [[ -f "$DOCKER_DAEMON_JSON_PATH" ]]; then
    subtle_note "检测到已有 daemon.json，脚本会尽量保留其它配置，只修改 registry-mirrors。"
  fi

  read_yes_no clear_mirrors "是否清空 Docker 镜像源并恢复默认" "$clear_mirrors"
  if [[ "$clear_mirrors" == "true" ]]; then
    mirrors_json="[]"
  else
    subtle_note "请输入一个或多个国内镜像源地址，多个用空格或逗号分隔。"
    subtle_note "例如阿里云、腾讯云、DaoCloud 等平台提供的 Docker Hub 加速地址。"
    read_line raw "Docker 镜像源地址" ""
    raw="${raw//,/ }"
    raw="${raw//;/ }"
    for token in $raw; do
      if [[ "$token" =~ ^https?:// ]]; then
        mirrors+=("$token")
      else
        printf '已跳过无效地址：%s\n' "$token"
      fi
    done

    [[ "${#mirrors[@]}" -gt 0 ]] || die "没有输入有效的镜像源地址。"
    mirrors_json="$(json_array_from_values "${mirrors[@]}")"
  fi

  write_docker_registry_mirrors "$mirrors_json"

  read_yes_no restart_now "是否现在重启 Docker 使配置生效" "$restart_now"
  if [[ "$restart_now" == "true" ]]; then
    restart_docker_if_possible
  fi

  section_title "Docker 镜像源配置完成"
  field_line "配置文件：" "$DOCKER_DAEMON_JSON_PATH"
  if [[ "$mirrors_json" == "[]" ]]; then
    field_line "registry-mirrors：" "已清空"
  else
    field_line "registry-mirrors：" "$mirrors_json"
  fi
}

compose_stack() {
  if [[ -f "$STACK_DIR/.env" ]]; then
    "${DOCKER_COMPOSE[@]}" --env-file "$STACK_DIR/.env" "$@"
  else
    "${DOCKER_COMPOSE[@]}" "$@"
  fi
}

prepare_existing_stack() {
  local label="$1"

  use_fixed_stack_dir
  field_line "$label：" "$STACK_DIR"

  [[ -f "$STACK_DIR/docker-compose.yml" ]] || die "未找到 Compose 文件：$STACK_DIR/docker-compose.yml"

  detect_compose
  ensure_docker_ready
}

service_from_compose_token() {
  local token="$(lower "$1")"

  case "$token" in
    1|nginx|proxy|gateway)
      printf 'nginx'
      ;;
    2|new-api|newapi|api)
      printf 'new-api'
      ;;
    3|cli-proxy-api|cliproxy-api|cliproxy|cpa|admin)
      printf 'cli-proxy-api'
      ;;
    4|gpt-image-2-webui|gpt-image-webui|gptimage|gpt-image|image-webui|webui|image)
      printf 'gpt-image-2-webui'
      ;;
    postgres|postgresql|pg|db|database)
      printf 'postgres'
      ;;
    redis|cache)
      printf 'redis'
      ;;
    *)
      return 1
      ;;
  esac
}

append_compose_target() {
  local service="$1"

  if ! contains_service "$service" "${COMPOSE_TARGETS[@]}"; then
    COMPOSE_TARGETS+=("$service")
  fi
}

select_compose_targets() {
  local raw=""
  local token=""
  local service=""

  COMPOSE_TARGETS=()
  subtle_note "输入 all 表示全部；也可以输入 1234、1 2、1,2、nginx、webui、postgres、redis。"

  while true; do
    read_line raw "请选择要操作的服务" "all"
    raw="$(lower "$raw")"
    raw="${raw//,/ }"
    raw="${raw//;/ }"

    if [[ -z "$raw" || "$raw" == "all" || "$raw" == "*" ]]; then
      COMPOSE_TARGETS=()
      printf '已选择：全部服务\n'
      return
    fi

    COMPOSE_TARGETS=()
    for token in $raw; do
      if [[ "$token" =~ ^[1234]+$ && "${#token}" -gt 1 ]]; then
        local index=0
        local char=""
        for ((index = 0; index < ${#token}; index++)); do
          char="${token:index:1}"
          if service="$(service_from_compose_token "$char")"; then
            append_compose_target "$service"
          fi
        done
      elif service="$(service_from_compose_token "$token")"; then
        append_compose_target "$service"
      else
        printf '无法识别的服务：%s\n' "$token"
      fi
    done

    if [[ "${#COMPOSE_TARGETS[@]}" -gt 0 ]]; then
      printf '已选择：%s\n' "$(join_list "${COMPOSE_TARGETS[@]}")"
      return
    fi

    printf '没有选到有效服务，请重新输入。\n'
  done
}

collect_answers() {
  local https_enabled="false"

  NEWAPI_SESSION_SECRET_VALUE="$(random_hex 32)"
  NEWAPI_CRYPTO_SECRET_VALUE="$(random_hex 32)"
  POSTGRES_PASSWORD_VALUE="$(random_hex 16)"
  CLIPROXY_REMOTE_SECRET_VALUE="$(random_hex 32)"
  CLIPROXY_API_KEY_VALUE="$(random_hex 32)"

  section_title "基础设置"
  use_fixed_stack_dir
  show_stack_dir_notice
  ensure_stack_dir_writable
  load_existing_env_defaults
  read_line PROJECT_NAME_VALUE "Compose 项目名" "$PROJECT_NAME_VALUE"
  read_line TZ_VALUE "时区" "$TZ_VALUE"
  read_yes_no ADVANCED_CONFIG_VALUE "是否启用高级配置（自定义镜像、端口、上游地址时使用）" "$ADVANCED_CONFIG_VALUE"

  section_title "网络设置"
  read_yes_no USE_EXTERNAL_APP_NET "是否让公开服务加入外部 app-net" "$USE_EXTERNAL_APP_NET"
  if [[ "$USE_EXTERNAL_APP_NET" == "true" ]]; then
    read_line APP_NET_NAME_VALUE "外部 Docker 网络名" "$APP_NET_NAME_VALUE"
    read_yes_no CREATE_APP_NET "如果网络不存在，是否自动创建" "$CREATE_APP_NET"
  fi

  select_services

  if needs_newapi_config; then
    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      section_title "New API 配置"
      read_line NEWAPI_IMAGE_VALUE "New API 镜像" "$NEWAPI_IMAGE_VALUE"
      if uses_nginx_frontend; then
        NEWAPI_PUBLISH_HOST_PORT_VALUE=false
        printf '已选择 Nginx，New API 默认不映射宿主机端口，只允许 Nginx 通过 Docker 网络访问。\n'
      else
        read_yes_no NEWAPI_PUBLISH_HOST_PORT_VALUE "是否开放 New API 直连端口" "$NEWAPI_PUBLISH_HOST_PORT_VALUE"
      fi
      if [[ "$NEWAPI_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
        read_line NEWAPI_HOST_PORT_VALUE "New API 主机端口" "$NEWAPI_HOST_PORT_VALUE"
      fi
      read_line NEWAPI_SESSION_SECRET_VALUE "New API 会话密钥（明文）" "$NEWAPI_SESSION_SECRET_VALUE"
      read_line NEWAPI_CRYPTO_SECRET_VALUE "New API 加密密钥（明文）" "$NEWAPI_CRYPTO_SECRET_VALUE"
      read_line NEWAPI_ERROR_LOG_ENABLED_VALUE "New API 是否开启错误日志" "$NEWAPI_ERROR_LOG_ENABLED_VALUE"
      read_line NEWAPI_BATCH_UPDATE_ENABLED_VALUE "New API 是否开启批量更新" "$NEWAPI_BATCH_UPDATE_ENABLED_VALUE"
      read_line NEWAPI_MAX_REQUEST_BODY_MB_VALUE "New API 最大请求体 MB" "$NEWAPI_MAX_REQUEST_BODY_MB_VALUE"
      read_line NEWAPI_MAX_FILE_DOWNLOAD_MB_VALUE "New API 最大下载文件 MB" "$NEWAPI_MAX_FILE_DOWNLOAD_MB_VALUE"
    else
      NEWAPI_IMAGE_VALUE="calciumion/new-api:latest"
      NEWAPI_ERROR_LOG_ENABLED_VALUE="true"
      NEWAPI_BATCH_UPDATE_ENABLED_VALUE="true"
      NEWAPI_MAX_REQUEST_BODY_MB_VALUE="10240"
      NEWAPI_MAX_FILE_DOWNLOAD_MB_VALUE="10240"
      if uses_nginx_frontend; then
        NEWAPI_PUBLISH_HOST_PORT_VALUE=false
        printf '已选择 Nginx，New API 默认只通过 Docker 网络访问。\n'
      else
        NEWAPI_PUBLISH_HOST_PORT_VALUE=true
      fi
    fi
  fi

  if needs_postgres_config; then
    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      section_title "PostgreSQL 配置"
      read_line POSTGRES_IMAGE_VALUE "PostgreSQL 镜像" "$POSTGRES_IMAGE_VALUE"
      read_line POSTGRES_USER_VALUE "PostgreSQL 用户名" "$POSTGRES_USER_VALUE"
      read_line POSTGRES_PASSWORD_VALUE "PostgreSQL 密码（明文，建议不要包含 @:/?#）" "$POSTGRES_PASSWORD_VALUE"
      read_line POSTGRES_DB_VALUE "PostgreSQL 数据库名" "$POSTGRES_DB_VALUE"
    else
      POSTGRES_IMAGE_VALUE="postgres:15"
      POSTGRES_USER_VALUE="newapi"
      POSTGRES_DB_VALUE="new-api"
    fi
  fi

  if needs_newapi_config; then
    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      section_title "Redis 配置"
      read_line REDIS_IMAGE_VALUE "Redis 镜像" "$REDIS_IMAGE_VALUE"
    else
      REDIS_IMAGE_VALUE="redis:7-alpine"
    fi
  fi

  if needs_cliproxy_config; then
    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      section_title "CLIProxyAPI 配置"
      read_line CLIPROXY_IMAGE_VALUE "CLIProxyAPI 镜像" "$CLIPROXY_IMAGE_VALUE"
      read_line CLIPROXY_DEPLOY_VALUE "CLIProxyAPI DEPLOY 值（可留空）" "$CLIPROXY_DEPLOY_VALUE"
      read_line CLIPROXY_REMOTE_SECRET_VALUE "CLIProxyAPI 远程管理密钥（明文）" "$CLIPROXY_REMOTE_SECRET_VALUE"
      read_line CLIPROXY_API_KEY_VALUE "CLIProxyAPI api-key（明文）" "$CLIPROXY_API_KEY_VALUE"
      if uses_nginx_frontend; then
        CLIPROXY_PUBLISH_HOST_PORTS_VALUE=false
        printf '已选择 Nginx，CLIProxyAPI 默认不映射宿主机端口，只通过 Nginx 代理 8317 服务。\n'
      else
        read_yes_no CLIPROXY_PUBLISH_HOST_PORTS_VALUE "是否开放 CLIProxyAPI 直连端口" "$CLIPROXY_PUBLISH_HOST_PORTS_VALUE"
      fi
      if [[ "$CLIPROXY_PUBLISH_HOST_PORTS_VALUE" == "true" ]]; then
        read_line CLIPROXY_PORT_8317_VALUE "CLIProxyAPI 8317 端口映射" "$CLIPROXY_PORT_8317_VALUE"
        read_line CLIPROXY_PORT_8085_VALUE "CLIProxyAPI 8085 端口映射" "$CLIPROXY_PORT_8085_VALUE"
        read_line CLIPROXY_PORT_1455_VALUE "CLIProxyAPI 1455 端口映射" "$CLIPROXY_PORT_1455_VALUE"
        read_line CLIPROXY_PORT_54545_VALUE "CLIProxyAPI 54545 端口映射" "$CLIPROXY_PORT_54545_VALUE"
        read_line CLIPROXY_PORT_51121_VALUE "CLIProxyAPI 51121 端口映射" "$CLIPROXY_PORT_51121_VALUE"
        read_line CLIPROXY_PORT_11451_VALUE "CLIProxyAPI 11451 端口映射" "$CLIPROXY_PORT_11451_VALUE"
      fi
    else
      CLIPROXY_IMAGE_VALUE="eceasy/cli-proxy-api:latest"
      CLIPROXY_DEPLOY_VALUE=""
      if uses_nginx_frontend; then
        CLIPROXY_PUBLISH_HOST_PORTS_VALUE=false
        printf '已选择 Nginx，CLIProxyAPI 默认只通过 Nginx 代理访问。\n'
      else
        CLIPROXY_PUBLISH_HOST_PORTS_VALUE=true
      fi
    fi
  fi

  if needs_gpt_image_webui_config; then
    if [[ -z "$GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL_VALUE" ]]; then
      GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL_VALUE="$(default_gpt_image_webui_base_url)"
    fi

    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      section_title "GPT Image WebUI 配置"
      read_line GPT_IMAGE_WEBUI_IMAGE_VALUE "GPT Image WebUI 镜像" "$GPT_IMAGE_WEBUI_IMAGE_VALUE"
      read_line GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL_VALUE "默认 OpenAI 兼容 Base URL（可留空）" "$GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL_VALUE"
      read_line GPT_IMAGE_WEBUI_OPENAI_API_KEY_VALUE "默认 OpenAI API Key（可留空，明文）" "$GPT_IMAGE_WEBUI_OPENAI_API_KEY_VALUE"
      read_line GPT_IMAGE_WEBUI_OPENAI_IMAGE_TIMEOUT_MS_VALUE "图片请求超时时间 ms" "$GPT_IMAGE_WEBUI_OPENAI_IMAGE_TIMEOUT_MS_VALUE"
      read_line GPT_IMAGE_WEBUI_STORAGE_MODE_VALUE "图片存储模式 fs/indexeddb" "$GPT_IMAGE_WEBUI_STORAGE_MODE_VALUE"
      read_line GPT_IMAGE_WEBUI_APP_PASSWORD_VALUE "访问密码（可留空，明文）" "$GPT_IMAGE_WEBUI_APP_PASSWORD_VALUE"
      read_yes_no GPT_IMAGE_WEBUI_CLEANUP_ENABLED_VALUE "是否启用生成图片自动清理" "$GPT_IMAGE_WEBUI_CLEANUP_ENABLED_VALUE"
      if [[ "$GPT_IMAGE_WEBUI_CLEANUP_ENABLED_VALUE" == "true" ]]; then
        read_line GPT_IMAGE_WEBUI_RETENTION_DAYS_VALUE "生成图片保留天数" "$GPT_IMAGE_WEBUI_RETENTION_DAYS_VALUE"
        read_line GPT_IMAGE_WEBUI_CLEANUP_INTERVAL_HOURS_VALUE "自动清理间隔小时" "$GPT_IMAGE_WEBUI_CLEANUP_INTERVAL_HOURS_VALUE"
        read_yes_no GPT_IMAGE_WEBUI_CLEANUP_RUN_ON_START_VALUE "容器启动时是否先清理一次" "$GPT_IMAGE_WEBUI_CLEANUP_RUN_ON_START_VALUE"
        read_yes_no GPT_IMAGE_WEBUI_CLEANUP_DRY_RUN_VALUE "是否只试运行清理" "$GPT_IMAGE_WEBUI_CLEANUP_DRY_RUN_VALUE"
      fi
      if uses_nginx_frontend; then
        GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE=false
        printf '已选择 Nginx，GPT Image WebUI 默认不映射宿主机端口，只通过 Nginx 访问。\n'
      else
        read_yes_no GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE "是否开放 GPT Image WebUI 直连端口" "$GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE"
      fi
      if [[ "$GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
        read_line GPT_IMAGE_WEBUI_HOST_PORT_VALUE "GPT Image WebUI 主机端口" "$GPT_IMAGE_WEBUI_HOST_PORT_VALUE"
      fi
    else
      GPT_IMAGE_WEBUI_IMAGE_VALUE="tannic666/gpt-image-2-webui:latest"
      GPT_IMAGE_WEBUI_OPENAI_IMAGE_TIMEOUT_MS_VALUE="1200000"
      GPT_IMAGE_WEBUI_STORAGE_MODE_VALUE="fs"
      GPT_IMAGE_WEBUI_CLEANUP_ENABLED_VALUE="true"
      GPT_IMAGE_WEBUI_RETENTION_DAYS_VALUE="3"
      GPT_IMAGE_WEBUI_CLEANUP_INTERVAL_HOURS_VALUE="24"
      GPT_IMAGE_WEBUI_CLEANUP_RUN_ON_START_VALUE="true"
      GPT_IMAGE_WEBUI_CLEANUP_DRY_RUN_VALUE="false"
      GPT_IMAGE_WEBUI_CLEANUP_LOG_FILE_VALUE="/app/logs/cleanup-generated-images.log"
      if uses_nginx_frontend; then
        GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE=false
        printf '已选择 Nginx，GPT Image WebUI 默认只通过 Nginx 访问。\n'
      else
        GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE=true
      fi
    fi
  fi

  if needs_nginx_config; then
    section_title "Nginx 配置"
    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      read_line NGINX_IMAGE_VALUE "Nginx 镜像" "$NGINX_IMAGE_VALUE"
      read_nginx_mode NGINX_DEPLOY_MODE_VALUE "$NGINX_DEPLOY_MODE_VALUE"
      if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
        NGINX_ENABLE_HTTPS=false
        NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE=true
        read_line NGINX_LAN_API_PORT_VALUE "局域网 API 入口主机端口" "$NGINX_LAN_API_PORT_VALUE"
        while true; do
          read_line NGINX_LAN_ADMIN_PORT_VALUE "局域网管理端入口主机端口" "$NGINX_LAN_ADMIN_PORT_VALUE"
          if [[ "$NGINX_LAN_ADMIN_PORT_VALUE" != "$NGINX_LAN_API_PORT_VALUE" ]]; then
            break
          fi
          printf 'API 入口端口和管理端端口不能相同，请重新输入。\n'
        done
        while true; do
          read_line NGINX_LAN_WEBUI_PORT_VALUE "局域网 GPT Image WebUI 入口主机端口" "$NGINX_LAN_WEBUI_PORT_VALUE"
          if [[ "$NGINX_LAN_WEBUI_PORT_VALUE" != "$NGINX_LAN_API_PORT_VALUE" && "$NGINX_LAN_WEBUI_PORT_VALUE" != "$NGINX_LAN_ADMIN_PORT_VALUE" ]]; then
            break
          fi
          printf 'WebUI 入口端口不能和 API / 管理端端口相同，请重新输入。\n'
        done
      else
        read_yes_no https_enabled "是否启用 Nginx HTTPS 配置" "$NGINX_ENABLE_HTTPS"
        NGINX_ENABLE_HTTPS="$https_enabled"
        if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
          read_yes_no NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE "是否将 80 端口 301 重定向到 443" "$NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE"
        else
          NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE=true
        fi
        read_line NGINX_HTTP_PORT_VALUE "Nginx HTTP 主机端口" "$NGINX_HTTP_PORT_VALUE"
        if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
          read_line NGINX_HTTPS_PORT_VALUE "Nginx HTTPS 主机端口" "$NGINX_HTTPS_PORT_VALUE"
        fi
        read_line NGINX_API_SERVER_NAMES_VALUE "New API 绑定域名（多个空格分隔）" "$NGINX_API_SERVER_NAMES_VALUE"
        read_line NGINX_ADMIN_SERVER_NAME_VALUE "CLIProxyAPI 绑定域名（多个空格分隔）" "$NGINX_ADMIN_SERVER_NAME_VALUE"
        read_line NGINX_WEBUI_SERVER_NAMES_VALUE "GPT Image WebUI 绑定域名（多个空格分隔）" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
        NGINX_HTTP_SERVER_NAMES_VALUE="${NGINX_API_SERVER_NAMES_VALUE} ${NGINX_ADMIN_SERVER_NAME_VALUE} ${NGINX_WEBUI_SERVER_NAMES_VALUE}"
        if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
          read_nginx_certificate_files
        fi
        read_line NGINX_NEWAPI_UPSTREAM_VALUE "New API 上游地址" "$NGINX_NEWAPI_UPSTREAM_VALUE"
        read_line NGINX_CLIPROXY_UPSTREAM_VALUE "CLIProxyAPI 上游地址" "$NGINX_CLIPROXY_UPSTREAM_VALUE"
        read_line NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE "GPT Image WebUI 上游地址" "$NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE"
        printf '已绑定：New API -> %s；CLIProxyAPI -> %s；GPT Image WebUI -> %s。\n' "$NGINX_API_SERVER_NAMES_VALUE" "$NGINX_ADMIN_SERVER_NAME_VALUE" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
        if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
          if [[ "$NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE" == "true" ]]; then
            printf 'HTTP 80 会 301 跳转到 HTTPS 端口 %s。\n' "$NGINX_HTTPS_PORT_VALUE"
          else
            printf 'HTTP 80 与 HTTPS 端口 %s 都会保留直连访问。\n' "$NGINX_HTTPS_PORT_VALUE"
          fi
        fi
      fi
    else
      NGINX_IMAGE_VALUE="nginx:alpine"
      read_nginx_mode NGINX_DEPLOY_MODE_VALUE "$NGINX_DEPLOY_MODE_VALUE"
      if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
        NGINX_ENABLE_HTTPS=false
        NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE=true
      else
        read_yes_no https_enabled "是否启用 Nginx HTTPS 配置" "$NGINX_ENABLE_HTTPS"
        NGINX_ENABLE_HTTPS="$https_enabled"
        if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
          read_yes_no NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE "是否将 80 端口 301 重定向到 443" "$NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE"
        else
          NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE=true
        fi
      fi
      if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" ]]; then
        read_line NGINX_API_SERVER_NAMES_VALUE "New API 绑定域名（多个空格分隔）" "$NGINX_API_SERVER_NAMES_VALUE"
        read_line NGINX_ADMIN_SERVER_NAME_VALUE "CLIProxyAPI 绑定域名（多个空格分隔）" "$NGINX_ADMIN_SERVER_NAME_VALUE"
        read_line NGINX_WEBUI_SERVER_NAMES_VALUE "GPT Image WebUI 绑定域名（多个空格分隔）" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
        NGINX_HTTP_SERVER_NAMES_VALUE="${NGINX_API_SERVER_NAMES_VALUE} ${NGINX_ADMIN_SERVER_NAME_VALUE} ${NGINX_WEBUI_SERVER_NAMES_VALUE}"
        if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
          read_nginx_certificate_files
        fi
      fi
      NGINX_NEWAPI_UPSTREAM_VALUE="new-api:3000"
      NGINX_CLIPROXY_UPSTREAM_VALUE="cli-proxy-api:8317"
      NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE="gpt-image-2-webui:3000"
      if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" ]]; then
        printf '已绑定：New API -> %s；CLIProxyAPI -> %s；GPT Image WebUI -> %s。\n' "$NGINX_API_SERVER_NAMES_VALUE" "$NGINX_ADMIN_SERVER_NAME_VALUE" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
        if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
          if [[ "$NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE" == "true" ]]; then
            printf 'HTTP 80 会 301 跳转到 HTTPS 端口 %s。\n' "$NGINX_HTTPS_PORT_VALUE"
          else
            printf 'HTTP 80 与 HTTPS 端口 %s 都会保留直连访问。\n' "$NGINX_HTTPS_PORT_VALUE"
          fi
        fi
      fi
    fi
  fi

  resolve_publish_ports
}

dotenv_quote() {
  local value="$1"
  value="${value//\'/\'\\\'\'}"
  printf "'%s'" "$value"
}

write_env_line() {
  local key="$1"
  local value="$2"
  printf '%s=%s\n' "$key" "$(dotenv_quote "$value")"
}

yaml_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

prepare_directories() {
  mkdir -p "$STACK_DIR"
  mkdir -p "$STACK_DIR/new-api/data"
  mkdir -p "$STACK_DIR/new-api/logs"
  mkdir -p "$STACK_DIR/cliproxyapi/auths"
  mkdir -p "$STACK_DIR/cliproxyapi/logs"
  mkdir -p "$STACK_DIR/gpt-image-2-webui/generated-images"
  mkdir -p "$STACK_DIR/gpt-image-2-webui/logs"
  mkdir -p "$STACK_DIR/nginx/conf.d"
  mkdir -p "$STACK_DIR/nginx/certs"
}

write_env_file() {
  local env_file="$STACK_DIR/.env"

  {
    write_env_line "COMPOSE_PROJECT_NAME" "$PROJECT_NAME_VALUE"
    write_env_line "TZ" "$TZ_VALUE"
    write_env_line "APP_NET_NAME" "$APP_NET_NAME_VALUE"
    write_env_line "NEWAPI_IMAGE" "$NEWAPI_IMAGE_VALUE"
    write_env_line "NEWAPI_PUBLISH_HOST_PORT" "$NEWAPI_PUBLISH_HOST_PORT_VALUE"
    write_env_line "NEWAPI_HOST_PORT" "$NEWAPI_HOST_PORT_VALUE"
    write_env_line "NEWAPI_SESSION_SECRET" "$NEWAPI_SESSION_SECRET_VALUE"
    write_env_line "NEWAPI_CRYPTO_SECRET" "$NEWAPI_CRYPTO_SECRET_VALUE"
    write_env_line "NEWAPI_ERROR_LOG_ENABLED" "$NEWAPI_ERROR_LOG_ENABLED_VALUE"
    write_env_line "NEWAPI_BATCH_UPDATE_ENABLED" "$NEWAPI_BATCH_UPDATE_ENABLED_VALUE"
    write_env_line "NEWAPI_MAX_REQUEST_BODY_MB" "$NEWAPI_MAX_REQUEST_BODY_MB_VALUE"
    write_env_line "NEWAPI_MAX_FILE_DOWNLOAD_MB" "$NEWAPI_MAX_FILE_DOWNLOAD_MB_VALUE"
    write_env_line "POSTGRES_IMAGE" "$POSTGRES_IMAGE_VALUE"
    write_env_line "POSTGRES_USER" "$POSTGRES_USER_VALUE"
    write_env_line "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD_VALUE"
    write_env_line "POSTGRES_DB" "$POSTGRES_DB_VALUE"
    write_env_line "REDIS_IMAGE" "$REDIS_IMAGE_VALUE"
    write_env_line "CLIPROXY_IMAGE" "$CLIPROXY_IMAGE_VALUE"
    write_env_line "CLIPROXY_DEPLOY" "$CLIPROXY_DEPLOY_VALUE"
    write_env_line "CLIPROXY_REMOTE_SECRET" "$CLIPROXY_REMOTE_SECRET_VALUE"
    write_env_line "CLIPROXY_API_KEY" "$CLIPROXY_API_KEY_VALUE"
    write_env_line "CLIPROXY_PUBLISH_HOST_PORTS" "$CLIPROXY_PUBLISH_HOST_PORTS_VALUE"
    write_env_line "CLIPROXY_PORT_8317" "$CLIPROXY_PORT_8317_VALUE"
    write_env_line "CLIPROXY_PORT_8085" "$CLIPROXY_PORT_8085_VALUE"
    write_env_line "CLIPROXY_PORT_1455" "$CLIPROXY_PORT_1455_VALUE"
    write_env_line "CLIPROXY_PORT_54545" "$CLIPROXY_PORT_54545_VALUE"
    write_env_line "CLIPROXY_PORT_51121" "$CLIPROXY_PORT_51121_VALUE"
    write_env_line "CLIPROXY_PORT_11451" "$CLIPROXY_PORT_11451_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_IMAGE" "$GPT_IMAGE_WEBUI_IMAGE_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT" "$GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_HOST_PORT" "$GPT_IMAGE_WEBUI_HOST_PORT_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_OPENAI_API_KEY" "$GPT_IMAGE_WEBUI_OPENAI_API_KEY_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL" "$GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_OPENAI_IMAGE_TIMEOUT_MS" "$GPT_IMAGE_WEBUI_OPENAI_IMAGE_TIMEOUT_MS_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_STORAGE_MODE" "$GPT_IMAGE_WEBUI_STORAGE_MODE_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_APP_PASSWORD" "$GPT_IMAGE_WEBUI_APP_PASSWORD_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_CLEANUP_ENABLED" "$GPT_IMAGE_WEBUI_CLEANUP_ENABLED_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_RETENTION_DAYS" "$GPT_IMAGE_WEBUI_RETENTION_DAYS_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_CLEANUP_INTERVAL_HOURS" "$GPT_IMAGE_WEBUI_CLEANUP_INTERVAL_HOURS_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_CLEANUP_RUN_ON_START" "$GPT_IMAGE_WEBUI_CLEANUP_RUN_ON_START_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_CLEANUP_DRY_RUN" "$GPT_IMAGE_WEBUI_CLEANUP_DRY_RUN_VALUE"
    write_env_line "GPT_IMAGE_WEBUI_CLEANUP_LOG_FILE" "$GPT_IMAGE_WEBUI_CLEANUP_LOG_FILE_VALUE"
    write_env_line "NGINX_IMAGE" "$NGINX_IMAGE_VALUE"
    write_env_line "NGINX_DEPLOY_MODE" "$NGINX_DEPLOY_MODE_VALUE"
    write_env_line "NGINX_ENABLE_HTTPS" "$NGINX_ENABLE_HTTPS"
    write_env_line "NGINX_SHARE_CERT" "$NGINX_SHARE_CERT_VALUE"
    write_env_line "NGINX_HTTP_TO_HTTPS_REDIRECT" "$NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE"
    write_env_line "NGINX_HTTP_PORT" "$NGINX_HTTP_PORT_VALUE"
    write_env_line "NGINX_HTTPS_PORT" "$NGINX_HTTPS_PORT_VALUE"
    write_env_line "NGINX_LAN_API_PORT" "$NGINX_LAN_API_PORT_VALUE"
    write_env_line "NGINX_LAN_ADMIN_PORT" "$NGINX_LAN_ADMIN_PORT_VALUE"
    write_env_line "NGINX_LAN_WEBUI_PORT" "$NGINX_LAN_WEBUI_PORT_VALUE"
    write_env_line "NGINX_HTTP_SERVER_NAMES" "$NGINX_HTTP_SERVER_NAMES_VALUE"
    write_env_line "NGINX_API_SERVER_NAMES" "$NGINX_API_SERVER_NAMES_VALUE"
    write_env_line "NGINX_ADMIN_SERVER_NAME" "$NGINX_ADMIN_SERVER_NAME_VALUE"
    write_env_line "NGINX_WEBUI_SERVER_NAMES" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
    write_env_line "NGINX_API_CERT" "$NGINX_API_CERT_VALUE"
    write_env_line "NGINX_API_KEY" "$NGINX_API_KEY_VALUE"
    write_env_line "NGINX_ADMIN_CERT" "$NGINX_ADMIN_CERT_VALUE"
    write_env_line "NGINX_ADMIN_KEY" "$NGINX_ADMIN_KEY_VALUE"
    write_env_line "NGINX_WEBUI_CERT" "$NGINX_WEBUI_CERT_VALUE"
    write_env_line "NGINX_WEBUI_KEY" "$NGINX_WEBUI_KEY_VALUE"
    write_env_line "NGINX_NEWAPI_UPSTREAM" "$NGINX_NEWAPI_UPSTREAM_VALUE"
    write_env_line "NGINX_CLIPROXY_UPSTREAM" "$NGINX_CLIPROXY_UPSTREAM_VALUE"
    write_env_line "NGINX_GPT_IMAGE_WEBUI_UPSTREAM" "$NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE"
  } > "$env_file"
}

write_clipproxy_config() {
  local config_file="$STACK_DIR/cliproxyapi/config.yaml"

  cat > "$config_file" <<YAML
host: ""
port: 8317
tls:
  enable: false
  cert: ""
  key: ""
remote-management:
  allow-remote: true
  secret-key: $(yaml_quote "$CLIPROXY_REMOTE_SECRET_VALUE")
  disable-control-panel: false
  panel-github-repository: "https://github.com/kongkongyo/Cli-Proxy-API-Management-Center"
auth-dir: "~/.cli-proxy-api"
api-keys:
  - $(yaml_quote "$CLIPROXY_API_KEY_VALUE")
debug: true
pprof:
  enable: false
  addr: "127.0.0.1:8316"
commercial-mode: true
logging-to-file: false
logs-max-total-size-mb: 0
error-logs-max-files: 10
usage-statistics-enabled: true
proxy-url: ""
force-model-prefix: false
passthrough-headers: false
request-retry: 3
max-retry-credentials: 0
max-retry-interval: 30
quota-exceeded:
  switch-project: true
  switch-preview-model: true
routing:
  strategy: "round-robin"
ws-auth: false
nonstream-keepalive-interval: 0
YAML
}

write_nginx_conf() {
  local active_conf="$STACK_DIR/nginx/conf.d/default.conf"

  if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
    cat > "$active_conf" <<NGINX
# 局域网模式
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

# 1. New API
server {
    listen 80 default_server;
    server_name _;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_NEWAPI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}

# 2. CPA / CLIProxyAPI
server {
    listen 8080 default_server;
    server_name _;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_CLIPROXY_UPSTREAM_VALUE};
        proxy_connect_timeout 600s;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
    }
}

# 3. GPT Image WebUI
server {
    listen 8081 default_server;
    server_name _;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
NGINX
    return
  fi

  if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
    if [[ "$NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE" == "true" ]]; then
      if [[ "$NGINX_HTTPS_PORT_VALUE" == "443" ]]; then
        cat > "$active_conf" <<NGINX
# HTTP 自动跳转 HTTPS
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

# 访问入口
server {
    listen 80;
    server_name ${NGINX_HTTP_SERVER_NAMES_VALUE};

    return 301 https://\$host\$request_uri;
}

# 1. API 服务 (New API)
server {
    listen 443 ssl;
    server_name ${NGINX_API_SERVER_NAMES_VALUE};

    ssl_certificate      /etc/nginx/certs/${NGINX_API_CERT_VALUE};
    ssl_certificate_key  /etc/nginx/certs/${NGINX_API_KEY_VALUE};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_NEWAPI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}

# 2. 管理后台 (CPA / CLIProxyAPI)
server {
    listen 443 ssl;
    server_name ${NGINX_ADMIN_SERVER_NAME_VALUE};

    ssl_certificate      /etc/nginx/certs/${NGINX_ADMIN_CERT_VALUE};
    ssl_certificate_key  /etc/nginx/certs/${NGINX_ADMIN_KEY_VALUE};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_CLIPROXY_UPSTREAM_VALUE};
        proxy_connect_timeout 600s;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
    }
}

# 3. GPT Image WebUI
server {
    listen 443 ssl;
    server_name ${NGINX_WEBUI_SERVER_NAMES_VALUE};

    ssl_certificate      /etc/nginx/certs/${NGINX_WEBUI_CERT_VALUE};
    ssl_certificate_key  /etc/nginx/certs/${NGINX_WEBUI_KEY_VALUE};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}

NGINX
      else
        cat > "$active_conf" <<NGINX
# HTTP 自动跳转 HTTPS
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

# 访问入口
server {
    listen 80;
    server_name ${NGINX_HTTP_SERVER_NAMES_VALUE};

    return 301 https://\$host:${NGINX_HTTPS_PORT_VALUE}\$request_uri;
}

# 1. API 服务 (New API)
server {
    listen 443 ssl;
    server_name ${NGINX_API_SERVER_NAMES_VALUE};

    ssl_certificate      /etc/nginx/certs/${NGINX_API_CERT_VALUE};
    ssl_certificate_key  /etc/nginx/certs/${NGINX_API_KEY_VALUE};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_NEWAPI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}

# 2. 管理后台 (CPA / CLIProxyAPI)
server {
    listen 443 ssl;
    server_name ${NGINX_ADMIN_SERVER_NAME_VALUE};

    ssl_certificate      /etc/nginx/certs/${NGINX_ADMIN_CERT_VALUE};
    ssl_certificate_key  /etc/nginx/certs/${NGINX_ADMIN_KEY_VALUE};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_CLIPROXY_UPSTREAM_VALUE};
        proxy_connect_timeout 600s;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
    }
}

# 3. GPT Image WebUI
server {
    listen 443 ssl;
    server_name ${NGINX_WEBUI_SERVER_NAMES_VALUE};

    ssl_certificate      /etc/nginx/certs/${NGINX_WEBUI_CERT_VALUE};
    ssl_certificate_key  /etc/nginx/certs/${NGINX_WEBUI_KEY_VALUE};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
NGINX
      fi
    else
      cat > "$active_conf" <<NGINX
# HTTP / HTTPS 双入口，不做强制跳转
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

# 1. API 服务 (New API) - HTTP
server {
    listen 80;
    server_name ${NGINX_API_SERVER_NAMES_VALUE};

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_NEWAPI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}

# 2. 管理后台 (CPA / CLIProxyAPI) - HTTP
server {
    listen 80;
    server_name ${NGINX_ADMIN_SERVER_NAME_VALUE};

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_CLIPROXY_UPSTREAM_VALUE};
        proxy_connect_timeout 600s;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
    }
}

# 3. GPT Image WebUI - HTTP
server {
    listen 80;
    server_name ${NGINX_WEBUI_SERVER_NAMES_VALUE};

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}

# 4. API 服务 (New API) - HTTPS
server {
    listen 443 ssl;
    server_name ${NGINX_API_SERVER_NAMES_VALUE};

    ssl_certificate      /etc/nginx/certs/${NGINX_API_CERT_VALUE};
    ssl_certificate_key  /etc/nginx/certs/${NGINX_API_KEY_VALUE};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_NEWAPI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}

# 5. 管理后台 (CPA / CLIProxyAPI) - HTTPS
server {
    listen 443 ssl;
    server_name ${NGINX_ADMIN_SERVER_NAME_VALUE};

    ssl_certificate      /etc/nginx/certs/${NGINX_ADMIN_CERT_VALUE};
    ssl_certificate_key  /etc/nginx/certs/${NGINX_ADMIN_KEY_VALUE};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_CLIPROXY_UPSTREAM_VALUE};
        proxy_connect_timeout 600s;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
    }
}

# 6. GPT Image WebUI - HTTPS
server {
    listen 443 ssl;
    server_name ${NGINX_WEBUI_SERVER_NAMES_VALUE};

    ssl_certificate      /etc/nginx/certs/${NGINX_WEBUI_CERT_VALUE};
    ssl_certificate_key  /etc/nginx/certs/${NGINX_WEBUI_KEY_VALUE};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
NGINX
    fi
    return
  fi

  cat > "$active_conf" <<NGINX
# HTTP 模式
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

# 1. API 服务 (New API)
server {
    listen 80;
    server_name ${NGINX_API_SERVER_NAMES_VALUE};

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_NEWAPI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}

# 2. 管理后台 (CPA / CLIProxyAPI)
server {
    listen 80;
    server_name ${NGINX_ADMIN_SERVER_NAME_VALUE};

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_CLIPROXY_UPSTREAM_VALUE};
        proxy_connect_timeout 600s;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
    }
}

# 3. GPT Image WebUI
server {
    listen 80;
    server_name ${NGINX_WEBUI_SERVER_NAMES_VALUE};

    client_max_body_size 0;

    location / {
        proxy_pass http://${NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
NGINX
}

validate_nginx_certificates() {
  local certs=()
  local file=""

  needs_nginx_config || return 0
  [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_ENABLE_HTTPS" == "true" ]] || return 0

  certs+=("$NGINX_API_CERT_VALUE" "$NGINX_API_KEY_VALUE")
  if [[ "$NGINX_SHARE_CERT_VALUE" != "true" ]]; then
    certs+=("$NGINX_ADMIN_CERT_VALUE" "$NGINX_ADMIN_KEY_VALUE")
    certs+=("$NGINX_WEBUI_CERT_VALUE" "$NGINX_WEBUI_KEY_VALUE")
  fi

  for file in "${certs[@]}"; do
    [[ -n "$file" ]] || die "HTTPS 证书文件名不能为空。"
    [[ "$file" != /* && "$file" != *".."* ]] || die "证书文件名只填写 nginx/certs 下的文件名，不要填写路径：$file"
    [[ -f "$STACK_DIR/nginx/certs/$file" ]] || die "未找到证书文件：$STACK_DIR/nginx/certs/$file。请先签发/安装证书，或确认部署时填写的文件名。"
  done
}

write_compose_file() {
  local compose_file="$STACK_DIR/docker-compose.yml"

  cat > "$compose_file" <<'YAML'
services:
  new-api:
    image: "${NEWAPI_IMAGE:-calciumion/new-api:latest}"
    restart: unless-stopped
    command: --log-dir /app/logs
YAML

  if [[ "$NEWAPI_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
    cat >> "$compose_file" <<'YAML'
    ports:
      - "${NEWAPI_HOST_PORT:-3000}:3000"
YAML
  fi

  cat >> "$compose_file" <<'YAML'
    volumes:
      - ./new-api/data:/data
      - ./new-api/logs:/app/logs
    environment:
      TZ: "${TZ:-Asia/Shanghai}"
      SQL_DSN: "postgresql://${POSTGRES_USER:-newapi}:${POSTGRES_PASSWORD:-change-me}@postgres:5432/${POSTGRES_DB:-new-api}?sslmode=disable"
      REDIS_CONN_STRING: "redis://redis:6379/0"
      SESSION_SECRET: "${NEWAPI_SESSION_SECRET:-change-me-session-secret}"
      CRYPTO_SECRET: "${NEWAPI_CRYPTO_SECRET:-change-me-crypto-secret}"
      ERROR_LOG_ENABLED: "${NEWAPI_ERROR_LOG_ENABLED:-true}"
      BATCH_UPDATE_ENABLED: "${NEWAPI_BATCH_UPDATE_ENABLED:-true}"
      MAX_REQUEST_BODY_MB: "${NEWAPI_MAX_REQUEST_BODY_MB:-10240}"
      MAX_FILE_DOWNLOAD_MB: "${NEWAPI_MAX_FILE_DOWNLOAD_MB:-10240}"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "wget -q -O - http://127.0.0.1:3000/api/status | grep -Eq '\"success\"[[:space:]]*:[[:space:]]*true'",
        ]
      interval: 30s
      timeout: 10s
      retries: 5
    networks:
      public-net:
        aliases:
          - newapi-new-api-1
      stack-internal: {}

  postgres:
    image: "${POSTGRES_IMAGE:-postgres:15}"
    restart: unless-stopped
    environment:
      TZ: "${TZ:-Asia/Shanghai}"
      POSTGRES_USER: "${POSTGRES_USER:-newapi}"
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-change-me}"
      POSTGRES_DB: "${POSTGRES_DB:-new-api}"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-newapi} -d ${POSTGRES_DB:-new-api}"]
      interval: 5s
      timeout: 5s
      retries: 20
    networks:
      - stack-internal

  redis:
    image: "${REDIS_IMAGE:-redis:7-alpine}"
    restart: unless-stopped
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD-SHELL", "redis-cli ping | grep -q PONG"]
      interval: 5s
      timeout: 5s
      retries: 20
    networks:
      - stack-internal

  cli-proxy-api:
    image: "${CLIPROXY_IMAGE:-eceasy/cli-proxy-api:latest}"
    restart: unless-stopped
    environment:
      TZ: "${TZ:-Asia/Shanghai}"
      DEPLOY: "${CLIPROXY_DEPLOY:-}"
YAML

  if [[ "$CLIPROXY_PUBLISH_HOST_PORTS_VALUE" == "true" ]]; then
    cat >> "$compose_file" <<'YAML'
    ports:
      - "${CLIPROXY_PORT_8317:-8317}:8317"
      - "${CLIPROXY_PORT_8085:-8085}:8085"
      - "${CLIPROXY_PORT_1455:-1455}:1455"
      - "${CLIPROXY_PORT_54545:-54545}:54545"
      - "${CLIPROXY_PORT_51121:-51121}:51121"
      - "${CLIPROXY_PORT_11451:-11451}:11451"
YAML
  fi

  cat >> "$compose_file" <<'YAML'
    volumes:
      - ./cliproxyapi/config.yaml:/CLIProxyAPI/config.yaml
      - ./cliproxyapi/auths:/root/.cli-proxy-api
      - ./cliproxyapi/logs:/CLIProxyAPI/logs
    networks:
      - public-net

  gpt-image-2-webui:
    image: "${GPT_IMAGE_WEBUI_IMAGE:-tannic666/gpt-image-2-webui:latest}"
    restart: unless-stopped
    environment:
      NODE_ENV: production
      OPENAI_API_KEY: "${GPT_IMAGE_WEBUI_OPENAI_API_KEY:-}"
      OPENAI_API_BASE_URL: "${GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL:-}"
      OPENAI_IMAGE_TIMEOUT_MS: "${GPT_IMAGE_WEBUI_OPENAI_IMAGE_TIMEOUT_MS:-1200000}"
      NEXT_PUBLIC_IMAGE_STORAGE_MODE: "${GPT_IMAGE_WEBUI_STORAGE_MODE:-fs}"
      APP_PASSWORD: "${GPT_IMAGE_WEBUI_APP_PASSWORD:-}"
      GENERATED_IMAGE_CLEANUP_ENABLED: "${GPT_IMAGE_WEBUI_CLEANUP_ENABLED:-true}"
      GENERATED_IMAGE_RETENTION_DAYS: "${GPT_IMAGE_WEBUI_RETENTION_DAYS:-3}"
      GENERATED_IMAGE_CLEANUP_INTERVAL_HOURS: "${GPT_IMAGE_WEBUI_CLEANUP_INTERVAL_HOURS:-24}"
      GENERATED_IMAGE_CLEANUP_RUN_ON_START: "${GPT_IMAGE_WEBUI_CLEANUP_RUN_ON_START:-true}"
      GENERATED_IMAGE_CLEANUP_DRY_RUN: "${GPT_IMAGE_WEBUI_CLEANUP_DRY_RUN:-false}"
      GENERATED_IMAGE_CLEANUP_LOG_FILE: "${GPT_IMAGE_WEBUI_CLEANUP_LOG_FILE:-/app/logs/cleanup-generated-images.log}"
YAML

  if [[ "$GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
    cat >> "$compose_file" <<'YAML'
    ports:
      - "${GPT_IMAGE_WEBUI_HOST_PORT:-3001}:3000"
YAML
  fi

  cat >> "$compose_file" <<'YAML'
    volumes:
      - ./gpt-image-2-webui/generated-images:/app/generated-images
      - ./gpt-image-2-webui/logs:/app/logs
    networks:
      - public-net

  nginx:
    image: "${NGINX_IMAGE:-nginx:alpine}"
    restart: unless-stopped
    ports:
YAML

  if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
    cat >> "$compose_file" <<'YAML'
      - "${NGINX_LAN_API_PORT:-80}:80"
      - "${NGINX_LAN_ADMIN_PORT:-8080}:8080"
      - "${NGINX_LAN_WEBUI_PORT:-8081}:8081"
YAML
  else
    cat >> "$compose_file" <<'YAML'
      - "${NGINX_HTTP_PORT:-80}:80"
YAML
  fi

  if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_ENABLE_HTTPS" == "true" ]]; then
    cat >> "$compose_file" <<'YAML'
      - "${NGINX_HTTPS_PORT:-443}:443"
YAML
  fi

  cat >> "$compose_file" <<'YAML'
    volumes:
      - ./nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf:ro
YAML

  if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_ENABLE_HTTPS" == "true" ]]; then
    cat >> "$compose_file" <<'YAML'
      - ./nginx/certs:/etc/nginx/certs:ro
YAML
  fi

  cat >> "$compose_file" <<'YAML'
    depends_on:
      - new-api
      - cli-proxy-api
      - gpt-image-2-webui
    networks:
      - public-net

volumes:
  postgres-data:
  redis-data:

networks:
YAML

  if [[ "$USE_EXTERNAL_APP_NET" == "true" ]]; then
    cat >> "$compose_file" <<'YAML'
  public-net:
    name: "${APP_NET_NAME:-app-net}"
    external: true
YAML
  else
    cat >> "$compose_file" <<'YAML'
  public-net:
    driver: bridge
YAML
  fi

  cat >> "$compose_file" <<'YAML'
  stack-internal:
    driver: bridge
YAML
}

write_files() {
  prepare_directories
  write_env_file
  write_clipproxy_config
  write_nginx_conf
  validate_nginx_certificates
  write_compose_file
}

ensure_app_net() {
  if [[ "$USE_EXTERNAL_APP_NET" != "true" ]]; then
    return
  fi

  if docker network inspect "$APP_NET_NAME_VALUE" >/dev/null 2>&1; then
    printf 'Docker 网络已存在：%s\n' "$APP_NET_NAME_VALUE"
    return
  fi

  if [[ "$CREATE_APP_NET" == "true" ]]; then
    docker network create "$APP_NET_NAME_VALUE" >/dev/null
    printf '已创建 Docker 网络：%s\n' "$APP_NET_NAME_VALUE"
    return
  fi

  die "外部网络 '$APP_NET_NAME_VALUE' 不存在。请重新运行并允许创建，或者手动创建。"
}

safe_remove_dir() {
  local target="$1"
  local resolved="$target"

  if command -v realpath >/dev/null 2>&1; then
    resolved="$(realpath -m "$target")"
  fi

  case "$resolved" in
    ""|"/"|"$HOME"|"$CURRENT_DIR")
      die "拒绝删除危险路径：$resolved"
      ;;
  esac

  rm -rf -- "$resolved"
}

run_compose() {
  local args=(--env-file "$STACK_DIR/.env" up -d)

  if [[ "$DEPLOY_ALL" != "true" ]]; then
    args+=("${SELECTED_SERVICES[@]}")
  fi

  section_title "执行部署"
  printf '%s\n' "$(color_text "$COLOR_MAGENTA" "正在执行 Docker Compose...")"
  printf '%s\n' "$(color_text "$COLOR_DIM" "命令：${DOCKER_COMPOSE[*]} ${args[*]}")"
  (
    cd "$STACK_DIR"
    "${DOCKER_COMPOSE[@]}" "${args[@]}"
    "${DOCKER_COMPOSE[@]}" --env-file "$STACK_DIR/.env" ps
  )
}

print_summary() {
  local lan_ip=""
  local api_primary=""
  local admin_primary=""
  local webui_primary=""
  local newapi_url=""
  local cliproxy_url=""
  local webui_url=""

  lan_ip="$(detect_lan_ip)"
  api_primary="$(first_word "$NGINX_API_SERVER_NAMES_VALUE")"
  admin_primary="$(first_word "$NGINX_ADMIN_SERVER_NAME_VALUE")"
  webui_primary="$(first_word "$NGINX_WEBUI_SERVER_NAMES_VALUE")"

  if needs_nginx_config; then
    if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
      if [[ -n "$lan_ip" ]]; then
        newapi_url="http://${lan_ip}:${NGINX_LAN_API_PORT_VALUE}"
        cliproxy_url="http://${lan_ip}:${NGINX_LAN_ADMIN_PORT_VALUE}"
        webui_url="http://${lan_ip}:${NGINX_LAN_WEBUI_PORT_VALUE}"
      else
        newapi_url="http://服务器IP:${NGINX_LAN_API_PORT_VALUE}"
        cliproxy_url="http://服务器IP:${NGINX_LAN_ADMIN_PORT_VALUE}"
        webui_url="http://服务器IP:${NGINX_LAN_WEBUI_PORT_VALUE}"
      fi
    elif [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
      newapi_url="$(url_with_port https "$api_primary" "$NGINX_HTTPS_PORT_VALUE")"
      cliproxy_url="$(url_with_port https "$admin_primary" "$NGINX_HTTPS_PORT_VALUE")"
      webui_url="$(url_with_port https "$webui_primary" "$NGINX_HTTPS_PORT_VALUE")"
    else
      newapi_url="$(url_with_port http "$api_primary" "$NGINX_HTTP_PORT_VALUE")"
      cliproxy_url="$(url_with_port http "$admin_primary" "$NGINX_HTTP_PORT_VALUE")"
      webui_url="$(url_with_port http "$webui_primary" "$NGINX_HTTP_PORT_VALUE")"
    fi
  else
    newapi_url="http://服务器IP:${NEWAPI_HOST_PORT_VALUE}"
    cliproxy_url="http://服务器IP:${CLIPROXY_PORT_8317_VALUE}"
    webui_url="http://服务器IP:${GPT_IMAGE_WEBUI_HOST_PORT_VALUE}"
  fi

  section_title "部署完成"
  field_line "安装目录：" "$STACK_DIR"
  field_line "Compose 文件：" "$STACK_DIR/docker-compose.yml"
  field_line "环境文件：" "$STACK_DIR/.env"

  if needs_nginx_config; then
    section_title "Nginx 入口"
    if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
      field_line "Nginx 模式：" "局域网，不需要域名。"
      field_line "New API 入口端口：" "$NGINX_LAN_API_PORT_VALUE"
      field_line "CPA 入口端口：" "$NGINX_LAN_ADMIN_PORT_VALUE"
      field_line "GPT Image WebUI 入口端口：" "$NGINX_LAN_WEBUI_PORT_VALUE"
    else
      field_line "Nginx 模式：" "公网，按域名转发。"
      field_line "New API 绑定域名：" "$NGINX_API_SERVER_NAMES_VALUE"
      field_line "CPA 绑定域名：" "$NGINX_ADMIN_SERVER_NAME_VALUE"
      field_line "GPT Image WebUI 绑定域名：" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
      field_line "公网 HTTP 端口：" "$NGINX_HTTP_PORT_VALUE"
      if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
        field_line "公网 HTTPS 端口：" "$NGINX_HTTPS_PORT_VALUE"
        if [[ "$NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE" == "true" ]]; then
          field_line "HTTP 80 -> HTTPS：" "301 重定向到 ${NGINX_HTTPS_PORT_VALUE}"
        else
          field_line "HTTP 80 -> HTTPS：" "不重定向，HTTP/HTTPS 都可用"
        fi
      fi
    fi
    field_line "Nginx 配置文件：" "$STACK_DIR/nginx/conf.d/default.conf"
  fi

  if needs_newapi_config; then
    section_title "New API 信息"
    field_line "访问地址：" "$newapi_url"
    if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_API_SERVER_NAMES_VALUE" != "" ]]; then
      field_line "绑定域名：" "$NGINX_API_SERVER_NAMES_VALUE"
    fi
    field_line "SESSION_SECRET：" "$NEWAPI_SESSION_SECRET_VALUE"
    field_line "CRYPTO_SECRET：" "$NEWAPI_CRYPTO_SECRET_VALUE"
    subtle_note "上面两个是 New API 内部会话签名和数据加密密钥，不是后台登录密码；部署后不要随便修改。"
    if [[ "$NEWAPI_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
      field_line "直连端口：" "$NEWAPI_HOST_PORT_VALUE"
    else
      subtle_note "New API 未映射宿主机端口，只通过 Nginx / Docker 网络访问。"
    fi
  fi

  if needs_cliproxy_config; then
    section_title "CPA / CLIProxyAPI 信息"
    field_line "访问地址：" "$cliproxy_url"
    field_line "配置文件：" "$STACK_DIR/cliproxyapi/config.yaml"
    if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_ADMIN_SERVER_NAME_VALUE" != "" ]]; then
      field_line "绑定域名：" "$NGINX_ADMIN_SERVER_NAME_VALUE"
    fi
    field_line "远程管理密钥：" "$CLIPROXY_REMOTE_SECRET_VALUE"
    field_line "API Key：" "$CLIPROXY_API_KEY_VALUE"
    if [[ "$CLIPROXY_PUBLISH_HOST_PORTS_VALUE" != "true" ]]; then
      subtle_note "CLIProxyAPI 未映射宿主机端口，只通过 Nginx / Docker 网络访问。"
    else
      field_line "8317 直连端口：" "$CLIPROXY_PORT_8317_VALUE"
      field_line "8085 直连端口：" "$CLIPROXY_PORT_8085_VALUE"
      field_line "1455 直连端口：" "$CLIPROXY_PORT_1455_VALUE"
      field_line "54545 直连端口：" "$CLIPROXY_PORT_54545_VALUE"
      field_line "51121 直连端口：" "$CLIPROXY_PORT_51121_VALUE"
      field_line "11451 直连端口：" "$CLIPROXY_PORT_11451_VALUE"
    fi
  fi

  if needs_gpt_image_webui_config; then
    section_title "GPT Image WebUI 信息"
    field_line "访问地址：" "$webui_url"
    field_line "图片目录：" "$STACK_DIR/gpt-image-2-webui/generated-images"
    field_line "日志目录：" "$STACK_DIR/gpt-image-2-webui/logs"
    if needs_nginx_config && [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_WEBUI_SERVER_NAMES_VALUE" != "" ]]; then
      field_line "绑定域名：" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
    fi
    if [[ -n "$GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL_VALUE" ]]; then
      field_line "默认 Base URL：" "$GPT_IMAGE_WEBUI_OPENAI_API_BASE_URL_VALUE"
    else
      subtle_note "默认 Base URL 为空，用户可在 WebUI 页面填写。"
    fi
    if [[ -n "$GPT_IMAGE_WEBUI_APP_PASSWORD_VALUE" ]]; then
      field_line "访问密码：" "$GPT_IMAGE_WEBUI_APP_PASSWORD_VALUE"
    fi
    if [[ "$GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE" != "true" ]]; then
      subtle_note "GPT Image WebUI 未映射宿主机端口，只通过 Nginx / Docker 网络访问。"
    else
      field_line "直连端口：" "$GPT_IMAGE_WEBUI_HOST_PORT_VALUE"
    fi
  fi

  if needs_postgres_config; then
    section_title "PostgreSQL / Redis 信息"
    field_line "PostgreSQL 用户名：" "$POSTGRES_USER_VALUE"
    field_line "PostgreSQL 密码：" "$POSTGRES_PASSWORD_VALUE"
    field_line "PostgreSQL 数据库名：" "$POSTGRES_DB_VALUE"
    field_line "Redis：" "内部网络 redis:6379，无宿主机端口映射。"
  fi

  if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_ENABLE_HTTPS" == "true" ]]; then
    section_title "证书信息"
    field_line "证书目录：" "$STACK_DIR/nginx/certs"
    if [[ "$NGINX_SHARE_CERT_VALUE" == "true" ]]; then
      field_line "共用证书：" "是"
      field_line "证书文件：" "$NGINX_API_CERT_VALUE"
      field_line "私钥文件：" "$NGINX_API_KEY_VALUE"
    else
      field_line "共用证书：" "否"
      field_line "New API 证书：" "$NGINX_API_CERT_VALUE"
      field_line "New API 私钥：" "$NGINX_API_KEY_VALUE"
      field_line "CPA 证书：" "$NGINX_ADMIN_CERT_VALUE"
      field_line "CPA 私钥：" "$NGINX_ADMIN_KEY_VALUE"
      field_line "GPT Image WebUI 证书：" "$NGINX_WEBUI_CERT_VALUE"
      field_line "GPT Image WebUI 私钥：" "$NGINX_WEBUI_KEY_VALUE"
    fi
  fi
}

update_stack() {
  local prune_images="false"
  local target_label="全部服务"

  section_title "更新服务镜像/容器"
  prepare_existing_stack "要更新的部署目录"
  select_compose_targets

  if [[ "${#COMPOSE_TARGETS[@]}" -gt 0 ]]; then
    target_label="$(join_list "${COMPOSE_TARGETS[@]}")"
  fi

  field_line "部署目录：" "$STACK_DIR"
  field_line "更新范围：" "$target_label"

  section_title "拉取镜像"
  (
    cd "$STACK_DIR"
    compose_stack pull "${COMPOSE_TARGETS[@]}"
  )

  section_title "重建并启动"
  (
    cd "$STACK_DIR"
    compose_stack up -d "${COMPOSE_TARGETS[@]}"
    compose_stack ps
  )

  read_yes_no prune_images "是否清理未使用的旧镜像" "$prune_images"
  if [[ "$prune_images" == "true" ]]; then
    section_title "清理旧镜像"
    docker image prune -f
  fi

  section_title "更新完成"
}

show_nginx_menu() {
  section_title "Nginx 管理"
  menu_option "$COLOR_GREEN" "[1]" "测试 Nginx 配置"
  menu_option "$COLOR_CYAN" "[2]" "重载 Nginx 配置"
  menu_option "$COLOR_BLUE" "[3]" "重启 Nginx 容器"
  menu_option "$COLOR_GREEN" "[4]" "启动/拉起 Nginx"
  menu_option "$COLOR_MAGENTA" "[5]" "查看 Nginx 状态"
  menu_option "$COLOR_YELLOW" "[6]" "查看 Nginx 日志"
  menu_option "$COLOR_DIM" "[7]" "返回/退出"
}

manage_nginx() {
  local action=""

  prepare_existing_stack "Nginx 管理目录"
  field_line "部署目录：" "$STACK_DIR"
  if [[ -f "$STACK_DIR/nginx/conf.d/default.conf" ]]; then
    field_line "配置文件：" "$STACK_DIR/nginx/conf.d/default.conf"
  fi

  while true; do
    show_nginx_menu
    read_line action "请选择 Nginx 操作" "1"
    case "$(lower "$action")" in
      1|test|check)
        section_title "测试 Nginx 配置"
        (
          cd "$STACK_DIR"
          compose_stack exec -T nginx nginx -t
        )
        ;;
      2|reload)
        section_title "重载 Nginx 配置"
        (
          cd "$STACK_DIR"
          compose_stack exec -T nginx nginx -t
          compose_stack exec -T nginx nginx -s reload
        )
        ;;
      3|restart)
        section_title "重启 Nginx 容器"
        (
          cd "$STACK_DIR"
          compose_stack restart nginx
          compose_stack ps nginx
        )
        ;;
      4|start|up)
        section_title "启动/拉起 Nginx"
        (
          cd "$STACK_DIR"
          compose_stack up -d nginx
          compose_stack ps nginx
        )
        ;;
      5|status|ps)
        section_title "Nginx 状态"
        (
          cd "$STACK_DIR"
          compose_stack ps nginx
        )
        ;;
      6|log|logs)
        section_title "Nginx 日志"
        (
          cd "$STACK_DIR"
          compose_stack logs --tail=120 nginx
        )
        ;;
      7|back|exit|quit|q)
        return 0
        ;;
      *)
        printf '%s\n' "$(color_text "$COLOR_YELLOW" "请输入 1-7。")"
        ;;
    esac
  done
}

find_acme_sh() {
  if [[ -x "$HOME/.acme.sh/acme.sh" ]]; then
    printf '%s' "$HOME/.acme.sh/acme.sh"
    return 0
  fi

  if command -v acme.sh >/dev/null 2>&1; then
    command -v acme.sh
    return 0
  fi

  return 1
}

ensure_acme_sh() {
  local email=""
  local install_acme="true"

  if ACME_SH_BIN="$(find_acme_sh)"; then
    field_line "acme.sh：" "$ACME_SH_BIN"
    "$ACME_SH_BIN" --version || true
    return
  fi

  section_title "安装 acme.sh"
  subtle_note "未检测到 acme.sh，将使用官方安装脚本安装到当前用户目录。"
  read_yes_no install_acme "是否现在安装 acme.sh" "$install_acme"
  [[ "$install_acme" == "true" ]] || die "已取消安装 acme.sh。"

  read_line email "acme.sh 注册邮箱" ""
  [[ -n "$email" ]] || die "邮箱不能为空。"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://get.acme.sh | sh -s "email=$email"
  elif command -v wget >/dev/null 2>&1; then
    wget -O - https://get.acme.sh | sh -s "email=$email"
  else
    die "未检测到 curl 或 wget，无法下载安装 acme.sh。"
  fi

  if ACME_SH_BIN="$(find_acme_sh)"; then
    field_line "acme.sh：" "$ACME_SH_BIN"
    "$ACME_SH_BIN" --version || true
    return
  fi

  die "acme.sh 安装后仍未找到，请重新打开终端或检查 ~/.acme.sh/acme.sh。"
}

set_acme_default_ca() {
  local set_ca="true"

  read_yes_no set_ca "是否设置默认 CA 为 Let's Encrypt" "$set_ca"
  if [[ "$set_ca" == "true" ]]; then
    "$ACME_SH_BIN" --set-default-ca --server letsencrypt
  fi
}

write_acme_reload_script() {
  local reload_script="$STACK_DIR/acme-reload-nginx.sh"

  cat > "$reload_script" <<'SH'
#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 0

if ! command -v docker >/dev/null 2>&1; then
  exit 0
fi

if docker compose version >/dev/null 2>&1; then
  docker compose --env-file "$SCRIPT_DIR/.env" exec -T nginx nginx -s reload >/dev/null 2>&1 || true
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose --env-file "$SCRIPT_DIR/.env" exec -T nginx nginx -s reload >/dev/null 2>&1 || true
fi
SH

  chmod +x "$reload_script" 2>/dev/null || true
  printf '%s' "$reload_script"
}

prepare_certificate_directory() {
  use_fixed_stack_dir
  show_stack_dir_notice
  ensure_stack_dir_writable
  mkdir -p "$STACK_DIR/nginx/certs"
}

issue_aliyun_certificate() {
  local base_domain=""
  local include_wildcard="true"
  local ali_key=""
  local ali_secret=""
  local use_existing_ali="false"
  local cert_file=""
  local key_file=""
  local cert_path=""
  local key_path=""
  local reload_script=""
  local reload_cmd=""
  local domain_args=()

  section_title "阿里云 DNS 签发证书"
  ensure_acme_sh
  set_acme_default_ca
  prepare_certificate_directory

  subtle_note "请先在阿里云 RAM 给用于签证书的用户授权 AliyunDNSFullAccess 或等价 DNS 解析权限。"
  subtle_note "Ali_Key / Ali_Secret 会明文输入；acme.sh 可能会保存到 ~/.acme.sh/account.conf 供自动续签使用。"

  if [[ -n "${Ali_Key:-}" && -n "${Ali_Secret:-}" ]]; then
    use_existing_ali="true"
    read_yes_no use_existing_ali "检测到当前环境已有 Ali_Key / Ali_Secret，是否直接使用" "$use_existing_ali"
  fi

  if [[ "$use_existing_ali" == "true" ]]; then
    ali_key="$Ali_Key"
    ali_secret="$Ali_Secret"
  else
    read_line ali_key "Ali_Key（明文）" ""
    read_line ali_secret "Ali_Secret（明文）" ""
  fi

  [[ -n "$ali_key" ]] || die "Ali_Key 不能为空。"
  [[ -n "$ali_secret" ]] || die "Ali_Secret 不能为空。"
  export Ali_Key="$ali_key"
  export Ali_Secret="$ali_secret"

  read_line base_domain "主域名，例如 774966.xyz" ""
  [[ -n "$base_domain" ]] || die "主域名不能为空。"
  read_yes_no include_wildcard "是否同时签发泛域名 *.${base_domain}" "$include_wildcard"

  domain_args=(-d "$base_domain")
  if [[ "$include_wildcard" == "true" ]]; then
    domain_args+=(-d "*.${base_domain}")
  fi

  read_line cert_file "安装后的 fullchain 证书文件名" "${base_domain}.fullchain.cer"
  read_line key_file "安装后的私钥文件名" "${base_domain}.key"
  cert_path="$STACK_DIR/nginx/certs/$cert_file"
  key_path="$STACK_DIR/nginx/certs/$key_file"
  reload_script="$(write_acme_reload_script)"
  reload_cmd="$(dotenv_quote "$reload_script")"

  section_title "签发证书"
  "$ACME_SH_BIN" --issue --dns dns_ali "${domain_args[@]}"

  section_title "安装证书"
  "$ACME_SH_BIN" --install-cert -d "$base_domain" \
    --key-file "$key_path" \
    --fullchain-file "$cert_path" \
    --reloadcmd "$reload_cmd"

  write_last_certificate_metadata "$base_domain" "$cert_file" "$key_file" "$include_wildcard"

  section_title "证书完成"
  field_line "证书目录：" "$STACK_DIR/nginx/certs"
  field_line "fullchain：" "$cert_file"
  field_line "私钥：" "$key_file"
  field_line "证书记忆：" "$(last_certificate_metadata_file)"
  field_line "Nginx 重载脚本：" "$reload_script"
  subtle_note "部署公网 HTTPS 时选择共用证书，并填写上面的 fullchain 和私钥文件名即可。"
}

renew_acme_certificates() {
  section_title "手动续签证书"
  ensure_acme_sh
  "$ACME_SH_BIN" --cron
}

show_certificate_menu() {
  section_title "SSL 证书 / acme.sh"
  menu_option "$COLOR_GREEN" "[1]" "检查/安装 acme.sh"
  menu_option "$COLOR_CYAN" "[2]" "阿里云 DNS 签发并安装证书"
  menu_option "$COLOR_BLUE" "[3]" "手动续签全部证书"
  menu_option "$COLOR_MAGENTA" "[4]" "查看 acme.sh 版本"
  menu_option "$COLOR_DIM" "[5]" "返回/退出"
}

manage_certificates() {
  local action=""

  while true; do
    show_certificate_menu
    read_line action "请选择证书操作" "2"
    case "$(lower "$action")" in
      1|install|check)
        ensure_acme_sh
        set_acme_default_ca
        ;;
      2|issue|cert|ssl|aliyun|ali|dns_ali)
        issue_aliyun_certificate
        ;;
      3|renew|cron)
        renew_acme_certificates
        ;;
      4|version|-v|--version)
        ensure_acme_sh
        "$ACME_SH_BIN" --version || true
        ;;
      5|back|exit|quit|q)
        return 0
        ;;
      *)
        printf '%s\n' "$(color_text "$COLOR_YELLOW" "请输入 1-5。")"
        ;;
    esac
  done
}

uninstall_stack() {
  section_title "卸载部署"
  use_fixed_stack_dir
  show_stack_dir_notice

  if [[ -f "$STACK_DIR/docker-compose.yml" ]]; then
    if try_detect_compose && docker info >/dev/null 2>&1; then
      section_title "停止容器"
      printf '%s\n' "$(color_text "$COLOR_MAGENTA" "正在执行 Docker Compose down...")"
      (
        cd "$STACK_DIR"
        if [[ -f "$STACK_DIR/.env" ]]; then
          "${DOCKER_COMPOSE[@]}" --env-file "$STACK_DIR/.env" down -v --remove-orphans
        else
          "${DOCKER_COMPOSE[@]}" down -v --remove-orphans
        fi
      ) || subtle_note "容器停止失败，将继续清理目录。"
    else
      subtle_note "未检测到可用的 Docker Compose 或 Docker 未运行，跳过容器停止。"
    fi
  else
    subtle_note "未找到 docker-compose.yml，将直接清理目录。"
  fi

  if [[ -d "$STACK_DIR" ]]; then
    local remove_dir="true"
    read_yes_no remove_dir "是否删除安装目录和配置文件" "$remove_dir"
    if [[ "$remove_dir" == "true" ]]; then
      safe_remove_dir "$STACK_DIR"
      printf '%s\n' "$(color_text "$COLOR_GREEN" "已删除目录：$STACK_DIR")"
    fi
  fi

  section_title "卸载完成"
}

show_misc_menu() {
  section_title "杂项"
  menu_option "$COLOR_GREEN" "[1]" "启用 Bash/ls 颜色"
  menu_option "$COLOR_DIM" "[2]" "返回/退出"
}

enable_bash_colors() {
  local target_home="${HOME:-}"
  local bashrc=""
  local backup=""

  section_title "启用 Bash/ls 颜色"

  if [[ -z "$target_home" ]] && command -v getent >/dev/null 2>&1; then
    target_home="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6 || true)"
  fi
  [[ -n "$target_home" ]] || target_home="/root"
  bashrc="$target_home/.bashrc"

  mkdir -p "$(dirname "$bashrc")"
  if [[ -f "$bashrc" ]]; then
    backup="${bashrc}.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$bashrc" "$backup"
    field_line "备份文件：" "$backup"
  else
    touch "$bashrc"
    field_line "创建文件：" "$bashrc"
  fi

  sed -i \
    -e 's/^[[:space:]]*#\([[:space:]]*force_color_prompt=yes\)/\1/' \
    -e 's/^[[:space:]]*#\([[:space:]]*export LS_OPTIONS=.*--color=auto.*\)/\1/' \
    -e 's/^[[:space:]]*#\([[:space:]]*eval "\$(dircolors)".*\)/\1/' \
    -e 's/^[[:space:]]*#\([[:space:]]*alias ls=.*LS_OPTIONS.*\)/\1/' \
    -e 's/^[[:space:]]*#\([[:space:]]*alias ll=.*LS_OPTIONS.*\)/\1/' \
    -e 's/^[[:space:]]*#\([[:space:]]*alias l=.*LS_OPTIONS.*\)/\1/' \
    "$bashrc"

  if ! grep -q "AI API Stack bash colors" "$bashrc"; then
    cat >> "$bashrc" <<'BASHRC'

# AI API Stack bash colors
if [ -n "$PS1" ]; then
  if [ "$(id -u 2>/dev/null)" = "0" ]; then
    __ai_api_stack_prompt_color='01;31m'
  else
    __ai_api_stack_prompt_color='01;32m'
  fi
  PS1='${debian_chroot:+($debian_chroot)}\[\033['"$__ai_api_stack_prompt_color"'\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
  unset __ai_api_stack_prompt_color
fi

if command -v dircolors >/dev/null 2>&1; then
  if [ -r ~/.dircolors ]; then
    eval "$(dircolors -b ~/.dircolors)"
  else
    eval "$(dircolors -b)"
  fi
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
# End AI API Stack bash colors
BASHRC
  fi

  field_line "配置文件：" "$bashrc"
  subtle_note "重新登录 SSH，或执行 source ~/.bashrc 后生效。"
}

manage_misc() {
  local action=""

  while true; do
    show_misc_menu
    read_line action "请选择杂项操作" "1"
    case "$(lower "$action")" in
      1|bash|color|colors|ls|prompt)
        enable_bash_colors
        ;;
      2|back|exit|quit|q)
        return 0
        ;;
      *)
        printf '%s\n' "$(color_text "$COLOR_YELLOW" "请输入 1 或 2。")"
        ;;
    esac
  done
}

print_usage() {
  cat <<'USAGE'
用法:
  bash one-click/deploy.sh
  bash one-click/deploy.sh docker
  bash one-click/deploy.sh mirror
  bash one-click/deploy.sh cert
  bash one-click/deploy.sh deploy
  bash one-click/deploy.sh update
  bash one-click/deploy.sh nginx
  bash one-click/deploy.sh misc
  bash one-click/deploy.sh uninstall
USAGE
}

parse_action() {
  local first_arg="${1:-}"

  case "$(lower "$first_arg")" in
    ""|deploy|up|install|-d|--deploy)
      printf '%s' "deploy"
      ;;
    docker|docker-install|install-docker|setup-docker|--docker)
      printf '%s' "docker"
      ;;
    mirror|docker-mirror|registry-mirror|daemon|--mirror)
      printf '%s' "mirror"
      ;;
    update|pull|upgrade|refresh|sync|--update)
      printf '%s' "update"
      ;;
    cert|ssl|acme|acme.sh|certificate|--cert|--ssl)
      printf '%s' "cert"
      ;;
    nginx|nginx-manage|nginx-manager|--nginx)
      printf '%s' "nginx"
      ;;
    misc|miscellaneous|utils|tools|other|others|--misc)
      printf '%s' "misc"
      ;;
    uninstall|down|remove|rm|-u|--uninstall)
      printf '%s' "uninstall"
      ;;
    -h|--help|help)
      printf '%s' "help"
      ;;
    *)
      printf '%s' "deploy"
      ;;
  esac
}

main() {
  local action=""

  init_ui
  banner

  action="$(parse_action "${1-}")"
  if [[ "$action" == "help" ]]; then
    print_usage
    return 0
  fi

  if [[ -z "${1:-}" && -t 0 ]]; then
    show_main_menu
    while true; do
      read_line action "请选择操作" "1"
      case "$(lower "$action")" in
        1|docker|docker-install|install-docker|setup-docker)
          action="docker"
          break
          ;;
        2|cert|ssl|acme|acme.sh|certificate)
          action="cert"
          break
          ;;
        3|deploy|up|install)
          action="deploy"
          break
          ;;
        4|update|pull|upgrade|refresh|sync)
          action="update"
          break
          ;;
        5|nginx|nginx-manage|nginx-manager)
          action="nginx"
          break
          ;;
        6|mirror|docker-mirror|registry-mirror|daemon)
          action="mirror"
          break
          ;;
        7|uninstall|down|remove|rm)
          action="uninstall"
          break
          ;;
        8|misc|miscellaneous|utils|tools|other|others)
          action="misc"
          break
          ;;
        9|exit|quit|q)
          printf '%s\n' "$(color_text "$COLOR_DIM" "已退出。")"
          return 0
          ;;
        *)
          printf '%s\n' "$(color_text "$COLOR_YELLOW" "请输入 1 到 9。")"
          ;;
      esac
    done
  fi

  subtle_note "输入支持常规命令行编辑，密码项也会明文显示。"

  case "$action" in
    docker)
      install_docker_debian12
      return 0
      ;;
    mirror)
      configure_docker_mirror
      return 0
      ;;
    update)
      update_stack
      return 0
      ;;
    cert)
      manage_certificates
      return 0
      ;;
    nginx)
      manage_nginx
      return 0
      ;;
    misc)
      manage_misc
      return 0
      ;;
    uninstall)
      uninstall_stack
      return 0
      ;;
  esac

  detect_compose
  ensure_docker_ready
  collect_answers
  write_files
  ensure_app_net
  run_compose
  print_summary
}

main "$@"
