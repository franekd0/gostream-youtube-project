FROM docker:29-cli AS docker-cli
FROM golang:1.25-bookworm AS go-sdk
FROM jenkins/inbound-agent:jdk21

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx
COPY --from=go-sdk /usr/local/go /usr/local/go

ENV PATH="/usr/local/go/bin:${PATH}"

RUN docker --version && docker buildx version && go version
