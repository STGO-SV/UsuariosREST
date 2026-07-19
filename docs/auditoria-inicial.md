# Auditoría técnica inicial — UsuariosREST

Fecha de ejecución: 19 de julio de 2026  
Raíz auditada: `C:\Dev\Duoc\HeDevops\EFT\UsuariosREST`

## 1. Resumen ejecutivo

El proyecto contiene una API CRUD pequeña y reconocible, construida con Spring Boot 3.2.4, Java 17, Maven Wrapper y MySQL. Los cuatro verbos exigidos (GET, POST, PUT y DELETE) están implementados sobre `/user`, y existe un endpoint de salud informal en `/`. El código fuente compila y se puede producir el WAR `target/usuariosBuild.war` si se omiten las pruebas.

El flujo entregable todavía no es reproducible: `mvnw clean test` y `mvnw clean package` fallan porque la única prueba intenta abrir la conexión RDS del perfil normal; el host configurado no resuelve y no existe un perfil de pruebas aislado. No hay repositorio Git inicializado en esta carpeta, Jenkinsfile, pipeline, archivos de GitHub ni evidencias de AWS/EC2. Docker está instalado pero su daemon no está activo, de modo que la imagen no pudo construirse. La configuración de datos contiene un endpoint RDS específico y placeholders de usuario/contraseña; no expone una contraseña real, pero acopla compilación, pruebas y ejecución a infraestructura externa.

**Estado general: ROJO.** Hay una base funcional aprovechable, pero actualmente fallan las pruebas y el empaquetado normal, y la mayoría de la pauta DevOps no tiene evidencia.

Estimación conservadora del estado actual: **15–25/100**, sujeta a los pesos de la pauta oficial no incluida. Con las acciones del plan mínimo, **80–90/100 es viable**.

## 2. Herramientas y versiones

| Herramienta | Resultado | Estado/observación |
|---|---:|---|
| Sistema operativo | Windows 11 (10.0), amd64 | Reportado por Maven |
| Java | Oracle JDK 17.0.9 LTS | Disponible; coincide con `java.version=17` |
| Git | 2.55.0.windows.3 | Disponible |
| Docker CLI | 29.4.3, build 055a478 | Disponible |
| Docker Engine | No disponible | No existe el pipe `docker_engine`/`dockerDesktopLinuxEngine`; daemon detenido |
| Maven Wrapper | Apache Maven 3.9.5 | Disponible después de descargar la distribución |
| Spring Boot | 3.2.4 | Configurado en `pom.xml` |
| Build | Maven Wrapper | Scripts `mvnw` y `mvnw.cmd` |
| Empaquetado | WAR | `packaging=war`, nombre final `usuariosBuild.war` |

`docker info` además informó una advertencia sobre el plugin `docker-ai.exe`; no es causa del fallo principal ni es necesario para la evaluación.

## 3. Estructura y arquitectura actual

```text
UsuariosREST/
├── pom.xml
├── mvnw / mvnw.cmd
├── Dockerfile
├── README.md
├── src/main/java/com/usuarios/UsuariosRest/
│   ├── UsuariosRestApplication.java
│   ├── ServletInitializer.java
│   ├── controllers/{InicioController,UsuarioController}.java
│   ├── models/UsuarioModel.java
│   ├── repositories/IUsuarioRepository.java
│   └── services/UsuarioService.java
├── src/main/java/Swagger/SwaggerConfigurations.java
├── src/main/resources/application.properties
└── src/test/java/.../UsuariosRestApplicationTests.java
```

Arquitectura: controlador REST → servicio → repositorio Spring Data JPA → MySQL. `UsuarioModel` es una entidad JPA asociada a la tabla `users`, con `id`, `firstName`, `lastName` y `email`. `IUsuarioRepository` extiende `JpaRepository<UsuarioModel, Long>`. La aplicación puede iniciarse con `main`, y `ServletInitializer` habilita el despliegue WAR tradicional.

Dependencias relevantes: Spring Web, Spring Data JPA, MySQL Connector/J, Spring Boot Test, Springdoc OpenAPI UI 2.5.0, anotaciones/modelos Swagger Jakarta, Lombok y DevTools. Lombok no se usa en el código revisado. El servidor embebido proviene de `spring-boot-starter-web`; el Dockerfile elige además Tomcat 10.1.23 con JRE 21 como contenedor externo.

