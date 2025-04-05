#!/bin/bash

set -e  # Exit on any error

# Install Java and dependencies
apt update
apt install openjdk-17-jdk wget ufw -y

# Define Nexus version and URL
NEXUS_VERSION="3.79.0-09"
NEXUSDIR="nexus-$NEXUS_VERSION"
NEXUSURL="https://sonatype-download.global.ssl.fastly.net/repository/downloads-prod-group/3/nexus-unix-x86-64-$NEXUS_VERSION.tar.gz"

# Create working directories
mkdir -p /opt/nexus /tmp/nexus
cd /tmp/nexus

echo "📦 Downloading Nexus $NEXUS_VERSION..."
wget -O nexus.tar.gz $NEXUSURL

# Validate gzip file
if ! file nexus.tar.gz | grep -q 'gzip compressed data'; then
    echo "❌ The downloaded file is not a valid gzip archive. Exiting."
    exit 1
fi

# Extract tarball
echo "📂 Extracting Nexus..."
tar -xzf nexus.tar.gz
EXTRACTED_DIR=$(tar -tf nexus.tar.gz | head -1 | cut -f1 -d"/")
mv "$EXTRACTED_DIR" /opt/nexus/$NEXUSDIR

# Create nexus user if not present
id nexus &>/dev/null || useradd -r -s /bin/false nexus

# Set permissions
chown -R nexus:nexus /opt/nexus

# Configure Nexus to run as 'nexus' user
echo 'run_as_user="nexus"' > /opt/nexus/$NEXUSDIR/bin/nexus.rc

# Create systemd service
cat <<EOF > /etc/systemd/system/nexus.service
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/$NEXUSDIR/bin/nexus start
ExecStop=/opt/nexus/$NEXUSDIR/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

# Reload and start service
systemctl daemon-reload
systemctl enable nexus
systemctl start nexus

# Configure UFW firewall
echo "🔐 Configuring firewall rules..."
ufw allow 22/tcp        # Allow SSH (just in case)
ufw allow 8081/tcp      # Allow Nexus port
ufw --force enable      # Enable UFW without interactive prompt

echo "✅ Nexus $NEXUS_VERSION installed and running on port 8081"
echo "🌐 Access it at: http://<your-server-ip>:8081"
