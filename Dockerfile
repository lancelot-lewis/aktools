# ============ 构建阶��� ============
FROM python:3.13-slim-bullseye as builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# 升级 pip 和构建工具
RUN pip install --upgrade pip setuptools wheel

# 创建虚拟环境
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 安装依赖
RUN pip install --no-cache-dir \
    akshare \
    fastapi \
    uvicorn \
    gunicorn \
    --upgrade

# ============ 运行阶段 ============
FROM python:3.13-slim-bullseye

# 添加元数据
LABEL org.opencontainers.image.title="aktools"
LABEL org.opencontainers.image.description="AKShare Tools FastAPI Server"
LABEL org.opencontainers.image.source="https://github.com/akfamily/aktools"

# 创建非 root 用户
RUN useradd -m -u 1000 appuser

# 从 builder 阶段复制虚拟环境
COPY --from=builder /opt/venv /opt/venv

# 设置环境变量
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# 安装 aktools
RUN pip install --no-cache-dir aktools --upgrade

# 设置工作目录
ENV APP_HOME=/usr/local/lib/python3.13/site-packages/aktools
WORKDIR $APP_HOME

# 改变所有者
RUN chown -R appuser:appuser $APP_HOME

# 切换到非 root 用户
USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8080/api/public/health', timeout=5)" || exit 1

# 暴露端口
EXPOSE 8080

# 启动命令
CMD ["gunicorn", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "4", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--timeout", "120", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "aktools.main:app"]
