FROM timescale/timescaledb:latest-pg14
#Forked from https://github.com/Twenty7/postgresql-timescaledb-postgis-docker
LABEL maintainer="Ralim<ralim@ralimtek.com>"

ENV POSTGIS_VERSION 3.2.1
ENV POSTGIS_SHA256 1E9CC4C4F390E4C3BE4F5C125A72F39DFA847412332952429952CBD731AC9BA3

ENV POSTGIS2_GEOS_VERSION tags/3.10.2

RUN set -eux \
    \
    && apk add --no-cache --virtual .fetch-deps \
    ca-certificates \
    openssl \
    tar \
    \
    && wget -O postgis.tar.gz "https://github.com/postgis/postgis/archive/$POSTGIS_VERSION.tar.gz" \
    && echo "$POSTGIS_SHA256 *postgis.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/postgis \
    && tar \
    --extract \
    --file postgis.tar.gz \
    --directory /usr/src/postgis \
    --strip-components 1 \
    && rm postgis.tar.gz \
    \
    && apk add --no-cache --virtual .build-deps \
    autoconf \
    automake \
    clang-dev \
    file \
    g++ \
    gcc \
    gdal-dev \
    gettext-dev \
    json-c-dev \
    libtool \
    libxml2-dev \
    llvm11-dev \
    llvm12-dev \
    make \
    pcre-dev \
    perl \
    proj-dev \
    protobuf-c-dev \
    \
    # GEOS setup
    && if   [ $(printf %.1s "$POSTGIS_VERSION") == 3 ]; then \
    apk add --no-cache --virtual .build-deps-geos geos-dev cunit-dev ; \
    elif [ $(printf %.1s "$POSTGIS_VERSION") == 2 ]; then \
    apk add --no-cache --virtual .build-deps-geos cmake git ; \
    cd /usr/src ; \
    git clone https://github.com/libgeos/geos.git ; \
    cd geos ; \
    git checkout ${POSTGIS2_GEOS_VERSION} -b geos_build ; \
    mkdir cmake-build ; \
    cd cmake-build ; \
    cmake -DCMAKE_BUILD_TYPE=Release .. ; \
    make -j$(nproc) ; \
    make check ; \
    make install ; \
    cd / ; \
    rm -fr /usr/src/geos ; \
    else \
    echo ".... unknown PosGIS ...." ; \
    fi \
    \
    # build PostGIS
    \
    && cd /usr/src/postgis \
    && gettextize \
    && ./autogen.sh \
    && ./configure \
    --with-pcredir="$(pcre-config --prefix)" \
    && make -j$(nproc) \
    && make install \
    \
    # regression check
    # && mkdir /tempdb \
    # && chown -R postgres:postgres /tempdb \
    # && su postgres -c 'pg_ctl -D /tempdb init' \
    # && su postgres -c 'pg_ctl -D /tempdb start' \
    # && cd regress \
    # && make -j$(nproc) check RUNTESTFLAGS=--extension   PGUSER=postgres \
    # #&& make -j$(nproc) check RUNTESTFLAGS=--dumprestore PGUSER=postgres \
    # #&& make garden                                      PGUSER=postgres \
    # && su postgres -c 'pg_ctl -D /tempdb --mode=immediate stop' \
    # && rm -rf /tempdb \
    # && rm -rf /tmp/pgis_reg \
    # add .postgis-rundeps
    && apk add --no-cache --virtual .postgis-rundeps \
    gdal \
    json-c \
    libstdc++ \
    pcre \
    proj \
    protobuf-c \
    # Geos setup
    && if [ $(printf %.1s "$POSTGIS_VERSION") == 3 ]; then \
    apk add --no-cache --virtual .postgis-rundeps-geos geos ; \
    fi \
    # clean
    && cd / \
    && rm -rf /usr/src/postgis \
    && apk del .fetch-deps .build-deps .build-deps-geos

COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/10_postgis.sh
COPY ./update-postgis.sh /usr/local/bin
