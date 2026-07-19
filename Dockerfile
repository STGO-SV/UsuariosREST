FROM tomcat:10.1.23-jre21

LABEL org.opencontainers.image.title="UsuariosREST" \
      org.opencontainers.image.description="API Spring Boot WAR para la evaluación EFT" \
      org.opencontainers.image.version="1.0"

RUN rm -rf /usr/local/tomcat/webapps/*

COPY target/usuariosBuild.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080
