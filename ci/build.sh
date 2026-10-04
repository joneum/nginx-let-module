#!/bin/sh
#
# Build an nginx that carries this module and the one its test suite
# needs to print a variable.  The continuous integration workflow runs
# this, and so can you:
#
#     ci/build.sh 1.31.5 /tmp/nginx-test
#     TEST_NGINX_BINARY=/tmp/nginx-test/sbin/nginx prove -r t/
#
# usage: ci/build.sh <nginx version> <install prefix> [mode]
#
#     static    the module built into the binary (the default)
#     dynamic   the module built as a loadable object
#
# nginx and echo-nginx-module land in $CI_WORK, ./ci-work by default,
# and are reused on a second run.  A warning from this module's own
# sources fails the build.

set -eu

NGINX=${1:?nginx version missing}
PREFIX=${2:?install prefix missing}
MODE=${3:-static}

SRC=$(cd "$(dirname "$0")/.." && pwd)
WORK=${CI_WORK:-$SRC/ci-work}
DEPS=$WORK/deps
JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)

ECHO_TAG=${ECHO_TAG:-v0.65}

mkdir -p "$DEPS"

if [ ! -d "$DEPS/echo-nginx-module" ]; then
	git -c advice.detachedHead=false clone -q --depth 1 --branch "$ECHO_TAG" \
		https://github.com/openresty/echo-nginx-module.git \
		"$DEPS/echo-nginx-module"
fi

tarball=$WORK/nginx-$NGINX.tar.gz
url=https://nginx.org/download/nginx-$NGINX.tar.gz

if [ ! -s "$tarball" ]; then
	# curl is a package on FreeBSD, fetch is in the base system
	if command -v curl > /dev/null 2>&1; then
		curl -sSfL -o "$tarball" "$url"
	else
		fetch -q -o "$tarball" "$url"
	fi
fi

rm -rf "$WORK/nginx-$NGINX"
tar xzf "$tarball" -C "$WORK"

case $MODE in
static)
	how=--add-module
	;;
dynamic)
	how=--add-dynamic-module
	;;
*)
	echo "ci/build.sh: unknown mode \"$MODE\"" >&2
	exit 2
	;;
esac

cd "$WORK/nginx-$NGINX"

echo "--- configure ($MODE) ---"
./configure --prefix="$PREFIX" --with-debug --with-http_ssl_module \
	"$how=$DEPS/echo-nginx-module" "$how=$SRC" \
	> "$WORK/configure-$NGINX.log" 2>&1 ||
	{ tail -30 "$WORK/configure-$NGINX.log"; exit 1; }

echo "--- make -j$JOBS ---"
make -j"$JOBS" > "$WORK/make-$NGINX.log" 2>&1 ||
	{ tail -40 "$WORK/make-$NGINX.log"; exit 1; }

if grep -E "(ngx_http_let_module|let\.tab)\.c.*warning" "$WORK/make-$NGINX.log"; then
	echo "ci/build.sh: the compiler warned about this module, see above" >&2
	exit 1
fi

make install > /dev/null
"$PREFIX/sbin/nginx" -v