### OpenAPI

Springdoc puede publicar la especificación en `/api-docs` y normalmente la UI en `/swagger-ui/index.html`. `SwaggerConfigurations` está en el paquete raíz `Swagger`, fuera del árbol de escaneo de `com.usuarios.UsuariosRest`; además, su método `api()` no tiene `@Bean`. Por tanto, esa clase personalizada no se activa, aunque la autoconfiguración de Springdoc sí puede funcionar. Esto requiere prueba de ejecución después de aislar la base de datos.

### Pruebas existentes

Solo existe `UsuariosRestApplicationTests.contextLoads()`. Es una prueba de carga de contexto, no prueba CRUD ni contratos HTTP.

## 4. Compilación y pruebas

| Comando | Resultado | Evidencia relevante |
|---|---|---|
| `.\mvnw.cmd clean test` | **FALLÓ** | 1 ejecutada, 0 fallos de aserción, 1 error, 0 omitidas |
| `.\mvnw.cmd clean package` | **FALLÓ** | Vuelve a fallar en la misma prueba; no alcanza el empaquetado normal |
| `.\mvnw.cmd package -DskipTests` | **EXITOSO (diagnóstico)** | Genera `target/usuariosBuild.war`; las pruebas fueron omitidas |

Causa raíz observada: `java.net.UnknownHostException` para el host RDS configurado, seguida de `CommunicationsException`; al no obtener metadatos JDBC, Hibernate termina informando que no puede determinar el dialecto. Esto demuestra acoplamiento de las pruebas a RDS, no un error de compilación Java.

Artefacto diagnóstico generado: `C:\Dev\Duoc\HeDevops\EFT\UsuariosREST\target\usuariosBuild.war`. No debe considerarse un artefacto aprobado por CI porque se generó omitiendo pruebas.

Advertencias/riesgos relevantes: ausencia de `src/test/resources`, prueba dependiente de red, y ninguna cobertura de GET/POST/PUT/DELETE.

## 5. Endpoints existentes

| Método y ruta | Implementación | Respuesta aparente | Evaluación |
|---|---|---|---|
| `GET /` | `InicioController.comienzo` | Texto con versión y año | Funcional sin DB, pero no es health check formal |
| `GET /user` | `findAll()` | `200` implícito y lista JSON | Implementado; requiere MySQL |
| `GET /user/{id}` | `findById()` | `200` con usuario; `400` si no existe | Funcional en principio; semánticamente debería ser `404` |
| `POST /user` | `save()` | Entidad persistida, `200` implícito | Implementado; suele preferirse `201` |
| `PUT /user/{id}` | búsqueda + actualización | `200`; `400`; `500` | Implementado; mensaje del servicio dice “eliminar” por error |
| `DELETE /user/{id}` | búsqueda + `deleteById()` | `200` vacío; `400`; `500` | Implementado |

Errores/riesgos de código evidentes:

- `getUsuario()` fuerza el resultado de `findAll()` a `ArrayList`; la implementación actual probablemente lo tolera, pero el contrato solo garantiza `List`, por lo que el cast es frágil.
- `UserNotFoundException` es una clase interna no estática del servicio y los mensajes mezclan actualización/eliminación.
- Hay imports web no usados dentro del servicio.
- No hay validación de entrada, restricciones de columnas, manejo centralizado de errores ni pruebas de controlador/servicio.
- Los códigos `400` para recursos inexistentes son funcionales pero poco correctos frente a REST (`404`).

## 6. Base de datos y compatibilidad SQL

Se espera MySQL, esquema `municipalidad_la_florida`, puerto 3306. Los cinco datos habitualmente exigidos aparecen conceptualmente: motor/driver por dependencia, host, puerto, base, usuario y contraseña; sin embargo, usuario y contraseña son placeholders y no hay estrategia de variables de entorno. El host es un endpoint RDS específico codificado. No se encontró una contraseña real.

`spring.jpa.hibernate.ddl-auto=update` permite que Hibernate cree o modifique la tabla automáticamente. Es cómodo para la demostración, pero riesgoso en un entorno compartido y reduce el control reproducible del esquema.

