pipeline {
    agent { label 'docker' }

    stages {
        stage('Build backend image') {
            steps {
                sh 'docker build --tag "gostream-backend:$(git rev-parse HEAD)" ./backend'
            }
        }

        stage('Build frontend image') {
            steps {
                sh 'docker build --tag "gostream-frontend:$(git rev-parse HEAD)" ./frontend'
            }
        }
    }
}
