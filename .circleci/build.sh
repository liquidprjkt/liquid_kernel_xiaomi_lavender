#!/usr/bin/env bash
echo "Cloning dependencies"
git clone --depth=1 https://gitlab.com/rk134/liquid-clang clang
git clone --depth=1 https://github.com/UsiFX/AnyKernel3 AnyKernel
git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 los-4.9-64
git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 los-4.9-32
echo "Done"
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
TANGGAL=$(date +"%Y%m%d")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
export PATH=$KERNEL_DIR/clang/bin:$PATH
export KBUILD_COMPILER_STRING="$(${KERNEL_DIR}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
export ARCH=arm64
export KBUILD_BUILD_HOST=liquid-ci
export KBUILD_BUILD_USER="usif"

# Send info plox channel
sendinfo() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>• liquid° Kernel •</b>%0Astarted on: <code>liquidCI</code>%0Adevice: <b>Xiaomi Redmi Note7/7S</b>%0Abranch: <code>$(git rev-parse --abbrev-ref HEAD)</code>%0Acompiler: <code>${KBUILD_COMPILER_STRING}</code>%0Astart date: <code>$(date)</code>"
}

# Push kernel to channel
push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$priv_chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>Xiaomi Redmi Note 7/7s</b>"
}

# Fin Error
finerr() {
    curl -F document=@$(echo *.log) "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F text="Build throw an error(s)"
    exit 1
}
# Compile plox
function compile() {
    make O=out ARCH=arm64 lavender-perf_defconfig
    make -j$(nproc --all) O=out \
                    PATH=$KERNEL_DIR/clang/bin:$PATH \
                    ARCH=arm64 \
                    CC=clang \
                    AR=llvm-ar \
                    NM=llvm-nm \
                    STRIP=llvm-strip \
                    OBJCOPY=llvm-objcopy \
                    OBJDUMP=llvm-objdump \
                    OBJSIZE=llvm-size \
                    HOSTCC=clang \
                    HOSTCXX=clang++ \
                    HOSTAR=llvm-ar \
                    CLANG_TRIPLE=aarch64-linux-gnu- \
                    CROSS_COMPILE=aarch64-linux-android- \
                    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                    V=0 2>&1 | tee build.log
    if ! [ -a "$IMAGE" ]; then
        finerr
        exit 1
    fi
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
}
# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 liquid-lavender-${TANGGAL}.zip *
    cd ..
}
sticker
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
