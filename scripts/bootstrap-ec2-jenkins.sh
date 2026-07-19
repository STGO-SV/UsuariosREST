#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo or as root." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
echo "Installing base packages and Java 21..."
apt-get update
apt-get install -y ca-certificates curl fontconfig git gnupg openjdk-21-jre-headless wget

echo "Configuring the official Docker repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
source /etc/os-release
architecture="$(dpkg --print-architecture)"
codename="${UBUNTU_CODENAME:-${VERSION_CODENAME}}"
printf '%s\n' \
  'Types: deb' \
  'URIs: https://download.docker.com/linux/ubuntu' \
  "Suites: ${codename}" \
  'Components: stable' \
  "Architectures: ${architecture}" \
  'Signed-By: /etc/apt/keyrings/docker.asc' \
  > /etc/apt/sources.list.d/docker.sources

echo "Configuring the Jenkins LTS repository..."
wget -qO /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
printf '%s\n' \
  'deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' \
  > /etc/apt/sources.list.d/jenkins.list

apt-get update
echo "Installing Docker Engine and Jenkins LTS..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin jenkins

echo "Configuring services and Jenkins Docker permissions..."
systemctl enable --now docker
usermod -aG docker jenkins
install -d -m 0750 -o jenkins -g jenkins /opt/usuarios-rest
systemctl enable jenkins
systemctl restart jenkins

echo "Verifying installation..."
java -version
git --version
docker --version
systemctl is-active --quiet docker
systemctl is-active --quiet jenkins
id -nG jenkins | tr ' ' '\n' | grep -qx docker
runuser -u jenkins -- docker info >/dev/null
echo "EC2 Jenkins bootstrap completed successfully."
echo "Jenkins listens on port 8080; the application pipeline uses host port 8088."