La entidad usa tabla `users`. Sin una estrategia física explícita, Spring/Hibernate normalmente transforma `firstName` y `lastName` a `first_name` y `last_name`; el JSON conserva `firstName`/`lastName`. **No se encontró ningún archivo `.sql` en el proyecto ni fue suministrado entre los adjuntos disponibles**, por lo que la compatibilidad solicitada con SQL queda **BLOQUEADA/REQUIERE VERIFICACIÓN**. Debe comprobarse que el script use `users(id, first_name, last_name, email)` o declarar nombres explícitos en Java.

## 7. Dockerfile

Contenido/estrategia: imagen `tomcat:10.1.23-jre21`, puerto 8080 y copia del WAR preconstruido a `webapps/usuariosBuild.war`. El `COPY` coincide con el `finalName` actual. La instrucción heredada de Tomcat inicia el servidor; no hace falta un `CMD` propio.

Estado: **sintaxis simple y plausiblemente válida, construcción no verificada**. `docker build -t usuariosrest:audit .` se intentó dentro y fuera del sandbox, pero falló antes de procesar el Dockerfile porque Docker Desktop/Engine no está ejecutándose.

Problemas de reproducibilidad y despliegue:

- No es multi-stage: exige que Jenkins/Maven genere antes el WAR correcto.
- El build Docker falla si las pruebas se ejecutan normalmente y, si no existe el WAR, falla el `COPY`.
- `MAINTAINER` está obsoleto; es una advertencia, no un bloqueo.
- No hay `.dockerignore`; el contexto puede incluir `.git`, fuentes y `target` innecesarios.
- La aplicación compila para Java 17 y la imagen usa JRE 21: es compatible hacia atrás, pero añade una diferencia innecesaria entre build y runtime.
- Para WAR tradicional, Tomcat suele marcarse como dependencia `provided`; aquí llega transitivamente sin ese alcance, con riesgo de bibliotecas de contenedor duplicadas.
- El contexto será `/usuariosBuild`, por lo que las rutas desplegadas probablemente serán `/usuariosBuild/user`, no `/user`. Esto debe reflejarse en las pruebas/evidencia o desplegar como `ROOT.war`.
- El contenedor seguirá requiriendo DNS, red, Security Groups y credenciales RDS válidas. No se intentó conexión a RDS.
- No hay healthcheck, usuario no-root personalizado ni parametrización documentada. Para la pauta, la falta de parametrización es más crítica que el endurecimiento opcional.

Empaquetado: el proyecto y Dockerfile son coherentes entre sí como WAR. Si la pauta exige explícitamente JAR, existe un riesgo documental y de puntaje: habría que confirmar la exigencia y alinear `pom.xml`, Dockerfile y comando de ejecución. No conviene cambiar solo la extensión.

## 8. Compatibilidad AWS, Jenkins y RDS

- **RDS:** dependencia y URL MySQL presentes, pero endpoint no resoluble, credenciales placeholder, sin variables de entorno ni evidencia de conectividad/Security Groups.
- **EC2:** una imagen Docker podría ejecutarse en EC2 una vez resueltos daemon, artefacto, variables y red. No existe evidencia de instancia, Docker instalado en EC2, puertos o acceso.
- **Jenkins:** Maven Wrapper permite CI, pero el test acoplado a RDS rompe el pipeline. No hay Jenkinsfile ni credenciales administradas.
- **GitHub:** la carpeta auditada no contiene `.git`; `git status`, rama y remotos no pudieron obtenerse. No hay workflows ni evidencia de repositorio remoto.
- **Docker:** estrategia WAR/Tomcat razonable, pero build no comprobado y ejecución dependiente de MySQL.

## 9. Matriz de cumplimiento de la pauta

