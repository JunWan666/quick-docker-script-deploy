#!/usr/bin/env bash
# 交互式一键部署脚本：负责收集输入、生成配置、创建目录并启动 Docker Compose。
set -Eeuo pipefail

SCRIPT_SOURCE=""
if [[ ${BASH_SOURCE[0]+set} == set ]]; then
  SCRIPT_SOURCE="${BASH_SOURCE[0]}"
fi

if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
else
  SCRIPT_DIR="$(pwd)"
fi
CURRENT_DIR="$(pwd)"
DEFAULT_STACK_DIR="/opt/ai-api-stack"

DOCKER_COMPOSE=()
SELECTED_SERVICES=()
COMPOSE_TARGETS=()
EXISTING_APP_SERVICES=()
DEPLOY_ALL=true
EXISTING_STACK=false
PRESERVE_EXISTING_SERVICES=true
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
NEWAPI_PUBLISH_HOST_PORT_VALUE=false
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

NEWAPI_V2_IMAGE_VALUE="tannic666/newapi:latest"
NEWAPI_V2_PUBLISH_HOST_PORT_VALUE=false
NEWAPI_V2_HOST_PORT_VALUE="3002"
NEWAPI_V2_SESSION_SECRET_VALUE=""
NEWAPI_V2_CRYPTO_SECRET_VALUE=""
NEWAPI_V2_ERROR_LOG_ENABLED_VALUE="true"
NEWAPI_V2_BATCH_UPDATE_ENABLED_VALUE="true"
NEWAPI_V2_MAX_REQUEST_BODY_MB_VALUE="10240"
NEWAPI_V2_MAX_FILE_DOWNLOAD_MB_VALUE="10240"
NEWAPI_V2_NODE_NAME_VALUE="newapi-v2-node-1"

NEWAPI_V2_POSTGRES_IMAGE_VALUE="postgres:15"
NEWAPI_V2_POSTGRES_USER_VALUE="newapi_v2"
NEWAPI_V2_POSTGRES_PASSWORD_VALUE=""
NEWAPI_V2_POSTGRES_DB_VALUE="newapi_v2"

NEWAPI_V2_REDIS_IMAGE_VALUE="redis:7-alpine"
NEWAPI_V2_REDIS_PASSWORD_VALUE=""

CLIPROXY_IMAGE_VALUE="eceasy/cli-proxy-api:latest"
CLIPROXY_DEPLOY_VALUE=""
CLIPROXY_PUBLISH_HOST_PORTS_VALUE=false
CLIPROXY_PORT_8317_VALUE="8317"
CLIPROXY_PORT_8085_VALUE="8085"
CLIPROXY_PORT_1455_VALUE="1455"
CLIPROXY_PORT_54545_VALUE="54545"
CLIPROXY_PORT_51121_VALUE="51121"
CLIPROXY_PORT_11451_VALUE="11451"
CLIPROXY_REMOTE_SECRET_VALUE=""
CLIPROXY_API_KEY_VALUE=""

SUB2API_IMAGE_VALUE="weishaw/sub2api:latest"
SUB2API_POSTGRES_IMAGE_VALUE="postgres:18-alpine"
SUB2API_REDIS_IMAGE_VALUE="redis:8-alpine"
SUB2API_PUBLISH_HOST_PORT_VALUE=false
SUB2API_HOST_PORT_VALUE="8081"
SUB2API_SERVER_MODE_VALUE="release"
SUB2API_RUN_MODE_VALUE="standard"
SUB2API_POSTGRES_USER_VALUE="sub2api"
SUB2API_POSTGRES_PASSWORD_VALUE=""
SUB2API_POSTGRES_DB_VALUE="sub2api"
SUB2API_REDIS_PASSWORD_VALUE=""
SUB2API_ADMIN_EMAIL_VALUE="admin@sub2api.local"
SUB2API_ADMIN_PASSWORD_VALUE=""
SUB2API_JWT_SECRET_VALUE=""
SUB2API_TOTP_ENCRYPTION_KEY_VALUE=""
SUB2API_UPDATE_PROXY_URL_VALUE=""

GPT_IMAGE_WEBUI_IMAGE_VALUE="tannic666/gpt-image-2-webui:latest"
GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE=false
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

GEMINI_IMAGE_DESK_IMAGE_VALUE="tannic666/gemini-image-desk:latest"
GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE=false
GEMINI_IMAGE_DESK_HOST_PORT_VALUE="3003"
GEMINI_IMAGE_DESK_BASE_URL_VALUE="https://generativelanguage.googleapis.com"
GEMINI_IMAGE_DESK_DEFAULT_MODEL_VALUE="gemini-2.5-flash-image"
GEMINI_IMAGE_DESK_PUBLIC_BASE_URL_CONFIG_VALUE="false"

DUFS_IMAGE_VALUE="tannic666/dufs:latest"
DUFS_PUBLISH_HOST_PORT_VALUE=false
DUFS_HOST_PORT_VALUE="5000"
DUFS_DATA_DIR_VALUE="${DEFAULT_STACK_DIR}/dufs/data"
DUFS_ADMIN_USER_VALUE="admin"
DUFS_ADMIN_PASSWORD_VALUE=""
DUFS_ANONYMOUS_READ_VALUE=true
DUFS_AUTH_VALUE=""
DUFS_ALLOW_UPLOAD_VALUE=true
DUFS_ALLOW_DELETE_VALUE=true
DUFS_ALLOW_SEARCH_VALUE=true
DUFS_ALLOW_ARCHIVE_VALUE=true
DUFS_RENDER_TRY_INDEX_VALUE=true

NGINX_IMAGE_VALUE="nginx:alpine"
NGINX_DEPLOY_MODE_VALUE="lan"
NGINX_ENABLE_HTTPS=false
NGINX_SHARE_CERT_VALUE=true
NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE=true
NGINX_HTTP_PORT_VALUE="80"
NGINX_HTTPS_PORT_VALUE="443"
NGINX_LAN_API_PORT_VALUE="80"
NGINX_LAN_ADMIN_PORT_VALUE="8080"
NGINX_LAN_SUB2API_PORT_VALUE="8081"
NGINX_LAN_WEBUI_PORT_VALUE="8082"
NGINX_LAN_NEWAPI_V2_PORT_VALUE="8083"
NGINX_LAN_GEMINI_IMAGE_DESK_PORT_VALUE="8084"
NGINX_LAN_DUFS_PORT_VALUE="8085"
NGINX_HTTP_SERVER_NAMES_VALUE="example.com www.example.com api.example.com admin.example.com sub.example.com image.example.com newapi.example.com gemini.example.com file.example.com"
NGINX_API_SERVER_NAMES_VALUE="example.com www.example.com api.example.com"
NGINX_ADMIN_SERVER_NAME_VALUE="admin.example.com"
NGINX_SUB2API_SERVER_NAMES_VALUE="sub.example.com"
NGINX_WEBUI_SERVER_NAMES_VALUE="image.example.com"
NGINX_NEWAPI_V2_SERVER_NAMES_VALUE="newapi.example.com"
NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE="gemini.example.com"
NGINX_DUFS_SERVER_NAMES_VALUE="file.example.com"
NGINX_API_CERT_VALUE="fullchain.cer"
NGINX_API_KEY_VALUE="example.com.key"
NGINX_ADMIN_CERT_VALUE="fullchain.cer"
NGINX_ADMIN_KEY_VALUE="example.com.key"
NGINX_SUB2API_CERT_VALUE="fullchain.cer"
NGINX_SUB2API_KEY_VALUE="example.com.key"
NGINX_WEBUI_CERT_VALUE="fullchain.cer"
NGINX_WEBUI_KEY_VALUE="example.com.key"
NGINX_NEWAPI_V2_CERT_VALUE="fullchain.cer"
NGINX_NEWAPI_V2_KEY_VALUE="example.com.key"
NGINX_GEMINI_IMAGE_DESK_CERT_VALUE="fullchain.cer"
NGINX_GEMINI_IMAGE_DESK_KEY_VALUE="example.com.key"
NGINX_DUFS_CERT_VALUE="fullchain.cer"
NGINX_DUFS_KEY_VALUE="example.com.key"
NGINX_NEWAPI_UPSTREAM_VALUE="new-api:3000"
NGINX_CLIPROXY_UPSTREAM_VALUE="cli-proxy-api:8317"
NGINX_SUB2API_UPSTREAM_VALUE="sub2api:8080"
NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE="gpt-image-2-webui:3000"
NGINX_NEWAPI_V2_UPSTREAM_VALUE="newapi-v2:3000"
NGINX_GEMINI_IMAGE_DESK_UPSTREAM_VALUE="gemini-image-desk:3000"
NGINX_DUFS_UPSTREAM_VALUE="dufs:5000"

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
  printf '%s\n' "$(color_text "$COLOR_DIM" "$(printf '%72s' '-- By JunWan --')")"
  printf '%s\n' "$(color_text "${COLOR_BOLD}${COLOR_GREEN}" "AI API Stack 一键部署脚本")"
  printf '%s\n' "$(color_text "$COLOR_DIM" "Nginx + New API + NewAPI v2 + CLIProxyAPI + Sub2API + GPT Image WebUI + Gemini Image Desk + Dufs + PostgreSQL + Redis")"
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
  menu_option "$COLOR_GREEN" "[1]" "通用安装/检查 Docker"
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
    read -e -r -p "$prompt" input_value || die "无法读取输入，已退出。"
  else
    printf '%s' "$prompt"
    read -r input_value || die "检测到非交互输入，请下载脚本后执行。"
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
  local skip_port=""

  if needs_newapi_config && [[ "$NEWAPI_PUBLISH_HOST_PORT_VALUE" == "true" ]] && ! service_was_existing "new-api"; then
    ensure_available_port NEWAPI_HOST_PORT_VALUE "New API 直连" 3000
  fi

  if needs_newapi_v2_config && [[ "$NEWAPI_V2_PUBLISH_HOST_PORT_VALUE" == "true" ]] && ! service_was_existing "newapi-v2"; then
    skip_port=""
    needs_newapi_config && skip_port="$NEWAPI_HOST_PORT_VALUE"
    ensure_available_port NEWAPI_V2_HOST_PORT_VALUE "新版 NewAPI 直连" 3002 "$skip_port"
  fi

  if needs_cliproxy_config && [[ "$CLIPROXY_PUBLISH_HOST_PORTS_VALUE" == "true" ]] && ! service_was_existing "cli-proxy-api"; then
    ensure_available_port CLIPROXY_PORT_8317_VALUE "CLIProxyAPI 8317 直连" 8317
    ensure_available_port CLIPROXY_PORT_8085_VALUE "CLIProxyAPI 8085 直连" 8085 "$CLIPROXY_PORT_8317_VALUE"
    ensure_available_port CLIPROXY_PORT_1455_VALUE "CLIProxyAPI 1455 直连" 1455
    ensure_available_port CLIPROXY_PORT_54545_VALUE "CLIProxyAPI 54545 直连" 54545
    ensure_available_port CLIPROXY_PORT_51121_VALUE "CLIProxyAPI 51121 直连" 51121
    ensure_available_port CLIPROXY_PORT_11451_VALUE "CLIProxyAPI 11451 直连" 11451
  fi

  if needs_sub2api_config && [[ "$SUB2API_PUBLISH_HOST_PORT_VALUE" == "true" ]] && ! service_was_existing "sub2api"; then
    ensure_available_port SUB2API_HOST_PORT_VALUE "Sub2API 直连" 8081 "$NEWAPI_HOST_PORT_VALUE"
  fi

  if needs_gpt_image_webui_config && [[ "$GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE" == "true" ]] && ! service_was_existing "gpt-image-2-webui"; then
    ensure_available_port GPT_IMAGE_WEBUI_HOST_PORT_VALUE "GPT Image WebUI 直连" 3001 "$SUB2API_HOST_PORT_VALUE"
  fi

  if needs_gemini_image_desk_config && [[ "$GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE" == "true" ]] && ! service_was_existing "gemini-image-desk"; then
    skip_port=""
    needs_gpt_image_webui_config && skip_port="$GPT_IMAGE_WEBUI_HOST_PORT_VALUE"
    ensure_available_port GEMINI_IMAGE_DESK_HOST_PORT_VALUE "Gemini Image Desk 直连" 3003 "$skip_port"
  fi

  if needs_dufs_config && [[ "$DUFS_PUBLISH_HOST_PORT_VALUE" == "true" ]] && ! service_was_existing "dufs"; then
    skip_port=""
    needs_gemini_image_desk_config && skip_port="$GEMINI_IMAGE_DESK_HOST_PORT_VALUE"
    ensure_available_port DUFS_HOST_PORT_VALUE "Dufs 静态文件服务直连" 5000 "$skip_port"
  fi

  if ! needs_nginx_config; then
    return
  fi

  if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
    if needs_newapi_config && ! service_was_existing "new-api"; then
      ensure_available_port NGINX_LAN_API_PORT_VALUE "Nginx 局域网 API 入口" 18080
    fi
    if needs_cliproxy_config && ! service_was_existing "cli-proxy-api"; then
      ensure_available_port NGINX_LAN_ADMIN_PORT_VALUE "Nginx 局域网管理端入口" 18081 "$NGINX_LAN_API_PORT_VALUE"
    fi
    if needs_sub2api_config && ! service_was_existing "sub2api"; then
      ensure_available_port NGINX_LAN_SUB2API_PORT_VALUE "Nginx 局域网 Sub2API 入口" 18082 "$NGINX_LAN_ADMIN_PORT_VALUE"
    fi
    if needs_gpt_image_webui_config && ! service_was_existing "gpt-image-2-webui"; then
      ensure_available_port NGINX_LAN_WEBUI_PORT_VALUE "Nginx 局域网 GPT Image WebUI 入口" 18083 "$NGINX_LAN_SUB2API_PORT_VALUE"
    fi
    if needs_newapi_v2_config && ! service_was_existing "newapi-v2"; then
      skip_port=""
      needs_gpt_image_webui_config && skip_port="$NGINX_LAN_WEBUI_PORT_VALUE"
      ensure_available_port NGINX_LAN_NEWAPI_V2_PORT_VALUE "Nginx 局域网新版 NewAPI 入口" 18084 "$skip_port"
    fi
    if needs_gemini_image_desk_config && ! service_was_existing "gemini-image-desk"; then
      skip_port=""
      needs_newapi_v2_config && skip_port="$NGINX_LAN_NEWAPI_V2_PORT_VALUE"
      ensure_available_port NGINX_LAN_GEMINI_IMAGE_DESK_PORT_VALUE "Nginx 局域网 Gemini Image Desk 入口" 18085 "$skip_port"
    fi
    if needs_dufs_config && ! service_was_existing "dufs"; then
      skip_port=""
      needs_gemini_image_desk_config && skip_port="$NGINX_LAN_GEMINI_IMAGE_DESK_PORT_VALUE"
      ensure_available_port NGINX_LAN_DUFS_PORT_VALUE "Nginx 局域网 Dufs 静态文件入口" 18086 "$skip_port"
    fi
  else
    if [[ "$EXISTING_STACK" != "true" ]]; then
      ensure_available_port NGINX_HTTP_PORT_VALUE "Nginx 公网 HTTP 入口" 18080
    fi
    if [[ "$NGINX_ENABLE_HTTPS" == "true" && "$EXISTING_STACK" != "true" ]]; then
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
  subtle_note "脚本会在该目录生成根 docker-compose.yml、.env、Nginx 配置，并只为已选服务创建目录和服务 compose 文件。"
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

  load_env_default "$env_file" "NEWAPI_V2_IMAGE" NEWAPI_V2_IMAGE_VALUE
  load_env_default "$env_file" "NEWAPI_V2_PUBLISH_HOST_PORT" NEWAPI_V2_PUBLISH_HOST_PORT_VALUE
  load_env_default "$env_file" "NEWAPI_V2_HOST_PORT" NEWAPI_V2_HOST_PORT_VALUE
  load_env_default "$env_file" "NEWAPI_V2_SESSION_SECRET" NEWAPI_V2_SESSION_SECRET_VALUE
  load_env_default "$env_file" "NEWAPI_V2_CRYPTO_SECRET" NEWAPI_V2_CRYPTO_SECRET_VALUE
  load_env_default "$env_file" "NEWAPI_V2_ERROR_LOG_ENABLED" NEWAPI_V2_ERROR_LOG_ENABLED_VALUE
  load_env_default "$env_file" "NEWAPI_V2_BATCH_UPDATE_ENABLED" NEWAPI_V2_BATCH_UPDATE_ENABLED_VALUE
  load_env_default "$env_file" "NEWAPI_V2_MAX_REQUEST_BODY_MB" NEWAPI_V2_MAX_REQUEST_BODY_MB_VALUE
  load_env_default "$env_file" "NEWAPI_V2_MAX_FILE_DOWNLOAD_MB" NEWAPI_V2_MAX_FILE_DOWNLOAD_MB_VALUE
  load_env_default "$env_file" "NEWAPI_V2_NODE_NAME" NEWAPI_V2_NODE_NAME_VALUE
  load_env_default "$env_file" "NEWAPI_V2_POSTGRES_IMAGE" NEWAPI_V2_POSTGRES_IMAGE_VALUE
  load_env_default "$env_file" "NEWAPI_V2_POSTGRES_USER" NEWAPI_V2_POSTGRES_USER_VALUE
  load_env_default "$env_file" "NEWAPI_V2_POSTGRES_PASSWORD" NEWAPI_V2_POSTGRES_PASSWORD_VALUE
  load_env_default "$env_file" "NEWAPI_V2_POSTGRES_DB" NEWAPI_V2_POSTGRES_DB_VALUE
  load_env_default "$env_file" "NEWAPI_V2_REDIS_IMAGE" NEWAPI_V2_REDIS_IMAGE_VALUE
  load_env_default "$env_file" "NEWAPI_V2_REDIS_PASSWORD" NEWAPI_V2_REDIS_PASSWORD_VALUE

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

  load_env_default "$env_file" "SUB2API_IMAGE" SUB2API_IMAGE_VALUE
  load_env_default "$env_file" "SUB2API_POSTGRES_IMAGE" SUB2API_POSTGRES_IMAGE_VALUE
  load_env_default "$env_file" "SUB2API_REDIS_IMAGE" SUB2API_REDIS_IMAGE_VALUE
  load_env_default "$env_file" "SUB2API_PUBLISH_HOST_PORT" SUB2API_PUBLISH_HOST_PORT_VALUE
  load_env_default "$env_file" "SUB2API_HOST_PORT" SUB2API_HOST_PORT_VALUE
  load_env_default "$env_file" "SUB2API_SERVER_MODE" SUB2API_SERVER_MODE_VALUE
  load_env_default "$env_file" "SUB2API_RUN_MODE" SUB2API_RUN_MODE_VALUE
  load_env_default "$env_file" "SUB2API_POSTGRES_USER" SUB2API_POSTGRES_USER_VALUE
  load_env_default "$env_file" "SUB2API_POSTGRES_PASSWORD" SUB2API_POSTGRES_PASSWORD_VALUE
  load_env_default "$env_file" "SUB2API_POSTGRES_DB" SUB2API_POSTGRES_DB_VALUE
  load_env_default "$env_file" "SUB2API_REDIS_PASSWORD" SUB2API_REDIS_PASSWORD_VALUE
  load_env_default "$env_file" "SUB2API_ADMIN_EMAIL" SUB2API_ADMIN_EMAIL_VALUE
  load_env_default "$env_file" "SUB2API_ADMIN_PASSWORD" SUB2API_ADMIN_PASSWORD_VALUE
  load_env_default "$env_file" "SUB2API_JWT_SECRET" SUB2API_JWT_SECRET_VALUE
  load_env_default "$env_file" "SUB2API_TOTP_ENCRYPTION_KEY" SUB2API_TOTP_ENCRYPTION_KEY_VALUE
  load_env_default "$env_file" "SUB2API_UPDATE_PROXY_URL" SUB2API_UPDATE_PROXY_URL_VALUE

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

  load_env_default "$env_file" "GEMINI_IMAGE_DESK_IMAGE" GEMINI_IMAGE_DESK_IMAGE_VALUE
  load_env_default "$env_file" "GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT" GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE
  load_env_default "$env_file" "GEMINI_IMAGE_DESK_HOST_PORT" GEMINI_IMAGE_DESK_HOST_PORT_VALUE
  load_env_default "$env_file" "GEMINI_IMAGE_DESK_BASE_URL" GEMINI_IMAGE_DESK_BASE_URL_VALUE
  load_env_default "$env_file" "GEMINI_IMAGE_DESK_DEFAULT_MODEL" GEMINI_IMAGE_DESK_DEFAULT_MODEL_VALUE
  load_env_default "$env_file" "GEMINI_IMAGE_DESK_PUBLIC_BASE_URL_CONFIG" GEMINI_IMAGE_DESK_PUBLIC_BASE_URL_CONFIG_VALUE

  load_env_default "$env_file" "DUFS_IMAGE" DUFS_IMAGE_VALUE
  load_env_default "$env_file" "DUFS_PUBLISH_HOST_PORT" DUFS_PUBLISH_HOST_PORT_VALUE
  load_env_default "$env_file" "DUFS_HOST_PORT" DUFS_HOST_PORT_VALUE
  load_env_default "$env_file" "DUFS_DATA_DIR" DUFS_DATA_DIR_VALUE
  load_env_default "$env_file" "DUFS_ADMIN_USER" DUFS_ADMIN_USER_VALUE
  load_env_default "$env_file" "DUFS_ADMIN_PASSWORD" DUFS_ADMIN_PASSWORD_VALUE
  load_env_default "$env_file" "DUFS_ANONYMOUS_READ" DUFS_ANONYMOUS_READ_VALUE
  load_env_default "$env_file" "DUFS_AUTH" DUFS_AUTH_VALUE
  load_env_default "$env_file" "DUFS_ALLOW_UPLOAD" DUFS_ALLOW_UPLOAD_VALUE
  load_env_default "$env_file" "DUFS_ALLOW_DELETE" DUFS_ALLOW_DELETE_VALUE
  load_env_default "$env_file" "DUFS_ALLOW_SEARCH" DUFS_ALLOW_SEARCH_VALUE
  load_env_default "$env_file" "DUFS_ALLOW_ARCHIVE" DUFS_ALLOW_ARCHIVE_VALUE
  load_env_default "$env_file" "DUFS_RENDER_TRY_INDEX" DUFS_RENDER_TRY_INDEX_VALUE

  load_env_default "$env_file" "NGINX_IMAGE" NGINX_IMAGE_VALUE
  load_env_default "$env_file" "NGINX_DEPLOY_MODE" NGINX_DEPLOY_MODE_VALUE
  load_env_default "$env_file" "NGINX_ENABLE_HTTPS" NGINX_ENABLE_HTTPS
  load_env_default "$env_file" "NGINX_SHARE_CERT" NGINX_SHARE_CERT_VALUE
  load_env_default "$env_file" "NGINX_HTTP_TO_HTTPS_REDIRECT" NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE
  load_env_default "$env_file" "NGINX_HTTP_PORT" NGINX_HTTP_PORT_VALUE
  load_env_default "$env_file" "NGINX_HTTPS_PORT" NGINX_HTTPS_PORT_VALUE
  load_env_default "$env_file" "NGINX_LAN_API_PORT" NGINX_LAN_API_PORT_VALUE
  load_env_default "$env_file" "NGINX_LAN_ADMIN_PORT" NGINX_LAN_ADMIN_PORT_VALUE
  load_env_default "$env_file" "NGINX_LAN_SUB2API_PORT" NGINX_LAN_SUB2API_PORT_VALUE
  load_env_default "$env_file" "NGINX_LAN_WEBUI_PORT" NGINX_LAN_WEBUI_PORT_VALUE
  load_env_default "$env_file" "NGINX_LAN_NEWAPI_V2_PORT" NGINX_LAN_NEWAPI_V2_PORT_VALUE
  load_env_default "$env_file" "NGINX_LAN_GEMINI_IMAGE_DESK_PORT" NGINX_LAN_GEMINI_IMAGE_DESK_PORT_VALUE
  load_env_default "$env_file" "NGINX_LAN_DUFS_PORT" NGINX_LAN_DUFS_PORT_VALUE
  load_env_default "$env_file" "NGINX_HTTP_SERVER_NAMES" NGINX_HTTP_SERVER_NAMES_VALUE
  load_env_default "$env_file" "NGINX_API_SERVER_NAMES" NGINX_API_SERVER_NAMES_VALUE
  load_env_default "$env_file" "NGINX_ADMIN_SERVER_NAME" NGINX_ADMIN_SERVER_NAME_VALUE
  load_env_default "$env_file" "NGINX_SUB2API_SERVER_NAMES" NGINX_SUB2API_SERVER_NAMES_VALUE
  load_env_default "$env_file" "NGINX_WEBUI_SERVER_NAMES" NGINX_WEBUI_SERVER_NAMES_VALUE
  load_env_default "$env_file" "NGINX_NEWAPI_V2_SERVER_NAMES" NGINX_NEWAPI_V2_SERVER_NAMES_VALUE
  load_env_default "$env_file" "NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES" NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE
  load_env_default "$env_file" "NGINX_DUFS_SERVER_NAMES" NGINX_DUFS_SERVER_NAMES_VALUE
  load_env_default "$env_file" "NGINX_API_CERT" NGINX_API_CERT_VALUE
  load_env_default "$env_file" "NGINX_API_KEY" NGINX_API_KEY_VALUE
  load_env_default "$env_file" "NGINX_ADMIN_CERT" NGINX_ADMIN_CERT_VALUE
  load_env_default "$env_file" "NGINX_ADMIN_KEY" NGINX_ADMIN_KEY_VALUE
  load_env_default "$env_file" "NGINX_SUB2API_CERT" NGINX_SUB2API_CERT_VALUE
  load_env_default "$env_file" "NGINX_SUB2API_KEY" NGINX_SUB2API_KEY_VALUE
  load_env_default "$env_file" "NGINX_WEBUI_CERT" NGINX_WEBUI_CERT_VALUE
  load_env_default "$env_file" "NGINX_WEBUI_KEY" NGINX_WEBUI_KEY_VALUE
  load_env_default "$env_file" "NGINX_NEWAPI_V2_CERT" NGINX_NEWAPI_V2_CERT_VALUE
  load_env_default "$env_file" "NGINX_NEWAPI_V2_KEY" NGINX_NEWAPI_V2_KEY_VALUE
  load_env_default "$env_file" "NGINX_GEMINI_IMAGE_DESK_CERT" NGINX_GEMINI_IMAGE_DESK_CERT_VALUE
  load_env_default "$env_file" "NGINX_GEMINI_IMAGE_DESK_KEY" NGINX_GEMINI_IMAGE_DESK_KEY_VALUE
  load_env_default "$env_file" "NGINX_DUFS_CERT" NGINX_DUFS_CERT_VALUE
  load_env_default "$env_file" "NGINX_DUFS_KEY" NGINX_DUFS_KEY_VALUE
  load_env_default "$env_file" "NGINX_NEWAPI_UPSTREAM" NGINX_NEWAPI_UPSTREAM_VALUE
  load_env_default "$env_file" "NGINX_CLIPROXY_UPSTREAM" NGINX_CLIPROXY_UPSTREAM_VALUE
  load_env_default "$env_file" "NGINX_SUB2API_UPSTREAM" NGINX_SUB2API_UPSTREAM_VALUE
  load_env_default "$env_file" "NGINX_GPT_IMAGE_WEBUI_UPSTREAM" NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE
  load_env_default "$env_file" "NGINX_NEWAPI_V2_UPSTREAM" NGINX_NEWAPI_V2_UPSTREAM_VALUE
  load_env_default "$env_file" "NGINX_GEMINI_IMAGE_DESK_UPSTREAM" NGINX_GEMINI_IMAGE_DESK_UPSTREAM_VALUE
  load_env_default "$env_file" "NGINX_DUFS_UPSTREAM" NGINX_DUFS_UPSTREAM_VALUE
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

