#!/usr/bin/env sh

set -ex

: "${TARGET?The TARGET environment variable must be set.}"

echo "Running tests for target: ${TARGET}, Rust version=${TRAVIS_RUST_VERSION}"
export RUST_BACKTRACE=1
export RUST_TEST_THREADS=1
export RUST_TEST_NOCAPTURE=1

# FIXME: workaround cargo breaking Travis-CI again:
# https://github.com/rust-lang/cargo/issues/5721
if [ "$TRAVIS" = "true" ]
then
    export TERM=dumb
fi

# Runs jemalloc tests when building jemalloc-sys (runs "make check"):
if [ "${NO_JEMALLOC_TESTS}" = "1" ]
then
    echo "jemalloc's tests are not run"
else
    export JEMALLOC_SYS_RUN_JEMALLOC_TESTS=1
fi

# On Windows, jemalloc-sys test binaries / test-dylib / jemalloc-ctl all
# reference POSIX-only functions (aligned_alloc, posix_memalign, dlfcn.h).
# Build everything to prove compilation, but skip workspace tests.
case "${TARGET}" in
    *windows*)
        echo "Windows: building workspace (compilation check), testing only jemallocator-global"
        cargo build --workspace --target "${TARGET}" --exclude test-dylib
        cargo test --target "${TARGET}" --manifest-path jemallocator-global/Cargo.toml
        exit 0
        ;;
    *)
        ;;
esac

cargo build --workspace --target "${TARGET}"
cargo test --workspace --target "${TARGET}"
cargo test --workspace --target "${TARGET}" --features profiling
cargo test --workspace --target "${TARGET}" --features debug
cargo test --workspace --target "${TARGET}" --features stats
cargo test --workspace --target "${TARGET}" --features 'debug profiling'

cargo test --workspace --target "${TARGET}" \
    --features override_allocator_on_supported_platforms
cargo test --workspace --target "${TARGET}" --no-default-features
cargo test --workspace --target "${TARGET}" --no-default-features \
    --features background_threads_runtime_support

if [ "${NOBGT}" = "1" ]
then
    echo "enabling background threads by default at run-time is not tested"
else
    cargo test --workspace --target "${TARGET}" --features background_threads
fi

cargo test --workspace --target "${TARGET}" --release
cargo test --target "${TARGET}" --manifest-path jemalloc-sys/Cargo.toml
cargo test --target "${TARGET}" \
             --manifest-path jemalloc-sys/Cargo.toml \
             --features override_allocator_on_supported_platforms

# FIXME: jemalloc-ctl fails in the following targets
case "${TARGET}" in
    "i686-unknown-linux-musl") ;;
    "x86_64-unknown-linux-musl") ;;
    *)

        cargo test --target "${TARGET}" \
                   --manifest-path jemalloc-ctl/Cargo.toml \
                   --no-default-features
        ;;
esac

cargo test --target "${TARGET}" \
             --manifest-path jemallocator-global/Cargo.toml
cargo test --target "${TARGET}" \
             --manifest-path jemallocator-global/Cargo.toml \
             --features force_global_jemalloc

# Test that overriding works in dylibs.
case "$TARGET" in
    "i686-unknown-linux-musl") ;;
    "x86_64-unknown-linux-musl") ;;
    *windows*) ;;
    *)
        cargo run --target "${TARGET}" \
            -p test-dylib \
            --features override_allocator_on_supported_platforms
        ;;
esac
