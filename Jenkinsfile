pipeline {
    agent { label 'docker' }

    environment {
        NEXUS_REGISTRY = 'nexus:8081'
        NEXUS_DOCKER_REPOSITORY = 'gostream'
    }

    stages {
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
    }
}
