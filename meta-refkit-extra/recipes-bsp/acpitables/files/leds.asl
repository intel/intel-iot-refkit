/*
 * This is somewhat modified acpi table for Intel 570X leds
 * originally from Mika Westerberg.
 *
 * Copyright (C) 2016, Intel Corporation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
DefinitionBlock ("leds.aml", "SSDT", 5, "", "LEDS", 1)
{
    External (_SB_.PCI0, DeviceObj)

    Scope (\_SB.PCI0)
    {
        Device (LEDS)
        {
            Name (_HID, "PRP0001")
            Name (_DDN, "GPIO LEDs device")

            Name (_CRS, ResourceTemplate () {
                GpioIo (
                    Exclusive,                  // Not shared
                    PullNone,                   // No need for pulls
                    0,                          // Debounce timeout
                    0,                          // Drive strength
                    IoRestrictionOutputOnly,    // Only used as output
                    "\\_SB.GPO2",               // GPIO controller
                    0)                          // Must be 0
                {
                    22,                         // ISH_GPIO_0_LS
                    23,                         // ISH_GPIO_1_LS
                    24,                         // ISH_GPIO_2_LS
                    25                          // ISH_GPIO_3_LS
                }
            })

            Name (_DSD, Package () {
                ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                Package () {
                    Package () {"compatible", "gpio-leds"},
                },
                ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"),
                Package () {
                    Package () {"led-0", "LED0"},
                    Package () {"led-1", "LED1"},
                    Package () {"led-2", "LED2"},
                    Package () {"led-3", "LED3"},
                }
            })

            /*
             * For more information about these bindings see:
             * Documentation/devicetree/bindings/leds/leds-gpio.txt and
             * Documentation/acpi/gpio-properties.txt.
             */
            Name (LED0, Package () {
                ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                Package () {
                    Package () {"label", "heartbeat"},
                    Package () {"gpios", Package () {^LEDS, 0, 0, 0}},
                    Package () {"linux,default-state", "off"},
                    Package () {"linux,retain-state-suspended", 1},
                }
            })

            Name (LED1, Package () {
                ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                Package () {
                    Package () {"label", "sd-card"},
                    Package () {"gpios", Package () {^LEDS, 0, 1, 0}},
                    Package () {"linux,default-state", "off"},
                    Package () {"linux,retain-state-suspended", 1},
                }
            })

            Name (LED2, Package () {
                ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                Package () {
                    Package () {"label", "wifi"},
                    Package () {"gpios", Package () {^LEDS, 0, 2, 0}},
                    Package () {"linux,default-state", "off"},
                    Package () {"linux,retain-state-suspended", 1},
                }
            })

            Name (LED3, Package () {
                ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                Package () {
                    Package () {"label", "led-3"},
                    Package () {"gpios", Package () {^LEDS, 0, 3, 0}},
                    Package () {"linux,default-state", "off"},
                    Package () {"linux,retain-state-suspended", 1},
                }
            })
        }
    }
}
