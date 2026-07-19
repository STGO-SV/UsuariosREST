#!/usr/bin/env bash
set -euo pipefail

failures=0
check_command() {
  local command_name="$1"
  if command -v "${command_name}" >/dev/null 2>&1; then
    echo "OK command: ${command_name}"
  else
    echo "FAIL command: ${command_name}" >&2
    failures=$((failures + 1))
  fi
}
check_service() {
  local service_name="$1"
  if systemctl is-active --quiet "${service_name}"; then
    echo "OK service: ${service_name}"
  else
    echo "FAIL service: ${service_name}" >&2
    failures=$((failures + 1))
  fi
}
for command_name in java git docker curl; do check_command "${command_name}"; done
check_service docker
check_service jenkins
if id jenkins >/dev/null 2>&1 && id -nG jenkins | tr ' ' '\n' | grep -qx docker; then
  echo "OK: jenkins belongs to docker group"
else
  echo "FAIL: jenkins is not in docker group" >&2
  failures=$((failures + 1))
fi
if sudo -u jenkins docker info >/dev/null 2>&1; then
  echo "OK: jenkins can access Docker Engine"
else
  echo "FAIL: jenkins cannot access Docker Engine" >&2
  failures=$((failures + 1))
fi
echo "Listening ports relevant to the evaluation:"
ss -lnt | awk 'NR == 1 || /:8080 |:8088 |:22 /'
echo "Disk usage:"
df -h / /var/lib/jenkins /var/lib/docker 2>/dev/null | sort -u
echo "Memory:"
free -h
echo "Java:"; java -version
echo "Git: $(git --version)"
echo "Docker: $(docker --version)"
if [[ "${failures}" -ne 0 ]]; then
  echo "EC2/Jenkins verification failed with ${failures} problem(s)." >&2
  exit 1
fi
echo "EC2/Jenkins verification completed successfully."
