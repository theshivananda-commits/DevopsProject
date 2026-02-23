#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "=== Bootstrap started at $(date) ==="

# ─── System Update ───────────────────────────────────────────────
dnf update -y

# ─── Install Docker ──────────────────────────────────────────────
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# ─── Install CloudWatch Agent ────────────────────────────────────
dnf install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/app/*.log",
            "log_group_name": "/devops-demo/app",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/devops-demo/bootstrap",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWCONFIG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ─── App directories ─────────────────────────────────────────────
mkdir -p /var/log/app
mkdir -p /opt/app

# ─── Deploy script (called by CI/CD) ─────────────────────────────
cat > /opt/app/deploy.sh << 'DEPLOY'
#!/bin/bash
set -euo pipefail

IMAGE="${1:-ghcr.io/YOUR_GITHUB_USERNAME/devops-demo:latest}"
CONTAINER_NAME="devops-demo-app"

echo "[$(date)] Deploying image: $IMAGE"

# Pull latest image
docker pull "$IMAGE"

# Stop existing container gracefully
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Run new container
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p 5000:5000 \
  -e APP_VERSION="$(date +%Y%m%d-%H%M%S)" \
  -v /var/log/app:/var/log/app \
  "$IMAGE"

# Health check with retries
echo "Waiting for app to be healthy..."
for i in $(seq 1 12); do
  if curl -sf http://localhost:5000/health > /dev/null 2>&1; then
    echo "[$(date)] App is healthy after ${i} attempts!"
    exit 0
  fi
  sleep 5
done

echo "[$(date)] ERROR: App failed health check after 60 seconds!"
docker logs "$CONTAINER_NAME" --tail 50
exit 1
DEPLOY

chmod +x /opt/app/deploy.sh

# ─── Cleanup old Docker images (runs nightly) ────────────────────
cat > /etc/cron.daily/docker-cleanup << 'CRON'
#!/bin/bash
docker image prune -f --filter "until=48h" >> /var/log/app/docker-cleanup.log 2>&1
CRON
chmod +x /etc/cron.daily/docker-cleanup

echo "=== Bootstrap completed at $(date) ==="
