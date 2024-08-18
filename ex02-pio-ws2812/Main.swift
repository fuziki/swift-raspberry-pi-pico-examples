//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

let LED_PIN: UInt32 = 17

enum WS2812 {
    static var ws2812ProgramForPio0: pio_program!

    case pio0

    var pio: PIO {
        switch self {
        case .pio0:
            get_pio0()
        }
    }

    func setup(ledPin: UInt32) {
        let ws2812ProgramInstructions = malloc(4 * MemoryLayout<UInt16>.size)!
            .assumingMemoryBound(to: UInt16.self)
        ws2812ProgramInstructions.advanced(by: 0).pointee = 0x6221
        ws2812ProgramInstructions.advanced(by: 1).pointee = 0x1123
        ws2812ProgramInstructions.advanced(by: 2).pointee = 0x1400
        ws2812ProgramInstructions.advanced(by: 3).pointee = 0xa442

        Self.ws2812ProgramForPio0 = pio_program(instructions: ws2812ProgramInstructions, length: 4, origin: -1)

        let offset = pio_add_program(pio, &Self.ws2812ProgramForPio0)
        ws2812_program_init(pio, 0, offset, ledPin, 800000, false)
    }

    func set(color: UInt32) {
        pio_sm_put_blocking(pio, 0, color)
    }
}

@main
struct Main {
    static func main() {
        stdio_init_all()
        WS2812.pio0.setup(ledPin: LED_PIN)

        while true {
            WS2812.pio0.set(color: 0xFF000000)
            sleep_ms(500)

            // Green color (GRB format)
            WS2812.pio0.set(color: 0x00FF0000)
            sleep_ms(500)

            // Blue color (GRB format)
            WS2812.pio0.set(color: 0x0000FF00)
            sleep_ms(500)
        }
    }
}

// https://github.com/apple/swift-playdate-examples/blob/749dd8f518429168d03e754764afb334a80b527d/Sources/Playdate/Playdate.swift#L21
@_documentation(visibility: internal)
@_cdecl("posix_memalign")
public func posix_memalign(
  _ memptr: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
  _ alignment: Int,
  _ size: Int
) -> CInt {
  guard let allocation = malloc(Int(size + alignment - 1)) else {
    #if hasFeature(Embedded)
    fatalError()
    #else
    fatalError("Unable to handle memory request: Out of memory.")
    #endif
  }
  let misalignment = Int(bitPattern: allocation) % alignment
  #if hasFeature(Embedded)
  precondition(misalignment == 0)
  #else
  precondition(
    misalignment == 0,
    "Unable to handle requests for over-aligned memory.")
  #endif
  memptr.pointee = allocation
  return 0
}
