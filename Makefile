GCC_BIN = /Applications/MapleIDE.app/Contents/Resources/Java/hardware/tools/arm/bin/
OBJDIR = Builds
SOURCES = $(shell find -E . -regex '^.*\.(c(pp)?|[sS])$$' | sed -E -e 's/\.(c(pp)?|[sS])$$/.o/g')
OBJECTS = $(patsubst %,$(OBJDIR)/%,$(filter-out $(PROJECT).o,$(SOURCES)))
#ifeq ($(wildcard libmaple/libmaple.a),)
	CORE_SOURCES = $(shell find -E /Applications/MapleIDE.app/Contents/Resources/Java/hardware/leaflabs/cores/maple -regex '^.*\.(c(pp)?|[sS])$$' | sed -E -e 's/\.(c(pp)?|[sS])$$/.o/g')
	CORE_OBJECTS = $(patsubst /Applications/MapleIDE.app/Contents/Resources/Java/hardware/leaflabs/cores/maple/%,libmaple/%,$(filter-out $(PROJECT).o,$(CORE_SOURCES)))
#else
#	CORE_SORCES =
#	CORE_OBJECTS =
#endif
INCLUDE_PATHS = -I. $(shell find -E . -regex '^.*\.h$$' | sed -e 's/^\(.*\)\/[^\/]*$$/-I\1/g' | sort | uniq)
LIBRARY_PATHS = -L/Applications/MapleIDE.app/Contents/Resources/Java/hardware/leaflabs/cores/maple $(shell find -E . -regex '^.*\.a$$' | sed -e 's/^\(.*\)\/[^\/]*$$/-L\1/g' | sort | uniq)
LIBRARIES =
# LINKER_SCRIPT = -T/Applications/MapleIDE.app/Contents/Resources/Java/hardware/leaflabs/cores/maple/maple_mini/flash.ld $(shell find -E . -regex '^.*\.ld$$')
LINKER_SCRIPT = -T/Applications/MapleIDE.app/Contents/Resources/Java/hardware/leaflabs/cores/maple/maple_mini/flash.ld

###############################################################################
AR      = $(GCC_BIN)arm-none-eabi-ar
AS      = $(GCC_BIN)arm-none-eabi-gcc
CC      = $(GCC_BIN)arm-none-eabi-gcc
CPP     = /Users/ryosuke/Develop/gcc-arm-none-eabi-4_9-2015q2/bin/arm-none-eabi-g++
LD      = $(GCC_BIN)arm-none-eabi-g++
OBJCOPY = $(GCC_BIN)arm-none-eabi-objcopy
OBJDUMP = $(GCC_BIN)arm-none-eabi-objdump
SIZE 	= $(GCC_BIN)arm-none-eabi-size
DFU     = $(GCC_BIN)dfu-util
CLANG   = clang

CPU_COMMON = -c -mcpu=cortex-m3 -mthumb -DBOARD_maple_mini -DMCU_STM32F103CB -DSTM32_MEDIUM_DENSITY -DERROR_LED_PORT=GPIOB -DERROR_LED_PIN=1 -DMAPLE_IDE
CPU = -march=armv7-m $(CPU_COMMON)
CPU_CLANG = -target armv7m-none-eabi -mfloat-abi=$(FLOAT_ABI) $(CPU_COMMON)
CC_COMMON = -g -DVECT_TAB_FLASH -nostdlib -ffunction-sections -fdata-sections
CC_FLAGS = $(CPU) $(CC_COMMON) -I/Applications/MapleIDE.app/Contents/Resources/Java/hardware/leaflabs/cores/maple -Wl,--gc-sections
CC_CLANG = $(CPU_CLANG) $(CC_COMMON) -isystem /Applications/MapleIDE.app/Contents/Resources/Java/hardware/leaflabs/cores/maple --sysroot=/Applications/MapleIDE.app/Contents/Resources/Java/hardware/tools/arm -fshort-enums

CXX_FLAGS = -fno-rtti -fno-exceptions

LD_FLAGS = -mcpu=cortex-m3 -mthumb -Xlinker --gc-sections --print-gc-sections --march=armv7-m -Wall

CLANG_FLAGS = $(CPU_CLANG) $(CC_CLANG) $(CXX_FLAGS) -std=gnu++14 $(WARNING_FLAGS)

BOARD_USB_VENDOR_ID  := 1EAF
BOARD_USB_PRODUCT_ID := 0003

ifeq ($(HARDFP),1)
	FLOAT_ABI = hard
else
	FLOAT_ABI = softfp
endif

ifeq ($(DEBUG), 1)
  CC_COMMON += -DDEBUG -O0
