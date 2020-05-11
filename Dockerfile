# ================================
# Build image
# ================================
FROM vapor/swift:5.2 as build
WORKDIR /build

# Copy entire repo into container
COPY . .

RUN mkdir /build-bins
RUN mkdir /build-libs

# Install sqlite3
RUN apt-get update -y \
    && apt-get install -y libsqlite3-dev

# Compile with optimizations
RUN swift build \
    --enable-test-discovery \
    -c release \
    -Xswiftc -g
    
RUN git clone -b 0.39.1 --single-branch https://github.com/realm/SwiftLint SwiftLint && \
    cd SwiftLint && \
    swift build --configuration release && \
    mv `swift build --configuration release --show-bin-path`/swiftlint /build-bins && \
    cp /usr/lib/libsourcekitdInProc.so /build-libs && \
    cd /build

# ================================
# Run image
# ================================
FROM vapor/ubuntu:18.04
WORKDIR /run

# Copy build artifacts
COPY --from=build /build/.build/release /run
# Copy Swift runtime libraries
COPY --from=build /usr/lib/swift/ /usr/lib/swift/
# Copy Swift runtime libraries
COPY --from=build /build-libs /usr/lib/
# Copy resources
COPY --from=build /build/Resources ./Resources

ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0"]
