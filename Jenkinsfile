pipeline {
    agent { label 'docker' }

    options { disableConcurrentBuilds() }

    environment {
        NEXUS_REGISTRY = 'nexus:8081'
        NEXUS_DOCKER_REPOSITORY = 'gostream'
    }

    stages {
        stage('Run backend unit tests') {
            steps {
                sh '''#!/bin/bash
                    set -euo pipefail
                    # Stream the source because the Docker daemon runs in a separate container.
                    tar -cf - -C backend . | docker run --rm -i --workdir /src golang:1.25-alpine \\
                        sh -ec 'tar -xf - && go test -v ./...'
                '''
            }
        }

        stage('Build and push images to Nexus') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-docker-publisher',
                    usernameVariable: 'NEXUS_USERNAME',
                    passwordVariable: 'NEXUS_PASSWORD'
                )]) {
                    sh '''
                        set +x
                        set -eu

                        DOCKER_CONFIG=$(mktemp -d)
                        export DOCKER_CONFIG
                        trap 'rm -rf -- "$DOCKER_CONFIG"' EXIT
                        trap 'exit 1' HUP INT TERM

                        printf '%s' "$NEXUS_PASSWORD" |
                            docker login --username "$NEXUS_USERNAME" --password-stdin "$NEXUS_REGISTRY"
                        unset NEXUS_USERNAME NEXUS_PASSWORD

                        commit=$(git rev-parse HEAD)
                        for component in backend frontend; do
                            image="$NEXUS_REGISTRY/$NEXUS_DOCKER_REPOSITORY/gostream-$component:$commit"
                            printf 'Building and publishing %s\\n' "$image"
                            docker buildx build --tag "$image" \\
                                --output type=image,push=true,store=false "./$component"
                        done
                    '''
                }
            }
        }

        stage('Verify deployment agent') {
            when {
                beforeAgent true
                branch 'main'
            }
            agent { label 'deploy' }
            options { skipDefaultCheckout() }
            steps {
                sh 'hostname'
            }
        }
    }
}
