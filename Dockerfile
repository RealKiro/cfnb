# syntax=docker/dockerfile:1

# ============ 构建阶段：编译 Python 依赖 ============
FROM python:3.12-alpine AS builder

# brotlicffi / cffi 需要编译环境（仅存在于构建阶段，不会进入最终镜像）
RUN apk add --no-cache build-base libffi-dev

WORKDIR /app
COPY requirements.txt .

RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ============ 运行阶段：精简 Alpine 运行镜像 ============
FROM python:3.12-alpine

# 运行时依赖：
#   bash  -> main.py 在 Linux 下用 bash 调 git_sync.sh
#   curl  -> 带宽测速
#   git   -> GitHub 自动同步
#   tzdata -> 时区支持（TZ 环境变量）
RUN apk add --no-cache bash curl git tzdata

# 从构建阶段复制独立的 Python 虚拟环境
COPY --from=builder /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai

WORKDIR /app

# 仅复制运行必需文件；config.json / git_sync.sh / ip.txt 建议通过挂载覆盖
COPY main.py config.json git_sync.sh docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh git_sync.sh

# RUN_INTERVAL: 循环间隔秒数；0 或未设置 = 只运行一次
ENTRYPOINT ["./docker-entrypoint.sh"]
