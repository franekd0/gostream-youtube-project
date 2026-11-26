FROM docker:29-cli AS docker-cli
FROM golang:1.25-bookworm AS go-sdk
RUN GOBIN=/out go install github.com/google/go-containerregistry/cmd/crane@v0.22.1

FROM ghcr.io/aquasecurity/trivy:0.76.2@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb AS trivy
FROM jenkins/inbound-agent:jdk21

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx
COPY --from=go-sdk /usr/local/go /usr/local/go
COPY --from=go-sdk /out/crane /usr/local/bin/crane
COPY --from=trivy /usr/local/bin/trivy /usr/local/bin/trivy

ENV PATH="/usr/local/go/bin:${PATH}"

RUN docker --version && docker buildx version && go version && trivy --version && crane version
