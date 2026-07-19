# UsuariosREST

API CRUD de usuarios construida con Spring Boot 3.2.4, Java 17, Maven, MySQL y Docker. El artefacto es un JAR ejecutable de Spring Boot con Tomcat embebido.

## Verificación local

```powershell
.\mvnw.cmd clean test
.\mvnw.cmd clean package
```

Las pruebas usan H2 en memoria y no requieren AWS. La ejecución real obtiene `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME` y `DB_PASSWORD` desde el entorno; use `.env.example` como plantilla y no versione secretos.

## Docker contra una base configurada

```powershell
.\scripts\build-docker-image.ps1
.\scripts\run-docker-local.ps1
.\scripts\test-docker-deployment.ps1
.\scripts\stop-docker-local.ps1
```

Endpoints principales: `GET /`, `GET /user`, `GET /user/{id}`, `POST /user`, `PUT /user/{id}` y `DELETE /user/{id}`.

## Documentación

- [Base de datos y RDS](docs/bloque-3-rds-real.md)
- [Docker local](docs/bloque-4-docker-local.md)
- [Preparación EC2/Jenkins](docs/bloque-5-preparacion-ec2-jenkins.md)
Validación de integración automática GitHub–Jenkins.
