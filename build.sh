#!/bin/bash

set -e
set -u

declare -r toolchain_tarball="$(pwd)/haiku-cross.tar.xz"

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.2.1'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.1.1'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.0'

declare -r binutils_tarball='/tmp/binutils.tar.xz'
declare -r binutils_directory='/tmp/binutils-2.39'

declare -r gcc_tarball='/tmp/gcc.tar.xz'
declare -r gcc_directory='/tmp/gcc-11.2.0'

declare -r haiku_directory='/tmp/haiku'
declare -r buildtools_directory='/tmp/buildtools'

declare -r jam='/tmp/jam'

declare -r triple='x86_64-unknown-haiku'

declare -r cflags='-Wno-unused-command-line-argument -Os -s -DNDEBUG'

declare -r toolchain_directory="/tmp/unknown-unknown-haiku"

wget --no-verbose 'https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz' --output-document="${gmp_tarball}"
tar --directory="$(dirname "${gmp_directory}")" --extract --file="${gmp_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/mpfr/mpfr-4.1.1.tar.xz' --output-document="${mpfr_tarball}"
tar --directory="$(dirname "${mpfr_directory}")" --extract --file="${mpfr_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/mpc/mpc-1.3.0.tar.gz' --output-document="${mpc_tarball}"
tar --directory="$(dirname "${mpc_directory}")" --extract --file="${mpc_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/binutils/binutils-2.39.tar.xz' --output-document="${binutils_tarball}"
tar --directory="$(dirname "${binutils_directory}")" --extract --file="${binutils_tarball}"

wget --no-verbose 'https://ftp.gnu.org/gnu/gcc/gcc-11.2.0/gcc-11.2.0.tar.xz' --output-document="${gcc_tarball}"
tar --directory="$(dirname "${gcc_directory}")" --extract --file="${gcc_tarball}"

git clone --depth='1' --branch 'master' 'https://review.haiku-os.org/haiku' "${haiku_directory}"
git clone --depth='1' --branch 'master' 'https://review.haiku-os.org/buildtools' "${buildtools_directory}"

mkdir "${toolchain_directory}"

patch --input="$(realpath './gcc-11.2.0_2021_07_28.patchset')" --strip=1 --directory="${gcc_directory}"

sed -i 's/#ifdef _GLIBCXX_HAVE_SYS_SDT_H/#ifdef _GLIBCXX_HAVE_SYS_SDT_HHH/g' "${gcc_directory}/libstdc++-v3/libsupc++/unwind-cxx.h"

while read file; do
	sed -i "s/-O2/${cflags}/g" "${file}"
done <<< "$(find '/tmp' -type 'f' -regex '.*configure')"

cd "${buildtools_directory}/jam"

make all --jobs
./jam0 -sBINDIR='/tmp' install

cd "${haiku_directory}"

./configure --build-cross-tools 'x86_64' --cross-tools-source "${buildtools_directory}"

"${jam}" -q 'haiku.hpkg' 'haiku_devel.hpkg' '<build>package'

declare -r package="$(realpath './generated/objects/linux/x86_64/release/tools/package/package')"

mkdir "${triple}"

"${package}" extract -C "${triple}" './generated/objects/haiku/x86_64/packaging/packages/haiku.hpkg'
"${package}" extract -C "${triple}" './generated/objects/haiku/x86_64/packaging/packages/haiku_devel.hpkg'
find './generated/download' -name '*.hpkg' -exec "${package}" extract -C "${triple}" {} \;

mv "${triple}" "${toolchain_directory}"

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs
make install

sed -i 's/#include <stdint.h>/#include <stdint.h>\n#include <stdio.h>/g' "${toolchain_directory}/include/mpc.h"

[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"

cd "${binutils_directory}/build"
rm --force --recursive ./*

../configure \
	--target="${triple}" \
	--prefix="${toolchain_directory}" \
	--enable-gold \
	--enable-ld \
	--enable-largefile='yes') \
	--disable-libtool-lock \
	--disable-nls \
	--enable-plugins \
	--enable-64bit-bfd

make all --jobs="$(nproc)"
make install

[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"

cd "${gcc_directory}/build"
rm --force --recursive ./*

pushd "${toolchain_directory}/${triple}"

ln -s '../' 'boot/system'

pushd

../configure \
	--target="${triple}" \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--with-mpc="${toolchain_directory}" \
	--with-mpfr="${toolchain_directory}" \
	--with-system-zlib \
	--with-bugurl='https://github.com/AmanoTeam/Haiku-Cross/issues' \
	--enable-__cxa_atexit \
	--enable-cet='auto' \
	--enable-checking='release' \
	--enable-default-ssp \
	--enable-gnu-indirect-function \
	--enable-gnu-unique-object \
	--enable-libstdcxx-backtrace \
	--enable-link-serialization='1' \
	--enable-linker-build-id \
	--enable-lto \
	--enable-plugin \
	--enable-shared \
	--enable-threads='posix' \
	--enable-libssp \
	--enable-languages='c,c++' \
	--disable-multilib \
	--disable-libstdcxx-pch \
	--disable-werror \
	--disable-libgomp \
	--disable-bootstrap \
	--disable-nls \
	--disable-shared \
	--disable-libatomic \
	--without-headers \
	--enable-ld \
	--enable-gold \
	--enable-frame-pointer \
	--with-sysroot="${toolchain_directory}/${triple}" \
	--with-default-libstdcxx-abi='gcc4-compatible'

LD_LIBRARY_PATH="${toolchain_directory}/lib" PATH="${PATH}:${toolchain_directory}/bin" make CFLAGS_FOR_TARGET="${cflags} -fno-stack-protector -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/non-packaged/develop/headers -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/app -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/device -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/drivers -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/game -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/interface -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/kernel -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/locale -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/mail -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/media -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/midi -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/midi2 -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/net -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/opengl -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/storage -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/support -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/translation -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/graphics -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/input_server -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/mail_daemon -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/registrar -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/screen_saver -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/tracker -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/be_apps/Deskbar -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/be_apps/NetPositive -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/be_apps/Tracker -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/3rdparty -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/bsd -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/glibc -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/gnu -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/posix -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers" CXXFLAGS_FOR_TARGET="${cflags} -fno-stack-protector -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/non-packaged/develop/headers -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/app -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/device -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/drivers -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/game -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/interface -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/kernel -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/locale -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/mail -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/media -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/midi -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/midi2 -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/net -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/opengl -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/storage -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/support -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/translation -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/graphics -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/input_server -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/mail_daemon -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/registrar -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/screen_saver -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/add-ons/tracker -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/be_apps/Deskbar -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/be_apps/NetPositive -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/os/be_apps/Tracker -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/3rdparty -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/bsd -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/glibc -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/gnu -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers/posix -I/tmp/unknown-unknown-dragonfly/x86_64-unknown-haiku/boot/system/develop/headers" all --jobs="$(nproc)"
make install

rm --recursive "${toolchain_directory}/lib/gcc/${triple}/11.2.0/include-fixed"

tar --directory="$(dirname "${toolchain_directory}")" --create --file=- "$(basename "${toolchain_directory}")" |  xz --threads=0 --compress -9 > "${toolchain_tarball}"
