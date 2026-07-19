# Plan mínimo y seguro para alcanzar 80 puntos

## Objetivo y estrategia

Meta operativa: asegurar **85–90 puntos potenciales** para conservar margen ante fallos de demostración. La estrategia es mantener la API simple, convertir el build en determinista y concentrar el trabajo en evidencias end-to-end exigidas: GitHub → Jenkins → pruebas → paquete → Docker → EC2/RDS.

La cifra actual estimada es 15–25/100. Los pesos exactos no fueron suministrados; antes de implementar se debe mapear este plan a la pauta oficial y ajustar el margen.

## Criterios a asegurar al 100%

1. **GitHub y Jenkins:** repositorio trazable, Jenkins conectado y ejecución desde SCM.
2. **Pipeline de cinco etapas:** cinco etapas visibles, exitosas y documentadas; sugerencia mínima: Checkout, Test, Package, Build Docker y Deploy/Verify.
3. **Despliegue Docker:** imagen reproducible y contenedor operativo en EC2.
4. **Pruebas CRUD:** POST, PUT, GET y DELETE demostrados con datos y respuestas verificables.
5. **Parámetros RDS:** host, puerto, base, usuario y contraseña configurados mediante variables/credenciales, sin secretos en Git.
6. **Evidencia:** capturas/logs y video que sigan la pauta en el mismo orden.

Estos criterios forman la cadena de entrega y tienen alto riesgo de “todo o nada”; una falla temprana invalida varias evidencias posteriores.

## Criterios que pueden quedar en 80%

- Explicación del ciclo DevOps: explicación breve, específica del proyecto y respaldada por el pipeline; evitar teoría extensa.
- Preparación de EC2: cubrir instalación, puertos, ejecución y persistencia mínima; omitir hardening avanzado si no está puntuado.
- Configuración RDS: demostrar instancia, esquema, conectividad y seguridad básica; evitar alta disponibilidad, réplicas y tuning no exigidos.
- Calidad adicional de Swagger, respuestas HTTP y refactor: corregir solo lo necesario para una demo estable.

## Secuencia recomendada y dependencias

| Fase | Trabajo mínimo | Depende de | Punto de control | Tiempo |
|---:|---|---|---|---:|
| 0 | Obtener pauta completa y confirmar JAR/WAR | — | Tabla criterio/peso/evidencia | 0,5 h |
| 1 | Aislar tests de RDS y hacer build verde | 0 | `mvnw clean test` y `clean package` exitosos | 2–3 h |
| 2 | Parametrizar conexión y alinear SQL/JPA | 1 | Cinco variables + esquema comprobado | 1,5–2 h |
| 3 | Crear pruebas CRUD deterministas | 1–2 | Evidencia automática de 4 verbos | 2–3 h |
| 4 | Alinear empaquetado y Dockerfile | 0–3 | Imagen local construida y API saludable | 1–2 h |
| 5 | Preparar GitHub y Jenkinsfile de 5 etapas | 1–4 | Pipeline verde desde repositorio | 2–3 h |
| 6 | Preparar RDS y EC2, desplegar | 2, 4–5 | API en EC2 conectada a RDS | 2–4 h |
| 7 | Ejecutar CRUD end-to-end y recopilar evidencia | 6 | Secuencia reproducible completa | 1–2 h |
| 8 | Documentar ciclo y grabar video | 5–7 | Checklist de pauta sin vacíos | 2–3 h |

Tiempo total estimado: **14–22 horas efectivas**. Reservar 2 horas adicionales de contingencia si AWS/Jenkins son nuevos para el equipo.

## Detalle de implementación mínima

### 1. Build determinista

- Crear un perfil de pruebas con base embebida o mocks, sin llamadas a RDS.
- Mantener una prueba de contexto y agregar pruebas relevantes de controlador/servicio.
- Exigir `mvnw clean test` y `mvnw clean package` verdes antes de avanzar.
- No aceptar `-DskipTests` en la rama/pipeline evaluado.

### 2. Configuración segura y portable

- Sustituir valores específicos por variables para URL/host, puerto, base, usuario y contraseña.
- Guardar secretos en Jenkins Credentials y variables del contenedor/EC2.
- Proveer una plantilla sin secretos y documentar cómo inyectarla.
- Revisar `allowPublicKeyRetrival`: además de estar posiblemente mal escrito (`Retrieval`), decidir SSL según requisitos reales de RDS.

### 3. SQL y CRUD