detect_existing_app_services() {
  local compose_file="$STACK_DIR/docker-compose.yml"
  local service=""

  EXISTING_STACK=false
  EXISTING_APP_SERVICES=()
  [[ -f "$compose_file" ]] || return 0

  EXISTING_STACK=true
  for service in new-api newapi-v2 cli-proxy-api sub2api gpt-image-2-webui gemini-image-desk dufs; do
    if grep -qE "^  ${service}:$" "$compose_file"; then
      EXISTING_APP_SERVICES+=("$service")
    fi
  done
}

service_was_existing() {
  local service="$1"

  contains_service "$service" "${EXISTING_APP_SERVICES[@]}"
}

merge_existing_services_if_requested() {
  local service=""

  [[ "$EXISTING_STACK" == "true" ]] || return 0
  [[ "${#EXISTING_APP_SERVICES[@]}" -gt 0 ]] || return 0
  [[ "$DEPLOY_ALL" != "true" ]] || return 0

  field_line "当前已部署服务：" "$(join_list "${EXISTING_APP_SERVICES[@]}")"
  read_yes_no PRESERVE_EXISTING_SERVICES "是否保留已有服务并在此基础上追加本次选择" "$PRESERVE_EXISTING_SERVICES"

  if [[ "$PRESERVE_EXISTING_SERVICES" != "true" ]]; then
    subtle_note "将只按本次选择重写 Compose；未选择的旧服务不会被当前 Compose 管理。"
    return 0
  fi

  for service in "${EXISTING_APP_SERVICES[@]}"; do
    append_selected_service "$service"
  done

  printf '实际部署/保留：%s\n' "$(join_list "${SELECTED_SERVICES[@]}")"
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
    nginx|proxy|gateway)
      printf 'nginx'
      ;;
    1|newapi|new-api|api)
      printf 'new-api'
      ;;
    postgres|postgresql|pg|db|redis|cache)
      printf 'new-api'
      ;;
    5|newapi-v2|new-api-v2|newapi2|new-api2|newapi-new|new-newapi|tannic-newapi)
      printf 'newapi-v2'
      ;;
    newapi-v2-postgres|newapi-v2-pg|newapi-v2-db|newapi-v2-redis|newapi-v2-cache)
      printf 'newapi-v2'
      ;;
    2|cliproxy|cliproxyapi|cli-proxy-api|cli|cpa)
      printf 'cli-proxy-api'
      ;;
    3|sub2api|sub-api|subapi|sub|subscription)
      printf 'sub2api'
      ;;
    4|gpt-image-2-webui|gpt-image-webui|gptimage|gpt-image|image-webui|webui|image|image2)
      printf 'gpt-image-2-webui'
      ;;
    6|gemini-image-desk|gemini-desk|gemini-image|gemini|image-desk)
      printf 'gemini-image-desk'
      ;;
    7|dufs|static|static-file|static-files|static-host|file|files|assets)
      printf 'dufs'
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
  local saw_nginx_default="false"

  section_title "服务选择"
  menu_option "$COLOR_GREEN" " 1)" "new-api"
  menu_option "$COLOR_GREEN" " 2)" "cli-proxy-api"
  menu_option "$COLOR_GREEN" " 3)" "sub2api"
  menu_option "$COLOR_GREEN" " 4)" "gpt-image-2-webui"
  menu_option "$COLOR_GREEN" " 5)" "newapi-v2（tannic666/newapi，新版）"
  menu_option "$COLOR_GREEN" " 6)" "gemini-image-desk"
  menu_option "$COLOR_GREEN" " 7)" "dufs（静态文件/图片/HTML 直链）"
  subtle_note "Nginx 默认作为统一网关必装，会按所选应用自动生成入口。"
  subtle_note "new-api、新版 NewAPI 和 sub2api 的 PostgreSQL / Redis 依赖会自动处理，不单独选择。"
  subtle_note "输入 all、1234567、1 2、1,5 或服务名都可以。"

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
    saw_nginx_default="false"

    for token in $raw; do
      if [[ "$token" =~ ^[1-7]+$ && "${#token}" -gt 1 ]]; then
        local index=0
        local char=""
        for ((index = 0; index < ${#token}; index++)); do
          char="${token:index:1}"
          if service="$(service_from_token "$char")"; then
            if [[ "$service" == "nginx" ]]; then
              saw_nginx_default="true"
            else
              append_selected_service "$service"
            fi
          fi
        done
      elif service="$(service_from_token "$token")"; then
        if [[ "$service" == "nginx" ]]; then
          saw_nginx_default="true"
        else
          append_selected_service "$service"
        fi
      else
        printf '无法识别的服务：%s\n' "$token"
      fi
    done

    if [[ "${#SELECTED_SERVICES[@]}" -eq 0 && "$saw_nginx_default" == "true" ]]; then
      subtle_note "Nginx 默认必装，不需要选择；请至少选择一个应用，或输入 all。"
    fi

    if [[ "${#SELECTED_SERVICES[@]}" -gt 0 ]]; then
      if [[ "$saw_nginx_default" == "true" ]]; then
        subtle_note "Nginx 默认必装，已忽略输入里的 nginx。"
      fi
      printf '已选择：%s\n' "$(join_list "${SELECTED_SERVICES[@]}")"
      return
    fi

    printf '没有选到有效服务，请重新输入。\n'
  done
}

needs_newapi_config() {
  selected_or_all "new-api" && return 0
  return 1
}

needs_postgres_config() {
  needs_newapi_config && return 0
  return 1
}

needs_newapi_v2_config() {
  selected_or_all "newapi-v2" && return 0
  return 1
}

needs_cliproxy_config() {
  selected_or_all "cli-proxy-api" && return 0
  return 1
}

needs_sub2api_config() {
  selected_or_all "sub2api" && return 0
  return 1
}

needs_gpt_image_webui_config() {
  selected_or_all "gpt-image-2-webui" && return 0
  return 1
}

needs_gemini_image_desk_config() {
  selected_or_all "gemini-image-desk" && return 0
  return 1
}

needs_dufs_config() {
  selected_or_all "dufs" && return 0
  return 1
}

needs_nginx_config() {
  return 0
}

last_certificate_metadata_file() {
  printf '%s' "$STACK_DIR/nginx/certs/.last-cert.env"
}

nginx_selected_service_names() {
  local names=()

  needs_newapi_config && names+=("New API")
  needs_cliproxy_config && names+=("CPA")
  needs_sub2api_config && names+=("Sub2API")
  needs_gpt_image_webui_config && names+=("GPT Image WebUI")
  needs_newapi_v2_config && names+=("新版 NewAPI")
  needs_gemini_image_desk_config && names+=("Gemini Image Desk")
  needs_dufs_config && names+=("Dufs 静态文件")

  join_list "${names[@]}"
}

build_nginx_http_server_names() {
  local names=()

  needs_newapi_config && names+=("$NGINX_API_SERVER_NAMES_VALUE")
  needs_cliproxy_config && names+=("$NGINX_ADMIN_SERVER_NAME_VALUE")
  needs_sub2api_config && names+=("$NGINX_SUB2API_SERVER_NAMES_VALUE")
  needs_gpt_image_webui_config && names+=("$NGINX_WEBUI_SERVER_NAMES_VALUE")
  needs_newapi_v2_config && names+=("$NGINX_NEWAPI_V2_SERVER_NAMES_VALUE")
  needs_gemini_image_desk_config && names+=("$NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE")
  needs_dufs_config && names+=("$NGINX_DUFS_SERVER_NAMES_VALUE")

  printf '%s' "${names[*]}"
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
      NGINX_SUB2API_CERT_VALUE="$last_cert"
      NGINX_SUB2API_KEY_VALUE="$last_key"
      NGINX_WEBUI_CERT_VALUE="$last_cert"
      NGINX_WEBUI_KEY_VALUE="$last_key"
      NGINX_NEWAPI_V2_CERT_VALUE="$last_cert"
      NGINX_NEWAPI_V2_KEY_VALUE="$last_key"
      NGINX_GEMINI_IMAGE_DESK_CERT_VALUE="$last_cert"
      NGINX_GEMINI_IMAGE_DESK_KEY_VALUE="$last_key"
      NGINX_DUFS_CERT_VALUE="$last_cert"
      NGINX_DUFS_KEY_VALUE="$last_key"
      printf '已设置：所有 Nginx HTTPS 站点共用证书 %s / %s。\n' "$last_cert" "$last_key"
      return
    fi
  fi

  read_yes_no share_cert "$(nginx_selected_service_names) 是否共用同一个证书" "$NGINX_SHARE_CERT_VALUE"
  NGINX_SHARE_CERT_VALUE="$share_cert"

  if [[ "$NGINX_SHARE_CERT_VALUE" == "true" ]]; then
    read_line NGINX_API_CERT_VALUE "nginx/certs 里的证书文件名" "$NGINX_API_CERT_VALUE"
    read_line NGINX_API_KEY_VALUE "nginx/certs 里的私钥文件名" "$NGINX_API_KEY_VALUE"
    NGINX_ADMIN_CERT_VALUE="$NGINX_API_CERT_VALUE"
    NGINX_ADMIN_KEY_VALUE="$NGINX_API_KEY_VALUE"
    NGINX_SUB2API_CERT_VALUE="$NGINX_API_CERT_VALUE"
    NGINX_SUB2API_KEY_VALUE="$NGINX_API_KEY_VALUE"
    NGINX_WEBUI_CERT_VALUE="$NGINX_API_CERT_VALUE"
    NGINX_WEBUI_KEY_VALUE="$NGINX_API_KEY_VALUE"
    NGINX_NEWAPI_V2_CERT_VALUE="$NGINX_API_CERT_VALUE"
    NGINX_NEWAPI_V2_KEY_VALUE="$NGINX_API_KEY_VALUE"
    NGINX_GEMINI_IMAGE_DESK_CERT_VALUE="$NGINX_API_CERT_VALUE"
    NGINX_GEMINI_IMAGE_DESK_KEY_VALUE="$NGINX_API_KEY_VALUE"
    NGINX_DUFS_CERT_VALUE="$NGINX_API_CERT_VALUE"
    NGINX_DUFS_KEY_VALUE="$NGINX_API_KEY_VALUE"
    printf '已设置：%s 共用证书 %s / %s。\n' "$(nginx_selected_service_names)" "$NGINX_API_CERT_VALUE" "$NGINX_API_KEY_VALUE"
    return
  fi

  if needs_newapi_config; then
    read_line NGINX_API_CERT_VALUE "nginx/certs 里的 New API 证书文件名" "$NGINX_API_CERT_VALUE"
    read_line NGINX_API_KEY_VALUE "nginx/certs 里的 New API 私钥文件名" "$NGINX_API_KEY_VALUE"
  fi
  if needs_cliproxy_config; then
    read_line NGINX_ADMIN_CERT_VALUE "nginx/certs 里的 CPA 证书文件名" "$NGINX_ADMIN_CERT_VALUE"
    read_line NGINX_ADMIN_KEY_VALUE "nginx/certs 里的 CPA 私钥文件名" "$NGINX_ADMIN_KEY_VALUE"
  fi
  if needs_sub2api_config; then
    read_line NGINX_SUB2API_CERT_VALUE "nginx/certs 里的 Sub2API 证书文件名" "$NGINX_SUB2API_CERT_VALUE"
    read_line NGINX_SUB2API_KEY_VALUE "nginx/certs 里的 Sub2API 私钥文件名" "$NGINX_SUB2API_KEY_VALUE"
  fi
  if needs_gpt_image_webui_config; then
    read_line NGINX_WEBUI_CERT_VALUE "nginx/certs 里的 GPT Image WebUI 证书文件名" "$NGINX_WEBUI_CERT_VALUE"
    read_line NGINX_WEBUI_KEY_VALUE "nginx/certs 里的 GPT Image WebUI 私钥文件名" "$NGINX_WEBUI_KEY_VALUE"
  fi
  if needs_newapi_v2_config; then
    read_line NGINX_NEWAPI_V2_CERT_VALUE "nginx/certs 里的新版 NewAPI 证书文件名" "$NGINX_NEWAPI_V2_CERT_VALUE"
    read_line NGINX_NEWAPI_V2_KEY_VALUE "nginx/certs 里的新版 NewAPI 私钥文件名" "$NGINX_NEWAPI_V2_KEY_VALUE"
  fi
  if needs_gemini_image_desk_config; then
    read_line NGINX_GEMINI_IMAGE_DESK_CERT_VALUE "nginx/certs 里的 Gemini Image Desk 证书文件名" "$NGINX_GEMINI_IMAGE_DESK_CERT_VALUE"
    read_line NGINX_GEMINI_IMAGE_DESK_KEY_VALUE "nginx/certs 里的 Gemini Image Desk 私钥文件名" "$NGINX_GEMINI_IMAGE_DESK_KEY_VALUE"
  fi
  if needs_dufs_config; then
    read_line NGINX_DUFS_CERT_VALUE "nginx/certs 里的 Dufs 静态文件证书文件名" "$NGINX_DUFS_CERT_VALUE"
    read_line NGINX_DUFS_KEY_VALUE "nginx/certs 里的 Dufs 静态文件私钥文件名" "$NGINX_DUFS_KEY_VALUE"
  fi
}

uses_nginx_frontend() {
  selected_or_all "nginx"
}

default_gpt_image_webui_base_url() {
  if needs_newapi_config; then
    printf 'http://new-api:3000/v1'
  elif needs_newapi_v2_config; then
    printf 'http://newapi-v2:3000/v1'
  fi
}

build_dufs_auth_value() {
  if [[ "$DUFS_ANONYMOUS_READ_VALUE" == "true" ]]; then
    printf '%s:%s@/:rw|@/' "$DUFS_ADMIN_USER_VALUE" "$DUFS_ADMIN_PASSWORD_VALUE"
    return
  fi

  printf '%s:%s@/:rw' "$DUFS_ADMIN_USER_VALUE" "$DUFS_ADMIN_PASSWORD_VALUE"
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

show_linux_os_info() {
  local pretty_name=""
  local os_id=""
  local version_id=""

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    pretty_name="${PRETTY_NAME:-}"
    os_id="${ID:-}"
    version_id="${VERSION_ID:-}"
  fi

  [[ -n "$pretty_name" ]] || pretty_name="$(uname -s 2>/dev/null || printf 'Unknown')"
  field_line "系统：" "$pretty_name"
  [[ -n "$os_id" ]] && field_line "发行版 ID：" "$os_id"
  [[ -n "$version_id" ]] && field_line "版本：" "$version_id"
  field_line "架构：" "$(uname -m 2>/dev/null || printf 'unknown')"
}

run_official_docker_repo_installer() {
  run_root bash -s <<'ROOT'
set -Eeuo pipefail

install_apt_docker() {
  local repo_id="$1"
  local suite="$2"
  local arch=""
  local conflicting_packages=()
  local pkg=""

  [[ -n "$suite" ]] || {
    printf '未能识别 apt 仓库发行版代号，无法使用官方 apt 仓库。\n' >&2
    exit 42
  }

  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl gnupg

  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      conflicting_packages+=("$pkg")
    fi
  done

  if [[ "${#conflicting_packages[@]}" -gt 0 ]]; then
    apt-get remove -y "${conflicting_packages[@]}" || true
  fi

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${repo_id}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  arch="$(dpkg --print-architecture)"

  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/${repo_id}
Suites: ${suite}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_rpm_docker() {
  local repo_id="$1"
  local pkg_mgr=""
  local repo_url="https://download.docker.com/linux/${repo_id}/docker-ce.repo"
  local repo_file="/etc/yum.repos.d/docker-ce.repo"

  if command -v dnf >/dev/null 2>&1; then
    pkg_mgr="dnf"
  elif command -v yum >/dev/null 2>&1; then
    pkg_mgr="yum"
  else
    printf '未检测到 dnf/yum，无法使用官方 rpm 仓库。\n' >&2
    exit 42
  fi

  "$pkg_mgr" remove -y docker docker-client docker-client-latest docker-common docker-latest \
    docker-latest-logrotate docker-logrotate docker-engine podman-docker containerd runc || true

  if [[ "$pkg_mgr" == "dnf" ]]; then
    "$pkg_mgr" install -y dnf-plugins-core ca-certificates curl
  else
    "$pkg_mgr" install -y yum-utils ca-certificates curl
  fi

  if ! "$pkg_mgr" config-manager --add-repo "$repo_url"; then
    mkdir -p /etc/yum.repos.d
    curl -fsSL "$repo_url" -o "$repo_file"
  fi

  "$pkg_mgr" install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

start_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker
  elif command -v service >/dev/null 2>&1; then
    service docker start
  else
    printf '未检测到 systemctl/service，请手动启动 Docker 服务。\n' >&2
  fi
}

[[ "$(uname -s 2>/dev/null || true)" == "Linux" ]] || {
  printf '当前不是 Linux 系统，无法自动安装 Docker Engine。\n' >&2
  exit 42
}

[[ -r /etc/os-release ]] || {
  printf '未找到 /etc/os-release，无法识别 Linux 发行版。\n' >&2
  exit 42
}

# shellcheck disable=SC1091
. /etc/os-release

case "${ID:-}" in
  debian)
    install_apt_docker "debian" "${VERSION_CODENAME:-}"
    ;;
  ubuntu)
    install_apt_docker "ubuntu" "${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
    ;;
  centos)
    install_rpm_docker "centos"
    ;;
  rhel)
    install_rpm_docker "rhel"
    ;;
  fedora)
    install_rpm_docker "fedora"
    ;;
  rocky|almalinux|ol|oraclelinux)
    install_rpm_docker "centos"
    ;;
  *)
    printf '未内置 %s 的官方仓库安装流程。\n' "${PRETTY_NAME:-${ID:-unknown}}" >&2
    exit 42
    ;;
