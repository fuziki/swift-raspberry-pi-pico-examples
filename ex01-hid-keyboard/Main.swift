/* Blink pattern
 * - 250 ms  : device not mounted
 * - 1000 ms : device mounted
 * - 2500 ms : device is suspended
 */

enum Blink: UInt32 {
    case notMounted = 250
    case mounted = 1000
    case suspended = 2500
}

// GPIO
let button_cmd_b_pin: UInt32 = 16
let led_pin: UInt32 = 15

// Every 10ms, we will sent 1 report for each HID profile (keyboard, mouse etc ..)
// tud_hid_report_complete_cb() is used to send the next report after previous one is complete
var start_ms_for_hid_task: UInt32 = 0
// use to avoid send multiple consecutive zero report for keyboard
var has_keyboard_key: Bool = false

var start_ms_for_led_blinking: UInt32 = 0
var led_state: Bool = false

var blink_interval_ms: UInt32 = Blink.notMounted.rawValue

@main
struct Main {
    static func main() {
        board_init()
        tusb_init()

        gpio_init(button_cmd_b_pin)
        gpio_set_dir(button_cmd_b_pin, false)
        gpio_pull_up(button_cmd_b_pin)

        gpio_init(led_pin)
        gpio_set_dir(led_pin, true)

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
    blink_interval_ms = Blink.mounted.rawValue
}

// Invoked when device is unmounted
@_cdecl("tud_umount_cb")
func tud_umount_cb() {
    blink_interval_ms = Blink.notMounted.rawValue
}

// Invoked when usb bus is suspended
// remote_wakeup_en : if host allow us  to perform remote wakeup
// Within 7ms, device must draw an average of current less than 2.5 mA from bus
@_cdecl("tud_suspend_cb")
func tud_suspend_cb(_ remote_wakeup_en: Bool) {
    blink_interval_ms = Blink.suspended.rawValue
}

// Invoked when usb bus is resumed
@_cdecl("tud_resume_cb")
func tud_resume_cb() {
    blink_interval_ms = Blink.mounted.rawValue
}

//--------------------------------------------------------------------+
// USB HID
//--------------------------------------------------------------------+

// Every 10ms, we will sent 1 report for each HID profile (keyboard, mouse etc ..)
// tud_hid_report_complete_cb() is used to send the next report after previous one is complete
func hid_task() {
    // Poll every 10ms
    let interval_ms: UInt32 = 10

    if get_board_millis() - start_ms_for_hid_task < interval_ms { return } // not enough time
    start_ms_for_hid_task += interval_ms;

    let button_cmd_b: Bool = !gpio_get(button_cmd_b_pin)

    // Remote wakeup
    if tud_suspended() && button_cmd_b {
        // Wake up host if we are in suspend mode
        // and REMOTE_WAKEUP feature is enabled by hostbbbbbbbbbbbbbb
        tud_remote_wakeup()
    } else {
        // Send the 1st of report chain, the rest will be sent by tud_hid_report_complete_cb()

        // skip if hid is not ready yet
        if !tud_hid_ready() { return }

        if button_cmd_b {
            let keycode: UnsafeMutablePointer<UInt8> = malloc(6 * MemoryLayout<UInt8>.size)!
                .assumingMemoryBound(to: UInt8.self)
            memset(keycode, 0, 6 * MemoryLayout<UInt8>.size)

            keycode.advanced(by: 0).pointee = UInt8(HID_KEY_B)
            tud_hid_keyboard_report(UInt8(REPORT_ID_KEYBOARD), UInt8(KEYBOARD_MODIFIER_LEFTGUI.rawValue), keycode)
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
) {
    if report_type == HID_REPORT_TYPE_OUTPUT {
        // Set keyboard LED e.g Capslock, Numlock etc...
        if report_id == REPORT_ID_KEYBOARD {
            // bufsize should be (at least) 1
            if bufsize < 1 { return }

            let kbd_leds: UInt8 = buffer[0]

            if (kbd_leds & UInt8(KEYBOARD_LED_CAPSLOCK.rawValue)) != 0 {
                // Capslock On: disable blink, turn led on
                blink_interval_ms = 0
                gpio_put(led_pin, true)
            } else {
                // Caplocks Off: back to normal blink
                gpio_put(led_pin, false)
                blink_interval_ms = Blink.mounted.rawValue
            }
        }
    }
}

//--------------------------------------------------------------------+
// BLINKING TASK
//--------------------------------------------------------------------+

func led_blinking_task() {
    // blink is disabled
    if blink_interval_ms == 0 { return }

    // Blink every interval ms
    if get_board_millis() - start_ms_for_led_blinking < blink_interval_ms { return } // not enough time
    start_ms_for_led_blinking += blink_interval_ms

    gpio_put(led_pin, led_state)
    led_state.toggle()
}
