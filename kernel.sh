#!/usr/bin/env bash

export TZ="Asia/Kolkata";
export BOT_API_KEY=605544093:AAGss2_5K8qIi97CW5sJ6XWjT1DomYQUh08
export CHAT_ID=-1001316778556
export KERNELNAME="NEXUS";
# Kernel compiling script

function check_toolchain() {

    export TC="$(find ${TOOLCHAIN}/bin -type f -name *-gcc)";

	if [[ -f "${TC}" ]]; then
		export CROSS_COMPILE="${TOOLCHAIN}/bin/$(echo ${TC} | awk -F '/' '{print $NF'} |\
sed -e 's/gcc//')";
		echo -e "Using toolchain: $(${CROSS_COMPILE}gcc --version | head -1)";
	else
		echo -e "No suitable toolchain found in ${TOOLCHAIN}";
		exit 1;
	fi
}

function transfer() {
	zipname="$(echo $1 | awk -F '/' '{print $NF}')";
	url="$(curl -# -T $1 https://transfer.sh)";
	printf '\n';
	echo -e "Download ${zipname} at ${url}";
#    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="$url" -d chat_id="-1001316778556"
}

if [[ -z ${KERNELDIR} ]]; then
    echo -e "Please set KERNELDIR";
    exit 1;
fi

export DEVICE=$1;
if [[ -z ${DEVICE} ]]; then
    export DEVICE="X00T";
fi

mkdir -p ${KERNELDIR}/aroma
mkdir -p ${KERNELDIR}/files

export SRCDIR="${KERNELDIR}";
export OUTDIR="${KERNELDIR}/out";
export ANYKERNEL="${KERNELDIR}/AnyKernel2/";
export AROMA="${KERNELDIR}/aroma/";
export ARCH="arm64";
export SUBARCH="arm64";
export KBUILD_BUILD_USER="psdashing"
export KBUILD_BUILD_HOST="Jarvis"
export TOOLCHAIN="$HOME/toolchains/gcc";
export DEFCONFIG="X00T_defconfig";
export ZIP_DIR="${HOME}/${KERNELDIR}/files";
export IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image.gz-dtb";

export CROSS_COMPILE_ARM32="$HOME/toolchains/gcc32/bin/arm-linux-gnueabi-";


export CC=$HOME/toolchains/dragontc/bin/clang
export CLANG_VERSION=$($CC --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
export CLANG_TRIPLE=aarch64-linux-gnu-
export CLANG_LD_PATH=$HOME/toolchains/dragontc
export LLVM_DIS=$HOME/clang/bin/llvm-dis

export MAKE_TYPE="Treble-Pie"

if [[ -z "${JOBS}" ]]; then
    export JOBS="$(nproc --all)";
#    export JOBS=64;
fi

export MAKE="make O=out";

check_toolchain;

export TCVERSION1="$(${CROSS_COMPILE}gcc --version | head -1 |\
awk -F '(' '{print $2}' | awk '{print tolower($1)}')"
export TCVERSION2="$(${CROSS_COMPILE}gcc --version | head -1 |\
awk -F ')' '{print $2}' | awk '{print tolower($1)}')"
export ZIPNAME="${KERNELNAME}-CAF-${DEVICE}-TREBLE-$(date +%Y%m%d-%H%M).zip"
export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"
[ ! -d "${ANYKERNEL}" ] && git clone --depth=1 https://github.com/KudProject/AnyKernel2 -b kud/X00T ${ANYKERNEL}

[ ! -d "${ZIP_DIR}" ] && mkdir -pv ${ZIP_DIR}
[ ! -d "${OUTDIR}" ] && mkdir -pv ${OUTDIR}

cd "${SRCDIR}";
rm -fv ${IMAGE};

MAKE_STATEMENT=make
 
# Menuconfig configuration
# ================
# If -no-menuconfig flag is present we will skip the kernel configuration step.
# Make operation will use santoni_defconfig directly.
if [[ "$*" == *"-no-menuconfig"* ]]
then
  NO_MENUCONFIG=1
  MAKE_STATEMENT="$MAKE_STATEMENT KCONFIG_CONFIG=./arch/arm64/configs/X00T_defconfig"
fi

if [[ "$@" =~ "mrproper" ]]; then
    ${MAKE} mrproper
fi

if [[ "$@" =~ "clean" ]]; then
    ${MAKE} clean
fi

# curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="CAADBQADFgADx8M3D8ZwwIWZRWcwAg"  -d chat_id=$CHAT_ID
curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="
Build Scheduled for $KERNELNAME Kernel(Treble-Pie)" -d chat_id=$CHAT_ID
make O=out ARCH=arm64 X00T_defconfig
START=$(date +"%s");
echo -e "Using ${JOBS} threads to compile"
 
make O=out ARCH=arm64 -j4 CROSS_COMPILE=$HOME/toolchains/gcc/bin/aarch64-linux-gnu- CROSS_COMPILE_ARM32=$HOME/toolchains/gcc32/bin/arm-linux-gnueabi-
exitCode="$?";
END=$(date +"%s")
DIFF=$(($END - $START))
echo -e "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.";


if [[ ! -f "${IMAGE}" ]]; then
    echo -e "Build failed :P";
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="$KERNELNAME Kernel stopped due to an error, Please take a Look" -d chat_id="-1001316778556"
    # curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="CAADBQADHwADx8M3DyJi1SWaX6BdAg"  -d chat_id="-1001263315920"
    success=false;
    exit 1;
else
    echo -e "Build Succesful!";
    success=true;
fi

echo -e "Copying kernel image";
cp -v "${IMAGE}" "${ANYKERNEL}/";
cd -;
cd ${ANYKERNEL};
mv Image.gz-dtb zImage
zip -r9 ${FINAL_ZIP} *;
cd -;

if [ -f "$FINAL_ZIP" ];
then
echo -e "$ZIPNAME zip can be found at $FINAL_ZIP";
if [[ ${success} == true ]]; then
    echo -e "Uploading ${ZIPNAME} to https://transfer.sh/";
    transfer "${FINAL_ZIP}";
    #curl -T ${FINAL_ZIP} ftp://VvRRockStar:af5jEgUhyhgI@uploads.androidfilehost.com 
    echo -e "UPLOAD SUCCESSFUL";
    echo -e "Please push the build to AFH Manually";

message="NEXUS"
compatible="AOSP PIE - Treble ONLY"
time="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."

# curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="$(git log --pretty=format:'%h : %s' -5)" -d chat_id=$CHAT_ID
curl -F chat_id="-1001316778556" -F document=@"${ZIP_DIR}/$ZIPNAME" -F caption="$message $compatible $time" https://api.telegram.org/bot$BOT_API_KEY/sendDocument


curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="
♔♔♔♔♔♔♔BUILD-DETAILS♔♔♔♔♔♔♔
🖋️ Author     : psdashing
🛠️ Make-Type  : $MAKE_TYPE
🗒️ Buld-Type  : HOMEMADE
⌚ Build-Time : $time
🗒️ Zip-Name   : $ZIPNAME
"  -d chat_id="-1001316778556"
# curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="CAADBQADFQADIIRIEhVlVOIt6EkuAgc"  -d chat_id=$CHAT_ID
# curl -F document=@$url caption="Latest Build." https://api.telegram.org/bot$BOT_API_KEY/sendDocument -d chat_id=$CHAT_ID



rm -rf ${ZIP_DIR}/${ZIPNAME}

fi
else
echo -e "Zip Creation Failed  ";
fi