WARNING_FLAGS = -Wall -Wextra -Wno-non-virtual-dtor -Wcast-align -Wundef -Wmissing-include-dirs -Wunused-macros -Wmissing-noreturn -Wmissing-format-attribute -Wcast-qual -Wunused -Wdisabled-optimization -Wfloat-equal -Wold-style-cast -Winline -Winit-self -Wformat-nonliteral -Wunreachable-code -Wformat-security -Wformat -Woverloaded-virtual -Wunsafe-loop-optimizations -Wlogical-op #-Weffc++
else
  CC_COMMON += -DNDEBUG -Os
  WARNING_FLAGS = -Wall -Wextra
endif

createObjDir:
	@if [ ! -d $(OBJDIR) ]; then mkdir $(OBJDIR); fi

all: allclean build upload

build: createObjDir $(OBJDIR)/$(PROJECT).bin

upload:
	@echo "Upload"
	screen -d || true
	screen -r -X quit || true
	python ./reset.py && \
	sleep 1 && \
	$(DFU) -a1 -R -d $(BOARD_USB_VENDOR_ID):$(BOARD_USB_PRODUCT_ID) -D $(OBJDIR)/$(PROJECT).bin

buildAndUpload: build upload

cleanLibMaple:
	@if [ -d libmaple ]; then rm -rf libmaple; fi

clean:
	@if [ -d $(OBJDIR) ]; then rm -rf $(OBJDIR); fi

allclean: clean cleanLibMaple

$(OBJDIR)/%.o: 	%.s
	@echo "Assemble $<"
	@mkdir -p $(dir $@)
	$(AS) $(CPU) -x assembler-with-cpp -o $@ $<

libmaple/%.o: 	/Applications/MapleIDE.app/Contents/Resources/Java/hardware/leaflabs/cores/maple/%.S
	@echo "Assemble $<"
	@mkdir -p $(dir $@)
	$(AS) $(CPU) -x assembler-with-cpp -o $@ $<

$(OBJDIR)/%.o: 	%.S
	@echo "Assemble $<"
	@mkdir -p $(dir $@)
	$(AS) $(CPU) -x assembler-with-cpp -o $@ $<

libmaple/%.o: 	/Applications/MapleIDE.app/Contents/Resources/Java/hardware/leaflabs/cores/maple/%.c
	@echo "Compile $<"
	@mkdir -p $(dir $@)
	$(CC) $(CC_FLAGS) -DARDUINO=18 -std=gnu99 $(INCLUDE_PATHS) -o $@ $<

$(OBJDIR)/%.o: 	%.c
	@echo "Compile $<"
	@mkdir -p $(dir $@)
	$(CC) $(CC_FLAGS) -DARDUINO=18 -std=gnu99 $(INCLUDE_PATHS) $(WARNING_FLAGS) -o $@ $<

$(OBJDIR)/%.d: %.c
	@echo "Generate dependency of $<"
	@mkdir -p $(dir $@)
	$(CC) -MM $(CC_FLAGS) -std=gnu99 $(INCLUDE_PATHS) $< -MF $@ -MT $(@:.d=.o)

libmaple/%.o: 	/Applications/MapleIDE.app/Contents/Resources/Java/hardware/leaflabs/cores/maple/%.cpp
	@echo "Compile $<"
	@mkdir -p $(dir $@)
	$(CPP) $(CC_FLAGS) $(CXX_FLAGS) $(INCLUDE_PATHS) -o $@ $<

$(OBJDIR)/%.o: %.cpp
	@echo "Compile $<"
	@mkdir -p $(dir $@)
	$(CPP) $(CC_FLAGS) $(CXX_FLAGS) $(INCLUDE_PATHS) $(WARNING_FLAGS) -std=gnu++14 -o $@ $<
#	$(CLANG) $(CLANG_FLAGS) $(INCLUDE_PATHS) -Weverything -o $@ $<

$(OBJDIR)/%.d: %.cpp
	@echo "Generate dependency of $<"
	@mkdir -p $(dir $@)
	$(CPP) -MM $(CC_FLAGS) $(CXX_FLAGS) $(INCLUDE_PATHS) $< -MF $@ -MT $(@:.d=.o)

libmaple/libmaple.a: $(CORE_OBJECTS)
	$(AR) -r $@ $^
#	rm -f $^

$(OBJDIR)/$(PROJECT).elf: $(OBJECTS) libmaple/libmaple.a
	@echo Link
	$(LD) $(LD_FLAGS) $(LINKER_SCRIPT) $(LIBRARY_PATHS) $(CORE_OBJECTS) -o $@ $^ $(LIBRARIES)
	$(SIZE) $@

$(OBJDIR)/$(PROJECT).bin: $(OBJDIR)/$(PROJECT).elf
	@echo Copy
	$(OBJCOPY) -v -Obinary $< $@
