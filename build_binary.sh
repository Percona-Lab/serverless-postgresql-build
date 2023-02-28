#!/bin/bash
# Bail out on errors, be strict
# cd
# git clone --recursive https://github.com/neondatabase/neon.git
# cd neon
# mkdir WORKDIR 
# bash -x build_binary.sh ${PWD}/WORKDIR/

PGVERSION="14"
VERSION="1.0.0"

set -ue

# Examine parameters
TARGET="$(uname -m)"
TARGET_CFLAGS=''
#
# Some programs that may be overriden
TAR=${TAR:-tar}

# Check if we have a functional getopt(1)
if ! getopt --test
then
    go_out="$(getopt --options="i" --longoptions=i686 \
        --name="$(basename "$0")" -- "$@")"
    test $? -eq 0 || exit 1
    eval set -- $go_out
fi

for arg
do
    case "$arg" in
    -- ) shift; break;;
    -i | --i686 )
        shift
        TARGET="i686"
        TARGET_CFLAGS="-m32 -march=i686"
        ;;
    esac
done

if [ -f /etc/debian_version ]; then
    GLIBC_VER_TMP="$(dpkg-query -W -f='${Version}' libc6 | awk -F'-' '{print $1}')"
else
    GLIBC_VER_TMP="$(rpm glibc -qa --qf %{VERSION})"
fi
export GLIBC_VER=".glibc${GLIBC_VER_TMP}"

# Working directory
if test "$#" -eq 0
then
    WORKDIR="$(readlink -f $(dirname $0)/../../../)"

    # Check that the current directory is not empty
    if test "x$(echo *)" != "x*"
    then
        echo >&2 \
            "Current directory is not empty. Use $0 . to force build in ."
        exit 1
    fi

    WORKDIR_ABS="$(cd "$WORKDIR"; pwd)"

elif test "$#" -eq 1
then
    WORKDIR="$1"

    # Check that the provided directory exists and is a directory
    if ! test -d "$WORKDIR"
    then
        echo >&2 "$WORKDIR is not a directory"
        exit 1
    fi

    WORKDIR_ABS="$(cd "$WORKDIR"; pwd)"

else
    echo >&2 "Usage: $0 [target dir]"
    exit 1

fi
SOURCEDIR="$(cd $(dirname "$0"); pwd)"
echo $SOURCEDIR

# Compilation flags
export CC=${CC:-gcc}
export CXX=${CXX:-g++}
export CFLAGS=${CFLAGS:-}
export CXXFLAGS=${CXXFLAGS:-}
export MAKE_JFLAG=-j4

# Create a temporary working directory
BASEINSTALLDIR="$(cd "$WORKDIR" && TMPDIR="$WORKDIR_ABS" mktemp -d neondatabase-neon.XXXXXX)"
INSTALLDIR="$WORKDIR_ABS/$BASEINSTALLDIR/neondatabase-neon-PG$PGVERSION-$VERSION-$(uname -s)-$(uname -m)$GLIBC_VER"   # Make it absolute

mkdir "$INSTALLDIR"

