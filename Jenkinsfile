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
                    tar -cf - -C backend . | docker run --rm -i --workdir /src golang:1.27.4-alpine \\
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

        stage('Scan images before publishing to Nexus') {
            environment {
                TRIVY_DB_REPOSITORY = "${NEXUS_REGISTRY}/trivy-ghcr/aquasecurity/trivy-db:2"
                TRIVY_JAVA_DB_REPOSITORY = "${NEXUS_REGISTRY}/trivy-ghcr/aquasecurity/trivy-java-db:1"
            }
            steps {
                dir('trivy-reports') {
                    deleteDir()
                }
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

                        build_dir=$(mktemp -d)
                        trap 'rm -rf -- "$build_dir"' EXIT
                        trap 'exit 1' HUP INT TERM
                        export DOCKER_CONFIG="$build_dir/docker-config"
                        mkdir "$DOCKER_CONFIG" trivy-reports

                        printf '%s' "$NEXUS_PASSWORD" |
                            docker login --username "$NEXUS_USERNAME" --password-stdin "$NEXUS_REGISTRY"
                        unset NEXUS_USERNAME NEXUS_PASSWORD

                        for component in backend frontend; do
                            image="$NEXUS_REGISTRY/$NEXUS_DOCKER_REPOSITORY/gostream-$component:$GOSTREAM_IMAGE_TAG"
                            archive="$build_dir/$component.tar"
                            report="trivy-reports/$component.json"
                            printf 'Building and scanning %s\\n' "$image"
                            docker buildx build --tag "$image" \\
                                --output "type=docker,dest=$archive" "./$component"
                            trivy image --input "$archive" --insecure --scanners vuln \\
                                --cache-dir "$JENKINS_AGENT_WORKDIR/.trivy-cache" \\
                                --skip-version-check --disable-telemetry \\
                                --exit-code 0 --format json --output "$report.tmp"
                            mv -- "$report.tmp" "$report"
                        done

                        blocked=0
                        for report in trivy-reports/*.json; do
                            status=0
                            trivy convert --severity HIGH,CRITICAL --format table --exit-code 42 "$report" || status=$?
                            case "$status" in
                                0) ;;
                                42) blocked=1 ;;
                                *) exit "$status" ;;
                            esac
                        done
                        if [ "$blocked" -ne 0 ]; then
                            echo 'Trivy found HIGH or CRITICAL vulnerabilities. Publication blocked.' >&2
                            exit 1
                        fi

                        for component in backend frontend; do
                            image="$NEXUS_REGISTRY/$NEXUS_DOCKER_REPOSITORY/gostream-$component:$GOSTREAM_IMAGE_TAG"
                            printf 'Publishing %s\\n' "$image"
                            crane push --insecure "$build_dir/$component.tar" "$image"
                        done
                    '''
                }
                script {
                    if (env.BRANCH_NAME == 'main') {
                        stash name: 'gostream-deployment', includes: 'compose.deploy.yaml,infra/deploy/deploy.sh'
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-reports/*.json', allowEmptyArchive: true, onlyIfSuccessful: false
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
