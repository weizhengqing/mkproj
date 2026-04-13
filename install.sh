#!/usr/bin/env bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="$HOME/.local/bin"
SCRIPT_NAME="mkproj"
SOURCE_FILE="$(dirname "$0")/mkproj.sh"

echo "正在安装 $SCRIPT_NAME 到 $TARGET_DIR..."

# 第一步：确保目标目录存在
mkdir -p "$TARGET_DIR"

# 第二步：复制脚本并重命名，防止原项目目录移动后失效
if cp "$SOURCE_FILE" "$TARGET_DIR/$SCRIPT_NAME"; then
    # 第三步：赋予执行权限
    chmod +x "$TARGET_DIR/$SCRIPT_NAME"

    echo -e "${GREEN}[SUCCESS] 安装成功！${NC}"
    echo "现在你可以在终端的任何位置输入 '$SCRIPT_NAME' 来运行它。"
    # 检查 PATH 是否包含目标目录
    if [[ ":$PATH:" != *":$TARGET_DIR:"* ]]; then
        echo -e "${RED}提示: $TARGET_DIR 不在你的 PATH 中。${NC}"
        echo "请将以下行添加到你的 ~/.zshrc 或 ~/.bashrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
else
    echo -e "${RED}[ERROR] 安装失败，请检查文件权限或目录状态。${NC}"
fi