| # | Componente | Estado | Evidencia / brecha |
|---:|---|---|---|
| 1 | Ciclo de vida y explicación DevOps | NO CUBIERTO | README solo contiene el título; no hay documentación/evidencia |
| 2 | Configuración AWS RDS | PARCIALMENTE CUBIERTO | URL con forma RDS y MySQL, pero sin instancia/conectividad verificable |
| 3 | Cinco parámetros de conexión | PARCIALMENTE CUBIERTO | URL aporta host, puerto y DB; usuario/clave son placeholders; falta manejo seguro |
| 4 | Preparación de EC2 | NO CUBIERTO | Sin scripts ni evidencia de EC2/Docker/puertos |
| 5 | GitHub y Jenkins | NO CUBIERTO | No hay `.git`, remoto, Jenkinsfile ni evidencia |
| 6 | Pipeline Jenkins de cinco etapas | NO CUBIERTO | No existe pipeline |
| 7 | Despliegue Docker | PARCIALMENTE CUBIERTO | Dockerfile existe; build/ejecución no verificables por daemon detenido y test roto |
| 8 | Pruebas POST, PUT, GET y DELETE | PARCIALMENTE CUBIERTO | Endpoints existen, pero no hay pruebas CRUD ni evidencia de ejecución |
| 9 | Video y evidencia | NO CUBIERTO | No se encontraron materiales |

No se marca ningún criterio como “YA CUBIERTO” porque la pauta evalúa evidencia demostrable, no solo presencia de código. Los puntos AWS dependientes de infraestructura real quedan además sujetos a **REQUIERE VERIFICACIÓN** cuando se habilite el entorno.

## 10. Riesgos priorizados

| Severidad | Riesgo | Impacto |
|---|---|---|
| Crítica | `clean test` y `clean package` fallan por dependencia directa de RDS | Bloquea CI, Jenkins y artefactos confiables |
| Crítica | No existe repositorio Git/Jenkinsfile/pipeline | Impide cubrir criterios centrales DevOps |
| Crítica | Sin evidencia ni configuración verificable de RDS/EC2 | Impide demostrar despliegue end-to-end |
| Alta | Configuración no parametrizada; endpoint RDS codificado | Entornos inseguros/no reproducibles |
| Alta | Docker no pudo construirse y el daemon está detenido | Despliegue no demostrado |
| Alta | No hay pruebas/evidencias CRUD | Riesgo directo sobre el criterio POST/PUT/GET/DELETE |
| Alta | WAR/Tomcat externo frente a posible exigencia JAR | Puede perder puntaje o producir discrepancias de rutas |
| Media | Context path `/usuariosBuild` | Las URLs de evidencia pueden diferir de las esperadas |
| Media | SQL no disponible y nombres físicos no explícitos | Compatibilidad del esquema sin confirmar |
| Media | Configuración Swagger fuera del component scan | Personalización inactiva; documentación por verificar |
| Media | `ddl-auto=update` | Cambios de esquema no controlados |
| Baja | Códigos HTTP, casts/imports/mensajes y `MAINTAINER` | Calidad y mantenibilidad; no bloquea por sí solo |

## 11. Acciones priorizadas y estimación

| Prioridad | Acción | Tiempo estimado | Punto de control |
|---:|---|---:|---|
| 1 | Confirmar pauta/pesos y decisión JAR vs WAR | 0,5 h | Formato de entrega acordado |
| 2 | Crear perfil de test local aislado y pruebas deterministas | 1,5–2,5 h | `clean test` verde sin AWS |
| 3 | Parametrizar los cinco datos RDS sin secretos en Git | 1–1,5 h | Arranque con variables y fallo claro sin ellas |
| 4 | Alinear SQL, entidad y nombres de columnas | 0,5–1 h | Script ejecutable + CRUD consistente |
| 5 | Añadir pruebas automáticas CRUD y guion de evidencia | 2–3 h | GET/POST/PUT/DELETE verdes |
| 6 | Definir pipeline Jenkins de cinco etapas | 2–3 h | checkout, test, package, image, deploy/evidence |
| 7 | Corregir y verificar Docker reproducible | 1–2 h | build y ejecución local exitosos |
| 8 | Inicializar/publicar GitHub y conectar Jenkins | 1–2 h | webhook/build desde SCM |
| 9 | Aprovisionar/verificar RDS y EC2 | 2–4 h | conectividad privada/controlada y API accesible |
| 10 | Preparar documentación, capturas y video | 2–3 h | checklist completo y video reproducible |

Total orientativo: **13,5–22 horas**, condicionado a permisos AWS, disponibilidad de Jenkins/Docker y claridad de la pauta.