# Build
(
    cd "$WORKDIR"

    # Build proper
    (
        cd $SOURCEDIR

        # Install the f1iles
        sed -i 's/BUILD_TYPE ?= debug/BUILD_TYPE ?= release/' Makefile
        make -j 4
        mkdir -p $INSTALLDIR/target/release
	for file in $(find target/release -maxdepth 1 -type f -executable); do
		cp $file $INSTALLDIR/target/release/
	done
        mkdir -p $INSTALLDIR/pg_install/v$PGVERSION/bin
        for file in $(find pg_install/v14/bin -maxdepth 1 -type f -executable); do
                cp $file $INSTALLDIR/pg_install/v$PGVERSION/bin
        done
        mkdir -p $INSTALLDIR/pg_install/build
        cp -r pg_install/v$PGVERSION $INSTALLDIR/pg_install
	cp -r pg_install/build/*v$PGVERSION $INSTALLDIR/pg_install/build
    )
    exit_value=$?

    if test "x$exit_value" = "x0"
    then

        cd "$INSTALLDIR"
        LIBLIST="linux-vdso.so libgcc_s.so librt.so libpthread.so libm.so libdl.so libcrypto.so libssl.so libpq.so"
        DIRLIST="target/release pg_install/v$PGVERSION/bin"

        LIBPATH=""

        function gather_libs {
            local elf_path=$1
            for lib in $LIBLIST; do
                for elf in $(find $elf_path -maxdepth 1 -exec file {} \; | grep 'ELF ' | cut -d':' -f1); do
                    IFS=$'\n'
                    for libfromelf in $(ldd $elf | grep $lib | awk '{print $3}'); do
                        if [ ! -f lib/private/$(basename $(readlink -f $libfromelf)) ] && [ ! -L lib/$(basename $(readlink -f $libfromelf)) ]; then
                            echo "Copying lib $(basename $(readlink -f $libfromelf))"
                            cp $(readlink -f $libfromelf) lib/private

                            echo "Symlinking lib $(basename $(readlink -f $libfromelf))"
                            cd lib
                            ln -s private/$(basename $(readlink -f $libfromelf)) $(basename $(readlink -f $libfromelf))
                            cd -

                            LIBPATH+=" $(echo $libfromelf | grep -v $(pwd))"
                        fi
                    done
                    unset IFS
                done
            done
        }

        function set_runpath {
            # Set proper runpath for bins but check before doing anything
            local elf_path=$1
            local r_path=$2
            for elf in $(find $elf_path -maxdepth 1 -exec file {} \; | grep 'ELF ' | cut -d':' -f1); do
                echo "Checking LD_RUNPATH for $elf"
                if [ -z $(patchelf --print-rpath $elf) ]; then
                    echo "Changing RUNPATH for $elf"
                    patchelf --set-rpath $r_path $elf
                fi
            done
        }

        function replace_libs {
            local elf_path=$1
            for libpath_sorted in $LIBPATH; do
                for elf in $(find $elf_path -maxdepth 1 -exec file {} \; | grep 'ELF ' | cut -d':' -f1); do
                    LDD=$(ldd $elf | grep $libpath_sorted|head -n1|awk '{print $1}')
                    if [[ ! -z $LDD  ]]; then
                        echo "Replacing lib $(basename $(readlink -f $libpath_sorted)) for $elf"
                        patchelf --replace-needed $LDD $(basename $(readlink -f $libpath_sorted)) $elf
                    fi
                done
            done
        }
        function check_libs {
            local elf_path=$1
            for elf in $(find $elf_path -maxdepth 1 -exec file {} \; | grep 'ELF ' | cut -d':' -f1); do
                if ! ldd $elf; then
                    exit 1
                fi
            done
        }

        if [ ! -d lib/private ]; then
            mkdir -p lib/private
        fi
        # Gather libs
        for DIR in $DIRLIST; do
            gather_libs $DIR
        done

        # Set proper runpath
        set_runpath target/release '$ORIGIN/../../lib/private/'
        set_runpath pg_install/v$PGVERSION/bin '$ORIGIN/../../../lib/private/'
        set_runpath lib/private '$ORIGIN'

        # Replace libs
        for DIR in $DIRLIST; do
            replace_libs $DIR
        done

        # Make final check in order to determine any error after linkage
        for DIR in $DIRLIST; do
            check_libs $DIR
        done

        cd "$WORKDIR"

        $TAR czf "neondatabase-neon-PG$PGVERSION-$VERSION-$(uname -s)-$(uname -m)$GLIBC_VER.tar.gz" \
            --owner=0 --group=0 -C "$INSTALLDIR/../" \
            "neondatabase-neon-PG$PGVERSION-$VERSION-$(uname -s)-$(uname -m)$GLIBC_VER"
    fi

    # Clean up build dir
    rm -rf "neondatabase-neon-PG$PGVERSION-$VERSION-$(uname -s)-$(uname -m)$GLIBC_VER"

    exit $exit_value

)
exit_value=$?

# Clean up
rm -rf "$WORKDIR_ABS/$BASEINSTALLDIR"

exit $exit_value
