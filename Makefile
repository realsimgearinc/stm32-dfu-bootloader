CROSS_COMPILE ?= arm-none-eabi-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
GIT_VERSION := $(shell git describe --abbrev=8 --dirty --always --tags)

OUTNAME ?= bootloader-dfu-fw

# Config bits
BOOTLOADER_SIZE = 4
FLASH_SIZE ?= 512
FLASH_BASE_ADDR = 0x08000000
FLASH_BOOTLDR_PAYLOAD_SIZE_KB = $(shell echo $$(($(FLASH_SIZE) - $(BOOTLOADER_SIZE))))
HSE_SPEED_MHZ ?= 8

# Default config
CONFIG ?= \
	-DENABLE_GPIO_DFU_BOOT -DGPIO_DFU_BOOT_PORT=GPIOC -DGPIO_DFU_BOOT_PIN=13 -DGPIO_DFU_BOOT_PULLUP \
	-DUSB_PULLUP_PORT=GPIOB -DUSB_PULLUP_PIN=8 \
	-DENABLE_PROTECTIONS -DENABLE_CHECKSUM -DENABLE_SAFEWRITE -DENABLE_WATCHDOG=20

CFLAGS = -Os -ggdb -std=c11 -Wall -pedantic -Werror \
	-ffunction-sections -fdata-sections -Wno-overlength-strings \
	-mcpu=cortex-m3 -mthumb -DSTM32F1 -fno-builtin-memcpy  \
	-pedantic -DVERSION=\"$(GIT_VERSION)\" -DHSE_SPEED_MHZ=$(HSE_SPEED_MHZ) -flto $(CONFIG)

LDFLAGS = -ggdb -ffunction-sections -fdata-sections \
	-Wl,-Tstm32f103.ld -nostartfiles -lc -lnosys \
	-mthumb -mcpu=cortex-m3 -Wl,-gc-sections -flto \
	-Wl,--print-memory-usage

all:	$(OUTNAME).bin

# DFU bootloader firmware
$(OUTNAME).elf: init.o main.o usb.o
	$(CC) $^ -o $@ $(LDFLAGS) -Wl,-Ttext=$(FLASH_BASE_ADDR) -Wl,-Map,$(OUTNAME).map

%.bin: %.elf
	$(OBJCOPY) -O binary $^ $@

%.o: %.c | flash_config.h
	$(CC) -c $< -o $@ $(CFLAGS)

flash_config.h:
	echo "#define FLASH_BASE_ADDR $(FLASH_BASE_ADDR)" > flash_config.h
	echo "#define FLASH_SIZE_KB $(FLASH_SIZE)" >> flash_config.h
	echo "#define FLASH_BOOTLDR_PAYLOAD_SIZE_KB $(FLASH_BOOTLDR_PAYLOAD_SIZE_KB)" >> flash_config.h
	echo "#define FLASH_BOOTLDR_SIZE_KB $(BOOTLOADER_SIZE)" >> flash_config.h

clean:
	-rm -f $(OUTNAME).elf *.o $(OUTNAME).bin $(OUTNAME).map flash_config.h

