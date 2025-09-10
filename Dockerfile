FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY target/Storage*.jar app.jar
EXPOSE 8666
ENTRYPOINT ["java", "-jar", "app.jar"]