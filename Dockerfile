FROM louislam/uptime-kuma:1

EXPOSE 3001

# Data directory — mount Azure File Share here for persistence
VOLUME /app/data
