FROM swiftlang/swift:nightly-main-jammy

COPY Makefile .

RUN apt-get update && apt-get install -y \
    gcc \
    cmake \
    gcc-arm-none-eabi \
    libnewlib-arm-none-eabi \
    build-essential \
    git \
    ninja-build \
    python3 \
    && apt-get clean

# RUN git clone --depth 1 -b 1.5.1 https://github.com/raspberrypi/pico-sdk.git \
#     && cd pico-sdk \
#     && git submodule update --init

# RUN git clone -b master https://github.com/raspberrypi/pico-examples.git

RUN make clone-pico-sdk

ENV PICO_SDK_PATH=/pico-sdk
ENV PICO_TOOLCHAIN_PATH=/usr/bin/arm-none-eabi-gcc

WORKDIR /workspace

ENTRYPOINT ["/bin/bash"]