Tareas opcionales de bajo retorno que deben posponerse: arquitectura de microservicios, Kubernetes, Terraform, observabilidad avanzada, autenticación completa, refactor masivo, frontend y optimizaciones prematuras. Abandonarlas si no aportan un criterio explícito o si consumen más de 30–45 minutos sin desbloquear una evidencia.

## 12. Comandos ejecutados y resultados

```powershell
java -version                         # OK: Java 17.0.9
git --version                         # OK: Git 2.55.0.windows.3
docker --version                      # OK: Docker CLI 29.4.3
docker info                           # FALLÓ: daemon/pipe no disponible
.\mvnw.cmd -version                   # OK: Maven 3.9.5, Java 17
git status                            # FALLÓ: no es repositorio Git
git branch --show-current             # FALLÓ: no es repositorio Git
git remote -v                         # FALLÓ: no es repositorio Git
.\mvnw.cmd clean test                 # FALLÓ: 1 test, 1 error por RDS/DNS
.\mvnw.cmd clean package              # FALLÓ: misma prueba; sin package normal
.\mvnw.cmd package -DskipTests        # OK diagnóstico: WAR generado
docker build -t usuariosrest:audit .  # FALLÓ: Docker Engine detenido
rg --files                            # Inventario del proyecto
rg --files -g '*.sql' ...             # No encontró SQL/Jenkinsfile/GitHub
```

No se ejecutaron `commit`, `push`, `pull`, `merge`, `rebase`, conexiones deliberadas a AWS ni cambios de credenciales. Maven sí intentó resolver el host configurado durante la prueba porque `@SpringBootTest` carga la configuración productiva; el intento falló antes de autenticar.

## 13. Archivos creados o modificados

- Creado: `docs/auditoria-inicial.md`.
- Creado: `docs/plan-minimo-80-puntos.md`.
- Generado por Maven: contenido de `target/`, incluido `target/usuariosBuild.war` mediante `-DskipTests` y reportes Surefire de los intentos fallidos.
- No se modificó código fuente, `pom.xml`, configuración, Dockerfile, README ni archivos originales.

## 14. Conclusión

**Sí es viable alcanzar al menos 80 puntos.** La API ya ofrece el CRUD requerido y el WAR se puede construir, lo que reduce el trabajo de aplicación. La ruta crítica no es agregar arquitectura: consiste en desacoplar pruebas de RDS, parametrizar la conexión, lograr un build verde, automatizar cinco etapas en Jenkins, verificar Docker/RDS/EC2 y producir evidencia clara. La viabilidad depende de contar oportunamente con accesos AWS, Docker activo, un repositorio GitHub y la pauta con sus pesos exactos.

## Corrección posterior a la auditoría: desacoplamiento de RDS

Fecha de corrección: 19 de julio de 2026.

### Problema original y causa raíz

La configuración activa contenía una URL JDBC ligada a un endpoint RDS y la única prueba `@SpringBootTest` cargaba esa misma configuración. En consecuencia, Maven necesitaba DNS, red y una base externa para crear el contexto. El host no resolvía, MySQL Connector/J producía `CommunicationsException` y Hibernate no podía obtener metadatos para determinar el dialecto. El resultado era 1 prueba ejecutada con 1 error, y tanto `clean test` como `clean package` terminaban en `BUILD FAILURE`.

### Solución aplicada

- La configuración normal continúa usando MySQL, pero ahora construye la URL desde `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME` y `DB_PASSWORD`. Los valores seguros por defecto son `localhost`, `3306` y `municipalidad_la_florida`; usuario y contraseña quedan vacíos si no son inyectados.
- Se corrigió `allowPublicKeyRetrival` a `allowPublicKeyRetrieval`.
- Se agregó H2 únicamente con alcance `test`.
- Se creó el perfil `test` con H2 en memoria, modo de compatibilidad MySQL y esquema `create-drop`.
- La clase de prueba activa el perfil mediante `@ActiveProfiles("test")`.
- Se mantuvo la prueba de contexto y se añadió una prueba mínima que guarda y recupera un `UsuarioModel` con `IUsuarioRepository`.

No se cambió la entidad: `@Table(name="users")`, `GenerationType.IDENTITY`, `firstName`, `lastName` y `email` funcionan sobre H2. Los campos continúan siendo anulables y el correo no es único; cambiar esas reglas alteraría el esquema/contrato y no era necesario para este bloque.

