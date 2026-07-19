pipeline {
    agent any
    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    environment {
        IMAGE_NAME = 'usuarios-rest'
        CONTAINER_NAME = 'usuarios-rest-app'
        APP_PORT = '8088'
    }
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Build and Test') {
            steps { sh 'chmod +x mvnw && ./mvnw clean package' }
            post {
                always { junit allowEmptyResults: false, testResults: 'target/surefire-reports/*.xml' }
            }
        }
        stage('Build Docker Image') {
            steps { sh 'docker build --tag "$IMAGE_NAME:$BUILD_NUMBER" --tag "$IMAGE_NAME:latest" .' }
        }
        stage('Deploy Container') {
            steps {
                withCredentials([file(credentialsId: 'usuarios-rest-rds-env', variable: 'RDS_ENV_FILE')]) {
                    sh '''
                        set +x
                        test -s "$RDS_ENV_FILE"
                        docker rm --force "$CONTAINER_NAME" >/dev/null 2>&1 || true
                        docker run --detach \
                          --name "$CONTAINER_NAME" \
                          --restart unless-stopped \
                          --env-file "$RDS_ENV_FILE" \
                          --publish "$APP_PORT:8080" \
                          "$IMAGE_NAME:$BUILD_NUMBER"
                    '''
                }
            }
        }
        stage('Smoke Test') {
            steps {
                sh '''
                    set -eu
                    ready=0
                    for attempt in $(seq 1 30); do
                      if curl --fail --silent --show-error "http://localhost:$APP_PORT/" >/dev/null && \
                         curl --fail --silent --show-error "http://localhost:$APP_PORT/user" >/dev/null; then
                        ready=1
                        break
                      fi
                      sleep 4
                    done
                    if [ "$ready" -ne 1 ]; then
                      docker logs --tail 100 "$CONTAINER_NAME" 2>&1 | grep -viE 'password|jdbc:mysql' || true
                      exit 1
                    fi
                    echo "Smoke test successful on application port $APP_PORT."
                '''
            }
        }
    }
    post {
        success { echo 'Pipeline completed: tests, image, deployment and smoke test succeeded.' }
        failure { echo 'Pipeline failed. Review the failed stage and sanitized container logs.' }
        cleanup { deleteDir() }
    }
}
