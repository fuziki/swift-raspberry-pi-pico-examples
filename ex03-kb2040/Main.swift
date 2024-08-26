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

// GPIO
let led_pin: UInt32 = 17
let left_pin: UInt32 = 8
let center_pin: UInt32 = 7
let right_pin: UInt32 = 6
let upper_pin: UInt32 = 2
let bottom_pin: UInt32 = 3

// Every 10ms, we will sent 1 report for each HID profile (keyboard, mouse etc ..)
// tud_hid_report_complete_cb() is used to send the next report after previous one is complete
var start_ms_for_hid_task: UInt32 = 0
// use to avoid send multiple consecutive zero report for keyboard
var has_keyboard_key: Bool = false

var start_ms_for_led_blinking: UInt32 = 0
var led_state: Bool = false

enum Blink {
    case notMounted
    case mounted
    case suspended
}

var blink_status: Blink = .notMounted

@main
struct Main {
    static func setInput(pin: UInt32) {
        gpio_init(pin)
        gpio_set_dir(pin, false)
        gpio_pull_up(pin)
    }

    static func setOutput(pin: UInt32) {
        gpio_init(pin)
        gpio_set_dir(pin, true)
    }

    static func main() {
        board_init()
        tusb_init()

        WS2812.pio0.setup(ledPin: led_pin)

        setInput(pin: left_pin)
        setInput(pin: center_pin)
        setInput(pin: right_pin)

        setOutput(pin: upper_pin)
        setOutput(pin: bottom_pin)

        gpio_put(upper_pin, false)
        gpio_put(bottom_pin, true)

        while true {
            tud_task() // tinyusb device task

            led_blinking_task()

            hid_task()
        }
    }
}

//--------------------------------------------------------------------+
// Device callbacks
//--------------------------------------------------------------------+

// Invoked when device is mounted
@_cdecl("tud_mount_cb")
func tud_mount_cb() {
    blink_status = .mounted
}

// Invoked when device is unmounted
@_cdecl("tud_umount_cb")
func tud_umount_cb() {
    blink_status = .notMounted
}

// Invoked when usb bus is suspended
// remote_wakeup_en : if host allow us  to perform remote wakeup
// Within 7ms, device must draw an average of current less than 2.5 mA from bus
@_cdecl("tud_suspend_cb")
func tud_suspend_cb(_ remote_wakeup_en: Bool) {
    blink_status = .suspended
}

// Invoked when usb bus is resumed
@_cdecl("tud_resume_cb")
func tud_resume_cb() {
    blink_status = .mounted
}

//--------------------------------------------------------------------+
// USB HID
//--------------------------------------------------------------------+

func getPressKey() -> UInt8? {
    gpio_put(upper_pin, false)
    gpio_put(bottom_pin, true)
    sleep_us(30)
    if !gpio_get(left_pin) { return UInt8(HID_KEY_S) }
    else if !gpio_get(center_pin) { return UInt8(HID_KEY_W) }
    else if !gpio_get(right_pin) { return UInt8(HID_KEY_I) }

    gpio_put(upper_pin, true)
    gpio_put(bottom_pin, false)
    sleep_us(30)
    if !gpio_get(left_pin) { return UInt8(HID_KEY_F) }
    else if !gpio_get(center_pin) { return UInt8(HID_KEY_T) }
    else if !gpio_get(right_pin) { return UInt8(HID_KEY_SPACE) }
    return nil
}swift

// Every 10ms, we will sent 1 report for each HID profile (keyboard, mouse etc ..)
// tud_hid_report_complete_cb() is used to send the next report after previous one is complete
func hid_task() {
    // Poll every 10ms
    let interval_ms: UInt32 = 10

    if get_board_millis() - start_ms_for_hid_task < interval_ms { return } // not enough time
    start_ms_for_hid_task += interval_ms;

    let code: UInt8? = getPressKey()

    // Remote wakeup
    if tud_suspended() && code != nil {
        // Wake up host if we are in suspend mode
        // and REMOTE_WAKEUP feature is enabled by host
        tud_remote_wakeup()
    } else {
        // Send the 1st of report chain, the rest will be sent by tud_hid_report_complete_cb()

        // skip if hid is not ready yet
        if !tud_hid_ready() { return }

        if let code {
            let keycode: UnsafeMutablePointer<UInt8> = malloc(6 * MemoryLayout<UInt8>.size)!
                .assumingMemoryBound(to: UInt8.self)
            memset(keycode, 0, 6 * MemoryLayout<UInt8>.size)

            keycode.advanced(by: 0).pointee = code
            tud_hid_keyboard_report(UInt8(REPORT_ID_KEYBOARD), 0, keycode)
            free(keycode)

            has_keyboard_key = true
        } else {
            // send empty key report if previously has key pressed
            if has_keyboard_key {
                tud_hid_keyboard_report(UInt8(REPORT_ID_KEYBOARD), 0, nil)
            }
            has_keyboard_key = false
        }
    }
}

