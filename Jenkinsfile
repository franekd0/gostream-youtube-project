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
                    coverage_report=$(mktemp ./go-coverage.XXXXXX)
                    trap 'rm -f -- "$coverage_report"' EXIT

                    # Stream the source because the Docker daemon runs in a separate container.
                    tar -cf - -C backend . | docker run --rm -i --workdir /src golang:1.25-alpine \\
                        sh -ec 'tar -xf - && go test -v -coverprofile=coverage.out ./... >&2 && cat coverage.out' \\
                        > "$coverage_report"
                    test -s "$coverage_report"
                    mv -f -- "$coverage_report" go-coverage.out
                '''
            }
        }

        stage('Analyze with SonarQube') {
            when { branch 'main' }
            steps {
                script {
                    def scannerHome = tool 'SonarScanner CLI'
                    withSonarQubeEnv('SonarQube') {
                        withEnv(["SONAR_SCANNER_HOME=${scannerHome}"]) {
                            sh '''
                                "$SONAR_SCANNER_HOME/bin/sonar-scanner" \\
                                    -Dsonar.projectKey=gostream \\
                                    -Dsonar.sources=backend,frontend/src \\
                                    -Dsonar.tests=backend \\
                                    '-Dsonar.test.inclusions=backend/**/*_test.go' \\
                                    -Dsonar.go.coverage.reportPaths=go-coverage.out
                            '''
                        }
                    }
                }
            }
        }

        stage('Build and push images to Nexus') {
            steps {
                script {
                    env.GOSTREAM_IMAGE_TAG = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                }
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

                        for component in backend frontend; do
                            image="$NEXUS_REGISTRY/$NEXUS_DOCKER_REPOSITORY/gostream-$component:$GOSTREAM_IMAGE_TAG"
                            printf 'Building and publishing %s\\n' "$image"
                            docker buildx build --tag "$image" \\
                                --output type=image,push=true,store=false "./$component"
                        done
                    '''
                }
                script {
                    if (env.BRANCH_NAME == 'main') {
                        stash name: 'gostream-deployment', includes: 'compose.deploy.yaml,infra/deploy/deploy.sh'
                    }
                }
            }
        }

        stage('Deploy GoStream on pis07') {
            when {
                beforeAgent true
                branch 'main'
            }
            agent { label 'deploy' }
            options { skipDefaultCheckout() }
            environment {
                DOCKER_CONFIG = '/home/jenkins/agent/.nexus-docker'
            }
            steps {
                unstash 'gostream-deployment'
                sh 'sh infra/deploy/deploy.sh "$GOSTREAM_IMAGE_TAG"'
            }
        }
    }
}
