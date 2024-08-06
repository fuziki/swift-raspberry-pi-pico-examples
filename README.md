# Swift Raspberry Pi Pico Examples

This repository contains examples for running Swift on the Raspberry Pi Pico.

## Getting Started

Follow these steps to build and upload the examples to your Raspberry Pi Pico.

### Prerequisites

- Ensure you have Docker installed on your machine.
- A Raspberry Pi Pico.

### Installation

1. Clone the repository:

    ```sh
    git clone https://github.com/fuziki/swift-raspberry-pi-pico-examples.git
    cd swift-raspberry-pi-pico-examples
    ```

1. Clone pico-sdk:

    ```sh
    make clone-pico-sdk
    ```

1. Build the Docker image:

    ```sh
    make docker-build
    ```

1. Build the `ex00-pico-w-blink` example:

    ```sh
    make build-ex00-pico-w-blink
    ```

### Uploading to Raspberry Pi Pico

1. Connect your Raspberry Pi Pico to your PC while holding the BOOTSEL button.
2. Copy the generated UF2 file to the Pico.  
   Drag and drop the `swift-app.uf2` file located in `ex00-pico-w-blink/build/` to the mounted `RPI-RP2` USB device.