- Obtener el SQL faltante y comparar `users`, `id`, `first_name`, `last_name`, `email`.
- Hacer explícitos los nombres si la pauta/script usa otra convención.
- Ejecutar una secuencia repetible: POST crea → GET confirma → PUT modifica → GET confirma → DELETE elimina → GET confirma ausencia.
- Guardar requests, responses, códigos HTTP y marcas de tiempo como evidencia.

### 4. Empaquetado y Docker

- Confirmar si la pauta exige JAR; elegir una sola estrategia y alinear Maven, Docker y rutas.
- Si se conserva WAR/Tomcat, resolver el alcance de Tomcat y el context path.
- Construir después de un package exitoso y arrancar con variables RDS.
- Verificar logs, puerto 8080, `/`, CRUD y Swagger si aporta evidencia.

### 5. Jenkins de cinco etapas

Pipeline mínimo recomendado:

1. `Checkout`: clonar el commit evaluado.
2. `Test`: `./mvnw clean test` (o `.cmd` si el agente es Windows).
3. `Package`: generar el artefacto sin saltar pruebas.
4. `Build Docker`: construir y etiquetar imagen con número de build/commit.
5. `Deploy & Verify`: desplegar en EC2 y ejecutar smoke/CRUD según la pauta.

Si la pauta cuenta “Deploy” y “Verify” por separado, combinar Package con Test o ajustar exactamente a sus cinco nombres sin perder controles.

## Puntos de control obligatorios

- **PC1:** build limpio repetido dos veces sin red AWS.
- **PC2:** ningún secreto aparece en `git grep`, logs ni video.
- **PC3:** Docker local inicia desde una copia limpia del repositorio.
- **PC4:** Jenkins produce el mismo artefacto/imagen sin intervención manual.
- **PC5:** EC2 resuelve y alcanza RDS con reglas mínimas; la API responde.
- **PC6:** secuencia CRUD completa y repetible.
- **PC7:** cada criterio de pauta tiene al menos una evidencia identificada.
- **PC8:** ensayo del video dentro del tiempo permitido.

No se debe avanzar a AWS mientras PC1–PC3 estén rojos: hacerlo mezcla fallos de aplicación, red e infraestructura y consume tiempo sin evidencia útil.

## Criterios de abandono para tareas opcionales

Abandonar o posponer una tarea cuando cumpla cualquiera:

- No se vincula a un criterio/puntaje explícito.
- No desbloquea un punto de control obligatorio.
- Supera 30–45 minutos sin una evidencia concreta.
- Introduce una tecnología no solicitada (Kubernetes, Terraform, microservicios, frontend, observabilidad avanzada).
- Requiere refactor amplio cuando una corrección localizada hace estable la demostración.

Priorizar evidencia verificable sobre sofisticación técnica.

## Contingencias principales

| Contingencia | Señal temprana | Respuesta mínima |
|---|---|---|
| Pauta exige JAR | Texto explícito o ejemplo de `java -jar` | Migrar una vez antes de trabajar Docker; alinear todas las referencias |
| Docker Desktop/daemon no inicia | `docker info` sin Server | Reparar/iniciar Docker antes de PC3; usar agente Jenkins Linux en EC2 si corresponde |
| RDS no resuelve/conecta | DNS, timeout o `CommunicationsException` | Validar endpoint, estado, VPC, rutas y Security Groups; no abrir 3306 al mundo |
| Jenkins no accede a Docker | permiso al socket/daemon | Añadir el usuario Jenkins al mecanismo permitido y reiniciar el servicio controladamente |
| Credenciales aparecen en logs | salida de env/comando | Usar Credentials Binding y masking; regenerar cualquier secreto expuesto |
| SQL no coincide con JPA | tabla/columna desconocida | Alinear nombres explícitos y ejecutar el script en una base de prueba |
| Context path WAR confunde la demo | `/user` devuelve 404 | Documentar `/usuariosBuild/user` o desplegar como raíz según decisión de empaquetado |
| AWS/Jenkins consume más tiempo | PC5 no se logra en 2 h | Congelar mejoras opcionales y concentrarse en pipeline, Docker y evidencia local completa |

## Definición de terminado para 80+

El plan se considera terminado cuando: el commit evaluado compila y prueba en Jenkins; las cinco etapas quedan verdes; la imagen se despliega en EC2; la aplicación usa RDS con cinco parámetros seguros; los cuatro verbos CRUD se demuestran; y el documento/video enlaza cada evidencia con su criterio. Si falta uno de estos elementos, el margen de 80 puntos no es confiable.
