#!/bin/ash

# =========================================================
# 【请修改以下变量 - 用户配置区】
# =========================================================

# 1. 您的原始账号 
USERNAME=""

# 2. 您的密码
PASSWORD=""

# 3. 运营商后缀 
# 示例：@gxylt
OPERATOR_SUFFIX="@gxylt"

# 4. WAN口名称 (通常是 eth0.2 或 eth1 等，可通过 ifconfig 或 LuCI 界面查看)
WAN_INTERFACE="wlan1" 

# 5. 认证服务器端口及 IP 
PORTAL_HOST_PORT="211.69.15.10:6060" 

# 6. 移动设备 UA (模拟 Edge/Chrome 手机浏览器) - 【已修改】
MOBILE_UA="Mozilla/5.0 (Linux; Android 10; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.6045.163 Mobile Safari/537.36 EdgA/119.0.2151.72" 

# =========================================================
# 【脚本核心逻辑 - 无需修改】
# =========================================================

# 完整认证 URL 路径 (不含 Host 和参数)
LOGIN_PATH="/quickauth.do"

# 固定的 AC 参数 (根据您的日志)
WLAN_ACNAME="HAIT-SR8808"
WLAN_ACIP="172.21.8.73"
PORTAL_PAGEID="21"
PORTAL_TYPE="0"

# 完整的认证 URL
LOGIN_URL="http://${PORTAL_HOST_PORT}${LOGIN_PATH}"

# 1. 检查网络连通性 (尝试 ping 百度，如果成功则认为已认证)(检测逻辑有问题，不使用)
#check_online() {
#    # -q: 静默，-T 5: 超时 5秒，--spider: 不下载文件
#    wget -q -T 5 --spider http://www.baidu.com
#    return $?
#}

# 2. 获取 WAN 口 IP (即 wlanuserip 参数)
get_wan_ip() {
    # 尝试从 WAN 接口获取 IP 地址
    WAN_IP=$(/sbin/ifconfig "${WAN_INTERFACE}" | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}')
    
    if [ -z "${WAN_IP}" ]; then
        echo "$(date) - 错误：无法获取 ${WAN_INTERFACE} 的 IP 地址！"
        return 1
    fi
    echo "${WAN_IP}"
    return 0
}

# 3. 生成 UUID (使用 OpenWrt 的 /proc/sys/kernel/random/uuid)
get_uuid() {
    # 尝试从 /proc 文件读取，失败则尝试用 od 生成
    cat /proc/sys/kernel/random/uuid 2>/dev/null || od -x /dev/urandom | head -1 | awk '{print $2$3"-"$4"-"$5"-"$6"-"$7}'
}

# 4. 生成 13 位毫秒时间戳
get_timestamp() {
    # OpenWrt ash 默认不支持 date +%s%3N，使用 $(date +%s) * 1000 模拟
    TIMESTAMP_S=$(date +%s)
    # 模拟毫秒时间戳，简单乘以 1000
    echo "$((${TIMESTAMP_S}000 + 0))" 
}

# 5. 执行登录操作
do_login() {
    WAN_IP=$(get_wan_ip)
    if [ $? -ne 0 ]; then
        return
    fi

    FULL_USERID="${USERNAME}${OPERATOR_SUFFIX}"
    TIMESTAMP=$(get_timestamp)
    UUID=$(get_uuid)
    
    # 构造完整的查询参数字符串
    QUERY_PARAMS="\
userid=${FULL_USERID}&\
passwd=${PASSWORD}&\
wlanuserip=${WAN_IP}&\
wlanacname=${WLAN_ACNAME}&\
wlanacIp=${WLAN_ACIP}&\
ssid=&vlan=&mac=&version=0&\
portalpageid=${PORTAL_PAGEID}&\
timestamp=${TIMESTAMP}&\
uuid=${UUID}&\
portaltype=${PORTAL_TYPE}&\
hostname=&bindCtrlId="

    # URL 编码，避免特殊字符问题 (尤其是 @ 符号)
    ENCODED_PARAMS=$(echo "${QUERY_PARAMS}" | sed 's/@/%40/g')

    FINAL_URL="${LOGIN_URL}?${ENCODED_PARAMS}"

    echo "$(date) - Starting authentication...  # 正在尝试认证"
    echo "Account: ${FULL_USERID}"
    echo "Client IP: ${WAN_IP}"
    echo "Using UA: Mobile"

    # 使用 curl 发送 GET 请求
    # -G: 强制 GET, -s: 静默, -k: 忽略证书, --connect-timeout 5
    # -A "${MOBILE_UA}": 设置 User-Agent 头部 - 【已修改】
    # -o /dev/null: 不输出返回内容, -w "%{http_code}" 输出 HTTP 状态码
    HTTP_CODE=$(curl -G -s -k -o /dev/null -w "%{http_code}" -A "${MOBILE_UA}" "${FINAL_URL}" --connect-timeout 5)

    if [ "$HTTP_CODE" = "200" ]; then
        # 认证成功后通常会返回 200 和 JSON 数据
        echo "$(date) - [${HTTP_CODE}] Auth request sent, waiting for network.   |  # 认证请求发送成功"
    else
        echo "$(date) - [${HTTP_CODE}] Auth request failed.  |  # 认证请求失败"
    fi
}

# 6. 主流程

     do_login
     sleep 5 # 等待 5 秒，让认证生效
  