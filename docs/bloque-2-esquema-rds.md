# Bloque 2 — Esquema MySQL y preparación para RDS

## 1. Objetivo

Normalizar el contrato entre Spring Boot, el script SQL oficial y una futura instancia MySQL 8 en AWS RDS, sin crear recursos AWS ni almacenar credenciales reales.

## 2. Contrato de datos final

| Elemento | Contrato SQL | Contrato JPA |
|---|---|---|
| Base | `municipalidad_la_florida`, UTF-8 `utf8mb4` | Se selecciona mediante `DB_NAME` |
| Tabla | `users`, InnoDB | `@Table(name="users")` |
| `id` | `BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY` | `long`, `@Id`, `GenerationType.IDENTITY` |
| `firstName` | `VARCHAR(255) NOT NULL` | `String`, columna explícita `firstName`, longitud 255, no nula |
| `lastName` | `VARCHAR(255) NOT NULL` | `String`, columna explícita `lastName`, longitud 255, no nula |
| `email` | `VARCHAR(255) NOT NULL UNIQUE` | `String`, columna `email`, longitud 255, no nula y única |

Las propiedades JSON permanecen `id`, `firstName`, `lastName` y `email`. El repositorio `JpaRepository<UsuarioModel, Long>`, el servicio y el controlador no requieren cambios para este contrato.

## 3. Comparación con el script oficial

Fuente primaria leída directamente y preservada sin modificaciones:

`C:\Users\santi\OneDrive\Documents\Analista Programador\2026\II\Herramientas Devops\9a sem\COMANDOS Y SCRIP BASE DE DATOS - ACTIVIDAD EFT.txt`

SHA-256 observado después de la lectura: `D9592CF85F97903DAA2C770340BF129D75EE8C7E17F45ACCE1A8D08F012F5729`.

La versión normalizada conserva:

- La base `municipalidad_la_florida`.
- La tabla `users` y sus cuatro columnas exactas.
- `BIGINT AUTO_INCREMENT` para el identificador.
- Nulabilidad obligatoria de nombres y correo.
- Unicidad del correo.
- Los diez usuarios oficiales, incluidos `León`, `Gómez`, `López`, `Martínez`, `Sánchez`, `Fernández`, `Sofía` y `Ramírez` con sus acentos UTF-8.

La normalización añade `IF NOT EXISTS`, InnoDB, `utf8mb4` y una carga repetible mediante `ON DUPLICATE KEY UPDATE`; no altera la intención ni agrega datos.

## 4. Incompatibilidades encontradas

Spring Boot 3 configura por defecto una estrategia física de Hibernate que transforma camelCase a snake_case. Sin anotaciones explícitas, `firstName` y `lastName` se mapearían normalmente a `first_name` y `last_name`, mientras el script oficial crea `firstName` y `lastName`.

La entidad original tampoco expresaba la nulabilidad, longitud ni unicidad que sí exige el script. `ddl-auto=update` podía ocultar o modificar diferencias en vez de detectarlas.

## 5. Correcciones aplicadas

- Se añadieron nombres de columna explícitos en `UsuarioModel`.
- Se declararon `nullable=false`, longitud 255 y `unique=true` para `email`.
- No se cambiaron getters, setters, propiedades JSON, repositorio, servicio, controlador ni endpoints.
- Se cambió la configuración normal a `spring.jpa.hibernate.ddl-auto=validate`.
- Se completó la URL JDBC para Unicode UTF-8, UTC y MySQL 8.

## 6. Estrategia `ddl-auto`

- Producción/RDS: `validate`. El script SQL crea la base y tabla; Hibernate solo valida el esquema.
- Pruebas: `create-drop` en `application-test.properties`, sobre H2 en memoria.
- No se usa `create`, `create-drop` ni `update` en la configuración normal.

Esto evita destrucción o cambios silenciosos en RDS. La aplicación fallará temprano si el script no se ejecutó o si el esquema no coincide.

## 7. Variables de entorno

| Variable | Uso | Ejemplo ficticio |
|---|---|---|
| `DB_HOST` | Endpoint DNS MySQL/RDS | `CHANGE_ME_RDS_ENDPOINT` |
| `DB_PORT` | Puerto TCP | `3306` |
| `DB_NAME` | Esquema oficial | `municipalidad_la_florida` |
| `DB_USERNAME` | Usuario MySQL | `CHANGE_ME` |
| `DB_PASSWORD` | Contraseña MySQL | `CHANGE_ME` |

URL efectiva:

```text
jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC&useSSL=false&allowPublicKeyRetrieval=true
```

No contiene secretos. Para RDS debe evaluarse posteriormente el uso de TLS (`useSSL=true` y parámetros de verificación) según la configuración real.

`.env.example` contiene solo valores ficticios. `.env`, `.env.local`, `.env.aws` y `.env.ec2` están ignorados.

## 8. Scripts creados

