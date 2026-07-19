# Ciclo de vida DevOps aplicado a UsuariosREST

El flujo comienza en código y SQL versionables. Maven Wrapper compila y prueba con H2, por lo que el control de calidad no depende de AWS. Un `clean package` verde produce el WAR que Docker despliega como aplicación raíz en Tomcat.

Jenkins automatiza la cadena en cinco etapas: obtiene el código, compila y prueba, construye la imagen, despliega y verifica por HTTP. Los secretos RDS no viven en el repositorio: Jenkins los entrega como archivo secreto al contenedor. La aplicación usa `ddl-auto=validate`, por lo que comprueba el esquema creado por SQL sin modificarlo silenciosamente.

En operación, el contenedor recibe solicitudes CRUD y Spring Data JPA accede a RDS. JUnit, logs, códigos HTTP y conteo final constituyen evidencia. Si falla una etapa, la entrega se detiene, se limpia el contenedor de evaluación y el ciclo vuelve al código.

```text
Código + SQL → Maven test/package → Imagen Docker → Despliegue → Smoke/CRUD → Evidencia → Retroalimentación
```