esac

start_docker_service
ROOT
}

run_docker_convenience_installer() {
  run_root bash -s <<'ROOT'
set -Eeuo pipefail

ensure_curl() {
  if command -v curl >/dev/null 2>&1; then
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ca-certificates curl
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y ca-certificates curl
  elif command -v yum >/dev/null 2>&1; then
    yum install -y ca-certificates curl
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install ca-certificates curl
  else
    printf '未检测到可用包管理器安装 curl，请先手动安装 curl。\n' >&2
    exit 1
  fi
}

start_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker || true
  elif command -v service >/dev/null 2>&1; then
    service docker start || true
  fi
}

tmp_script="$(mktemp)"
trap 'rm -f "$tmp_script"' EXIT

ensure_curl
curl -fsSL https://get.docker.com -o "$tmp_script"
sh "$tmp_script"
start_docker_service
ROOT
}

install_docker_universal() {
  local reinstall="false"
  local add_user_to_group="true"
  local target_user="${SUDO_USER:-}"
  local install_status=0
  local use_convenience="true"

  if [[ -z "$target_user" && "$(id -u)" -ne 0 ]]; then
    target_user="$(id -un 2>/dev/null || true)"
  fi

  section_title "通用安装/检查 Docker"
  show_linux_os_info
  show_docker_versions

  if command -v docker >/dev/null 2>&1; then
    read_yes_no reinstall "Docker 已存在，是否重新执行安装/修复流程" "$reinstall"
    [[ "$reinstall" == "true" ]] || return 0
  fi

  subtle_note "将优先使用 Docker 官方软件源安装 docker-ce、compose plugin、buildx plugin。"
  set +e
  run_official_docker_repo_installer
  install_status="$?"
  set -e

  if (( install_status != 0 )); then
    if [[ "$install_status" == "42" ]]; then
      subtle_note "当前系统没有匹配到内置的官方仓库安装流程。"
    else
      subtle_note "Docker 官方软件源安装流程失败，退出码：$install_status"
    fi

    if [[ -t 0 ]]; then
      read_yes_no use_convenience "是否改用 Docker 官方 get.docker.com 便捷脚本安装" "$use_convenience"
    else
      subtle_note "非交互环境下将自动改用 Docker 官方 get.docker.com 便捷脚本。"
    fi

    [[ "$use_convenience" == "true" ]] || die "已取消 Docker 安装。"
    subtle_note "将下载并执行 Docker 官方便捷脚本：https://get.docker.com"
    run_docker_convenience_installer
  fi

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
    nginx|proxy|gateway)
      printf 'nginx'
      ;;
    1|new-api|newapi|api)
      printf 'new-api'
      ;;
    5|newapi-v2|new-api-v2|newapi2|new-api2|newapi-new|new-newapi|tannic-newapi)
      printf 'newapi-v2'
      ;;
    2|cli-proxy-api|cliproxy-api|cliproxy|cpa|admin)
      printf 'cli-proxy-api'
      ;;
    3|sub2api|sub-api|subapi|sub|subscription)
      printf 'sub2api'
      ;;
    4|gpt-image-2-webui|gpt-image-webui|gptimage|gpt-image|image-webui|webui|image|image2)
      printf 'gpt-image-2-webui'
      ;;
    6|gemini-image-desk|gemini-desk|gemini-image|gemini|image-desk)
      printf 'gemini-image-desk'
      ;;
    7|dufs|static|static-file|static-files|static-host|file|files|assets)
      printf 'dufs'
      ;;
    newapi-v2-postgres|newapi-v2-pg|newapi-v2-db)
      printf 'newapi-v2-postgres'
      ;;
    newapi-v2-redis|newapi-v2-cache)
      printf 'newapi-v2-redis'
      ;;
    sub2api-postgres|sub2api-pg|sub2api-db)
      printf 'sub2api-postgres'
      ;;
    sub2api-redis|sub2api-cache)
      printf 'sub2api-redis'
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
  subtle_note "输入 all 表示全部；也可以输入 1234567、1 2、1,5、nginx、sub2api、webui、newapi-v2、gemini、dufs。"

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
      if [[ "$token" =~ ^[1-7]+$ && "${#token}" -gt 1 ]]; then
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
  NEWAPI_V2_SESSION_SECRET_VALUE="$(random_hex 32)"
  NEWAPI_V2_CRYPTO_SECRET_VALUE="$(random_hex 32)"
  NEWAPI_V2_POSTGRES_PASSWORD_VALUE="$(random_hex 16)"
  NEWAPI_V2_REDIS_PASSWORD_VALUE="$(random_hex 16)"
  CLIPROXY_REMOTE_SECRET_VALUE="$(random_hex 32)"
  CLIPROXY_API_KEY_VALUE="$(random_hex 32)"
  SUB2API_POSTGRES_PASSWORD_VALUE="$(random_hex 16)"
  SUB2API_REDIS_PASSWORD_VALUE="$(random_hex 16)"
  SUB2API_ADMIN_PASSWORD_VALUE="$(random_hex 12)"
  SUB2API_JWT_SECRET_VALUE="$(random_hex 32)"
  SUB2API_TOTP_ENCRYPTION_KEY_VALUE="$(random_hex 32)"
  DUFS_ADMIN_PASSWORD_VALUE="$(random_hex 12)"

  section_title "基础设置"
  use_fixed_stack_dir
  show_stack_dir_notice
  ensure_stack_dir_writable
  load_existing_env_defaults
  if [[ "$DUFS_IMAGE_VALUE" == "sigoden/dufs:latest" ]]; then
    DUFS_IMAGE_VALUE="tannic666/dufs:latest"
  fi
  detect_existing_app_services
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
  merge_existing_services_if_requested

  if needs_newapi_config; then
    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      section_title "New API 配置"
      read_line NEWAPI_IMAGE_VALUE "New API 镜像" "$NEWAPI_IMAGE_VALUE"
      if uses_nginx_frontend; then
        NEWAPI_PUBLISH_HOST_PORT_VALUE=false
        printf '默认启用 Nginx，New API 默认不映射宿主机端口，只允许 Nginx 通过 Docker 网络访问。\n'
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
        printf '默认启用 Nginx，New API 默认只通过 Docker 网络访问。\n'
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

  if needs_newapi_v2_config; then
    [[ -n "$NEWAPI_V2_SESSION_SECRET_VALUE" ]] || NEWAPI_V2_SESSION_SECRET_VALUE="$(random_hex 32)"
    [[ -n "$NEWAPI_V2_CRYPTO_SECRET_VALUE" ]] || NEWAPI_V2_CRYPTO_SECRET_VALUE="$(random_hex 32)"
    [[ -n "$NEWAPI_V2_POSTGRES_PASSWORD_VALUE" ]] || NEWAPI_V2_POSTGRES_PASSWORD_VALUE="$(random_hex 16)"
    [[ -n "$NEWAPI_V2_REDIS_PASSWORD_VALUE" ]] || NEWAPI_V2_REDIS_PASSWORD_VALUE="$(random_hex 16)"

    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      section_title "新版 NewAPI 配置"
      read_line NEWAPI_V2_IMAGE_VALUE "新版 NewAPI 镜像" "$NEWAPI_V2_IMAGE_VALUE"
      if uses_nginx_frontend; then
        NEWAPI_V2_PUBLISH_HOST_PORT_VALUE=false
        printf '默认启用 Nginx，新版 NewAPI 默认不映射宿主机端口，只允许 Nginx 通过 Docker 网络访问。\n'
      else
        read_yes_no NEWAPI_V2_PUBLISH_HOST_PORT_VALUE "是否开放新版 NewAPI 直连端口" "$NEWAPI_V2_PUBLISH_HOST_PORT_VALUE"
      fi
      if [[ "$NEWAPI_V2_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
        read_line NEWAPI_V2_HOST_PORT_VALUE "新版 NewAPI 主机端口" "$NEWAPI_V2_HOST_PORT_VALUE"
      fi
      read_line NEWAPI_V2_SESSION_SECRET_VALUE "新版 NewAPI 会话密钥（明文）" "$NEWAPI_V2_SESSION_SECRET_VALUE"
      read_line NEWAPI_V2_CRYPTO_SECRET_VALUE "新版 NewAPI 加密密钥（明文）" "$NEWAPI_V2_CRYPTO_SECRET_VALUE"
      read_line NEWAPI_V2_ERROR_LOG_ENABLED_VALUE "新版 NewAPI 是否开启错误日志" "$NEWAPI_V2_ERROR_LOG_ENABLED_VALUE"
      read_line NEWAPI_V2_BATCH_UPDATE_ENABLED_VALUE "新版 NewAPI 是否开启批量更新" "$NEWAPI_V2_BATCH_UPDATE_ENABLED_VALUE"
      read_line NEWAPI_V2_MAX_REQUEST_BODY_MB_VALUE "新版 NewAPI 最大请求体 MB" "$NEWAPI_V2_MAX_REQUEST_BODY_MB_VALUE"
      read_line NEWAPI_V2_MAX_FILE_DOWNLOAD_MB_VALUE "新版 NewAPI 最大下载文件 MB" "$NEWAPI_V2_MAX_FILE_DOWNLOAD_MB_VALUE"
      read_line NEWAPI_V2_NODE_NAME_VALUE "新版 NewAPI 节点名" "$NEWAPI_V2_NODE_NAME_VALUE"
      read_line NEWAPI_V2_POSTGRES_IMAGE_VALUE "新版 NewAPI PostgreSQL 镜像" "$NEWAPI_V2_POSTGRES_IMAGE_VALUE"
      read_line NEWAPI_V2_POSTGRES_USER_VALUE "新版 NewAPI PostgreSQL 用户名" "$NEWAPI_V2_POSTGRES_USER_VALUE"
      read_line NEWAPI_V2_POSTGRES_PASSWORD_VALUE "新版 NewAPI PostgreSQL 密码（明文，建议不要包含 @:/?#）" "$NEWAPI_V2_POSTGRES_PASSWORD_VALUE"
      read_line NEWAPI_V2_POSTGRES_DB_VALUE "新版 NewAPI PostgreSQL 数据库名" "$NEWAPI_V2_POSTGRES_DB_VALUE"
      read_line NEWAPI_V2_REDIS_IMAGE_VALUE "新版 NewAPI Redis 镜像" "$NEWAPI_V2_REDIS_IMAGE_VALUE"
      read_line NEWAPI_V2_REDIS_PASSWORD_VALUE "新版 NewAPI Redis 密码（明文）" "$NEWAPI_V2_REDIS_PASSWORD_VALUE"
    else
      NEWAPI_V2_IMAGE_VALUE="tannic666/newapi:latest"
      NEWAPI_V2_ERROR_LOG_ENABLED_VALUE="true"
      NEWAPI_V2_BATCH_UPDATE_ENABLED_VALUE="true"
      NEWAPI_V2_MAX_REQUEST_BODY_MB_VALUE="10240"
      NEWAPI_V2_MAX_FILE_DOWNLOAD_MB_VALUE="10240"
      NEWAPI_V2_NODE_NAME_VALUE="newapi-v2-node-1"
      NEWAPI_V2_POSTGRES_IMAGE_VALUE="postgres:15"
      NEWAPI_V2_POSTGRES_USER_VALUE="newapi_v2"
      NEWAPI_V2_POSTGRES_DB_VALUE="newapi_v2"
      NEWAPI_V2_REDIS_IMAGE_VALUE="redis:7-alpine"
      if uses_nginx_frontend; then
        NEWAPI_V2_PUBLISH_HOST_PORT_VALUE=false
        printf '默认启用 Nginx，新版 NewAPI 默认只通过 Docker 网络访问。\n'
      else
        NEWAPI_V2_PUBLISH_HOST_PORT_VALUE=true
      fi
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
        printf '默认启用 Nginx，CLIProxyAPI 默认不映射宿主机端口，只通过 Nginx 代理 8317 服务。\n'
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
        printf '默认启用 Nginx，CLIProxyAPI 默认只通过 Nginx 代理访问。\n'
      else
        CLIPROXY_PUBLISH_HOST_PORTS_VALUE=true
      fi
    fi
  fi

  if needs_sub2api_config; then
    [[ -n "$SUB2API_POSTGRES_PASSWORD_VALUE" ]] || SUB2API_POSTGRES_PASSWORD_VALUE="$(random_hex 16)"
    [[ -n "$SUB2API_REDIS_PASSWORD_VALUE" ]] || SUB2API_REDIS_PASSWORD_VALUE="$(random_hex 16)"
    [[ -n "$SUB2API_ADMIN_PASSWORD_VALUE" ]] || SUB2API_ADMIN_PASSWORD_VALUE="$(random_hex 12)"
    [[ -n "$SUB2API_JWT_SECRET_VALUE" ]] || SUB2API_JWT_SECRET_VALUE="$(random_hex 32)"
    [[ -n "$SUB2API_TOTP_ENCRYPTION_KEY_VALUE" ]] || SUB2API_TOTP_ENCRYPTION_KEY_VALUE="$(random_hex 32)"

    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      section_title "Sub2API 配置"
      read_line SUB2API_IMAGE_VALUE "Sub2API 镜像" "$SUB2API_IMAGE_VALUE"
      read_line SUB2API_POSTGRES_IMAGE_VALUE "Sub2API PostgreSQL 镜像" "$SUB2API_POSTGRES_IMAGE_VALUE"
      read_line SUB2API_REDIS_IMAGE_VALUE "Sub2API Redis 镜像" "$SUB2API_REDIS_IMAGE_VALUE"
      read_line SUB2API_SERVER_MODE_VALUE "Sub2API SERVER_MODE" "$SUB2API_SERVER_MODE_VALUE"
      read_line SUB2API_RUN_MODE_VALUE "Sub2API RUN_MODE" "$SUB2API_RUN_MODE_VALUE"
      read_line SUB2API_POSTGRES_USER_VALUE "Sub2API PostgreSQL 用户名" "$SUB2API_POSTGRES_USER_VALUE"
      read_line SUB2API_POSTGRES_PASSWORD_VALUE "Sub2API PostgreSQL 密码（明文）" "$SUB2API_POSTGRES_PASSWORD_VALUE"
      read_line SUB2API_POSTGRES_DB_VALUE "Sub2API PostgreSQL 数据库名" "$SUB2API_POSTGRES_DB_VALUE"
      read_line SUB2API_REDIS_PASSWORD_VALUE "Sub2API Redis 密码（明文）" "$SUB2API_REDIS_PASSWORD_VALUE"
      read_line SUB2API_ADMIN_EMAIL_VALUE "Sub2API 管理员邮箱" "$SUB2API_ADMIN_EMAIL_VALUE"
      read_line SUB2API_ADMIN_PASSWORD_VALUE "Sub2API 管理员密码（明文）" "$SUB2API_ADMIN_PASSWORD_VALUE"
      read_line SUB2API_JWT_SECRET_VALUE "Sub2API JWT_SECRET（明文）" "$SUB2API_JWT_SECRET_VALUE"
      read_line SUB2API_TOTP_ENCRYPTION_KEY_VALUE "Sub2API TOTP_ENCRYPTION_KEY（明文）" "$SUB2API_TOTP_ENCRYPTION_KEY_VALUE"
      read_line SUB2API_UPDATE_PROXY_URL_VALUE "Sub2API 更新代理 URL（可留空）" "$SUB2API_UPDATE_PROXY_URL_VALUE"
      if uses_nginx_frontend; then
        SUB2API_PUBLISH_HOST_PORT_VALUE=false
        printf '默认启用 Nginx，Sub2API 默认不映射宿主机端口，只通过 Nginx 访问。\n'
      else
        read_yes_no SUB2API_PUBLISH_HOST_PORT_VALUE "是否开放 Sub2API 直连端口" "$SUB2API_PUBLISH_HOST_PORT_VALUE"
      fi
      if [[ "$SUB2API_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
        read_line SUB2API_HOST_PORT_VALUE "Sub2API 主机端口" "$SUB2API_HOST_PORT_VALUE"
      fi
    else
      SUB2API_IMAGE_VALUE="weishaw/sub2api:latest"
      SUB2API_POSTGRES_IMAGE_VALUE="postgres:18-alpine"
      SUB2API_REDIS_IMAGE_VALUE="redis:8-alpine"
      SUB2API_SERVER_MODE_VALUE="release"
      SUB2API_RUN_MODE_VALUE="standard"
      SUB2API_POSTGRES_USER_VALUE="sub2api"
      SUB2API_POSTGRES_DB_VALUE="sub2api"
      if uses_nginx_frontend; then
        SUB2API_PUBLISH_HOST_PORT_VALUE=false
        printf '默认启用 Nginx，Sub2API 默认只通过 Nginx 访问。\n'
      else
        SUB2API_PUBLISH_HOST_PORT_VALUE=true
      fi
    fi
    [[ -n "$SUB2API_POSTGRES_PASSWORD_VALUE" ]] || SUB2API_POSTGRES_PASSWORD_VALUE="$(random_hex 16)"
    [[ -n "$SUB2API_REDIS_PASSWORD_VALUE" ]] || SUB2API_REDIS_PASSWORD_VALUE="$(random_hex 16)"
    [[ -n "$SUB2API_ADMIN_PASSWORD_VALUE" ]] || SUB2API_ADMIN_PASSWORD_VALUE="$(random_hex 12)"
    [[ -n "$SUB2API_JWT_SECRET_VALUE" ]] || SUB2API_JWT_SECRET_VALUE="$(random_hex 32)"
    [[ -n "$SUB2API_TOTP_ENCRYPTION_KEY_VALUE" ]] || SUB2API_TOTP_ENCRYPTION_KEY_VALUE="$(random_hex 32)"
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
        printf '默认启用 Nginx，GPT Image WebUI 默认不映射宿主机端口，只通过 Nginx 访问。\n'
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
        printf '默认启用 Nginx，GPT Image WebUI 默认只通过 Nginx 访问。\n'
      else
        GPT_IMAGE_WEBUI_PUBLISH_HOST_PORT_VALUE=true
      fi
    fi
  fi

  if needs_gemini_image_desk_config; then
    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      section_title "Gemini Image Desk 配置"
      read_line GEMINI_IMAGE_DESK_IMAGE_VALUE "Gemini Image Desk 镜像" "$GEMINI_IMAGE_DESK_IMAGE_VALUE"
      read_line GEMINI_IMAGE_DESK_BASE_URL_VALUE "Gemini API Base URL" "$GEMINI_IMAGE_DESK_BASE_URL_VALUE"
      read_line GEMINI_IMAGE_DESK_DEFAULT_MODEL_VALUE "默认 Gemini 图像模型" "$GEMINI_IMAGE_DESK_DEFAULT_MODEL_VALUE"
      read_line GEMINI_IMAGE_DESK_PUBLIC_BASE_URL_CONFIG_VALUE "是否允许页面填写 Base URL" "$GEMINI_IMAGE_DESK_PUBLIC_BASE_URL_CONFIG_VALUE"
      if uses_nginx_frontend; then
        GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE=false
        printf '默认启用 Nginx，Gemini Image Desk 默认不映射宿主机端口，只通过 Nginx 访问。\n'
      else
        read_yes_no GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE "是否开放 Gemini Image Desk 直连端口" "$GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE"
      fi
      if [[ "$GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
        read_line GEMINI_IMAGE_DESK_HOST_PORT_VALUE "Gemini Image Desk 主机端口" "$GEMINI_IMAGE_DESK_HOST_PORT_VALUE"
      fi
    else
      GEMINI_IMAGE_DESK_IMAGE_VALUE="tannic666/gemini-image-desk:latest"
      GEMINI_IMAGE_DESK_BASE_URL_VALUE="https://generativelanguage.googleapis.com"
      GEMINI_IMAGE_DESK_DEFAULT_MODEL_VALUE="gemini-2.5-flash-image"
      GEMINI_IMAGE_DESK_PUBLIC_BASE_URL_CONFIG_VALUE="false"
      if uses_nginx_frontend; then
        GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE=false
        printf '默认启用 Nginx，Gemini Image Desk 默认只通过 Nginx 访问。\n'
      else
        GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE=true
      fi
    fi
  fi

  if needs_dufs_config; then
    [[ -n "$DUFS_ADMIN_PASSWORD_VALUE" ]] || DUFS_ADMIN_PASSWORD_VALUE="$(random_hex 12)"
    if [[ -z "$DUFS_DATA_DIR_VALUE" || "$DUFS_DATA_DIR_VALUE" == "${DEFAULT_STACK_DIR}/dufs/data" ]]; then
      DUFS_DATA_DIR_VALUE="$STACK_DIR/dufs/data"
    fi

    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      section_title "Dufs 静态文件配置"
      read_line DUFS_IMAGE_VALUE "Dufs 镜像" "$DUFS_IMAGE_VALUE"
      read_line DUFS_DATA_DIR_VALUE "宿主机静态文件目录" "$DUFS_DATA_DIR_VALUE"
      DUFS_DATA_DIR_VALUE="$(expand_path "$DUFS_DATA_DIR_VALUE")"
      read_line DUFS_ADMIN_USER_VALUE "Dufs 管理员用户名" "$DUFS_ADMIN_USER_VALUE"
      read_line DUFS_ADMIN_PASSWORD_VALUE "Dufs 管理员密码（明文，建议只用字母数字）" "$DUFS_ADMIN_PASSWORD_VALUE"
      read_yes_no DUFS_ANONYMOUS_READ_VALUE "是否允许匿名只读访问直链文件" "$DUFS_ANONYMOUS_READ_VALUE"
      read_yes_no DUFS_ALLOW_UPLOAD_VALUE "是否允许管理员上传文件" "$DUFS_ALLOW_UPLOAD_VALUE"
      read_yes_no DUFS_ALLOW_DELETE_VALUE "是否允许管理员删除文件" "$DUFS_ALLOW_DELETE_VALUE"
      read_yes_no DUFS_ALLOW_SEARCH_VALUE "是否启用搜索" "$DUFS_ALLOW_SEARCH_VALUE"
      read_yes_no DUFS_ALLOW_ARCHIVE_VALUE "是否启用目录打包下载" "$DUFS_ALLOW_ARCHIVE_VALUE"
      read_yes_no DUFS_RENDER_TRY_INDEX_VALUE "目录存在 index.html 时是否优先渲染页面" "$DUFS_RENDER_TRY_INDEX_VALUE"
      if uses_nginx_frontend; then
        DUFS_PUBLISH_HOST_PORT_VALUE=false
        printf '默认启用 Nginx，Dufs 默认不映射宿主机端口，只通过 Nginx 访问。\n'
      else
        read_yes_no DUFS_PUBLISH_HOST_PORT_VALUE "是否开放 Dufs 直连端口" "$DUFS_PUBLISH_HOST_PORT_VALUE"
      fi
      if [[ "$DUFS_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
        read_line DUFS_HOST_PORT_VALUE "Dufs 主机端口" "$DUFS_HOST_PORT_VALUE"
      fi
    else
      DUFS_IMAGE_VALUE="tannic666/dufs:latest"
      DUFS_DATA_DIR_VALUE="$(expand_path "$DUFS_DATA_DIR_VALUE")"
      [[ -n "$DUFS_ADMIN_USER_VALUE" ]] || DUFS_ADMIN_USER_VALUE="admin"
      DUFS_ANONYMOUS_READ_VALUE=true
      DUFS_ALLOW_UPLOAD_VALUE=true
      DUFS_ALLOW_DELETE_VALUE=true
      DUFS_ALLOW_SEARCH_VALUE=true
      DUFS_ALLOW_ARCHIVE_VALUE=true
      DUFS_RENDER_TRY_INDEX_VALUE=true
      DUFS_PUBLISH_HOST_PORT_VALUE=false
      printf '默认启用 Dufs：匿名可读直链，管理员登录后可上传/删除，静态目录为 %s。\n' "$DUFS_DATA_DIR_VALUE"
    fi

    [[ -n "$DUFS_ADMIN_USER_VALUE" ]] || DUFS_ADMIN_USER_VALUE="admin"
    [[ -n "$DUFS_ADMIN_PASSWORD_VALUE" ]] || DUFS_ADMIN_PASSWORD_VALUE="$(random_hex 12)"
    DUFS_AUTH_VALUE="$(build_dufs_auth_value)"
  fi

  if needs_nginx_config; then
    section_title "Nginx 配置"
    if [[ "$ADVANCED_CONFIG_VALUE" == "true" ]]; then
      read_line NGINX_IMAGE_VALUE "Nginx 镜像" "$NGINX_IMAGE_VALUE"
      read_nginx_mode NGINX_DEPLOY_MODE_VALUE "$NGINX_DEPLOY_MODE_VALUE"
      if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
        NGINX_ENABLE_HTTPS=false
        NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE=true
        if needs_newapi_config; then
          read_line NGINX_LAN_API_PORT_VALUE "局域网 API 入口主机端口" "$NGINX_LAN_API_PORT_VALUE"
        fi
        if needs_cliproxy_config; then
          read_line NGINX_LAN_ADMIN_PORT_VALUE "局域网管理端入口主机端口" "$NGINX_LAN_ADMIN_PORT_VALUE"
        fi
        if needs_sub2api_config; then
          read_line NGINX_LAN_SUB2API_PORT_VALUE "局域网 Sub2API 入口主机端口" "$NGINX_LAN_SUB2API_PORT_VALUE"
        fi
        if needs_gpt_image_webui_config; then
          read_line NGINX_LAN_WEBUI_PORT_VALUE "局域网 GPT Image WebUI 入口主机端口" "$NGINX_LAN_WEBUI_PORT_VALUE"
        fi
        if needs_newapi_v2_config; then
          read_line NGINX_LAN_NEWAPI_V2_PORT_VALUE "局域网新版 NewAPI 入口主机端口" "$NGINX_LAN_NEWAPI_V2_PORT_VALUE"
        fi
        if needs_gemini_image_desk_config; then
          read_line NGINX_LAN_GEMINI_IMAGE_DESK_PORT_VALUE "局域网 Gemini Image Desk 入口主机端口" "$NGINX_LAN_GEMINI_IMAGE_DESK_PORT_VALUE"
        fi
        if needs_dufs_config; then
          read_line NGINX_LAN_DUFS_PORT_VALUE "局域网 Dufs 静态文件入口主机端口" "$NGINX_LAN_DUFS_PORT_VALUE"
        fi
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
        needs_newapi_config && read_line NGINX_API_SERVER_NAMES_VALUE "New API 绑定域名（多个空格分隔）" "$NGINX_API_SERVER_NAMES_VALUE"
        needs_cliproxy_config && read_line NGINX_ADMIN_SERVER_NAME_VALUE "CLIProxyAPI 绑定域名（多个空格分隔）" "$NGINX_ADMIN_SERVER_NAME_VALUE"
        needs_sub2api_config && read_line NGINX_SUB2API_SERVER_NAMES_VALUE "Sub2API 绑定域名（多个空格分隔）" "$NGINX_SUB2API_SERVER_NAMES_VALUE"
        needs_gpt_image_webui_config && read_line NGINX_WEBUI_SERVER_NAMES_VALUE "GPT Image WebUI 绑定域名（多个空格分隔）" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
        needs_newapi_v2_config && read_line NGINX_NEWAPI_V2_SERVER_NAMES_VALUE "新版 NewAPI 绑定域名（多个空格分隔）" "$NGINX_NEWAPI_V2_SERVER_NAMES_VALUE"
        needs_gemini_image_desk_config && read_line NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE "Gemini Image Desk 绑定域名（多个空格分隔）" "$NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE"
        needs_dufs_config && read_line NGINX_DUFS_SERVER_NAMES_VALUE "Dufs 静态文件绑定域名（多个空格分隔）" "$NGINX_DUFS_SERVER_NAMES_VALUE"
        NGINX_HTTP_SERVER_NAMES_VALUE="$(build_nginx_http_server_names)"
        if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
          read_nginx_certificate_files
        fi
        needs_newapi_config && read_line NGINX_NEWAPI_UPSTREAM_VALUE "New API 上游地址" "$NGINX_NEWAPI_UPSTREAM_VALUE"
        needs_cliproxy_config && read_line NGINX_CLIPROXY_UPSTREAM_VALUE "CLIProxyAPI 上游地址" "$NGINX_CLIPROXY_UPSTREAM_VALUE"
        needs_sub2api_config && read_line NGINX_SUB2API_UPSTREAM_VALUE "Sub2API 上游地址" "$NGINX_SUB2API_UPSTREAM_VALUE"
        needs_gpt_image_webui_config && read_line NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE "GPT Image WebUI 上游地址" "$NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE"
        needs_newapi_v2_config && read_line NGINX_NEWAPI_V2_UPSTREAM_VALUE "新版 NewAPI 上游地址" "$NGINX_NEWAPI_V2_UPSTREAM_VALUE"
        needs_gemini_image_desk_config && read_line NGINX_GEMINI_IMAGE_DESK_UPSTREAM_VALUE "Gemini Image Desk 上游地址" "$NGINX_GEMINI_IMAGE_DESK_UPSTREAM_VALUE"
        needs_dufs_config && read_line NGINX_DUFS_UPSTREAM_VALUE "Dufs 静态文件上游地址" "$NGINX_DUFS_UPSTREAM_VALUE"
        printf '已绑定所选 Nginx 站点：%s。\n' "$(nginx_selected_service_names)"
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
        needs_newapi_config && read_line NGINX_API_SERVER_NAMES_VALUE "New API 绑定域名（多个空格分隔）" "$NGINX_API_SERVER_NAMES_VALUE"
        needs_cliproxy_config && read_line NGINX_ADMIN_SERVER_NAME_VALUE "CLIProxyAPI 绑定域名（多个空格分隔）" "$NGINX_ADMIN_SERVER_NAME_VALUE"
        needs_sub2api_config && read_line NGINX_SUB2API_SERVER_NAMES_VALUE "Sub2API 绑定域名（多个空格分隔）" "$NGINX_SUB2API_SERVER_NAMES_VALUE"
        needs_gpt_image_webui_config && read_line NGINX_WEBUI_SERVER_NAMES_VALUE "GPT Image WebUI 绑定域名（多个空格分隔）" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
        needs_newapi_v2_config && read_line NGINX_NEWAPI_V2_SERVER_NAMES_VALUE "新版 NewAPI 绑定域名（多个空格分隔）" "$NGINX_NEWAPI_V2_SERVER_NAMES_VALUE"
        needs_gemini_image_desk_config && read_line NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE "Gemini Image Desk 绑定域名（多个空格分隔）" "$NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE"
        needs_dufs_config && read_line NGINX_DUFS_SERVER_NAMES_VALUE "Dufs 静态文件绑定域名（多个空格分隔）" "$NGINX_DUFS_SERVER_NAMES_VALUE"
        NGINX_HTTP_SERVER_NAMES_VALUE="$(build_nginx_http_server_names)"
        if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
          read_nginx_certificate_files
        fi
      fi
      NGINX_NEWAPI_UPSTREAM_VALUE="new-api:3000"
      NGINX_CLIPROXY_UPSTREAM_VALUE="cli-proxy-api:8317"
      NGINX_SUB2API_UPSTREAM_VALUE="sub2api:8080"
      NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE="gpt-image-2-webui:3000"
      NGINX_NEWAPI_V2_UPSTREAM_VALUE="newapi-v2:3000"
      NGINX_GEMINI_IMAGE_DESK_UPSTREAM_VALUE="gemini-image-desk:3000"
      NGINX_DUFS_UPSTREAM_VALUE="dufs:5000"
      if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" ]]; then
        printf '已绑定所选 Nginx 站点：%s。\n' "$(nginx_selected_service_names)"
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
  mkdir -p "$STACK_DIR/nginx/conf.d"
  mkdir -p "$STACK_DIR/nginx/certs"

  if needs_newapi_config; then
    mkdir -p "$STACK_DIR/new-api/data"
    mkdir -p "$STACK_DIR/new-api/logs"
  fi

  if needs_cliproxy_config; then
    mkdir -p "$STACK_DIR/cliproxyapi/auths"
    mkdir -p "$STACK_DIR/cliproxyapi/logs"
  fi

  if needs_newapi_v2_config; then
    mkdir -p "$STACK_DIR/newapi-v2/data"
    mkdir -p "$STACK_DIR/newapi-v2/logs"
  fi

  if needs_sub2api_config; then
    mkdir -p "$STACK_DIR/sub2api/data"
  fi

  if needs_gpt_image_webui_config; then
    mkdir -p "$STACK_DIR/gpt-image-2-webui/generated-images"
    mkdir -p "$STACK_DIR/gpt-image-2-webui/logs"
    chmod -R a+rwX "$STACK_DIR/gpt-image-2-webui/generated-images" "$STACK_DIR/gpt-image-2-webui/logs" 2>/dev/null || true
  fi

  if needs_gemini_image_desk_config; then
    mkdir -p "$STACK_DIR/gemini-image-desk"
  fi

  if needs_dufs_config; then
    mkdir -p "$STACK_DIR/dufs"
    mkdir -p "$DUFS_DATA_DIR_VALUE"
    chmod -R a+rwX "$DUFS_DATA_DIR_VALUE" 2>/dev/null || true
  fi
}

write_env_file() {
  local env_file="$STACK_DIR/.env"
  local nginx_http_server_names="$NGINX_HTTP_SERVER_NAMES_VALUE"

  if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
    nginx_http_server_names="$(build_nginx_http_server_names)"
  fi

  {
    write_env_line "COMPOSE_PROJECT_NAME" "$PROJECT_NAME_VALUE"
    write_env_line "STACK_DIR" "$STACK_DIR"
    write_env_line "TZ" "$TZ_VALUE"
    write_env_line "APP_NET_NAME" "$APP_NET_NAME_VALUE"

    if needs_newapi_config; then
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
    fi

    if needs_newapi_v2_config; then
      write_env_line "NEWAPI_V2_IMAGE" "$NEWAPI_V2_IMAGE_VALUE"
      write_env_line "NEWAPI_V2_PUBLISH_HOST_PORT" "$NEWAPI_V2_PUBLISH_HOST_PORT_VALUE"
      write_env_line "NEWAPI_V2_HOST_PORT" "$NEWAPI_V2_HOST_PORT_VALUE"
      write_env_line "NEWAPI_V2_SESSION_SECRET" "$NEWAPI_V2_SESSION_SECRET_VALUE"
      write_env_line "NEWAPI_V2_CRYPTO_SECRET" "$NEWAPI_V2_CRYPTO_SECRET_VALUE"
      write_env_line "NEWAPI_V2_ERROR_LOG_ENABLED" "$NEWAPI_V2_ERROR_LOG_ENABLED_VALUE"
      write_env_line "NEWAPI_V2_BATCH_UPDATE_ENABLED" "$NEWAPI_V2_BATCH_UPDATE_ENABLED_VALUE"
      write_env_line "NEWAPI_V2_MAX_REQUEST_BODY_MB" "$NEWAPI_V2_MAX_REQUEST_BODY_MB_VALUE"
      write_env_line "NEWAPI_V2_MAX_FILE_DOWNLOAD_MB" "$NEWAPI_V2_MAX_FILE_DOWNLOAD_MB_VALUE"
      write_env_line "NEWAPI_V2_NODE_NAME" "$NEWAPI_V2_NODE_NAME_VALUE"
      write_env_line "NEWAPI_V2_POSTGRES_IMAGE" "$NEWAPI_V2_POSTGRES_IMAGE_VALUE"
      write_env_line "NEWAPI_V2_POSTGRES_USER" "$NEWAPI_V2_POSTGRES_USER_VALUE"
      write_env_line "NEWAPI_V2_POSTGRES_PASSWORD" "$NEWAPI_V2_POSTGRES_PASSWORD_VALUE"
      write_env_line "NEWAPI_V2_POSTGRES_DB" "$NEWAPI_V2_POSTGRES_DB_VALUE"
      write_env_line "NEWAPI_V2_REDIS_IMAGE" "$NEWAPI_V2_REDIS_IMAGE_VALUE"
      write_env_line "NEWAPI_V2_REDIS_PASSWORD" "$NEWAPI_V2_REDIS_PASSWORD_VALUE"
    fi

    if needs_cliproxy_config; then
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
    fi

    if needs_sub2api_config; then
      write_env_line "SUB2API_IMAGE" "$SUB2API_IMAGE_VALUE"
      write_env_line "SUB2API_POSTGRES_IMAGE" "$SUB2API_POSTGRES_IMAGE_VALUE"
      write_env_line "SUB2API_REDIS_IMAGE" "$SUB2API_REDIS_IMAGE_VALUE"
      write_env_line "SUB2API_PUBLISH_HOST_PORT" "$SUB2API_PUBLISH_HOST_PORT_VALUE"
      write_env_line "SUB2API_HOST_PORT" "$SUB2API_HOST_PORT_VALUE"
      write_env_line "SUB2API_SERVER_MODE" "$SUB2API_SERVER_MODE_VALUE"
      write_env_line "SUB2API_RUN_MODE" "$SUB2API_RUN_MODE_VALUE"
      write_env_line "SUB2API_POSTGRES_USER" "$SUB2API_POSTGRES_USER_VALUE"
      write_env_line "SUB2API_POSTGRES_PASSWORD" "$SUB2API_POSTGRES_PASSWORD_VALUE"
      write_env_line "SUB2API_POSTGRES_DB" "$SUB2API_POSTGRES_DB_VALUE"
      write_env_line "SUB2API_REDIS_PASSWORD" "$SUB2API_REDIS_PASSWORD_VALUE"
      write_env_line "SUB2API_ADMIN_EMAIL" "$SUB2API_ADMIN_EMAIL_VALUE"
      write_env_line "SUB2API_ADMIN_PASSWORD" "$SUB2API_ADMIN_PASSWORD_VALUE"
      write_env_line "SUB2API_JWT_SECRET" "$SUB2API_JWT_SECRET_VALUE"
      write_env_line "SUB2API_TOTP_ENCRYPTION_KEY" "$SUB2API_TOTP_ENCRYPTION_KEY_VALUE"
      write_env_line "SUB2API_UPDATE_PROXY_URL" "$SUB2API_UPDATE_PROXY_URL_VALUE"
    fi

    if needs_gpt_image_webui_config; then
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
    fi

    if needs_gemini_image_desk_config; then
      write_env_line "GEMINI_IMAGE_DESK_IMAGE" "$GEMINI_IMAGE_DESK_IMAGE_VALUE"
      write_env_line "GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT" "$GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE"
      write_env_line "GEMINI_IMAGE_DESK_HOST_PORT" "$GEMINI_IMAGE_DESK_HOST_PORT_VALUE"
      write_env_line "GEMINI_IMAGE_DESK_BASE_URL" "$GEMINI_IMAGE_DESK_BASE_URL_VALUE"
      write_env_line "GEMINI_IMAGE_DESK_DEFAULT_MODEL" "$GEMINI_IMAGE_DESK_DEFAULT_MODEL_VALUE"
      write_env_line "GEMINI_IMAGE_DESK_PUBLIC_BASE_URL_CONFIG" "$GEMINI_IMAGE_DESK_PUBLIC_BASE_URL_CONFIG_VALUE"
    fi

    if needs_dufs_config; then
      write_env_line "DUFS_IMAGE" "$DUFS_IMAGE_VALUE"
      write_env_line "DUFS_PUBLISH_HOST_PORT" "$DUFS_PUBLISH_HOST_PORT_VALUE"
      write_env_line "DUFS_HOST_PORT" "$DUFS_HOST_PORT_VALUE"
      write_env_line "DUFS_DATA_DIR" "$DUFS_DATA_DIR_VALUE"
      write_env_line "DUFS_ADMIN_USER" "$DUFS_ADMIN_USER_VALUE"
      write_env_line "DUFS_ADMIN_PASSWORD" "$DUFS_ADMIN_PASSWORD_VALUE"
      write_env_line "DUFS_ANONYMOUS_READ" "$DUFS_ANONYMOUS_READ_VALUE"
      write_env_line "DUFS_AUTH" "$DUFS_AUTH_VALUE"
      write_env_line "DUFS_ALLOW_UPLOAD" "$DUFS_ALLOW_UPLOAD_VALUE"
      write_env_line "DUFS_ALLOW_DELETE" "$DUFS_ALLOW_DELETE_VALUE"
      write_env_line "DUFS_ALLOW_SEARCH" "$DUFS_ALLOW_SEARCH_VALUE"
      write_env_line "DUFS_ALLOW_ARCHIVE" "$DUFS_ALLOW_ARCHIVE_VALUE"
      write_env_line "DUFS_RENDER_TRY_INDEX" "$DUFS_RENDER_TRY_INDEX_VALUE"
    fi

    write_env_line "NGINX_IMAGE" "$NGINX_IMAGE_VALUE"
    write_env_line "NGINX_DEPLOY_MODE" "$NGINX_DEPLOY_MODE_VALUE"
    write_env_line "NGINX_ENABLE_HTTPS" "$NGINX_ENABLE_HTTPS"
    write_env_line "NGINX_SHARE_CERT" "$NGINX_SHARE_CERT_VALUE"
    write_env_line "NGINX_HTTP_TO_HTTPS_REDIRECT" "$NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE"
    write_env_line "NGINX_HTTP_PORT" "$NGINX_HTTP_PORT_VALUE"
    write_env_line "NGINX_HTTPS_PORT" "$NGINX_HTTPS_PORT_VALUE"
    write_env_line "NGINX_HTTP_SERVER_NAMES" "$nginx_http_server_names"

    if needs_newapi_config; then
      write_env_line "NGINX_LAN_API_PORT" "$NGINX_LAN_API_PORT_VALUE"
      write_env_line "NGINX_API_SERVER_NAMES" "$NGINX_API_SERVER_NAMES_VALUE"
      write_env_line "NGINX_API_CERT" "$NGINX_API_CERT_VALUE"
      write_env_line "NGINX_API_KEY" "$NGINX_API_KEY_VALUE"
      write_env_line "NGINX_NEWAPI_UPSTREAM" "$NGINX_NEWAPI_UPSTREAM_VALUE"
    fi

    if needs_cliproxy_config; then
      write_env_line "NGINX_LAN_ADMIN_PORT" "$NGINX_LAN_ADMIN_PORT_VALUE"
      write_env_line "NGINX_ADMIN_SERVER_NAME" "$NGINX_ADMIN_SERVER_NAME_VALUE"
      write_env_line "NGINX_ADMIN_CERT" "$NGINX_ADMIN_CERT_VALUE"
      write_env_line "NGINX_ADMIN_KEY" "$NGINX_ADMIN_KEY_VALUE"
      write_env_line "NGINX_CLIPROXY_UPSTREAM" "$NGINX_CLIPROXY_UPSTREAM_VALUE"
    fi

    if needs_sub2api_config; then
      write_env_line "NGINX_LAN_SUB2API_PORT" "$NGINX_LAN_SUB2API_PORT_VALUE"
      write_env_line "NGINX_SUB2API_SERVER_NAMES" "$NGINX_SUB2API_SERVER_NAMES_VALUE"
      write_env_line "NGINX_SUB2API_CERT" "$NGINX_SUB2API_CERT_VALUE"
      write_env_line "NGINX_SUB2API_KEY" "$NGINX_SUB2API_KEY_VALUE"
      write_env_line "NGINX_SUB2API_UPSTREAM" "$NGINX_SUB2API_UPSTREAM_VALUE"
    fi

    if needs_gpt_image_webui_config; then
      write_env_line "NGINX_LAN_WEBUI_PORT" "$NGINX_LAN_WEBUI_PORT_VALUE"
      write_env_line "NGINX_WEBUI_SERVER_NAMES" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
      write_env_line "NGINX_WEBUI_CERT" "$NGINX_WEBUI_CERT_VALUE"
      write_env_line "NGINX_WEBUI_KEY" "$NGINX_WEBUI_KEY_VALUE"
      write_env_line "NGINX_GPT_IMAGE_WEBUI_UPSTREAM" "$NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE"
    fi

    if needs_newapi_v2_config; then
      write_env_line "NGINX_LAN_NEWAPI_V2_PORT" "$NGINX_LAN_NEWAPI_V2_PORT_VALUE"
      write_env_line "NGINX_NEWAPI_V2_SERVER_NAMES" "$NGINX_NEWAPI_V2_SERVER_NAMES_VALUE"
      write_env_line "NGINX_NEWAPI_V2_CERT" "$NGINX_NEWAPI_V2_CERT_VALUE"
      write_env_line "NGINX_NEWAPI_V2_KEY" "$NGINX_NEWAPI_V2_KEY_VALUE"
      write_env_line "NGINX_NEWAPI_V2_UPSTREAM" "$NGINX_NEWAPI_V2_UPSTREAM_VALUE"
    fi

    if needs_gemini_image_desk_config; then
      write_env_line "NGINX_LAN_GEMINI_IMAGE_DESK_PORT" "$NGINX_LAN_GEMINI_IMAGE_DESK_PORT_VALUE"
      write_env_line "NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES" "$NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE"
      write_env_line "NGINX_GEMINI_IMAGE_DESK_CERT" "$NGINX_GEMINI_IMAGE_DESK_CERT_VALUE"
      write_env_line "NGINX_GEMINI_IMAGE_DESK_KEY" "$NGINX_GEMINI_IMAGE_DESK_KEY_VALUE"
      write_env_line "NGINX_GEMINI_IMAGE_DESK_UPSTREAM" "$NGINX_GEMINI_IMAGE_DESK_UPSTREAM_VALUE"
    fi

    if needs_dufs_config; then
      write_env_line "NGINX_LAN_DUFS_PORT" "$NGINX_LAN_DUFS_PORT_VALUE"
      write_env_line "NGINX_DUFS_SERVER_NAMES" "$NGINX_DUFS_SERVER_NAMES_VALUE"
      write_env_line "NGINX_DUFS_CERT" "$NGINX_DUFS_CERT_VALUE"
      write_env_line "NGINX_DUFS_KEY" "$NGINX_DUFS_KEY_VALUE"
      write_env_line "NGINX_DUFS_UPSTREAM" "$NGINX_DUFS_UPSTREAM_VALUE"
    fi
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

write_nginx_common_conf() {
  local file="$1"
  local redirect_target=""

  cat > "$file" <<'NGINX'
# Common config generated by one-click deploy.
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

client_max_body_size 0;

gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_proxied any;
gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml application/xml+rss;

proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
NGINX

  if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_ENABLE_HTTPS" == "true" && "$NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE" == "true" ]]; then
    if [[ "$NGINX_HTTPS_PORT_VALUE" == "443" ]]; then
      redirect_target="https://\$host\$request_uri"
    else
      redirect_target="https://\$host:${NGINX_HTTPS_PORT_VALUE}\$request_uri"
    fi

    cat >> "$file" <<NGINX

server {
    listen 80 default_server;
    server_name _;

    return 301 ${redirect_target};
}
NGINX
  fi
}

write_nginx_service_conf_header() {
  local file="$1"
  local title="$2"

  cat > "$file" <<NGINX
# ${title}
# Generated by one-click deploy. Put custom Nginx rules in another .conf file.
NGINX
}

nginx_service_conf_file() {
  local service="$1"

  case "$service" in
    new-api)
      printf '%s/nginx/conf.d/new-api.conf' "$STACK_DIR"
      ;;
    cli-proxy-api)
      printf '%s/nginx/conf.d/cliproxyapi.conf' "$STACK_DIR"
      ;;
    sub2api)
      printf '%s/nginx/conf.d/sub2api.conf' "$STACK_DIR"
      ;;
    gpt-image-2-webui)
      printf '%s/nginx/conf.d/webui.conf' "$STACK_DIR"
      ;;
    newapi-v2)
      printf '%s/nginx/conf.d/newapi-v2.conf' "$STACK_DIR"
      ;;
    gemini-image-desk)
      printf '%s/nginx/conf.d/gemini-desk.conf' "$STACK_DIR"
      ;;
    dufs)
      printf '%s/nginx/conf.d/dufs.conf' "$STACK_DIR"
      ;;
    *)
      die "Unknown Nginx service: $service"
      ;;
  esac
}

backup_existing_nginx_default_conf() {
  local file="$STACK_DIR/nginx/conf.d/default.conf"
  local backup=""

  [[ -f "$file" ]] || return 0
  grep -q '^# Common config generated by one-click deploy\.$' "$file" && return 0

  backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
  cp -p "$file" "$backup"
  subtle_note "Existing Nginx default.conf was backed up to: $backup"
}

append_nginx_proxy_server() {
  local file="$1"
  local title="$2"
  local listen_value="$3"
  local server_names="$4"
  local upstream="$5"
  local _forwarded_proto="$6"
  local cert_file="${7:-}"
  local key_file="${8:-}"
  local read_timeout="${9:-600s}"
  local connect_timeout="${10:-}"

  {
    printf '\n# %s\n' "$title"
    printf 'server {\n'
    printf '    listen %s;\n' "$listen_value"
    printf '    server_name %s;\n\n' "$server_names"

    if [[ -n "$cert_file" ]]; then
      printf '    ssl_certificate      /etc/nginx/certs/%s;\n' "$cert_file"
      printf '    ssl_certificate_key  /etc/nginx/certs/%s;\n\n' "$key_file"
      printf '    ssl_protocols TLSv1.2 TLSv1.3;\n'
      printf '    ssl_session_cache shared:SSL:10m;\n'
      printf '    ssl_session_timeout 10m;\n\n'
    fi

    printf '    location / {\n'
    printf '        proxy_pass http://%s;\n' "$upstream"
    if [[ -n "$connect_timeout" ]]; then
      printf '        proxy_connect_timeout %s;\n' "$connect_timeout"
    fi
    printf '        proxy_read_timeout %s;\n' "$read_timeout"
    printf '        proxy_send_timeout %s;\n' "$read_timeout"
    printf '    }\n'
    printf '}\n'
  } >> "$file"
}

write_nginx_service_conf() {
  local file="$1"
  local title="$2"
  local server_names="$3"
  local upstream="$4"
  local cert_file="${5:-}"
  local key_file="${6:-}"
  local read_timeout="${7:-600s}"
  local connect_timeout="${8:-}"
  local lan_listen="${9:-}"

  write_nginx_service_conf_header "$file" "$title"

  if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
    append_nginx_proxy_server "$file" "$title" "${lan_listen} default_server" "_" "$upstream" "http" "" "" "$read_timeout" "$connect_timeout"
    return
  fi

  if [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
    if [[ "$NGINX_HTTP_TO_HTTPS_REDIRECT_VALUE" != "true" ]]; then
      append_nginx_proxy_server "$file" "${title} - HTTP" "80" "$server_names" "$upstream" "http" "" "" "$read_timeout" "$connect_timeout"
    fi

    append_nginx_proxy_server "$file" "${title} - HTTPS" "443 ssl" "$server_names" "$upstream" "https" "$cert_file" "$key_file" "$read_timeout" "$connect_timeout"
    return
  fi

  append_nginx_proxy_server "$file" "$title" "80" "$server_names" "$upstream" "http" "" "" "$read_timeout" "$connect_timeout"
}

write_nginx_conf() {
  backup_existing_nginx_default_conf
  write_nginx_common_conf "$STACK_DIR/nginx/conf.d/default.conf"

  if needs_newapi_config; then
    write_nginx_service_conf "$(nginx_service_conf_file "new-api")" "New API" "$NGINX_API_SERVER_NAMES_VALUE" "$NGINX_NEWAPI_UPSTREAM_VALUE" "$NGINX_API_CERT_VALUE" "$NGINX_API_KEY_VALUE" "300s" "" "80"
  fi

  if needs_cliproxy_config; then
    write_nginx_service_conf "$(nginx_service_conf_file "cli-proxy-api")" "CPA / CLIProxyAPI" "$NGINX_ADMIN_SERVER_NAME_VALUE" "$NGINX_CLIPROXY_UPSTREAM_VALUE" "$NGINX_ADMIN_CERT_VALUE" "$NGINX_ADMIN_KEY_VALUE" "600s" "600s" "8080"
  fi

  if needs_sub2api_config; then
    write_nginx_service_conf "$(nginx_service_conf_file "sub2api")" "Sub2API" "$NGINX_SUB2API_SERVER_NAMES_VALUE" "$NGINX_SUB2API_UPSTREAM_VALUE" "$NGINX_SUB2API_CERT_VALUE" "$NGINX_SUB2API_KEY_VALUE" "600s" "" "8081"
  fi

  if needs_gpt_image_webui_config; then
    write_nginx_service_conf "$(nginx_service_conf_file "gpt-image-2-webui")" "GPT Image WebUI" "$NGINX_WEBUI_SERVER_NAMES_VALUE" "$NGINX_GPT_IMAGE_WEBUI_UPSTREAM_VALUE" "$NGINX_WEBUI_CERT_VALUE" "$NGINX_WEBUI_KEY_VALUE" "600s" "" "8082"
  fi

  if needs_newapi_v2_config; then
    write_nginx_service_conf "$(nginx_service_conf_file "newapi-v2")" "NewAPI v2" "$NGINX_NEWAPI_V2_SERVER_NAMES_VALUE" "$NGINX_NEWAPI_V2_UPSTREAM_VALUE" "$NGINX_NEWAPI_V2_CERT_VALUE" "$NGINX_NEWAPI_V2_KEY_VALUE" "300s" "" "8083"
  fi

  if needs_gemini_image_desk_config; then
    write_nginx_service_conf "$(nginx_service_conf_file "gemini-image-desk")" "Gemini Image Desk" "$NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE" "$NGINX_GEMINI_IMAGE_DESK_UPSTREAM_VALUE" "$NGINX_GEMINI_IMAGE_DESK_CERT_VALUE" "$NGINX_GEMINI_IMAGE_DESK_KEY_VALUE" "600s" "" "8084"
  fi

  if needs_dufs_config; then
    write_nginx_service_conf "$(nginx_service_conf_file "dufs")" "Dufs Static Files" "$NGINX_DUFS_SERVER_NAMES_VALUE" "$NGINX_DUFS_UPSTREAM_VALUE" "$NGINX_DUFS_CERT_VALUE" "$NGINX_DUFS_KEY_VALUE" "600s" "" "8085"
  fi
}

validate_nginx_certificates() {
  local certs=()
  local file=""

  needs_nginx_config || return 0
  [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_ENABLE_HTTPS" == "true" ]] || return 0

  if [[ "$NGINX_SHARE_CERT_VALUE" == "true" ]]; then
    certs+=("$NGINX_API_CERT_VALUE" "$NGINX_API_KEY_VALUE")
  else
    needs_newapi_config && certs+=("$NGINX_API_CERT_VALUE" "$NGINX_API_KEY_VALUE")
    needs_cliproxy_config && certs+=("$NGINX_ADMIN_CERT_VALUE" "$NGINX_ADMIN_KEY_VALUE")
    needs_sub2api_config && certs+=("$NGINX_SUB2API_CERT_VALUE" "$NGINX_SUB2API_KEY_VALUE")
    needs_gpt_image_webui_config && certs+=("$NGINX_WEBUI_CERT_VALUE" "$NGINX_WEBUI_KEY_VALUE")
    needs_newapi_v2_config && certs+=("$NGINX_NEWAPI_V2_CERT_VALUE" "$NGINX_NEWAPI_V2_KEY_VALUE")
    needs_gemini_image_desk_config && certs+=("$NGINX_GEMINI_IMAGE_DESK_CERT_VALUE" "$NGINX_GEMINI_IMAGE_DESK_KEY_VALUE")
    needs_dufs_config && certs+=("$NGINX_DUFS_CERT_VALUE" "$NGINX_DUFS_KEY_VALUE")
  fi

  for file in "${certs[@]}"; do
    [[ -n "$file" ]] || die "HTTPS 证书文件名不能为空。"
    [[ "$file" != /* && "$file" != *".."* ]] || die "证书文件名只填写 nginx/certs 下的文件名，不要填写路径：$file"
    [[ -f "$STACK_DIR/nginx/certs/$file" ]] || die "未找到证书文件：$STACK_DIR/nginx/certs/$file。请先签发/安装证书，或确认部署时填写的文件名。"
  done
}

write_compose_file() {
  local compose_file="${1:-$STACK_DIR/docker-compose.yml}"
  local include_nginx="${2:-true}"
  local include_nginx_depends="${3:-true}"
  local include_services="${4:-true}"

  cat > "$compose_file" <<'YAML'
services:
YAML

  if [[ "$include_services" == "true" ]] && needs_newapi_config; then
    cat >> "$compose_file" <<'YAML'
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
      - ${STACK_DIR:-/opt/ai-api-stack}/new-api/data:/data
      - ${STACK_DIR:-/opt/ai-api-stack}/new-api/logs:/app/logs
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

YAML
  fi

  if [[ "$include_services" == "true" ]] && needs_newapi_v2_config; then
    cat >> "$compose_file" <<'YAML'
  newapi-v2:
    image: "${NEWAPI_V2_IMAGE:-tannic666/newapi:latest}"
    restart: unless-stopped
    command: --log-dir /app/logs
YAML

    if [[ "$NEWAPI_V2_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
      cat >> "$compose_file" <<'YAML'
    ports:
      - "${NEWAPI_V2_HOST_PORT:-3002}:3000"
YAML
    fi

    cat >> "$compose_file" <<'YAML'
    volumes:
      - ${STACK_DIR:-/opt/ai-api-stack}/newapi-v2/data:/data
      - ${STACK_DIR:-/opt/ai-api-stack}/newapi-v2/logs:/app/logs
    environment:
      TZ: "${TZ:-Asia/Shanghai}"
      SQL_DSN: "postgresql://${NEWAPI_V2_POSTGRES_USER:-newapi_v2}:${NEWAPI_V2_POSTGRES_PASSWORD:-change-me}@newapi-v2-postgres:5432/${NEWAPI_V2_POSTGRES_DB:-newapi_v2}?sslmode=disable"
      REDIS_CONN_STRING: "redis://:${NEWAPI_V2_REDIS_PASSWORD:-change-me}@newapi-v2-redis:6379/0"
      SESSION_SECRET: "${NEWAPI_V2_SESSION_SECRET:-change-me-session-secret}"
      CRYPTO_SECRET: "${NEWAPI_V2_CRYPTO_SECRET:-change-me-crypto-secret}"
      ERROR_LOG_ENABLED: "${NEWAPI_V2_ERROR_LOG_ENABLED:-true}"
      BATCH_UPDATE_ENABLED: "${NEWAPI_V2_BATCH_UPDATE_ENABLED:-true}"
      MAX_REQUEST_BODY_MB: "${NEWAPI_V2_MAX_REQUEST_BODY_MB:-10240}"
      MAX_FILE_DOWNLOAD_MB: "${NEWAPI_V2_MAX_FILE_DOWNLOAD_MB:-10240}"
      NODE_NAME: "${NEWAPI_V2_NODE_NAME:-newapi-v2-node-1}"
    depends_on:
      newapi-v2-postgres:
        condition: service_healthy
      newapi-v2-redis:
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
      - public-net
      - newapi-v2-internal

  newapi-v2-postgres:
    image: "${NEWAPI_V2_POSTGRES_IMAGE:-postgres:15}"
    restart: unless-stopped
    environment:
      TZ: "${TZ:-Asia/Shanghai}"
      POSTGRES_USER: "${NEWAPI_V2_POSTGRES_USER:-newapi_v2}"
      POSTGRES_PASSWORD: "${NEWAPI_V2_POSTGRES_PASSWORD:-change-me}"
      POSTGRES_DB: "${NEWAPI_V2_POSTGRES_DB:-newapi_v2}"
    volumes:
      - newapi-v2-postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${NEWAPI_V2_POSTGRES_USER:-newapi_v2} -d ${NEWAPI_V2_POSTGRES_DB:-newapi_v2}"]
      interval: 5s
      timeout: 5s
      retries: 20
    networks:
      - newapi-v2-internal

  newapi-v2-redis:
    image: "${NEWAPI_V2_REDIS_IMAGE:-redis:7-alpine}"
    restart: unless-stopped
    command: ["redis-server", "--appendonly", "yes", "--requirepass", "${NEWAPI_V2_REDIS_PASSWORD:-change-me}"]
    environment:
      REDISCLI_AUTH: "${NEWAPI_V2_REDIS_PASSWORD:-change-me}"
    volumes:
      - newapi-v2-redis-data:/data
    healthcheck:
      test: ["CMD-SHELL", "redis-cli -a \"$${REDISCLI_AUTH}\" ping | grep -q PONG"]
      interval: 5s
      timeout: 5s
      retries: 20
    networks:
      - newapi-v2-internal

YAML
  fi

  if [[ "$include_services" == "true" ]] && needs_cliproxy_config; then
    cat >> "$compose_file" <<'YAML'
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
      - ${STACK_DIR:-/opt/ai-api-stack}/cliproxyapi/config.yaml:/CLIProxyAPI/config.yaml
      - ${STACK_DIR:-/opt/ai-api-stack}/cliproxyapi/auths:/root/.cli-proxy-api
      - ${STACK_DIR:-/opt/ai-api-stack}/cliproxyapi/logs:/CLIProxyAPI/logs
    networks:
      - public-net

YAML
  fi

  if [[ "$include_services" == "true" ]] && needs_sub2api_config; then
    cat >> "$compose_file" <<'YAML'
  sub2api:
    image: "${SUB2API_IMAGE:-weishaw/sub2api:latest}"
    restart: unless-stopped
    ulimits:
      nofile:
        soft: 100000
        hard: 100000
    volumes:
      - ${STACK_DIR:-/opt/ai-api-stack}/sub2api/data:/app/data
    environment:
      AUTO_SETUP: "true"
      SERVER_HOST: "0.0.0.0"
      SERVER_PORT: "8080"
      SERVER_MODE: "${SUB2API_SERVER_MODE:-release}"
      RUN_MODE: "${SUB2API_RUN_MODE:-standard}"
      DATABASE_HOST: "sub2api-postgres"
      DATABASE_PORT: "5432"
      DATABASE_USER: "${SUB2API_POSTGRES_USER:-sub2api}"
      DATABASE_PASSWORD: "${SUB2API_POSTGRES_PASSWORD:-change-me}"
      DATABASE_DBNAME: "${SUB2API_POSTGRES_DB:-sub2api}"
      DATABASE_SSLMODE: "disable"
      REDIS_HOST: "sub2api-redis"
      REDIS_PORT: "6379"
      REDIS_PASSWORD: "${SUB2API_REDIS_PASSWORD:-change-me}"
      REDIS_DB: "0"
      REDIS_ENABLE_TLS: "false"
      ADMIN_EMAIL: "${SUB2API_ADMIN_EMAIL:-admin@sub2api.local}"
      ADMIN_PASSWORD: "${SUB2API_ADMIN_PASSWORD:-}"
      JWT_SECRET: "${SUB2API_JWT_SECRET:-}"
      JWT_EXPIRE_HOUR: "24"
      TOTP_ENCRYPTION_KEY: "${SUB2API_TOTP_ENCRYPTION_KEY:-}"
      TZ: "${TZ:-Asia/Shanghai}"
      SECURITY_URL_ALLOWLIST_ENABLED: "false"
      SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP: "true"
      SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS: "true"
      UPDATE_PROXY_URL: "${SUB2API_UPDATE_PROXY_URL:-}"
YAML

  if [[ "$SUB2API_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
    cat >> "$compose_file" <<'YAML'
    ports:
      - "${SUB2API_HOST_PORT:-8081}:8080"
YAML
  fi

  cat >> "$compose_file" <<'YAML'
    depends_on:
      sub2api-postgres:
        condition: service_healthy
      sub2api-redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-q", "-T", "5", "-O", "/dev/null", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    networks:
      - public-net
      - sub2api-internal

  sub2api-postgres:
    image: "${SUB2API_POSTGRES_IMAGE:-postgres:18-alpine}"
    restart: unless-stopped
    ulimits:
      nofile:
        soft: 100000
        hard: 100000
    volumes:
      - sub2api-postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: "${SUB2API_POSTGRES_USER:-sub2api}"
      POSTGRES_PASSWORD: "${SUB2API_POSTGRES_PASSWORD:-change-me}"
      POSTGRES_DB: "${SUB2API_POSTGRES_DB:-sub2api}"
      PGDATA: "/var/lib/postgresql/data"
      TZ: "${TZ:-Asia/Shanghai}"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${SUB2API_POSTGRES_USER:-sub2api} -d ${SUB2API_POSTGRES_DB:-sub2api}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    networks:
      - sub2api-internal

  sub2api-redis:
    image: "${SUB2API_REDIS_IMAGE:-redis:8-alpine}"
    restart: unless-stopped
    ulimits:
      nofile:
        soft: 100000
        hard: 100000
    command: ["redis-server", "--save", "60", "1", "--appendonly", "yes", "--appendfsync", "everysec", "--requirepass", "${SUB2API_REDIS_PASSWORD:-change-me}"]
    volumes:
      - sub2api-redis-data:/data
    environment:
      TZ: "${TZ:-Asia/Shanghai}"
      REDISCLI_AUTH: "${SUB2API_REDIS_PASSWORD:-change-me}"
    healthcheck:
      test: ["CMD-SHELL", "redis-cli -a \"$${REDISCLI_AUTH}\" ping | grep -q PONG"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s
    networks:
      - sub2api-internal

YAML
  fi

  if [[ "$include_services" == "true" ]] && needs_gpt_image_webui_config; then
    cat >> "$compose_file" <<'YAML'
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
      - ${STACK_DIR:-/opt/ai-api-stack}/gpt-image-2-webui/generated-images:/app/generated-images
      - ${STACK_DIR:-/opt/ai-api-stack}/gpt-image-2-webui/logs:/app/logs
    networks:
      - public-net

YAML
  fi

  if [[ "$include_services" == "true" ]] && needs_gemini_image_desk_config; then
    cat >> "$compose_file" <<'YAML'
  gemini-image-desk:
    image: "${GEMINI_IMAGE_DESK_IMAGE:-tannic666/gemini-image-desk:latest}"
    restart: unless-stopped
    environment:
      PORT: "3000"
      GEMINI_BASE_URL: "${GEMINI_IMAGE_DESK_BASE_URL:-https://generativelanguage.googleapis.com}"
      GEMINI_DEFAULT_MODEL: "${GEMINI_IMAGE_DESK_DEFAULT_MODEL:-gemini-2.5-flash-image}"
      PUBLIC_BASE_URL_CONFIG: "${GEMINI_IMAGE_DESK_PUBLIC_BASE_URL_CONFIG:-false}"
YAML

    if [[ "$GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
      cat >> "$compose_file" <<'YAML'
    ports:
      - "${GEMINI_IMAGE_DESK_HOST_PORT:-3003}:3000"
YAML
    fi

    cat >> "$compose_file" <<'YAML'
    networks:
      - public-net

YAML
  fi

  if [[ "$include_services" == "true" ]] && needs_dufs_config; then
    cat >> "$compose_file" <<'YAML'
  dufs:
    image: "${DUFS_IMAGE:-tannic666/dufs:latest}"
    restart: unless-stopped
    environment:
      TZ: "${TZ:-Asia/Shanghai}"
      DUFS_SERVE_PATH: "/data"
      DUFS_BIND: "0.0.0.0"
      DUFS_PORT: "5000"
      DUFS_AUTH: "${DUFS_AUTH:-admin:change-me@/:rw|@/}"
      DUFS_ALLOW_UPLOAD: "${DUFS_ALLOW_UPLOAD:-true}"
      DUFS_ALLOW_DELETE: "${DUFS_ALLOW_DELETE:-true}"
      DUFS_ALLOW_SEARCH: "${DUFS_ALLOW_SEARCH:-true}"
      DUFS_ALLOW_ARCHIVE: "${DUFS_ALLOW_ARCHIVE:-true}"
      DUFS_RENDER_TRY_INDEX: "${DUFS_RENDER_TRY_INDEX:-true}"
YAML

    if [[ "$DUFS_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
      cat >> "$compose_file" <<'YAML'
    ports:
      - "${DUFS_HOST_PORT:-5000}:5000"
YAML
    fi

    cat >> "$compose_file" <<'YAML'
    volumes:
      - ${DUFS_DATA_DIR:-/opt/ai-api-stack/dufs/data}:/data
    networks:
      - public-net

YAML
  fi

  if [[ "$include_nginx" == "true" ]]; then
    cat >> "$compose_file" <<'YAML'
  nginx:
    image: "${NGINX_IMAGE:-nginx:alpine}"
    restart: unless-stopped
    ports:
YAML

  if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
    if needs_newapi_config; then
      cat >> "$compose_file" <<'YAML'
      - "${NGINX_LAN_API_PORT:-80}:80"
YAML
    fi
    if needs_cliproxy_config; then
      cat >> "$compose_file" <<'YAML'
      - "${NGINX_LAN_ADMIN_PORT:-8080}:8080"
YAML
    fi
    if needs_sub2api_config; then
      cat >> "$compose_file" <<'YAML'
      - "${NGINX_LAN_SUB2API_PORT:-8081}:8081"
YAML
    fi
    if needs_gpt_image_webui_config; then
      cat >> "$compose_file" <<'YAML'
      - "${NGINX_LAN_WEBUI_PORT:-8082}:8082"
YAML
    fi
    if needs_newapi_v2_config; then
      cat >> "$compose_file" <<'YAML'
      - "${NGINX_LAN_NEWAPI_V2_PORT:-8083}:8083"
YAML
    fi
    if needs_gemini_image_desk_config; then
      cat >> "$compose_file" <<'YAML'
      - "${NGINX_LAN_GEMINI_IMAGE_DESK_PORT:-8084}:8084"
YAML
    fi
    if needs_dufs_config; then
      cat >> "$compose_file" <<'YAML'
      - "${NGINX_LAN_DUFS_PORT:-8085}:8085"
YAML
    fi
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
      - ${STACK_DIR:-/opt/ai-api-stack}/nginx/conf.d:/etc/nginx/conf.d:ro
YAML

  if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_ENABLE_HTTPS" == "true" ]]; then
    cat >> "$compose_file" <<'YAML'
      - ${STACK_DIR:-/opt/ai-api-stack}/nginx/certs:/etc/nginx/certs:ro
YAML
  fi

  if [[ "$include_nginx_depends" == "true" ]]; then
    cat >> "$compose_file" <<'YAML'
    depends_on:
YAML
    needs_newapi_config && cat >> "$compose_file" <<'YAML'
      - new-api
YAML
    needs_cliproxy_config && cat >> "$compose_file" <<'YAML'
      - cli-proxy-api
YAML
    needs_sub2api_config && cat >> "$compose_file" <<'YAML'
      - sub2api
YAML
    needs_gpt_image_webui_config && cat >> "$compose_file" <<'YAML'
      - gpt-image-2-webui
YAML
    needs_newapi_v2_config && cat >> "$compose_file" <<'YAML'
      - newapi-v2
YAML
    needs_gemini_image_desk_config && cat >> "$compose_file" <<'YAML'
      - gemini-image-desk
YAML
    needs_dufs_config && cat >> "$compose_file" <<'YAML'
      - dufs
YAML
  fi

  cat >> "$compose_file" <<'YAML'
    networks:
      - public-net
YAML
  fi

  if [[ "$include_services" == "true" ]] && { needs_newapi_config || needs_newapi_v2_config || needs_sub2api_config; }; then
    cat >> "$compose_file" <<'YAML'

volumes:
YAML

    if needs_newapi_config; then
      cat >> "$compose_file" <<'YAML'
  postgres-data:
  redis-data:
YAML
    fi

    if needs_newapi_v2_config; then
      cat >> "$compose_file" <<'YAML'
  newapi-v2-postgres-data:
  newapi-v2-redis-data:
YAML
    fi

    if needs_sub2api_config; then
      cat >> "$compose_file" <<'YAML'
  sub2api-postgres-data:
  sub2api-redis-data:
YAML
    fi
  fi

  cat >> "$compose_file" <<'YAML'
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

  if [[ "$include_services" == "true" ]] && needs_newapi_config; then
    cat >> "$compose_file" <<'YAML'
  stack-internal:
    driver: bridge
YAML
  fi

  if [[ "$include_services" == "true" ]] && needs_newapi_v2_config; then
    cat >> "$compose_file" <<'YAML'
  newapi-v2-internal:
    driver: bridge
YAML
  fi

  if [[ "$include_services" == "true" ]] && needs_sub2api_config; then
    cat >> "$compose_file" <<'YAML'
  sub2api-internal:
    driver: bridge
YAML
  fi
}

write_service_compose_for() {
  local target_file="$1"
  local service="$2"
  local old_deploy_all="$DEPLOY_ALL"
  local old_selected=("${SELECTED_SERVICES[@]}")

  DEPLOY_ALL=false
  SELECTED_SERVICES=("$service")
  write_compose_file "$target_file" "false" "false"

  DEPLOY_ALL="$old_deploy_all"
  SELECTED_SERVICES=("${old_selected[@]}")
}

write_service_compose_files() {
  local include_newapi="false"
  local include_newapi_v2="false"
  local include_cliproxy="false"
  local include_sub2api="false"
  local include_webui="false"
  local include_gemini_desk="false"
  local include_dufs="false"

  needs_newapi_config && include_newapi="true"
  needs_newapi_v2_config && include_newapi_v2="true"
  needs_cliproxy_config && include_cliproxy="true"
  needs_sub2api_config && include_sub2api="true"
  needs_gpt_image_webui_config && include_webui="true"
  needs_gemini_image_desk_config && include_gemini_desk="true"
  needs_dufs_config && include_dufs="true"

  [[ "$include_newapi" == "true" ]] && write_service_compose_for "$STACK_DIR/new-api/docker-compose.yml" "new-api"
  [[ "$include_newapi_v2" == "true" ]] && write_service_compose_for "$STACK_DIR/newapi-v2/docker-compose.yml" "newapi-v2"
  [[ "$include_cliproxy" == "true" ]] && write_service_compose_for "$STACK_DIR/cliproxyapi/docker-compose.yml" "cli-proxy-api"
  [[ "$include_sub2api" == "true" ]] && write_service_compose_for "$STACK_DIR/sub2api/docker-compose.yml" "sub2api"
  [[ "$include_webui" == "true" ]] && write_service_compose_for "$STACK_DIR/gpt-image-2-webui/docker-compose.yml" "gpt-image-2-webui"
  [[ "$include_gemini_desk" == "true" ]] && write_service_compose_for "$STACK_DIR/gemini-image-desk/docker-compose.yml" "gemini-image-desk"
  [[ "$include_dufs" == "true" ]] && write_service_compose_for "$STACK_DIR/dufs/docker-compose.yml" "dufs"

  write_compose_file "$STACK_DIR/nginx/docker-compose.yml" "true" "false" "false"
}

write_files() {
  prepare_directories
  write_env_file
  needs_cliproxy_config && write_clipproxy_config
  write_nginx_conf
  validate_nginx_certificates
  write_compose_file
  write_service_compose_files
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

  if [[ "$DEPLOY_ALL" == "true" ]]; then
    args+=("--remove-orphans")
  else
    args+=("${SELECTED_SERVICES[@]}")
    args+=("nginx")
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
  local sub2api_primary=""
  local webui_primary=""
  local newapi_v2_primary=""
  local gemini_desk_primary=""
  local dufs_primary=""
  local newapi_url=""
  local cliproxy_url=""
  local sub2api_url=""
  local webui_url=""
  local newapi_v2_url=""
  local gemini_desk_url=""
  local dufs_url=""

  lan_ip="$(detect_lan_ip)"
  api_primary="$(first_word "$NGINX_API_SERVER_NAMES_VALUE")"
  admin_primary="$(first_word "$NGINX_ADMIN_SERVER_NAME_VALUE")"
  sub2api_primary="$(first_word "$NGINX_SUB2API_SERVER_NAMES_VALUE")"
  webui_primary="$(first_word "$NGINX_WEBUI_SERVER_NAMES_VALUE")"
  newapi_v2_primary="$(first_word "$NGINX_NEWAPI_V2_SERVER_NAMES_VALUE")"
  gemini_desk_primary="$(first_word "$NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE")"
  dufs_primary="$(first_word "$NGINX_DUFS_SERVER_NAMES_VALUE")"

  if needs_nginx_config; then
    if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
      if [[ -n "$lan_ip" ]]; then
        newapi_url="http://${lan_ip}:${NGINX_LAN_API_PORT_VALUE}"
        cliproxy_url="http://${lan_ip}:${NGINX_LAN_ADMIN_PORT_VALUE}"
        sub2api_url="http://${lan_ip}:${NGINX_LAN_SUB2API_PORT_VALUE}"
        webui_url="http://${lan_ip}:${NGINX_LAN_WEBUI_PORT_VALUE}"
        newapi_v2_url="http://${lan_ip}:${NGINX_LAN_NEWAPI_V2_PORT_VALUE}"
        gemini_desk_url="http://${lan_ip}:${NGINX_LAN_GEMINI_IMAGE_DESK_PORT_VALUE}"
        dufs_url="http://${lan_ip}:${NGINX_LAN_DUFS_PORT_VALUE}"
      else
        newapi_url="http://服务器IP:${NGINX_LAN_API_PORT_VALUE}"
        cliproxy_url="http://服务器IP:${NGINX_LAN_ADMIN_PORT_VALUE}"
        sub2api_url="http://服务器IP:${NGINX_LAN_SUB2API_PORT_VALUE}"
        webui_url="http://服务器IP:${NGINX_LAN_WEBUI_PORT_VALUE}"
        newapi_v2_url="http://服务器IP:${NGINX_LAN_NEWAPI_V2_PORT_VALUE}"
        gemini_desk_url="http://服务器IP:${NGINX_LAN_GEMINI_IMAGE_DESK_PORT_VALUE}"
        dufs_url="http://服务器IP:${NGINX_LAN_DUFS_PORT_VALUE}"
      fi
    elif [[ "$NGINX_ENABLE_HTTPS" == "true" ]]; then
      newapi_url="$(url_with_port https "$api_primary" "$NGINX_HTTPS_PORT_VALUE")"
      cliproxy_url="$(url_with_port https "$admin_primary" "$NGINX_HTTPS_PORT_VALUE")"
      sub2api_url="$(url_with_port https "$sub2api_primary" "$NGINX_HTTPS_PORT_VALUE")"
      webui_url="$(url_with_port https "$webui_primary" "$NGINX_HTTPS_PORT_VALUE")"
      newapi_v2_url="$(url_with_port https "$newapi_v2_primary" "$NGINX_HTTPS_PORT_VALUE")"
      gemini_desk_url="$(url_with_port https "$gemini_desk_primary" "$NGINX_HTTPS_PORT_VALUE")"
      dufs_url="$(url_with_port https "$dufs_primary" "$NGINX_HTTPS_PORT_VALUE")"
    else
      newapi_url="$(url_with_port http "$api_primary" "$NGINX_HTTP_PORT_VALUE")"
      cliproxy_url="$(url_with_port http "$admin_primary" "$NGINX_HTTP_PORT_VALUE")"
      sub2api_url="$(url_with_port http "$sub2api_primary" "$NGINX_HTTP_PORT_VALUE")"
      webui_url="$(url_with_port http "$webui_primary" "$NGINX_HTTP_PORT_VALUE")"
      newapi_v2_url="$(url_with_port http "$newapi_v2_primary" "$NGINX_HTTP_PORT_VALUE")"
      gemini_desk_url="$(url_with_port http "$gemini_desk_primary" "$NGINX_HTTP_PORT_VALUE")"
      dufs_url="$(url_with_port http "$dufs_primary" "$NGINX_HTTP_PORT_VALUE")"
    fi
  else
    newapi_url="http://服务器IP:${NEWAPI_HOST_PORT_VALUE}"
    cliproxy_url="http://服务器IP:${CLIPROXY_PORT_8317_VALUE}"
    sub2api_url="http://服务器IP:${SUB2API_HOST_PORT_VALUE}"
    webui_url="http://服务器IP:${GPT_IMAGE_WEBUI_HOST_PORT_VALUE}"
    newapi_v2_url="http://服务器IP:${NEWAPI_V2_HOST_PORT_VALUE}"
    gemini_desk_url="http://服务器IP:${GEMINI_IMAGE_DESK_HOST_PORT_VALUE}"
    dufs_url="http://服务器IP:${DUFS_HOST_PORT_VALUE}"
  fi

  section_title "部署完成"
  field_line "安装目录：" "$STACK_DIR"
  field_line "Compose 文件：" "$STACK_DIR/docker-compose.yml"
  field_line "环境文件：" "$STACK_DIR/.env"
  field_line "服务 Compose：" "已写入已选服务目录和 $STACK_DIR/nginx/docker-compose.yml"

  if needs_nginx_config; then
    section_title "Nginx 入口"
    if [[ "$NGINX_DEPLOY_MODE_VALUE" == "lan" ]]; then
      field_line "Nginx 模式：" "局域网，不需要域名。"
      needs_newapi_config && field_line "New API 入口端口：" "$NGINX_LAN_API_PORT_VALUE"
      needs_cliproxy_config && field_line "CPA 入口端口：" "$NGINX_LAN_ADMIN_PORT_VALUE"
      needs_sub2api_config && field_line "Sub2API 入口端口：" "$NGINX_LAN_SUB2API_PORT_VALUE"
      needs_gpt_image_webui_config && field_line "GPT Image WebUI 入口端口：" "$NGINX_LAN_WEBUI_PORT_VALUE"
      needs_newapi_v2_config && field_line "新版 NewAPI 入口端口：" "$NGINX_LAN_NEWAPI_V2_PORT_VALUE"
      needs_gemini_image_desk_config && field_line "Gemini Image Desk 入口端口：" "$NGINX_LAN_GEMINI_IMAGE_DESK_PORT_VALUE"
      needs_dufs_config && field_line "Dufs 静态文件入口端口：" "$NGINX_LAN_DUFS_PORT_VALUE"
    else
      field_line "Nginx 模式：" "公网，按域名转发。"
      needs_newapi_config && field_line "New API 绑定域名：" "$NGINX_API_SERVER_NAMES_VALUE"
      needs_cliproxy_config && field_line "CPA 绑定域名：" "$NGINX_ADMIN_SERVER_NAME_VALUE"
      needs_sub2api_config && field_line "Sub2API 绑定域名：" "$NGINX_SUB2API_SERVER_NAMES_VALUE"
      needs_gpt_image_webui_config && field_line "GPT Image WebUI 绑定域名：" "$NGINX_WEBUI_SERVER_NAMES_VALUE"
      needs_newapi_v2_config && field_line "新版 NewAPI 绑定域名：" "$NGINX_NEWAPI_V2_SERVER_NAMES_VALUE"
      needs_gemini_image_desk_config && field_line "Gemini Image Desk 绑定域名：" "$NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE"
      needs_dufs_config && field_line "Dufs 静态文件绑定域名：" "$NGINX_DUFS_SERVER_NAMES_VALUE"
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
    field_line "Nginx 配置目录：" "$STACK_DIR/nginx/conf.d"
  fi

  if needs_newapi_config; then
    section_title "New API 信息"
    field_line "访问地址：" "$newapi_url"
    if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_API_SERVER_NAMES_VALUE" != "" ]]; then
      field_line "绑定域名：" "$NGINX_API_SERVER_NAMES_VALUE"
    fi
    field_line "PostgreSQL 用户名：" "$POSTGRES_USER_VALUE"
    field_line "PostgreSQL 密码：" "$POSTGRES_PASSWORD_VALUE"
    field_line "PostgreSQL 数据库名：" "$POSTGRES_DB_VALUE"
    field_line "Redis：" "内部网络 redis:6379，无宿主机端口映射。"
    field_line "SESSION_SECRET：" "$NEWAPI_SESSION_SECRET_VALUE"
    field_line "CRYPTO_SECRET：" "$NEWAPI_CRYPTO_SECRET_VALUE"
    subtle_note "上面两个是 New API 内部会话签名和数据加密密钥，不是后台登录密码；部署后不要随便修改。"
    if [[ "$NEWAPI_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
      field_line "直连端口：" "$NEWAPI_HOST_PORT_VALUE"
    else
      subtle_note "New API 未映射宿主机端口，只通过 Nginx / Docker 网络访问。"
    fi
  fi

  if needs_newapi_v2_config; then
    section_title "新版 NewAPI 信息"
    field_line "访问地址：" "$newapi_v2_url"
    field_line "镜像：" "$NEWAPI_V2_IMAGE_VALUE"
    if [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_NEWAPI_V2_SERVER_NAMES_VALUE" != "" ]]; then
      field_line "绑定域名：" "$NGINX_NEWAPI_V2_SERVER_NAMES_VALUE"
    fi
    field_line "PostgreSQL 用户名：" "$NEWAPI_V2_POSTGRES_USER_VALUE"
    field_line "PostgreSQL 密码：" "$NEWAPI_V2_POSTGRES_PASSWORD_VALUE"
    field_line "PostgreSQL 数据库名：" "$NEWAPI_V2_POSTGRES_DB_VALUE"
    field_line "Redis 密码：" "$NEWAPI_V2_REDIS_PASSWORD_VALUE"
    field_line "SESSION_SECRET：" "$NEWAPI_V2_SESSION_SECRET_VALUE"
    field_line "CRYPTO_SECRET：" "$NEWAPI_V2_CRYPTO_SECRET_VALUE"
    subtle_note "新版 NewAPI 与旧版 new-api 使用独立目录、独立 PostgreSQL 和独立 Redis。"
    if [[ "$NEWAPI_V2_PUBLISH_HOST_PORT_VALUE" == "true" ]]; then
      field_line "直连端口：" "$NEWAPI_V2_HOST_PORT_VALUE"
    else
      subtle_note "新版 NewAPI 未映射宿主机端口，只通过 Nginx / Docker 网络访问。"
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

  if needs_sub2api_config; then
    section_title "Sub2API 信息"
    field_line "访问地址：" "$sub2api_url"
    field_line "健康检查：" "${sub2api_url%/}/health"
    field_line "数据目录：" "$STACK_DIR/sub2api/data"
    if needs_nginx_config && [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_SUB2API_SERVER_NAMES_VALUE" != "" ]]; then
      field_line "绑定域名：" "$NGINX_SUB2API_SERVER_NAMES_VALUE"
    fi
    field_line "管理员邮箱：" "$SUB2API_ADMIN_EMAIL_VALUE"
    field_line "管理员密码：" "$SUB2API_ADMIN_PASSWORD_VALUE"
    field_line "PostgreSQL 用户名：" "$SUB2API_POSTGRES_USER_VALUE"
    field_line "PostgreSQL 密码：" "$SUB2API_POSTGRES_PASSWORD_VALUE"
    field_line "PostgreSQL 数据库名：" "$SUB2API_POSTGRES_DB_VALUE"
    field_line "Redis 密码：" "$SUB2API_REDIS_PASSWORD_VALUE"
    if [[ "$SUB2API_PUBLISH_HOST_PORT_VALUE" != "true" ]]; then
      subtle_note "Sub2API 未映射宿主机端口，只通过 Nginx / Docker 网络访问。"
    else
      field_line "直连端口：" "$SUB2API_HOST_PORT_VALUE"
    fi
    subtle_note "Sub2API 应用容器已加入 public-net；默认就是外部 app-net。数据库和 Redis 使用独立内部网络。"
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
    subtle_note "GPT Image WebUI 已加入 public-net；默认就是外部 app-net。"
  fi

  if needs_gemini_image_desk_config; then
    section_title "Gemini Image Desk 信息"
    field_line "访问地址：" "$gemini_desk_url"
    field_line "镜像：" "$GEMINI_IMAGE_DESK_IMAGE_VALUE"
    field_line "默认 Base URL：" "$GEMINI_IMAGE_DESK_BASE_URL_VALUE"
    field_line "默认模型：" "$GEMINI_IMAGE_DESK_DEFAULT_MODEL_VALUE"
    if needs_nginx_config && [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE" != "" ]]; then
      field_line "绑定域名：" "$NGINX_GEMINI_IMAGE_DESK_SERVER_NAMES_VALUE"
    fi
    if [[ "$GEMINI_IMAGE_DESK_PUBLISH_HOST_PORT_VALUE" != "true" ]]; then
      subtle_note "Gemini Image Desk 未映射宿主机端口，只通过 Nginx / Docker 网络访问。"
    else
      field_line "直连端口：" "$GEMINI_IMAGE_DESK_HOST_PORT_VALUE"
    fi
    subtle_note "Gemini Image Desk 的 API Key 默认由用户在页面填写并保存在浏览器本地。"
  fi

  if needs_dufs_config; then
    section_title "Dufs 静态文件信息"
    field_line "访问地址：" "$dufs_url"
    field_line "静态文件目录：" "$DUFS_DATA_DIR_VALUE"
    field_line "管理员用户名：" "$DUFS_ADMIN_USER_VALUE"
    field_line "管理员密码：" "$DUFS_ADMIN_PASSWORD_VALUE"
    if needs_nginx_config && [[ "$NGINX_DEPLOY_MODE_VALUE" != "lan" && "$NGINX_DUFS_SERVER_NAMES_VALUE" != "" ]]; then
      field_line "绑定域名：" "$NGINX_DUFS_SERVER_NAMES_VALUE"
    fi
    if [[ "$DUFS_ANONYMOUS_READ_VALUE" == "true" ]]; then
      subtle_note "匿名用户可直接访问文件；管理员登录后可上传和管理文件。"
    else
      subtle_note "已关闭匿名只读访问，访问文件需要登录。"
    fi
    if [[ "$DUFS_PUBLISH_HOST_PORT_VALUE" != "true" ]]; then
      subtle_note "Dufs 未映射宿主机直连端口，只通过 Nginx / Docker 网络访问。"
    else
      field_line "直连端口：" "$DUFS_HOST_PORT_VALUE"
    fi
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
      needs_newapi_config && field_line "New API 证书：" "$NGINX_API_CERT_VALUE"
      needs_newapi_config && field_line "New API 私钥：" "$NGINX_API_KEY_VALUE"
      needs_cliproxy_config && field_line "CPA 证书：" "$NGINX_ADMIN_CERT_VALUE"
      needs_cliproxy_config && field_line "CPA 私钥：" "$NGINX_ADMIN_KEY_VALUE"
      needs_sub2api_config && field_line "Sub2API 证书：" "$NGINX_SUB2API_CERT_VALUE"
      needs_sub2api_config && field_line "Sub2API 私钥：" "$NGINX_SUB2API_KEY_VALUE"
      needs_gpt_image_webui_config && field_line "GPT Image WebUI 证书：" "$NGINX_WEBUI_CERT_VALUE"
      needs_gpt_image_webui_config && field_line "GPT Image WebUI 私钥：" "$NGINX_WEBUI_KEY_VALUE"
      needs_newapi_v2_config && field_line "新版 NewAPI 证书：" "$NGINX_NEWAPI_V2_CERT_VALUE"
      needs_newapi_v2_config && field_line "新版 NewAPI 私钥：" "$NGINX_NEWAPI_V2_KEY_VALUE"
      needs_gemini_image_desk_config && field_line "Gemini Image Desk 证书：" "$NGINX_GEMINI_IMAGE_DESK_CERT_VALUE"
      needs_gemini_image_desk_config && field_line "Gemini Image Desk 私钥：" "$NGINX_GEMINI_IMAGE_DESK_KEY_VALUE"
      needs_dufs_config && field_line "Dufs 静态文件证书：" "$NGINX_DUFS_CERT_VALUE"
      needs_dufs_config && field_line "Dufs 静态文件私钥：" "$NGINX_DUFS_KEY_VALUE"
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
    field_line "配置目录：" "$STACK_DIR/nginx/conf.d"
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

install_acme_certificate_files() {
  local base_domain="$1"
  local cert_file="$2"
  local key_file="$3"
  local include_wildcard="$4"
  local cert_path=""
  local key_path=""
  local reload_script=""
  local reload_cmd=""

  cert_path="$STACK_DIR/nginx/certs/$cert_file"
  key_path="$STACK_DIR/nginx/certs/$key_file"
  reload_script="$(write_acme_reload_script)"
  reload_cmd="$(dotenv_quote "$reload_script")"

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

issue_aliyun_certificate() {
  local base_domain=""
  local include_wildcard="true"
  local ali_key=""
  local ali_secret=""
  local use_existing_ali="false"
  local cert_file=""
  local key_file=""
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

  section_title "签发证书"
  "$ACME_SH_BIN" --issue --dns dns_ali "${domain_args[@]}"

  install_acme_certificate_files "$base_domain" "$cert_file" "$key_file" "$include_wildcard"
}

issue_cloudflare_certificate() {
  local base_domain=""
  local include_wildcard="true"
  local cf_token=""
  local cf_account_id=""
  local cf_zone_id=""
  local use_existing_cf="false"
  local cert_file=""
  local key_file=""
  local domain_args=()

  section_title "Cloudflare DNS 签发证书"
  ensure_acme_sh
  set_acme_default_ca
  prepare_certificate_directory

  subtle_note "请在 Cloudflare 创建 API Token，建议权限为 Zone:DNS:Edit 和 Zone:Zone:Read，并限制到对应 Zone。"
  subtle_note "CF_Token 会明文输入；acme.sh 会保存到 ~/.acme.sh/account.conf 或域名配置中供自动续签使用。"

  if [[ -n "${CF_Token:-}" ]]; then
    use_existing_cf="true"
    read_yes_no use_existing_cf "检测到当前环境已有 CF_Token，是否直接使用" "$use_existing_cf"
  fi

  if [[ "$use_existing_cf" == "true" ]]; then
    cf_token="$CF_Token"
    cf_account_id="${CF_Account_ID:-}"
    cf_zone_id="${CF_Zone_ID:-}"
  else
    read_line cf_token "CF_Token（明文）" ""
    read_line cf_account_id "CF_Account_ID（可留空）" "${CF_Account_ID:-}"
    read_line cf_zone_id "CF_Zone_ID（可留空，填了更稳定）" "${CF_Zone_ID:-}"
  fi

  [[ -n "$cf_token" ]] || die "CF_Token 不能为空。"
  export CF_Token="$cf_token"
  if [[ -n "$cf_account_id" ]]; then
    export CF_Account_ID="$cf_account_id"
  else
    unset CF_Account_ID 2>/dev/null || true
  fi
  if [[ -n "$cf_zone_id" ]]; then
    export CF_Zone_ID="$cf_zone_id"
  else
    unset CF_Zone_ID 2>/dev/null || true
  fi

  read_line base_domain "主域名，例如 774966.xyz" ""
  [[ -n "$base_domain" ]] || die "主域名不能为空。"
  read_yes_no include_wildcard "是否同时签发泛域名 *.${base_domain}" "$include_wildcard"

  domain_args=(-d "$base_domain")
  if [[ "$include_wildcard" == "true" ]]; then
    domain_args+=(-d "*.${base_domain}")
  fi

  read_line cert_file "安装后的 fullchain 证书文件名" "${base_domain}.fullchain.cer"
  read_line key_file "安装后的私钥文件名" "${base_domain}.key"

  section_title "签发证书"
  "$ACME_SH_BIN" --issue --dns dns_cf "${domain_args[@]}"

  install_acme_certificate_files "$base_domain" "$cert_file" "$key_file" "$include_wildcard"
}

disable_manual_dns_auto_renewal() {
  local base_domain="$1"

  section_title "关闭手动 DNS 自动续期记录"
  if "$ACME_SH_BIN" --remove -d "$base_domain" >/dev/null 2>&1; then
    subtle_note "已从 acme.sh 自动续期列表移除手动 DNS 证书；已安装到 nginx/certs 的证书文件会保留。"
  else
    subtle_note "未能自动移除 acme.sh 续期记录；如后续 cron 续期报错，可手动执行：$ACME_SH_BIN --remove -d $base_domain"
  fi
}

issue_manual_dns_certificate() {
  local base_domain=""
  local include_wildcard="true"
  local cert_file=""
  local key_file=""
  local continue_confirm=""
  local issue_status=0
  local domain_args=()

  section_title "手动 DNS 签发证书"
  ensure_acme_sh
  set_acme_default_ca
  prepare_certificate_directory

  subtle_note "手动 DNS 基本适用于所有能编辑 DNS 解析的域名服务商。"
  subtle_note "注意：手动 DNS 模式不能无人值守自动续期；每次续期都需要重新添加 TXT 记录。"

  read_line base_domain "主域名，例如 774966.xyz" ""
  [[ -n "$base_domain" ]] || die "主域名不能为空。"
  read_yes_no include_wildcard "是否同时签发泛域名 *.${base_domain}" "$include_wildcard"

  domain_args=(-d "$base_domain")
  if [[ "$include_wildcard" == "true" ]]; then
    domain_args+=(-d "*.${base_domain}")
  fi

  read_line cert_file "安装后的 fullchain 证书文件名" "${base_domain}.fullchain.cer"
  read_line key_file "安装后的私钥文件名" "${base_domain}.key"

  section_title "生成 DNS TXT 记录"
  subtle_note "下面 acme.sh 会输出需要添加的 _acme-challenge TXT 记录。请在你的 DNS 控制台添加全部 TXT 记录。"
  set +e
  "$ACME_SH_BIN" --issue --dns "${domain_args[@]}" \
    --yes-I-know-dns-manual-mode-enough-go-ahead-please
  issue_status="$?"
  set -e

  if (( issue_status != 0 )); then
    subtle_note "手动 DNS 模式第一步通常会在输出 TXT 记录后停止；这不一定表示失败。"
  fi

  read_line continue_confirm "TXT 记录添加完成并等待解析生效后，按回车继续验证" ""

  section_title "验证并签发证书"
  "$ACME_SH_BIN" --renew -d "$base_domain" \
    --yes-I-know-dns-manual-mode-enough-go-ahead-please

  install_acme_certificate_files "$base_domain" "$cert_file" "$key_file" "$include_wildcard"
  disable_manual_dns_auto_renewal "$base_domain"
  subtle_note "该证书使用手动 DNS 模式，本脚本不会保留自动续期；如需自动续期，建议改用阿里云或 Cloudflare DNS API 模式。"
}

renew_acme_certificates() {
  section_title "手动续签证书"
  ensure_acme_sh
  subtle_note "注意：手动 DNS 模式证书不能无人值守自动续期；acme.sh --cron 主要适用于 DNS API 等可自动验证的证书。"
  "$ACME_SH_BIN" --cron
}

show_certificate_menu() {
  section_title "SSL 证书 / acme.sh"
  menu_option "$COLOR_GREEN" "[1]" "检查/安装 acme.sh"
  menu_option "$COLOR_CYAN" "[2]" "阿里云 DNS 签发并安装证书"
  menu_option "$COLOR_CYAN" "[3]" "Cloudflare DNS Token 签发并安装证书"
  menu_option "$COLOR_MAGENTA" "[4]" "手动 DNS 签发并安装证书（不保留自动续期）"
  menu_option "$COLOR_BLUE" "[5]" "手动续签全部 DNS API 证书"
  menu_option "$COLOR_MAGENTA" "[6]" "查看 acme.sh 版本"
  menu_option "$COLOR_DIM" "[7]" "返回/退出"
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
      3|cloudflare|cf|dns_cf)
        issue_cloudflare_certificate
        ;;
      4|manual|manual-dns|dns-manual|txt|dns_txt)
        issue_manual_dns_certificate
        ;;
      5|renew|cron)
        renew_acme_certificates
        ;;
      6|version|-v|--version)
        ensure_acme_sh
        "$ACME_SH_BIN" --version || true
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

reload_bashrc_now() {
  local bashrc="$1"

  if [[ ! -r "$bashrc" ]]; then
    subtle_note "未能读取 $bashrc，跳过自动 source。"
    return 0
  fi

  set +u
  # shellcheck disable=SC1090
  if source "$bashrc"; then
    field_line "自动执行：" "source $bashrc"
  else
    subtle_note "自动 source $bashrc 时返回非 0；配置文件已写入，可以重新登录后生效。"
  fi
  set -Eeuo pipefail

  if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    subtle_note "当前脚本以 source 方式运行，配置已作用到当前 Shell。"
    return 0
  fi

  if [[ -t 0 && -t 1 ]] && command -v bash >/dev/null 2>&1; then
    subtle_note "包括 root 在内，普通执行脚本时子进程都无法直接修改父级 SSH Shell。"
    subtle_note "现在自动进入一个已加载该配置的新 Bash，无需手动复制 source 命令；输入 exit 可回到原来的 Shell。"
    exec bash --rcfile "$bashrc" -i
  fi

  subtle_note "当前不是交互式终端，已跳过自动进入新 Bash。"
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
  reload_bashrc_now "$bashrc"
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

read_main_menu_action() {
  local __var="$1"
  local selected=""

  show_main_menu
  while true; do
    read_line selected "请选择操作" "1"
    case "$(lower "$selected")" in
      1|docker|docker-install|install-docker|setup-docker)
        printf -v "$__var" '%s' "docker"
        return 0
        ;;
      2|cert|ssl|acme|acme.sh|certificate)
        printf -v "$__var" '%s' "cert"
        return 0
        ;;
      3|deploy|up|install)
        printf -v "$__var" '%s' "deploy"
        return 0
        ;;
      4|update|pull|upgrade|refresh|sync)
        printf -v "$__var" '%s' "update"
        return 0
        ;;
      5|nginx|nginx-manage|nginx-manager)
        printf -v "$__var" '%s' "nginx"
        return 0
        ;;
      6|mirror|docker-mirror|registry-mirror|daemon)
        printf -v "$__var" '%s' "mirror"
        return 0
        ;;
      7|uninstall|down|remove|rm)
        printf -v "$__var" '%s' "uninstall"
        return 0
        ;;
      8|misc|miscellaneous|utils|tools|other|others)
        printf -v "$__var" '%s' "misc"
        return 0
        ;;
      9|exit|quit|q)
        printf -v "$__var" '%s' "exit"
        return 0
        ;;
      *)
        printf '%s\n' "$(color_text "$COLOR_YELLOW" "请输入 1 到 9。")"
        ;;
    esac
  done
}

run_action() {
  local action="$1"

  subtle_note "输入支持常规命令行编辑，密码项也会明文显示。"

  case "$action" in
    docker)
      install_docker_universal
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

main() {
  local action=""

  init_ui
  banner

  if [[ ! -t 0 ]]; then
    printf '%s\n' "$(color_text "$COLOR_YELLOW" "检测到管道或非交互方式执行，交互式菜单无法稳定读取输入。")"
    printf '%s\n' "请改用："
    printf '%s\n' "curl -fsSL https://raw.githubusercontent.com/JunWan666/quick-docker-script-deploy/main/one-click/deploy.sh -o /tmp/deploy.sh && bash /tmp/deploy.sh"
    return 1
  fi

  action="$(parse_action "${1-}")"
  if [[ "$action" == "help" ]]; then
    print_usage
    return 0
  fi

  if [[ -z "${1:-}" && -t 0 ]]; then
    while true; do
      read_main_menu_action action
      if [[ "$action" == "exit" ]]; then
        printf '%s\n' "$(color_text "$COLOR_DIM" "已退出。")"
        return 0
      fi
      run_action "$action"
      if [[ "$action" == "deploy" ]]; then
        printf '\n%s\n' "$(color_text "$COLOR_DIM" "部署完成，已退出脚本。")"
        return 0
      fi
      printf '\n%s\n' "$(color_text "$COLOR_DIM" "操作完成，已返回主菜单。")"
    done
  fi

  run_action "$action"
}

main "$@"
