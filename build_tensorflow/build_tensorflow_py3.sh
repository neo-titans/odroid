#!/bin/bash
#
# Requirement:
# $ sudo apt-get install openjdk-8-jdk automake autoconf curl zip unzip libtool
# $ sudo apt-get install python3-numpy python3-dev swig zlib1g-dev
#
# Usage:
# $ bash build_tensrflow_py.sh
#

# Make virtulenv
virtualenv -p python3 --system-site-packages work3
cd work3
source bin/activate

# Build protobuf
# For grpc-java build
git clone https://github.com/google/protobuf.git
cd protobuf
git checkout tags/v3.0.0-beta-3
./autogen.sh
LDFLAGS=-static ./configure --prefix=$(pwd)/../
sed -i -e 's/LDFLAGS = -static/LDFLAGS = -all-static/' ./src/Makefile
make -j4
make install

# For bazel build
git checkout tags/v3.0.0-beta-2
./autogen.sh
LDFLAGS=-static ./configure --prefix=$(pwd)/../
sed -i -e 's/LDFLAGS = -static/LDFLAGS = -all-static/' ./src/Makefile
make -j4
cd ..

# Build grpc-java compiler
git clone https://github.com/grpc/grpc-java.git
cd grpc-java/
git checkout tags/v0.15.0
patch -p0 < ../../grpc-java.v0.15.0.patch
CXXFLAGS="-I$(pwd)/../include" LDFLAGS="-L$(pwd)/../lib" ./gradlew java_pluginExecutable -Pprotoc=$(pwd)/../bin/protoc
cd ..

# Build bazel
git clone https://github.com/bazelbuild/bazel.git
cd bazel
git checkout 47be2a40c601b5e4737f7a6825fad7e7f6ce0302

cp ../protobuf/src/protoc third_party/protobuf/protoc-linux-aarch64.exe
cp ../grpc-java/compiler/build/exe/java_plugin/protoc-gen-grpc-java third_party/grpc/protoc-gen-grpc-java-0.15.0-linux-aarch64.exe

patch -p0 < ../../bazel.47be2a4.patch
./compile.sh

cp output/bazel ../bin/
cd ..

# Build TensorFlow
git clone --recurse-submodules https://github.com/tensorflow/tensorflow
cd tensorflow
git checkout tags/v0.10.0rc0 # 3cb39956e622b322e43547cf2b6e337020643f21
patch -p0 < ../../tensorflow.v0.10.0rc0.patch

PYTHON_BIN_PATH=$(pwd)/../bin/python TF_NEED_GCP=0 TF_NEED_CUDA=0 ./configure
bazel build -c opt --local_resources 1536,0.5,1.0 --verbose_failures //tensorflow/tools/pip_package:build_pip_package
bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
cd ..

# Install and run
pip install /tmp/tensorflow_pkg/tensorflow-0.10.0rc0-py3-none-any.whl
time python lib/python3.5/site-packages/tensorflow/models/image/mnist/convolutional.py
