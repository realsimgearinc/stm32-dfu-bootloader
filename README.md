
STM32F103 DFU bootloader
========================

This is a tiny bootloader (under 4KB) for STM32F103 (although it probably
works for similar devices). It enables user to flash devices over USB
with any arbitrary payloads. It features some minimal payload checking
to ensure use apps are valid before booting them.

This version has been modified to accomodate our (RealSimGear Inc's) products 
and the changes and new features are noted at the end.

Features
--------

* Small size, ideally under 4KB to fit on the first four pages.
* RDP protection configurable at build time.
* Reboot into DFU mode support (by writing tag to RAM + reset).
* Watchdog support for failsafe.
* Total wipe on DFU downloads (avoid partial FW updates).
* Optional upload enable (to prevent firmware/data reads).
* Firmware checksum checking.


Reboot into bootloader
----------------------

One can reboot into bootloader (in DFU mode) by simply writing the magic
0xDEADBEEFCC00FFEE value to the last 8 bytes of RAM and triggering a full
system reset. This will make the bootloader start DFU mode instead of
loading the (valid) payload present in flash.

Protections
-----------

Bootloader might enable RDP (Readout protection) that will prevent debugger
over SWIO from reading data. This protection can be removed but will cause
all user flash (except the DFU bootloader) to be deleted, that's cause the
first 4KB are always write protected. It can also disable SWIO GPIOs to
prevent any debuggers from attaching to the device once booted.
The booloader also features some DFU proectections. It is possible to
disable firmware read by disabling UPLOAD commands. In order to prevent
data read it is possible to prevent partial writes, since what could allow
a small firmware being uploaded to extract data from flash. With this
protection enabled the bootloader will wipe all the blocks as soon as
an erase/write command is issued.

Force DFU mode
--------------

The bootloader can be configured to detect a GPIO condition on boot and
abort boot to go into DFU mode. The pin will be configured as an internal
pulldown and the user will need to pull it up to force DFU mode, which
will be read right after reset (there's some small delay to ensure the
pin is read correctly).

The firmware can optionally enable the Internal Watchdog on a configurable
period of 1 to 26 seconds. If the user app does not reset the watchdog
before the period is due it will reset the system and enter DFU mode.

Firmware format and checksum
----------------------------

The use firmware should be build and linked at an offset of 0x1000 (4KB)
so it can safely boot as a payload. The bootloader will check some stuff
before declaring the payload valid:

 * Stack points to somewhere in the RAM range (0x20000000).
 * The firmware contains its size at offset 0x20 (as a LE uint32).
 * The firmware 32bit XOR checksum is zero (can use offset 0x1C for that).

If these conditions are met, provided no other triggers to boot into DFU
are present, the bootloader will point VTOR to the user app and boot it.


Config flags
------------

* ENABLE_DFU_UPLOAD: Enables DFU upload commands, this is, enables reading
  flash memory (only within the user app boundaries) via DFU.
* ENABLE_SAFEWRITE: Ensures the user flash is completely erased before any
  DFU write/erase command is executed, to ensure no payloads are written
  that could lead to user data exfiltration.
* ENABLE_CHECKSUM: Forces the user app image to have a valid checksum to
  boot it, on failure it will fallback to DFU mode.
* ENABLE_WRITEPROT: Protects the first 4KB of flash against writes.
  Essentially prevents any user app from overwriting the bootloader area.
* ENABLE_PROTECTIONS: Disables JTAG at startup before jumping to user code
  and also ensures RDP protection is enabled before booting. It will update
  option bytes if that is not met and force a reset (should only happen the
  first time, after that RDP is enabled and can only be disabled via JTAG).
  This also protects the bootloader (first 4KB) like ENABLE_WRITEPROT does,
  making these two options incompatible.
* ENABLE_GPIO_DFU_BOOT: Enables DFU mode on pulling up a certain GPIO.
  You need to define GPIO_DFU_BOOT_PORT and GPIO_DFU_BOOT_PIN to either
  GPIOA, GPIOB, .. GPIOE and 0 .. 15 to indicate which port to enable and
  what pin to read from.
* ENABLE_PINRST_DFU_BOOT: Enables DFU mode when a reset from the NRST pin
  occurs.

By default all flags are set except for DFU upload, so it's most secure.

RealSimGear Specific Changes
============================

Most of the changes have been made to allow us to work with our hardware without
compromising the compatibility with upstream.

Additional Makefile Flags
-------------------------

* `HSE_SPEED_MHZ` can be set to control the value of the HSE_SPEED_MHZ config 
  flag.  If unset, it defaults to 8.

* `OUTNAME` can be set to control the output file names.  We use this for bulk
  building the variants of the bootloader for our various products.

* `LINK_SCRIPT` can be set to change the linker script used when building the
  final firmware image.  This needs to have the correct RAM size configured
  in it otherwise the bootloader will not verify the correct words of memory
  for the bootloader magic word.  The original F103x8 configuration is
  available as `stm32f103x8.ld`.  An alternate script for the xD and xE is
  included (which is now the default used).

Additional Config Flags
-----------------------

* You can change the USB VID/PID and USB strings using:
  `DFU_USB_VID` for the vendor ID, `DFU_USB_PID` for the product ID,
  `DFU_USB_MFG_STRING` for the Manufacturer string, and
  `DFU_USB_PROD_STRING` for the Product string.   We generally don't bother
  overriding the product string, but we do set VID/PID/MFG_STRING to match
  our standard.

* You can set `GPIO_DFU_BOOT_PULLUP` to enable the pull-up and use the boot mode
  switch as a low active switch, rather than a high active one.

* You can set `USB_PULLUP_PORT` and `USB_PULLUP_PIN` to indicate where the D+
  pullup is located.  Doing so disables the USB D+ GPIO hack to pull D+ low,
  and instead uses the preferred signalling method of manipulating the pull-up
  itself instead, without disconnecting the USB Transceiver.

* We've added the define `HSE_SPEED_MHZ` (as well as the makefile var) which
  specifies what the external crystal speed is in MHz.  Valid values are 8 (the
  traditional default) and 16.  Using 16 enables the XTPRE predivider when
  configuring the clocks to set up the PLL correctly.

A Note On USB IDs and Licensing
-------------------------------

Whilst the bootloader is provided here as per the requirements of the GNU Public
License, that does not entail authorisation to use RSG USB VID/PIDs arbitrarily.

The RealSimGear USB VID/PID can only be used on our Products.

Please use the original defaults (which take effect if you do not override
DFU_USB_VID, or DFU_USB_PID), or get an allocation from pid.codes if you
want to use this variation of this bootloader in your own products.   Doing so
does not hamper or otherwise impact the operation of the firmware.
