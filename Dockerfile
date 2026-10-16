# syntax=docker/dockerfile:1

# Build stage: base must match the runtime's Debian release (glibc).
FROM rust:1-slim-trixie AS build
WORKDIR /src
# Install the toolchain pinned in rust-toolchain.toml (cached layer)
COPY rust-toolchain.toml .
RUN rustup toolchain install
COPY . .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/src/target \
    cargo install --locked --path . --root /out \
    && mv /out/bin/* /out/app

# Runtime stage: minimal image, no shell, non-root user.
FROM gcr.io/distroless/cc-debian13:nonroot
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