### Archivos modificados o creados

- Modificados: `pom.xml`, `src/main/resources/application.properties`, `src/test/java/com/usuarios/UsuariosRest/UsuariosRestApplicationTests.java` y este informe.
- Creados: `src/test/resources/application-test.properties` y `docs/bloque-1-compilacion-reproducible.md`.

### Resultados antes y después

| Verificación | Antes | Después |
|---|---|---|
| `mvnw.cmd clean test` | FAILURE; 1 prueba, 1 error | SUCCESS; 2 pruebas, 0 fallos, 0 errores, 0 omitidas; 15,830 s total |
| `mvnw.cmd clean package` | FAILURE en pruebas | SUCCESS; 2 pruebas, 0 fallos, 0 errores, 0 omitidas; 18,560 s total |
| Dependencia para probar | RDS/MySQL externo | H2 en memoria, perfil `test` |
| Artefacto validado con pruebas | No | `target/usuariosBuild.war`, 52.533.395 bytes (~50,1 MiB) |

### Seguridad y riesgos pendientes

Un escaneo posterior no encontró el endpoint RDS original, una URL JDBC externa, nombre de usuario real, contraseña real ni los placeholders anteriores en archivos activos. `sa` con contraseña vacía existe exclusivamente en la base H2 efímera de pruebas. La configuración normal requiere inyectar credenciales válidas para funcionar contra MySQL/RDS.

Persisten fuera del alcance de este bloque: validar conectividad real con RDS, decidir WAR frente a JAR, verificar Docker, crear Jenkins y pruebas CRUD HTTP, revisar nulabilidad/unicidad del modelo, y definir una política de migración más controlada que `ddl-auto=update` para despliegue.

## Corrección posterior a la auditoría: normalización del esquema MySQL

Fecha de corrección: 19 de julio de 2026.

El script oficial adjunto se leyó directamente desde su archivo original, que se conservó sin cambios (SHA-256 observado: `D9592CF85F97903DAA2C770340BF129D75EE8C7E17F45ACCE1A8D08F012F5729`). Este define la base `municipalidad_la_florida`, la tabla `users`, las columnas `id`, `firstName`, `lastName` y `email`, y diez registros iniciales con acentos.

Se detectó una incompatibilidad objetiva: sin nombres de columna explícitos, la estrategia física predeterminada de Spring Boot/Hibernate convierte propiedades camelCase a nombres con guion bajo, por lo que `firstName` y `lastName` se buscarían como `first_name` y `last_name`. La entidad ahora fija `@Column(name="firstName")` y `@Column(name="lastName")`, sin cambiar propiedades Java ni JSON. También refleja `VARCHAR(255) NOT NULL`, correo único e identidad autoincremental del script oficial.

La estrategia normal cambió de `ddl-auto=update` a `ddl-auto=validate`: el script crea el esquema y Hibernate comprueba el contrato sin crear, destruir ni modificar datos. El perfil H2 conserva `create-drop` exclusivamente para pruebas. La URL MySQL 8 sigue parametrizada con `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME` y `DB_PASSWORD`, y ahora declara Unicode/UTF-8 y zona horaria UTC.

Se crearon scripts separados e idempotentes bajo `database/` para crear, cargar los diez datos oficiales y verificar la base. También se añadieron scripts PowerShell para configurar una RDS existente y comprobar DNS, TCP, autenticación, esquema, tabla y conteo sin imprimir la contraseña. `.env.example` contiene solo valores ficticios y `.gitignore` excluye `.env`, `.env.local`, `.env.aws` y `.env.ec2`.

Validación: `mvnw.cmd clean test` finalizó en 14,637 s y `mvnw.cmd clean package` en 18,509 s; ambos ejecutaron 2 pruebas con 0 fallos, 0 errores y 0 omitidas. El WAR resultante mide 52.533.475 bytes. Los scripts PowerShell pasan análisis sintáctico y rechazan variables ausentes con código distinto de cero. No se pudo ejecutar MySQL real porque el cliente `mysql` no está instalado y Docker Engine continúa detenido; la ejecución contra RDS permanece pendiente.
