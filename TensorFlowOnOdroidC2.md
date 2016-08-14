# Installing TensorFlow on ODROID-C2

ODROID-C2 (Quad Cortex A53 2GHz) have performance advantage than
Raspberry Pi 3(Quad A53 1.2GHz)
http://www.jeffgeerling.com/blog/2016/review-odroid-c2-compared-raspberry-pi-3-and-orange-pi-plus

I tried to install with reference to
https://github.com/samjabrahams/tensorflow-on-raspberry-pi. But I can't
install... 64bit ubuntu run on ODROID-C2, there is mismatch architecture?
(aarch64 and armv7l)

Next I tried to build from source code with reference to https://github.com/samjabrahams/tensorflow-on-raspberry-pi/blob/master/GUIDE.md.
But I got some errors...

```
.Unrecognized option: -client
Error: Could not create the Java Virtual Machine.
Error: A fatal exception has occurred. Program will exit.
```

Here is memo which steps to run tensorflow v0.10.0rc only CPU build on python3
on ubuntu16.04(aarch64) with bazel(master branch newer than 0.3.1)

## References

http://cudamusing.blogspot.jp/2015/11/building-tensorflow-for-jetson-tk1.html
https://github.com/samjabrahams/tensorflow-on-raspberry-pi
https://github.com/tensorflow/tensorflow/issues/851
https://github.com/tensorflow/tensorflow/issues/254
https://github.com/bazelbuild/bazel/issues/1264
https://github.com/bazelbuild/bazel/issues/1353
https://github.com/bazelbuild/bazel/wiki/Building-with-a-custom-toolchain
https://groups.google.com/forum/#!topic/grpc-io/lEwfOdDgdZU

## Build Steps

Use virtualenv to build modules.

1. Build protobuf
2. Build grpc-java compiler
3. Build bazel with above
4. Build tensorflow with bazel

## Conditions

* I use ODORID-C2 with EMMC 32GB.
* Flash ubuntu64-16.04-minimal-odroid-c2-20160803.img.xz from
http://odroid.com/dokuwiki/doku.php?id=en:odroid_flashing_tools
* I make 2GB swap partition on EMMC and replace kernel to use zswap.
It seems to be not necessary.

First make work direcotry with virtualenv.

```shell
sudo apt-get install python3 python-virtualenv python3-virtualenv
virtualenv -p python3 --system-site-packages work
cd work
source bin/activate
```

Install some packages for build

```
# For protobuf, grpc-java, bazel
sudo apt-get install openjdk-8-jdk automake autoconf curl zip unzip libtool

# For Tensorflow
sudo apt-get install python3-numpy python3-dev swig zlib1g-dev
```

I put some patches and build script in [build_tensorflow](./build_tensorflow)
folder.

## Build protobuf

See https://github.com/bazelbuild/bazel/tree/master/third_party/protobuf

It looks me grpc-java needs v3.0.0-beta-3. But protobuf in bazel needs
v3.0.0-beta-2 ? So make two version with make static link.

```shell
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
```

## Build grpc-java compiler

See https://github.com/grpc/grpc-java/blob/v0.15.0/compiler
I built v0.15.0 with protoc v3.0.0-beta3

```shell
git clone https://github.com/grpc/grpc-java.git
cd grpc-java/
git checkout tags/v0.15.0
```

Add some patch to build on arm and as static link.

```shell
patch -p0 < ../../grpc-java.v0.15.0.patch
```

Finally build with built protoc

```shell
CXXFLAGS="-I$(pwd)/../include" LDFLAGS="-L$(pwd)/../lib" ./gradlew java_pluginExecutable -Pprotoc=$(pwd)/../bin/protoc
cd ..
```

## Build bazel

Build master(47be2a4) which is newer than 0.3.1

```
git clone https://github.com/bazelbuild/bazel.git
cd bazel
git checkout 47be2a40c601b5e4737f7a6825fad7e7f6ce0302
```

Copy protoc and grpc-java from built binary

```
cp ../protobuf/src/protoc third_party/protobuf/protoc-linux-aarch64.exe
cp ../grpc-java/compiler/build/exe/java_plugin/protoc-gen-grpc-java third_party/grpc/protoc-gen-grpc-java-0.15.0-linux-aarch64.exe
```

Add some patch to build on arm and start to compile.

```
patch -p0 < ../../bazel.47be2a4.patch
./compile.sh
```

Copy bazel into bin

```
cp output/bazel ../bin/
cd ..
```

## Build TensorFlow

Get source v0.10.0rc0(3cb3995) and patch to build farmhash from https://github.com/tensorflow/tensorflow/issues/851

```shell
git clone --recurse-submodules https://github.com/tensorflow/tensorflow
cd tensorflow
git checkout tags/v0.10.0rc0 # 3cb39956e622b322e43547cf2b6e337020643f21
patch -p0 < ../../tensorflow.v0.10.0rc0.patch
```

Configure and build

```shell
PYTHON_BIN_PATH=$(pwd)/../bin/python TF_NEED_GCP=0 TF_NEED_CUDA=0 ./configure
bazel build -c opt --local_resources 1536,0.5,1.0 --verbose_failures //tensorflow/tools/pip_package:build_pip_package
bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
cd ..
```

I didn't check without 2GB swap. But I think it works without swap.

Finally install my build package  and run example.

```shell
pip install /tmp/tensorflow_pkg/tensorflow-0.10.0rc0-py3-none-any.whl
time python lib/python3.5/site-packages/tensorflow/models/image/mnist/convolutional.py
```

## Performance comparison
I ran once and took about 110 minutes on ODROID-C2.
Then it consumes power 5 Watt during run. (Idle 2 Watt)

```
...
Step 8500 (epoch 9.89), 767.3 ms
Minibatch loss: 1.604, learning rate: 0.006302
Minibatch error: 0.0%
Validation error: 0.9%
Test error: 0.8%

real	110m40.107s
user	394m27.710s
sys	1m8.660s
```

And I ran with official package on QNAP TS-453A (Ubuntu16.04 LXC)
which had Intel N3150 (Quad 1.6GHz Atom Braswell)

```shell
$ export TF_BINARY_URL=https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-0.10.0rc0-cp35-cp35m-linux_x86_64.whl
$ pip3 install --upgrade $TF_BINARY_URL
$ time python lib/python3.5/site-packages/tensorflow/models/image/mnist/convolutional.py
...
Step 8500 (epoch 9.89), 516.9 ms
Minibatch loss: 1.605, learning rate: 0.006302
Minibatch error: 0.0%
Validation error: 0.8%
Test error: 0.9%

real	74m30.912s
user	273m53.475s
sys	1m3.437s
```

And MacBook Pro (Retina, 13-inch, Late 2013) which had Intel Corei5
(Dual 2.4GHz Hyper Threading Haswell)

```
$ export TF_BINARY_URL=https://storage.googleapis.com/tensorflow/mac/cpu/tensorflow-0.10.0rc0-py3-none-any.whl
$ pip3 install --upgrade $TF_BINARY_URL
$ python lib/python3.5/site-packages/tensorflow/models/image/mnist/convolutional.py
...
Step 8500 (epoch 9.89), 265.3 ms
Minibatch loss: 1.615, learning rate: 0.006302
Minibatch error: 1.6%
Validation error: 0.9%
Test error: 0.8%

real	38m28.159s
user	114m13.666s
sys	11m24.914s
```

Coretex-A53 is behind of X86_64. It might Cortex-A72 or A73 reach x86_64 processors.  
But it is not practical for machine learning without GPU...
