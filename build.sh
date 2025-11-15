#!/bin/bash

function compile() 
{
rm -rf AnyKernel
source ~/.bashrc && source ~/.profile
export LC_ALL=C && export USE_CCACHE=1
export ARCH=arm64
export KBUILD_BUILD_HOST=linux
export KBUILD_BUILD_USER="anonim"
}

function KERNEL_COMPILE() {
	if [ "$1" == "install" ]; then
		# Download required package
		sudo apt update -y && sudo apt upgrade -y && sudo apt install nano bc ccache bison ca-certificates curl flex gcc git libc6-dev libssl-dev openssl python-is-python3 ssh wget zip zstd sudo make clang gcc-arm-linux-gnueabi software-properties-common build-essential libarchive-tools gcc-aarch64-linux-gnu -y && sudo apt install build-essential -y && sudo apt install libssl-dev libffi-dev libncurses5-dev zlib1g zlib1g-dev libreadline-dev libbz2-dev libsqlite3-dev make gcc -y && sudo apt install pigz -y && sudo apt install python2 -y && sudo apt install python3 -y && sudo apt install cpio -y && sudo apt install lld -y && sudo apt install llvm -y && sudo apt-get install g++-aarch64-linux-gnu -y && sudo apt install libelf-dev -y && sudo apt install binwalk
	fi

if [ ! -d "clang" ]; then
    wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r498229b.tar.gz -O "aosp-clang.tar.gz"
    mkdir clang && tar -xf aosp-clang.tar.gz -C clang && rm -rf aosp-clang.tar.gz
fi

[ -d "out" ] && rm -rf out || mkdir -p out

make O=out ARCH=arm64 RMX2020_defconfig

PATH="${PWD}/clang/bin:${PATH}" \
make -j$(nproc --all) O=out \
                      CC="clang" \
                      LLVM=1 \
                      CONFIG_NO_ERROR_ON_MISMATCH=y
}

function extract_image_gz_dtb()
{
    echo "[Image.gz-dtb extractor] Getting DTB offset from Image.gz-dtb..."
    OFFSET=$(binwalk "Image.gz-dtb" | grep "Flattened device tree" | awk '{print $1}')
    if [ -z "$OFFSET" ]; then
      echo "[Image.gz-dtb extractor] Could not find DTB in Image.gz-dtb"
      exit 1
    fi
    echo "[Image.gz-dtb extractor] Found DTB offset at $OFFSET"

    echo "[Image.gz-dtb extractor] Extracting kernel (gzip part)..."
    dd if="Image.gz-dtb" of="Image.gz" bs=1 count="$OFFSET" status=none

    echo "[Image.gz-dtb extractor] Extracting DTB..."
    dd if="Image.gz-dtb" of="dtb" bs=1 skip="$OFFSET" status=none

    echo "[Image.gz-dtb extractor] Decompressing kernel gzip to raw Image..."
    gzip -cd "Image.gz" > "Image"

    echo "[Image.gz-dtb extractor] Done"
    rm -rf Image.gz Image.gz-dtb
}

function install_kernel_patch()
{
    mkdir KernelPatchTools
    cd KernelPatchTools
    curl -L -O https://github.com/bmax121/KernelPatch/releases/download/0.12.2/kptools-linux
    curl -L -O https://github.com/bmax121/KernelPatch/releases/download/0.12.2/kpimg-android
    chmod +x ./kptools-linux
    if [ -e "./kpimg-android" ]; then
        mv ./kpimg-android ./kpimg-android
    fi
    cd ..
}

function kernel_patching()
{
    ../KernelPatchTools/kptools-linux -p -s "RainyPatch@111" -i ./Image -k ../KernelPatchTools/kpimg -o ./oImage
    rm -rf ./Image
    mv ./oImage ./Image
}

function KERNEL_RESULT() {
	# Create anykernel
	rm -rf AnyKernel
	git clone https://github.com/muhammmadnantaa-hub/AnyKernel.git AnyKernel

	# Cop
        cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
         if [ ! -d "KernelPatchTools" ]; then
        echo "KernelPatch tools does not exist. Installing"
        install_kernel_patch
        echo "KernelPatch tools installed!"
         fi

	# Created zip kernel
	cd AnyKernel
        extract_image_gz_dtb
        kernel_patching
        gzip -c Image > Image.gz
        cat Image.gz dtb > Image.gz-dtb
        rm -rf Image Image.gz dtb
        zip -r9 ksu-next.zip *

	# Upload kernel
	RESPONSE=$(curl -s -F "file=@ksu-next.zip" "https://store1.gofile.io/contents/uploadfile" \
	|| curl -s -F "file=@ksu-next.zip" "https://store2.gofile.io/contents/uploadfile")
	DOWNLOAD_LINK=$(echo "$RESPONSE" | grep -oP '"downloadPage":"\K[^"]+')
	echo -e "\nDownload link: $DOWNLOAD_LINK"
}

# Run functions
KERNEL_COMPILE "$1"
KERNEL_RESULT
echo -e "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !\n"
