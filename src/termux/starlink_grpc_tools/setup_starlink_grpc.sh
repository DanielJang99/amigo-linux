#!/data/data/com.termux/files/usr/bin/env bash

pip show grpcio
if [ $? eq 0 ]
then 
    exit 0
fi

pkg install c-ares
pkg update
pkg upgrade 

# GRPC_PYTHON_DISABLE_LIBC_COMPATIBILITY=1 GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1 GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1 GRPC_PYTHON_BUILD_SYSTEM_CARES=1 CFLAGS+=" -U__ANDROID_API__ -D__ANDROID_API__=33 -include unistd.h" LDFLAGS+=" -llog" pip install grpcio
pkg install python-grpcio

pip install --upgrade -r requirements.txt 

mkdir -p dish_status 
mkdir -p obstruction_maps
