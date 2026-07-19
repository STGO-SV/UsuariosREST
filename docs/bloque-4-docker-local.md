# Bloque 4 — Docker local contra AWS RDS

Fecha de validación: 19 de julio de 2026.

## Estado

**IMPLEMENTADO Y VERIFICADO.** Docker Desktop/Engine 29.4.3 estuvo operativo y se utilizó la estrategia WAR sobre Tomcat acordada para el proyecto. No se modificó ningún recurso AWS.

## Implementación

- `Dockerfile` usa `tomcat:10.1.23-jre21`, elimina aplicaciones de ejemplo y despliega `target/usuariosBuild.war` como `ROOT.war`; las rutas quedan en `/` y `/user`.
- `.dockerignore` excluye Git, secretos, fuentes y archivos ajenos al artefacto. `.env.rds` no forma parte del contexto.
- `build-docker-image.ps1` exige un `clean package` exitoso antes de construir `usuarios-rest:local`.
- `run-docker-local.ps1` carga `.env.rds` con `--env-file`, usa el nombre estable `usuarios-rest-local` y espera la respuesta HTTP.
- `test-docker-deployment.ps1` ejecuta POST → GET → PUT → GET → DELETE → GET y elimina el registro temporal incluso ante fallos.
- `stop-docker-local.ps1` sólo actúa sobre el contenedor exacto del proyecto.

## Evidencia obtenida

| Control | Resultado |
|---|---|
| `docker build --check .` | Sin advertencias |
| Maven previo al build | BUILD SUCCESS, sin omitir pruebas |
| Imagen final | `usuarios-rest:local`, 157.820.110 bytes (~150,5 MiB) |
| Inicio | Contenedor disponible por HTTP en aproximadamente 15 s |
| Hibernate | Conexión MySQL iniciada y esquema validado |
| `GET /user` inicial | HTTP 200, 10 registros oficiales |
| POST/GET/PUT/GET/DELETE | HTTP 200 en cada operación |
| GET del registro eliminado | HTTP 400, contrato actual de la API |
| `GET /user` final | HTTP 200, nuevamente 10 registros |

Las credenciales se inyectaron desde el archivo local ignorado. No se imprimieron ni se incorporaron a la imagen.

## Reproducción

```powershell
.\scripts\build-docker-image.ps1
.\scripts\run-docker-local.ps1
.\scripts\test-docker-deployment.ps1
.\scripts\stop-docker-local.ps1
```

## Riesgos pendientes

- Tomcat se ejecuta con el usuario predeterminado privilegiado de la imagen; debe endurecerse en producción.
- La etiqueta base está fijada por versión, no por digest.
- La conexión JDBC conserva TLS desactivado según la configuración académica actual.
- La prueba real depende de que RDS siga disponible y permita la IP de origen.
