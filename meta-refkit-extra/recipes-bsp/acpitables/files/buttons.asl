/*
 * This is somewhat modified acpi table for Intel 570x GP button
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
DefinitionBlock ("buttons.aml", "SSDT", 5, "", "BUTTONS", 1)
{
    External (_SB_.PCI0, DeviceObj)

    Scope (\_SB.PCI0)
    {
        Device (BTNS)
        {
            Name (_HID, "PRP0001")
            Name (_DDN, "GPIO buttons device")

            Name (_CRS, ResourceTemplate () {
                GpioInt (Edge, ActiveBoth, ExclusiveAndWake, PullUp, 0,
                        "\\_SB.GPO0", 0) {17} // BTN_N
            })

            Name (_DSD, Package () {
                ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                Package () {
                    Package () {"compatible", "gpio-keys"},
                    Package () {"autorepeat", 1}
                },
                ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"),
                Package () {
                    Package () {"button-0", "BTN0"},
                }
            })

            Name (BTN0, Package () {
                ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
                Package () {
                    Package () {"label", "GP BTN"},
                    Package () {"linux,code", 102}, // KEY_HOME
                    Package () {"linux,input-type", 1},
                    Package () {"gpios", Package () {^BTNS, 0, 0, 1}}
                }
            })
        }
    }
}
