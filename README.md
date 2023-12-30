
# XPSMiner ("x17 algo")

Nvidia GPU Support Only


## How to build (Windows)

1. Install Visual Studio >= 2013 (suggest to use MSVC toolset v120)

2. Install latest Nvidia Driver

3. Download and Install CUDA 9.1 (https://developer.nvidia.com/cuda-91-download-archive)

4. Fetch the xpsminer project
```
git clone https://github.com/xrpinals/XpsMiner
cd XpsMiner/compat
git clone https://github.com/xrpinals/curl-for-windows
cd ..
``` 

5. `cd XpsMiner`

6. Open project **XpsMiner.vcxproj**

7. Start to build and wait to done


## How to build (Ubuntu 18.04)

1. Install build tools and dependencies

```
sudo apt-get update
sudo apt-get install build-essential autoconf git
sudo apt-get install libssl-dev
sudo apt-get install libcurl4-openssl-dev
```

2. Install latest Nvidia Driver


```
# Blacklist Nvidia nouveau driver

sudo bash -c "echo blacklist nouveau > /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo bash -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"

sudo update-initramfs -u
sudo reboot
```


```
sudo rm /etc/apt/sources.list.d/cuda*
sudo apt remove --autoremove nvidia-cuda-toolkit
sudo apt remove --autoremove nvidia-*

sudo apt update
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt update
sudo apt install nvidia-driver-440
```


3. Install CUDA for linux

```
sudo apt-key adv --fetch-keys  http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
sudo bash -c 'echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list'
sudo bash -c 'echo "deb http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda_learn.list'

sudo apt update
sudo apt install cuda-10-1
sudo apt install nvidia-cuda-toolkit
```

4. Add the following lines to your ~/.profile file for CUDA 10.1
```
if [ -d "/usr/local/cuda-10.1/bin/" ]; then
    export PATH=/usr/local/cuda-10.1/bin${PATH:+:${PATH}}
    export LD_LIBRARY_PATH=/usr/local/cuda-10.1/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
fi
```

5. Check NVIDIA Cuda Compiler with `nvcc --version`

6. Check NVIDIA driver with `nvidia-smi`


7. Fetch the xpsminer project

```
git clone https://github.com/xrpinals/XpsMiner
cd XpsMiner/compat
git clone https://github.com/xrpinals/curl-for-windows
cd ..
```

8. build

```
sh autogen.sh
sh configure.sh
make -j4
```


## How to Use

1. Before mining, you should make sure you have a miner with Nvidia GPU

2. Install Nvidia GPU latest Driver

3. Start to mine

* windows


```XpsMiner.exe --url=stratum+tcp://127.0.0.1:42123 ```

* linux


```./XpsMiner --url=stratum+tcp://127.0.0.1:42123```

for example:

* windows


```XpsMiner.exe --url=stratum+tcp://127.0.0.1:42123```

* linux


```./XpsMiner --url=stratum+tcp://127.0.0.1:42123```

