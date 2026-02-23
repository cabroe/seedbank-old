# Build stage
FROM golang:1.24-alpine AS builder
WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o neural-brain .

# Run stage
FROM alpine:3.21
RUN apk add --no-cache ca-certificates
WORKDIR /app

COPY --from=builder /app/neural-brain .

ENV PORT=9124
EXPOSE 9124

ENTRYPOINT ["./neural-brain"]
