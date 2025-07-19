#!/bin/bash

# 定义日志函数
log_info() {
    echo "[INFO] $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 检查1panel是否安装
check_1panel() {
    if command_exists 1pctl || [ -d "/opt/1panel" ]; then
        log_info "检测到1panel已安装"
        return 0
    else
        log_info "未检测到1panel"
        return 1
    fi
}

# 检查1panel-network是否存在
check_1panel_network() {
    if docker network ls | grep -q "1panel-network"; then
        log_info "检测到1panel-network网络"
        return 0
    else
        log_info "未检测到1panel-network网络"
        return 1
    fi
}

# 检查 Docker 是否安装
if ! command_exists docker; then
    log_info "Docker 未安装，开始安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo usermod -aG docker $USER
    log_info "Docker 安装完成，请重新登录以应用更改。"
    exit 1
fi

# 检查 Docker Compose 是否安装
if ! command_exists docker-compose; then
    log_info "Docker Compose 未安装，开始安装 Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_info "Docker Compose 安装完成。"
fi

# 检查1panel并设置网络标志
use_1panel_network=false
if check_1panel; then
    if check_1panel_network; then
        read -p "检测到1panel，是否增加1panel网络配置？(y/n) " use_network
        if [ "$use_network" = "y" ]; then
            use_1panel_network=true
        fi
    else
        log_info "1panel-network网络不存在，跳过网络配置"
    fi
fi

# 生成docker-compose.yml的函数
generate_compose_file() {
    log_info "开始收集配置信息..."
    
    # 提示用户输入必要的环境变量
    read -p "请输入 TMDB API Token: " TMDB_API_TOKEN
    read -p "请输入 Telegram Bot Token: " TG_BOT_TOKEN
    read -p "请输入 Telegram Channel's Chat ID: " TG_CHAT_ID
    read -p "请输入 TVDB API Key (可选，留空则不配置): " TVDB_API_KEY
    read -p "请输入企业微信 企业 id (可选，留空则不配置): " WECHAT_CORP_ID
    read -p "请输入企业微信 应用凭证秘钥 (可选，留空则不配置): " WECHAT_CORP_SECRET
    read -p "请输入企业微信 应用 agentid (可选，留空则不配置): " WECHAT_AGENT_ID
    read -p "请输入企业微信 用户 id (可选，留空则默认为 @all): " WECHAT_USER_ID

    log_info "生成 docker-compose.yml 文件..."

    # 删除旧文件（如果存在）
    [ -f "docker-compose.yml" ] && rm -f docker-compose.yml

    # 生成基础结构
    {
        echo "version: '3'"
        echo "services:"
        echo "  emby_notifier_tg:"
        echo "    build:"
        echo "      context: ."
        echo "      dockerfile: dockerfile"
        echo "    image: b1gfac3c4t/emby_notifier_tg:latest"
        echo "    environment:"
        echo "      - TZ=Asia/Shanghai"
        echo "      - LOG_LEVEL=INFO"
        echo "      - LOG_EXPORT=False"
        echo "      - LOG_PATH=/var/tmp/emby_notifier_tg/"
        
        # 添加用户配置的环境变量
        [ -n "$TMDB_API_TOKEN" ] && echo "      - TMDB_API_TOKEN=$TMDB_API_TOKEN"
        [ -n "$TG_BOT_TOKEN" ] && echo "      - TG_BOT_TOKEN=$TG_BOT_TOKEN"
        [ -n "$TG_CHAT_ID" ] && echo "      - TG_CHAT_ID=$TG_CHAT_ID"
        [ -n "$TVDB_API_KEY" ] && echo "      - TVDB_API_KEY=$TVDB_API_KEY"
        [ -n "$WECHAT_CORP_ID" ] && echo "      - WECHAT_CORP_ID=$WECHAT_CORP_ID"
        [ -n "$WECHAT_CORP_SECRET" ] && echo "      - WECHAT_CORP_SECRET=$WECHAT_CORP_SECRET"
        [ -n "$WECHAT_AGENT_ID" ] && echo "      - WECHAT_AGENT_ID=$WECHAT_AGENT_ID"
        
        # 处理微信用户ID
        if [ -n "$WECHAT_USER_ID" ]; then
            echo "      - WECHAT_USER_ID=$WECHAT_USER_ID"
        else
            echo "      - WECHAT_USER_ID=@all"
        fi
        
        # 添加端口映射（仅在非 host 网络模式下）
        if [ "$use_1panel_network" = true ]; then
            echo "    ports:"
            echo "      - \"8000:8000\""
        fi
        echo "    restart: unless-stopped"
        
        # 添加网络配置
        if [ "$use_1panel_network" = true ]; then
            echo "    networks:"
            echo "      - 1panel-network"
            echo ""
            echo "networks:"
            echo "  1panel-network:"
            echo "    external: true"
        else
            echo "    network_mode: \"host\""
        fi
    } > docker-compose.yml

    log_info "docker-compose.yml 文件生成完成"
}

# 检查docker-compose.yml是否存在
if [ -f "docker-compose.yml" ]; then
    read -p "docker-compose.yml已存在，是否重新生成？(y/n) " regenerate
    if [ "$regenerate" = "y" ]; then
        generate_compose_file
    fi
else
    generate_compose_file
fi

# 验证生成的文件
if [ -f "docker-compose.yml" ]; then
    log_info "验证 docker-compose.yml 语法..."
    if docker-compose config >/dev/null 2>&1; then
        log_info "docker-compose.yml 语法验证通过"
    else
        log_info "docker-compose.yml 语法验证失败，请检查文件内容"
        exit 1
    fi
fi

# 启动 Emby Notifier 服务
log_info "启动 Emby Notifier 服务..."
docker-compose up -d

if [ $? -eq 0 ]; then
    log_info "Emby Notifier 服务已成功启动"
else
    log_info "Emby Notifier 服务启动失败，请检查错误信息"
    exit 1
fi
