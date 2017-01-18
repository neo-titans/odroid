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
git clone https://github.com/google/protobuf.git
cd protobuf
git checkout tags/v3.0.2
./autogen.sh
./configure --prefix=$(pwd)/../
make -j4
make install
cd ..

# Build grpc-java compiler
git clone https://github.com/grpc/grpc-java.git
cd grpc-java/
git checkout tags/v1.0.3
patch -p0 < ../../grpc-java.v1.0.3.patch
CXXFLAGS="-I$(pwd)/../include" LDFLAGS="-L$(pwd)/../lib" ./gradlew java_pluginExecutable -Pprotoc=$(pwd)/../bin/protoc
cp compiler/build/exe/java_plugin/protoc-gen-grpc-java ../bin/
cd ..

# Build bazel
git clone https://github.com/bazelbuild/bazel.git
cd bazel
git checkout tags/0.4.3
patch -p0 < ../../bazel.0.4.3.patch
PROTOC=$(pwd)/../bin/protoc GRPC_JAVA_PLUGIN=$(pwd)/../bin/protoc-gen-grpc-java ./compile.sh
cp output/bazel ../bin/
cd ..

# Build TensorFlow
git clone --recurse-submodules https://github.com/tensorflow/tensorflow
cd tensorflow
git checkout origin/r0.12
PYTHON_BIN_PATH=$(pwd)/../bin/python PYTHON_LIB_PATH=$(pwd)/../lib/python3.5/site-packages TF_NEED_GCP=0 TF_NEED_CUDA=0 TF_NEED_HDFS=0 TF_NEED_OPENCL=0 ./configure
bazel build -c opt --local_resources 1536,0.5,1.0 --verbose_failures //tensorflow/tools/pip_package:build_pip_package
bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
cd ..

# Install and run
pip install /tmp/tensorflow_pkg/tensorflow-0.12.1-cp35-cp35m-linux_aarch64.whl
time python lib/python3.5/site-packages/tensorflow/models/image/mnist/convolutional.py
