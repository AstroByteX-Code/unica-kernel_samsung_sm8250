#!/bin/sh
set -e

KERNEL_DIR=$(pwd)
DEVICE="$1"

# Global build variables
export ARCH=arm64
mkdir -p out
export PATH=$(pwd)/clang-r547379/bin:$PATH
BUILD_VAR="-j$(nproc) -C $(pwd) O=$(pwd)/out ARCH=arm64 LLVM=1"

build_kernel() {
    echo "-----------------------------------------------"
    echo "Beginning kernel compilation..."
    echo "-----------------------------------------------"

    make $BUILD_VAR vendor/kona-perf_defconfig vendor/samsung/kona-sec-common.config vendor/samsung/${DEVICE}.config ksu.config
    make $BUILD_VAR

    # Handle DTB
    cat $(pwd)/out/arch/arm64/boot/dts/vendor/qcom/*.dtb > $(pwd)/out/arch/arm64/boot/dts/vendor/qcom/dtb

    # Handle DTBO
    cp $(pwd)/out/arch/arm64/boot/dtbo.img dtbo.img
}

build_dtb() {
    echo "-----------------------------------------------"
    echo "Building dtb..."
    echo "-----------------------------------------------"
    make $BUILD_VAR dtbs

    cat "$(pwd)/out/arch/arm64/boot/dts/vendor/qcom/kona.dtb" \
        "$(pwd)/out/arch/arm64/boot/dts/vendor/qcom/kona-v2.dtb" \
        "$(pwd)/out/arch/arm64/boot/dts/vendor/qcom/kona-v2.1.dtb" \
        > "$(pwd)/out/arch/arm64/boot/dts/dtb"
}

build_dtbo() {
    echo "-----------------------------------------------"
    echo "Building dtbo.img..."
    echo "-----------------------------------------------"
    DTBO_FILES=$(find $(pwd)/out/arch/arm64/boot/dts/samsung/$DEVICE -name "kona-sec-$DEVICE-*.dtbo")
    $(pwd)/tools/mkdtimg create $(pwd)/out/dtbo.img --page_size=4096 ${DTBO_FILES}
}

prepare_ak3() {
    echo "-----------------------------------------------"
    echo "Packaging into AnyKernel3..."
    echo "-----------------------------------------------"

    cd AnyKernel3/

    cp "$KERNEL_DIR/out/dtbo.img" dtbo.img
    cp "$KERNEL_DIR/out/arch/arm64/boot/Image" Image
    cp "$KERNEL_DIR/out/arch/arm64/boot/dts/dtb" dtb

    sed -i "s/^device\.name1=.*/device.name1=${DEVICE}/" anykernel.sh

    # Timestamp + git hash
    TIMESTAMP=$(date +"%Y%m%d-%H%M")
    GITHASH=$(git -C "$KERNEL_DIR" rev-parse --short HEAD)

    ZIP_NAME="unica-kernel-${DEVICE}-${TIMESTAMP}-${GITHASH}.zip"

    zip -r "../${ZIP_NAME}" *

    cd "$KERNEL_DIR"
    echo ">>> Kernel packaged: ${ZIP_NAME}"
}

# Run all steps
build_kernel
build_dtb
build_dtbo
prepare_ak3
