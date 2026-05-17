# 使用 Debian 作为基础镜像
FROM debian:stable-slim

# 安装 vnStat、curl、bc、sudo
RUN apt-get update && \
    apt-get install -y vnstat curl bc sudo && \
    rm -rf /var/lib/apt/lists/*

# 拷贝监控脚本
COPY monitor.sh /usr/local/bin/monitor.sh
RUN chmod +x /usr/local/bin/monitor.sh

# 设置默认命令
CMD ["/usr/local/bin/monitor.sh"]
