#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${RDS_ENV_FILE:-/opt/usuarios-rest/secrets/rds.env}"
image_name="usuarios-rest:manual"
container_name="usuarios-rest-app"
app_port="${APP_PORT:-8088}"

if [[ ! -s "${env_file}" ]]; then
  echo "Secure RDS env file not found or empty: ${env_file}" >&2
  exit 1
fi
for required in DB_HOST DB_PORT DB_NAME DB_USERNAME DB_PASSWORD; do
  if ! grep -qE "^${required}=" "${env_file}"; then
    echo "Required key ${required} is missing from the env file." >&2
    exit 1
  fi
done

cd "${project_root}"
chmod +x mvnw
echo "Building and testing executable JAR..."
./mvnw clean package
echo "Building Docker image..."
docker build --tag "${image_name}" .

echo "Replacing only the UsuariosREST application container..."
docker rm --force "${container_name}" >/dev/null 2>&1 || true
docker run --detach \
  --name "${container_name}" \
  --restart unless-stopped \
  --env-file "${env_file}" \
  --publish "${app_port}:8080" \
  "${image_name}" >/dev/null

ready=0
for attempt in $(seq 1 30); do
  if curl --fail --silent --show-error "http://localhost:${app_port}/" >/dev/null && \
     curl --fail --silent --show-error "http://localhost:${app_port}/user" >/dev/null; then
    ready=1
    break
  fi
  sleep 4
done

if [[ "${ready}" -ne 1 ]]; then
  docker logs --tail 100 "${container_name}" 2>&1 | grep -viE 'password|jdbc:mysql' || true
  echo "Manual deployment smoke test failed." >&2
  exit 1
fi
echo "Manual deployment completed successfully on port ${app_port}."
