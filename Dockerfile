FROM alpine AS build

RUN apk add binutils build-base git bison cmake curl cmake rpcgen openssl-dev openssl-libs-static ncurses-dev ncurses-static libtirpc-static
RUN apk add boost-dev=1.77.0-r1 --repository=https://dl-cdn.alpinelinux.org/alpine/v3.15/main/

WORKDIR /mysql

RUN <<-EOF
  curl -L -s -o- https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-boost-8.0.39.tar.gz | tar xz --strip-components=1 -C .
  rm -rf mysql-test

  echo 'MY_TARGET_LINK_OPTIONS(mysql "-static")' >> client/CMakeLists.txt
  echo 'MY_TARGET_LINK_OPTIONS(mysqladmin "-static")' >> client/CMakeLists.txt
  echo 'MY_TARGET_LINK_OPTIONS(mysqldump "-static")' >> client/CMakeLists.txt
  echo 'MY_TARGET_LINK_OPTIONS(mysqlimport "-static")' >> client/CMakeLists.txt
  echo 'MY_TARGET_LINK_OPTIONS(mysqlpump "-static")' >> client/CMakeLists.txt

  mkdir bld
  cd bld
  cmake .. \
    -DDOWNLOAD_BOOST=0 \
    -DBOOST_INCLUDE_DIR=/usr/include/ \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    -DOPENSSL_LIBRARY=/usr/lib/libssl.a \
    -DCRYPTO_LIBRARY=/usr/lib/libcrypto.a \
    -Dprotobuf_BUILD_SHARED_LIBS=off \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_MYSQLX=OFF \
    -DEVENT__DISABLE_TESTS=ON \
    -DWITH_UNIT_TESTS=OFF \
    -DCURSES_CURSES_LIBRARY=/usr/lib/libcurses.a \
    -DCURSES_NCURSES_LIBRARY=/usr/lib/libncurses.a \
    -DCURSES_FORM_LIBRARY=/usr/lib/libform.a \
    -Dpkgcfg_lib_TIRPC_tirpc=/usr/lib/libtirpc.a \
    -Dpkgcfg_lib_NCURSES_ncursesw=/usr/lib/libncursesw.a \
    -DWITH_ROUTER=OFF -DWITHOUT_SERVER=ON -DWITH_NDB=OFF \
    -DWITH_NDBCLUSTER=OFF \
    -DWITH_NDB_JAVA=OFF \
    -DCMAKE_MODULE_LINKER_FLAGS="-static"

  make -j "$(nproc)"
  make install

  find /usr/local/mysql/bin/ -type f | xargs -I{} ash -c 'strip --strip-unneeded {} || true'
EOF

FROM alpine

COPY --link --from=build /usr/local/mysql/bin /usr/local/bin
