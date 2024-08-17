#!/bin/bash

export PICO_BOARD=pico
export PICO_SDK_PATH='/pico-sdk'
export PICO_TOOLCHAIN_PATH='/usr/bin/arm-none-eabi-gcc'

cmake -B build -G Ninja .
cmake --build build
