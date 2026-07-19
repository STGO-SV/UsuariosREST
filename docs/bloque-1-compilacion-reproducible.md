# Bloque 1 — Compilación reproducible

## 1. Objetivo

Hacer que `mvnw.cmd clean test` y `mvnw.cmd clean package` funcionen sin AWS, RDS, MySQL local ni Docker, conservando MySQL como base normal para el despliegue posterior.

Estado final: **COMPLETADO**. Ambos comandos terminan con `BUILD SUCCESS` y ejecutan las pruebas; no se utilizó `-DskipTests`.

## 2. Cambios realizados

- Se reemplazó el endpoint RDS fijo por cinco variables de entorno identificables.
- Se añadió H2 con alcance exclusivo de prueba.
- Se creó `application-test.properties` con una base en memoria reproducible.
- Se activó el perfil `test` mediante `@ActiveProfiles("test")` en la prueba.
- Se agregó una prueba mínima de persistencia y recuperación del repositorio.
- Se corrigió la opción JDBC `allowPublicKeyRetrieval`.
- No se modificaron endpoints, controladores, servicio, repositorio, entidad, Dockerfile ni configuración de AWS/Jenkins.

## 3. Configuración principal

La aplicación normal continúa usando MySQL:

```properties
spring.datasource.url=jdbc:mysql://${DB_HOST:localhost}:${DB_PORT:3306}/${DB_NAME:municipalidad_la_florida}?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
spring.datasource.username=${DB_USERNAME:}
spring.datasource.password=${DB_PASSWORD:}
spring.jpa.hibernate.ddl-auto=update
```

Los valores por defecto de host, puerto y nombre permiten apuntar a un MySQL local si existe, pero la compilación y las pruebas no lo requieren. No hay credenciales reales ni un endpoint RDS en el archivo.

## 4. Configuración de pruebas

`src/test/resources/application-test.properties` define:

- URL `jdbc:h2:mem:usuarios_test`.
- Modo de compatibilidad MySQL.
- Persistencia limitada al proceso de prueba (`DB_CLOSE_ON_EXIT=FALSE`).
- Driver H2 y usuario local efímero `sa` sin contraseña.
- Dialecto H2 compatible.
- Esquema recreado en cada ejecución con `create-drop`.
- `open-in-view=false` durante pruebas.

H2 está declarado en Maven con alcance `test`, por lo que no se incorpora como base de producción. El perfil se activa solo en `UsuariosRestApplicationTests`; la aplicación normal no fuerza `test`.

La entidad `UsuarioModel` inicializa correctamente la tabla `users`. `id` usa `GenerationType.IDENTITY`, y `firstName`, `lastName` y `email` se guardaron y recuperaron con éxito. Se conservaron los nombres Java/JSON y las reglas actuales: los campos no tienen restricción explícita de nulidad y el correo no es único.

## 5. Variables de entorno necesarias

| Variable | Función | Valor por defecto | Requerida en RDS |
|---|---|---|---|
| `DB_HOST` | Host MySQL/RDS | `localhost` | Sí |
| `DB_PORT` | Puerto MySQL | `3306` | Sí, aunque normalmente sea 3306 |
| `DB_NAME` | Nombre de la base | `municipalidad_la_florida` | Sí |
| `DB_USERNAME` | Usuario de base | Vacío | Sí |
| `DB_PASSWORD` | Contraseña de base | Vacío | Sí |

Estas variables no son necesarias para compilar o probar. En despliegue deben inyectarse desde un mecanismo seguro; no deben guardarse valores reales en Git, documentación o comandos capturados.

## 6. Comandos de verificación

```powershell
.\mvnw.cmd clean test
.\mvnw.cmd clean package
rg -n --hidden -g '!target/**' -g '!.git/**' `
  '(database-1\.|amazonaws\.com|jdbc:mysql://[^$]|NOMBRE_USERNAME|PASSWORD_GENERADA|spring\.datasource\.(username|password)=)' .
Get-Item target\usuariosBuild.war
```

No se ejecutaron comandos Docker, AWS, Jenkins o Git de escritura.

## 7. Resultados obtenidos

### `clean test`

- Estado: `BUILD SUCCESS`.
- Pruebas: 2.
- Fallos: 0.
- Errores: 0.
- Omitidas: 0.
- Tiempo de pruebas: 7,786 s.
- Tiempo total Maven: 15,830 s.
- Perfil observado en logs: `test`.
- Conexión observada: `jdbc:h2:mem:usuarios_test`.

### `clean package`

- Estado: `BUILD SUCCESS`.
- Pruebas: 2.
- Fallos: 0.
- Errores: 0.
- Omitidas: 0.
- Tiempo de pruebas: 7,629 s.
- Tiempo total Maven: 18,560 s.
- Artefacto: `C:\Dev\Duoc\HeDevops\EFT\UsuariosREST\target\usuariosBuild.war`.
- Tamaño: 52.533.395 bytes, aproximadamente 50,1 MiB.

Las dos pruebas confirman que el contexto carga con H2 y que el repositorio guarda y recupera un usuario.

### Revisión de secretos

No se encontró el host RDS anterior, una URL JDBC externa fija, un nombre de usuario real, una contraseña real ni los placeholders antiguos en archivos activos. El escaneo solo detectó:

- `${DB_USERNAME:}` y `${DB_PASSWORD:}` en la configuración normal.
- Usuario `sa` y contraseña vacía en el perfil H2 efímero de pruebas.

Ninguno es un secreto real.

## 8. Problemas pendientes

- Hibernate avisa que declarar `H2Dialect` explícitamente es redundante; se conserva porque es compatible y deja explícita la configuración solicitada.
- Los campos de la entidad son anulables y `email` no tiene unicidad. No bloquean H2 y no se cambiaron para evitar alterar el contrato/esquema fuera del alcance.
- `ddl-auto=update` permanece en la configuración MySQL y debe revisarse antes del despliegue productivo.
- Falta validar las cinco variables contra una instancia RDS real; eso pertenece al bloque AWS posterior.
- Siguen pendientes pruebas CRUD HTTP, Docker, Jenkins y la decisión JAR/WAR.

## 9. Conclusión

La compilación quedó desacoplada de RDS. Maven crea un entorno H2 nuevo durante cada ejecución, carga el contexto, valida el repositorio y genera el WAR con todas las pruebas activas. La aplicación normal conserva el driver y la URL MySQL parametrizada para una futura conexión segura a AWS RDS.
