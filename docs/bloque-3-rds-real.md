# Bloque 3 — AWS RDS MySQL real

## Estado

**COMPLETADO.** La instancia RDS ya existente fue validada sin modificar su configuración AWS. Se configuró el esquema, Spring Boot inició con Hibernate `validate`, se recuperaron los diez registros oficiales y el CRUD temporal terminó correctamente.

## 1. Recursos creados

Recursos existentes proporcionados por el usuario:

- Una instancia RDS MySQL 8 disponible.
- Un Security Group con MySQL/Aurora TCP 3306 limitado a la IP pública autorizada `/32`.

Recursos creados o modificados por Codex en AWS: **ninguno**. Solo se crearon la tabla y los datos dentro de la base ya autorizada.

## 2. Región

Región confirmada a partir del endpoint configurado, sin documentar el endpoint: `us-east-1`.

## 3. Configuración RDS propuesta, sin secretos

| Parámetro | Propuesta mínima |
|---|---|
| Motor | RDS for MySQL 8.0.44 |
| Identificador | Existente; omitido de la documentación |
| Clase | No consultada: AWS CLI no tiene sesión activa |
| Almacenamiento | No consultado: AWS CLI no tiene sesión activa |
| Base inicial | `municipalidad_la_florida` |
| Puerto | 3306 |
| Despliegue | Single-AZ |
| Backups | Retención de 1 día |
| Multi-AZ / réplicas | Desactivados |
| Performance Insights | Desactivado |
| Minor upgrades | Automáticos |
| Protección contra borrado | Desactivada para permitir limpieza posterior controlada |
| Acceso público | Confirmado funcional; restringido por Security Group a `/32` según el usuario |

La clase, almacenamiento y elegibilidad Free Tier no se pudieron verificar sin una sesión AWS CLI. Los costos del recurso existente continúan hasta que se detenga o elimine según las capacidades de RDS y la decisión del propietario.

## 4. Grupo de seguridad

El usuario confirmó una regla MySQL/Aurora TCP 3306 limitada a su IP pública `/32`. La conexión TCP real fue exitosa. No se modificó ni amplió esa regla. VPC, subredes y metadatos del grupo no se consultaron porque AWS CLI continúa sin sesión activa.

## 5. Scripts preparados

- `scripts/provision-rds.ps1`: valida AWS CLI/sesión, región y variables; detecta instancia existente, crea/reutiliza el grupo, crea RDS, espera disponibilidad y obtiene el endpoint.
- `scripts/get-rds-status.ps1`: muestra estado, endpoint, puerto, motor/versión, clase, almacenamiento, acceso público, grupos, base y región; no muestra credenciales.
- `scripts/configure-rds-database.ps1`: carga las cinco variables desde `.env.rds`, usa el cliente MySQL por PATH o su ruta absoluta, y ejecuta los tres SQL normalizados.
- `scripts/test-database-connection.ps1`: carga `.env.rds` y valida DNS, TCP, autenticación, esquema, tabla y conteo sin mostrar host, IP ni contraseña.
- `scripts/test-crud-rds.ps1`: crea un usuario temporal, ejecuta GET/PUT/DELETE, confirma ausencia y limpia en caso de error cuando es posible.

## 6. Resultado de conexión

Exitosa. DNS resolvió, TCP 3306 respondió, MySQL autenticó y el esquema `municipalidad_la_florida` resultó accesible. La primera verificación confirmó correctamente que `users` aún no existía; después de configurar el esquema, informó `users_table=1` y `user_count=10`.

## 7. Resultado de creación del esquema

Exitosa. Se ejecutaron en orden `01-create-schema.sql`, `02-seed-data.sql` y `03-verify-database.sql`. El resultado confirmó InnoDB, `utf8mb4`, columnas camelCase exactas, campos `NOT NULL`, identidad autoincremental, correo único y diez registros oficiales con acentos correctos.

