FROM golang:1.25-alpine AS build

WORKDIR /app
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o server .

FROM alpine:3.22

RUN apk add --no-cache ca-certificates wget
WORKDIR /app
COPY --from=build /app/server ./server
EXPOSE 8080
CMD ["./server"]

