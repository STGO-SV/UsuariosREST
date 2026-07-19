# Bloque 5 — Preparación de EC2 y Jenkins

Fecha: 19 de julio de 2026.

## Estado

**IMPLEMENTADO SIN VERIFICACIÓN REAL EN EC2/JENKINS.** Se prepararon y validaron sintácticamente el pipeline y los scripts, pero no se creó ni modificó infraestructura AWS y no había una instancia Jenkins autorizada para ejecutar el despliegue.

## Pipeline declarativo

El `Jenkinsfile` contiene exactamente cinco etapas:

1. Checkout.
2. Build and Test.
3. Build Docker Image.
4. Deploy Container.
5. Smoke Test.

El agente esperado es Linux con Java 21, Docker y acceso a RDS. El build usa `./mvnw clean package` y publica JUnit. El despliegue usa el puerto 8088 para no competir con Jenkins en 8080 y reemplaza sólo `usuarios-rest-app`. Al finalizar se limpia el workspace; el contenedor desplegado permanece activo.

La credencial requerida es un archivo secreto de Jenkins con ID `usuarios-rest-rds-env`, con las cinco claves `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME` y `DB_PASSWORD`. El pipeline desactiva el eco antes de usarlo y no contiene valores reales.

## Scripts preparados

- `bootstrap-ec2-jenkins.sh`: instala Java 21, Docker Engine y Jenkins LTS desde repositorios oficiales en Ubuntu; habilita servicios y concede acceso de Docker al usuario Jenkins.
- `verify-ec2-jenkins.sh`: comprueba comandos, servicios, socket/grupo Docker, puertos, disco, memoria y versiones.
- `deploy-on-ec2.sh`: alternativa manual que compila con pruebas, construye, despliega en 8088 y realiza smoke test.

Los tres archivos pasaron `bash -n` dentro de contenedores Linux efímeros. Cada validación montó únicamente el script correspondiente en sólo lectura; `.env.rds` no fue montado.

## Evidencia aún necesaria

- EC2 activa y sistema operativo compatible.
- Jenkins y Docker activos.
- Credencial creada sin mostrar su contenido.
- Las cinco etapas verdes desde SCM.
- Contenedor en 8088 y CRUD contra RDS desde EC2.