## 8. Resultado de Hibernate `validate`

Exitosa después de una corrección objetiva. El primer arranque no modificó datos y falló porque Hibernate buscaba `first_name` pese a los nombres declarados. Se configuró `PhysicalNamingStrategyStandardImpl`; el segundo arranque inicializó `EntityManagerFactory`, inició Tomcat en 8080 y no reportó columnas ausentes, errores de dialecto, zona horaria o codificación.

## 9. Resultado CRUD

Exitoso contra RDS real:

- POST creó el usuario temporal con id 11.
- GET recuperó el mismo usuario.
- PUT actualizó `firstName`.
- DELETE eliminó el temporal.
- GET final confirmó ausencia mediante la respuesta esperada de la API.
- El conteo posterior volvió a 10, conservando todos los registros oficiales.

## 10. Resultados Maven

| Comando | Resultado | Pruebas |
|---|---|---|
| `.\mvnw.cmd clean test` | `BUILD SUCCESS`, 21,160 s | 2; 0 fallos, 0 errores, 0 omitidas |
| `.\mvnw.cmd clean package` | `BUILD SUCCESS`, 21,028 s | 2; 0 fallos, 0 errores, 0 omitidas |

No se usó `-DskipTests`.

## 11. Evidencias recomendadas para el video

- Identidad/región AWS sin mostrar claves, ID de cuenta completo ni ARN innecesario.
- RDS en estado `available`, ocultando endpoint y credenciales.
- Regla de seguridad 3306 limitada al origen autorizado.
- Ejecución exitosa de los scripts SQL y conteo de diez registros.
- Inicio de Spring Boot con `ddl-auto=validate` y sin errores de esquema.
- GET `/user` con los diez registros oficiales.
- Ejecución completa de `test-crud-rds.ps1`.
- `clean test` y `clean package` verdes.

## 12. Costos y recursos por eliminar

Recursos potencialmente facturables: instancia RDS existente, almacenamiento, backups, transferencia y dirección IPv4 pública. La clase y cobertura Free Tier no fueron consultadas. El recurso puede generar costo mientras permanece disponible, incluso sin tráfico.

Después de obtener evidencia se debe eliminar, con autorización separada, la instancia `usuarios-rest-eval` y decidir si se conserva un snapshot final (el snapshot también puede generar costo). Luego se debe eliminar el grupo de seguridad del proyecto si ya no está asociado.

## 13. Riesgos pendientes

- AWS CLI continúa sin sesión, aunque no fue necesaria para validar la base existente.
- Elegibilidad Free Tier/créditos desconocida.
- Permisos IAM insuficientes para STS, EC2 Security Groups o RDS.
- Ausencia de VPC predeterminada o subredes aptas para RDS público.
- IP pública dinámica, que puede invalidar la regla `/32`.
- Acceso público temporal de RDS, aunque limitado por `/32`.
- `.env.rds` contiene secretos locales: está ignorado y nunca se imprimió, pero debe protegerse y eliminarse cuando deje de ser necesario.
- Exposición temporal de RDS a Internet, aunque limitada por grupo de seguridad.
- Configuración TLS de la aplicación aún usa `useSSL=false`.

## 14. Procedimiento posterior y eliminación

1. Para evidencia AWS adicional, autenticar AWS CLI y ejecutar `get-rds-status.ps1`, ocultando endpoint y metadatos sensibles en el video.
2. Conservar `.env.rds` solo durante las pruebas y mantenerlo fuera de Git.
3. Antes de EC2/Jenkins, reemplazar el origen `/32` local por el origen mínimo correspondiente y evaluar TLS.
4. Tras la evaluación, solicitar autorización de eliminación; eliminar la instancia desde AWS CLI o consola, decidir explícitamente si se conserva snapshot final y verificar que no queden recursos facturables.

No se incluye un comando automático de borrado para impedir eliminaciones accidentales.