- `database/01-create-schema.sql`: crea y selecciona la base, y crea `users` de forma idempotente.
- `database/02-seed-data.sql`: carga los diez registros oficiales y actualiza nombres si el correo ya existe.
- `database/03-verify-database.sql`: muestra base/codificación, DDL, estructura, conteo, registros y metadatos.
- `scripts/configure-rds-database.ps1`: valida variables, cliente y TCP; ejecuta los tres SQL en orden y detiene el flujo ante errores.
- `scripts/test-database-connection.ps1`: verifica DNS, TCP, autenticación, esquema, existencia de `users` y cantidad de filas.

La contraseña se entrega al proceso `mysql` mediante `MYSQL_PWD` temporal y se restaura/elimina en `finally`; no se escribe en argumentos ni mensajes. Este mecanismo evita exposición casual en la línea de comandos, aunque en un despliegue maduro conviene evaluar un archivo de opciones temporal protegido o integración con un gestor de secretos.

## 9. Configuración de una RDS existente

Después de crear RDS y permitir conectividad desde el host autorizado, establecer las cinco variables en la sesión sin registrarlas en archivos versionados y ejecutar:

```powershell
.\scripts\configure-rds-database.ps1
```

El script exige que `DB_NAME` sea `municipalidad_la_florida`, porque los SQL oficiales definen ese nombre. Comprueba TCP antes de autenticarse, crea el esquema, carga los datos y ejecuta la verificación final. No crea la instancia RDS.

## 10. Verificación de conexión

Con las mismas variables configuradas:

```powershell
.\scripts\test-database-connection.ps1
```

La salida esperada incluye resolución DNS, TCP exitoso, `schema=municipalidad_la_florida`, `users_table=1` y `user_count=10` (o un número mayor si existen usuarios adicionales legítimos).

## 11. Resultados Maven

| Comando | Estado | Pruebas | Tiempo |
|---|---|---:|---:|
| `.\mvnw.cmd clean test` | `BUILD SUCCESS` | 2; 0 fallos, 0 errores, 0 omitidas | 14,637 s total; 7,293 s pruebas |
| `.\mvnw.cmd clean package` | `BUILD SUCCESS` | 2; 0 fallos, 0 errores, 0 omitidas | 18,509 s total; 7,421 s pruebas |

Artefacto actual: `C:\Dev\Duoc\HeDevops\EFT\UsuariosREST\target\usuariosBuild.jar`. Se genera mediante `clean package` sin `-DskipTests`; el tamaño se verifica en cada build.

## 12. Validaciones realizadas

- Lectura UTF-8 directa del archivo oficial y conservación de acentos.
- Comparación manual campo a campo entre SQL, entidad, repositorio, servicio y controlador.
- Confirmación de la convención camelCase→snake_case y corrección explícita.
- Análisis sintáctico de ambos scripts PowerShell: sin errores.
- Ejecución negativa controlada: ambos scripts devuelven código 1 y mensaje claro si falta `DB_HOST`, sin imprimir contraseñas.
- Verificación de reglas `.gitignore` para cuatro archivos de secretos locales.
- Escaneo estático: no se encontró endpoint RDS ni credencial real en archivos activos; `CHANGE_ME` es ficticio.
- Maven/H2: contexto y persistencia JPA exitosos con el contrato actualizado.

No se realizó una ejecución MySQL: `mysql --version` confirmó que el cliente no está instalado y `docker info` confirmó que Docker Engine sigue detenido. No se construyó imagen ni se añadió Compose.

## 13. Riesgos pendientes

- Falta validar `validate` y los SQL contra MySQL 8/RDS real.
- `CREATE DATABASE` requiere privilegios que algunos usuarios RDS pueden no tener; si la base ya fue creada al aprovisionar RDS, el usuario debe al menos poder usarla y crear la tabla.
- `useSSL=false` sirve para preparación, pero la política TLS debe definirse antes de producción.
- `MYSQL_PWD` es temporal y no se imprime, aunque sigue siendo una variable del proceso; debe protegerse el host de ejecución.
- El seed es repetible por correo, pero no elimina datos adicionales ni fuerza exactamente diez filas.
- Docker, Jenkins, pruebas CRUD HTTP y despliegue AWS siguen fuera de este bloque.

## 14. Procedimiento futuro exacto para RDS

1. Crear MySQL 8 RDS con base inicial `municipalidad_la_florida`, sin hacer público el puerto innecesariamente.
2. Autorizar TCP 3306 solo desde EC2/Jenkins o el host administrativo requerido.
3. Instalar el cliente MySQL 8 en el host que ejecutará la configuración.
4. Establecer `DB_HOST`, `DB_PORT=3306`, `DB_NAME=municipalidad_la_florida`, `DB_USERNAME` y `DB_PASSWORD` mediante un mecanismo seguro.
5. Ejecutar `scripts/configure-rds-database.ps1` y exigir código 0.
6. Ejecutar `scripts/test-database-connection.ps1` y conservar salida sin secretos como evidencia.
7. Ejecutar la aplicación con las mismas cinco variables; `ddl-auto=validate` debe completar el arranque.
8. Probar GET/POST/PUT/DELETE y comprobar persistencia en `users`.
9. Si Hibernate falla al validar, detener el despliegue y comparar `SHOW CREATE TABLE users` con el contrato de este documento; no volver a `update` para ocultar el problema.
