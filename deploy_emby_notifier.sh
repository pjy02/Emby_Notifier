#!/bin/bash

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null
then
    echo "Docker 未安装，开始安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "Docker 安装完成，请重新登录以应用更改。"
    exit 1
fi

# 检查 Docker Compose 是否安装
if ! command -v docker-compose &> /dev/null
then
    echo "Docker Compose 未安装，开始安装 Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose 安装完成。"
fi

# 提示用户输入必要的环境变量
read -p "请输入 TMDB API Token: " TMDB_API_TOKEN
read -p "请输入 Telegram Bot Token: " TG_BOT_TOKEN
read -p "请输入 Telegram Channel's Chat ID: " TG_CHAT_ID
read -p "请输入 TVDB API Key (可选，留空则不配置): " TVDB_API_KEY
read -p "请输入企业微信 企业 id (可选，留空则不配置): " WECHAT_CORP_ID
read -p "请输入企业微信 应用凭证秘钥 (可选，留空则不配置): " WECHAT_CORP_SECRET
read -p "请输入企业微信 应用 agentid (可选，留空则不配置): " WECHAT_AGENT_ID
read -p "请输入企业微信 用户 id (可选，留空则默认为 @all): " WECHAT_USER_ID

# 初始化环境变量部分的内容
ENV_VARS=""

# 添加必要的固定环境变量
ENV_VARS+="      - TZ=Asia/Shanghai\n"
ENV_VARS+="      - LOG_LEVEL=INFO\n"
ENV_VARS+="      - LOG_EXPORT=False\n"
ENV_VARS+="      - LOG_PATH=/var/tmp/emby_notifier_tg/\n"

# 添加用户输入的环境变量，仅当用户输入了内容时才添加
if [ -n "$TMDB_API_TOKEN" ]; then
    ENV_VARS+="      - TMDB_API_TOKEN=$TMDB_API_TOKEN\n"
fi
if [ -n "$TG_BOT_TOKEN" ]; then
    ENV_VARS+="      - TG_BOT_TOKEN=$TG_BOT_TOKEN\n"
fi
if [ -n "$TG_CHAT_ID" ]; then
    ENV_VARS+="      - TG_CHAT_ID=$TG_CHAT_ID\n"
fi
if [ -n "$TVDB_API_KEY" ]; then
    ENV_VARS+="      - TVDB_API_KEY=$TVDB_API_KEY\n"
fi
if [ -n "$WECHAT_CORP_ID" ]; then
    ENV_VARS+="      - WECHAT_CORP_ID=$WECHAT_CORP_ID\n"
fi
if [ -n "$WECHAT_CORP_SECRET" ]; then
    ENV_VARS+="      - WECHAT_CORP_SECRET=$WECHAT_CORP_SECRET\n"
fi
if [ -n "$WECHAT_AGENT_ID" ]; then
    ENV_VARS+="      - WECHAT_AGENT_ID=$WECHAT_AGENT_ID\n"
fi
if [ -n "$WECHAT_USER_ID" ]; then
    ENV_VARS+="      - WECHAT_USER_ID=$WECHAT_USER_ID\n"
else
    ENV_VARS+="      - WECHAT_USER_ID=@all\n"
fi

# 生成 docker-compose.yml 文件
cat << EOF > docker-compose.yml
version: '3'
services:
  emby_notifier_tg:
    build:
      context: .
      dockerfile: dockerfile
    image: b1gfac3c4t/emby_notifier_tg:latest
    environment:
$ENV_VARS
    network_mode: "bridge"
    ports:
      - "8000:8000"
    restart: unless-stopped
EOF

# 启动 Emby Notifier 服务
docker-compose up -d

echo "Emby Notifier 服务已启动。"
