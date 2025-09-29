#!/bin/bash

# 生成 .env 文件的脚本
# 从 AnyRouter API 获取账号信息并生成 .env 配置

set -e

# 检查环境变量
if [ -z "$URL" ]; then
    echo "错误: 请设置环境变量 URL"
    exit 1
fi

if [ -z "$TOKEN" ]; then
    echo "错误: 请设置环境变量 TOKEN"
    echo "示例: export TOKEN=your_bearer_token"
    exit 1
fi

echo "正在从 AnyRouter API 获取账号数据..."
echo "API 地址: http://$URL"

# 执行curl命令获取数据
RESPONSE=$(curl --silent --location "http://$URL/api/cookies?include_values=true&domain=anyrouter.top" \
    --header "Authorization: Bearer $TOKEN")

if [ $? -ne 0 ]; then
    echo "错误: 无法获取 API 数据"
    exit 1
fi

echo "正在解析账号数据..."

# 检查是否安装了jq
if ! command -v jq &> /dev/null; then
    echo "错误: 需要安装 jq 来解析 JSON 数据"
    echo "请运行: sudo apt-get install jq 或 brew install jq"
    exit 1
fi

# 获取账号数量
ACCOUNT_COUNT=$(echo "$RESPONSE" | jq '.data | length')

if [ "$ACCOUNT_COUNT" -eq 0 ]; then
    echo "警告: 未找到任何账号数据"
    exit 1
fi

echo "发现 $ACCOUNT_COUNT 个账号"

# 构建 ANYROUTER_ACCOUNTS JSON 数组
ACCOUNTS_JSON="["

for ((i=0; i<$ACCOUNT_COUNT; i++)); do
    # 提取第i个账号的session值
    SESSION=$(echo "$RESPONSE" | jq -r ".data[$i].cookies_data[] | select(.name == \"session\") | .value // empty")
    
    # 提取第i个账号的api_user值
    API_USER=$(echo "$RESPONSE" | jq -r ".data[$i].local_storage_data.user.id // empty")
    
    # 获取账号名称用于显示
    ACCOUNT_NAME=$(echo "$RESPONSE" | jq -r ".data[$i].custom_name // \"账号$((i+1))\"")
    
    if [ -z "$SESSION" ] || [ "$SESSION" = "null" ]; then
        echo "警告: 账号 $ACCOUNT_NAME 缺少 session 数据，跳过"
        continue
    fi
    
    if [ -z "$API_USER" ] || [ "$API_USER" = "null" ]; then
        echo "警告: 账号 $ACCOUNT_NAME 缺少 api_user 数据，跳过"
        continue
    fi
    
    # 添加逗号分隔符（除了第一个账号）
    if [ "$ACCOUNTS_JSON" != "[" ]; then
        ACCOUNTS_JSON="$ACCOUNTS_JSON,"
    fi
    
    # 构建账号JSON对象，包含name字段
    ACCOUNT_JSON="{\"name\":\"$ACCOUNT_NAME\",\"cookies\":{\"session\":\"$SESSION\"},\"api_user\":\"$API_USER\"}"
    ACCOUNTS_JSON="$ACCOUNTS_JSON$ACCOUNT_JSON"
    
    echo "  ✓ 账号: $ACCOUNT_NAME (ID: $API_USER)"
done

ACCOUNTS_JSON="$ACCOUNTS_JSON]"

# 检查是否有有效账号
if [ "$ACCOUNTS_JSON" = "[]" ]; then
    echo "错误: 没有找到有效的账号数据"
    exit 1
fi

# 生成.env文件
cat > .env << EOF
# AnyRouter 账号配置
ANYROUTER_ACCOUNTS=$ACCOUNTS_JSON
EOF

echo ""
echo "✅ .env 文件已生成成功！"
echo ""
echo "配置的账号数量: $(echo "$ACCOUNTS_JSON" | jq '. | length')"
echo ""
echo "生成的配置预览:"
echo "ANYROUTER_ACCOUNTS=$ACCOUNTS_JSON" | head -c 200
echo "..."
