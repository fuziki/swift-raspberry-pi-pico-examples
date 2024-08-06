clone-pico-sdk:
	git clone -b master https://github.com/raspberrypi/pico-sdk.git \
		&& cd pico-sdk \
		&& git submodule update --init

patch:
	git submodule update --init
	cd pico-sdk && git submodule update --init
	patch pico-sdk/src/rp2_common/pico_cyw43_arch/include/pico/cyw43_arch.h < patchs/cyw43_arch.patch
	patch pico-sdk/src/rp2_common/pico_platform/include/pico/platform.h < patchs/platform.patch

docker-build:
	docker build --platform linux/amd64 -t swift-build-env-amd64 .

docker-run:
	docker run -it --rm -v $(shell pwd):/workspace swift-build-env-amd64 /workspace/build.sh

project:
	xcrun --sdk macosx swift run --package-path tools xcodegen --spec project.yml

build-ex00-pico-w-blink:
	make docker-run -C ex00-pico-w-blink/

build-ex01-hid-keyboard:
	make docker-run -C ex01-hid-keyboard/
