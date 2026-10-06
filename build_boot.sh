#!/bin/sh
set -e

KERNEL_DIR=$(pwd)
DEVICE="$1"
TOOLCHAIN_DIR="$2"

# Global build variables
export ARCH=arm64
OUT_DIR="$KERNEL_DIR/out"
mkdir -p "$OUT_DIR"
export PATH=$(pwd)/clang-r547379/bin:$PATH
BUILD_VAR="-j$(nproc) -C $KERNEL_DIR O=$OUT_DIR ARCH=arm64 LLVM=1"

build_kernel() {
    echo "-----------------------------------------------"
    echo "Beginning kernel compilation..."
    echo "-----------------------------------------------"

    make $BUILD_VAR vendor/kona-perf_defconfig \
        vendor/samsung/kona-sec-common.config \
        vendor/samsung/${DEVICE}.config \
        ksu.config localversion.config

    make $BUILD_VAR
}

git submodule update --init --recursive

build_dtb() {
    echo "-----------------------------------------------"
    echo "Building dtb..."
    echo "-----------------------------------------------"
    make $BUILD_VAR dtbs

    mkdir -p "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom"
    cat "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/kona.dtb" \
        "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/kona-v2.dtb" \
        "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/kona-v2.1.dtb" \
        > "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/dtb"
}

build_dtbo() {
    echo "-----------------------------------------------"
    echo "Building dtbo.img..."
    echo "-----------------------------------------------"
    DTBO_FILES=$(find "$OUT_DIR/arch/arm64/boot/dts/samsung/$DEVICE" -name "kona-sec-$DEVICE-*.dtbo")
    chmod +x "$KERNEL_DIR/tools/mkdtimg"
    "$KERNEL_DIR/tools/mkdtimg" create "$OUT_DIR/dtbo.img" --page_size=4096 ${DTBO_FILES}
}

build_boot() {
    echo "-----------------------------------------------"
    echo "Building boot.img..."
    echo "-----------------------------------------------"
    MKBOOTIMG="$KERNEL_DIR/mkbootimg/mkbootimg.py"
    OUT_KERNEL="$OUT_DIR/arch/arm64/boot/Image"
    DTB_OUT="$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/dtb"

    if [ ! -f "$OUT_KERNEL" ]; then
        echo "Error: Kernel Image not built."
        exit 1
    fi
    if [ ! -f "$DTB_OUT" ]; then
        echo "Error: DTB not built."
        exit 1
    fi

    CMDLINE="console=null androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 printk.devkmsg=on firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7"
    BASE="0x00000000"
    KOFFSET="0x00008000"
    ROFFSET="0x02000000"
    SECOFFSET="0x00000000"
    DTBOFFSET="0x01f00000"
    TAGSOFFSET="0x01e00000"
    BOARD="SRPUB26A012"
    PAGESZ="4096"
    RAMDISK="$KERNEL_DIR/boot/ramdisk"
    MONTH="$(date +%Y-%m)"

    python3 "$MKBOOTIMG" \
        --header_version 2 \
        --kernel "$OUT_KERNEL" \
        --ramdisk "$RAMDISK" \
        --dtb "$DTB_OUT" \
        --cmdline "$CMDLINE" \
        --base "$BASE" \
        --kernel_offset "$KOFFSET" \
        --ramdisk_offset "$ROFFSET" \
        --second_offset "$SECOFFSET" \
        --dtb_offset "$DTBOFFSET" \
        --tags_offset "$TAGSOFFSET" \
        --board "$BOARD" \
        --pagesize "$PAGESZ" \
        --os_version 16.0.0 \
        --os_patch_level "$MONTH" \
        --output boot.img
}

# Run all steps
build_kernel
build_dtb
build_dtbo
build_boot
