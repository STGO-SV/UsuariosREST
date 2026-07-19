FROM eclipse-temurin:17-jre-jammy

LABEL org.opencontainers.image.title="UsuariosREST" \
      org.opencontainers.image.description="API Spring Boot JAR para la evaluación EFT" \
      org.opencontainers.image.version="1.0"

WORKDIR /app

COPY target/usuariosBuild.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
