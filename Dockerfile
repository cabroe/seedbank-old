# Build stage
FROM golang:1.24-alpine AS builder
WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o seedbank .

# Run stage
FROM alpine:3.21
RUN apk add --no-cache ca-certificates
WORKDIR /app

COPY --from=builder /app/seedbank .

ENV PORT=9124
EXPOSE 9124

ENTRYPOINT ["./seedbank"]