// Invoked when sent REPORT successfully to host
// Application can use this to send the next report
// Note: For composite reports, report[0] is report ID
@_cdecl("tud_hid_report_complete_cb")
func tud_hid_report_complete_cb(
    _ instance: UInt8,
    _ report: UnsafeMutablePointer<UInt8>,
    _ len: UInt16
) {}

// Invoked when received GET_REPORT control request
// Application must fill buffer report's content and return its length.
// Return zero will cause the stack to STALL request
@_cdecl("tud_hid_get_report_cb")
func tud_hid_get_report_cb(
    _ instance: UInt8,
    _ report_id: UInt8,
    _ report_type: hid_report_type_t,
    _ buffer: UnsafeMutablePointer<UInt8>,
    _ reqlen: UInt16
) -> UInt16  { 0 }

// Invoked when received SET_REPORT control request or
// received data on OUT endpoint ( Report ID = 0, Type = 0 )
@_cdecl("tud_hid_set_report_cb")
func tud_hid_set_report_cb(
    _ instance: UInt8,
    _ report_id: Int8,
    _ report_type: hid_report_type_t,
    _ buffer: UnsafeMutablePointer<UInt8>,
    _ bufsize: UInt16
) {}

//--------------------------------------------------------------------+
// BLINKING TASK
//--------------------------------------------------------------------+

func led_blinking_task() {
    switch blink_status {
    case .notMounted:
        // Blink every interval ms
        if get_board_millis() - start_ms_for_led_blinking < 250 { return } // not enough time
        start_ms_for_led_blinking += 250

        WS2812.pio0.set(color: led_state ? 0x00FF0000 : 0x00000000)
        led_state.toggle()
    case .mounted:
        // Blink every interval ms
        let ms = get_board_millis()
        if ms - start_ms_for_led_blinking < 10 { return } // not enough time
        start_ms_for_led_blinking += 10

        let cycle = ms % 3000
        let power = cycle < 1500 ? cycle : 3000 - cycle
        let uni = 32 * power / 1500

        WS2812.pio0.set(color: uni << 8)
    case .suspended:
        // Blink every interval ms
        if get_board_millis() - start_ms_for_led_blinking < 2500 { return } // not enough time
        start_ms_for_led_blinking += 2500

        WS2812.pio0.set(color: led_state ? 0xFF000000 : 0x00000000)
        led_state.toggle()
    }
}


func hid_task1() {
    let interval_ms: UInt32 = 10
    if get_board_millis() - start_ms_for_hid_task < interval_ms { return }
    start_ms_for_hid_task += interval_ms;

    let code: UInt8? = getPressKey()
    if tud_suspended() && code != nil {
        tud_remote_wakeup()
        return
    }

    if !tud_hid_ready() { return }
    if let code {
        let keycode: UnsafeMutablePointer<UInt8> = malloc(6 * MemoryLayout<UInt8>.size)!
            .assumingMemoryBound(to: UInt8.self)
        memset(keycode, 0, 6 * MemoryLayout<UInt8>.size)

        keycode.advanced(by: 0).pointee = code
        tud_hid_keyboard_report(UInt8(REPORT_ID_KEYBOARD), 0, keycode)
        free(keycode)

        has_keyboard_key = true
    } else {
        if has_keyboard_key {
            tud_hid_keyboard_report(UInt8(REPORT_ID_KEYBOARD), 0, nil)
        }
        has_keyboard_key = false
    }
}
