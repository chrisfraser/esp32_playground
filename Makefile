#############################################################
# Required variables for each makefile
# Discard this section from all parent makefiles
# Expected variables (with automatic defaults):
#   CSRCS (all "C" files in the dir)
#   SUBDIRS (all subdirs with a Makefile)
#   GEN_LIBS - list of libs to be generated ()
#   GEN_IMAGES - list of object file images to be generated ()
#   GEN_BINS - list of binaries to be generated ()
#   COMPONENTS_xxx - a list of libs/objs in the form
#     subdir/lib to be extracted and rolled up into
#     a generated lib/image xxx.a ()
#

TARGET = eagle
#FLAVOR = release
FLAVOR = debug

#EXTRA_CCFLAGS += -u

# esptool path and port
ESPTOOL ?= utils/esptool32.py
ESPPORT ?= /dev/ttyUSB0
# Baud rate for programmer
BAUD ?= 230400

# SPI_SPEED = 40, 26, 20, 80
SPI_SPEED ?= 40
# SPI_MODE: qio, qout, dio, dout
SPI_MODE ?= qio
# SPI_SIZE_MAP
# 0 : 512 KB (256 KB + 256 KB)
# 1 : 256 KB
# 2 : 1024 KB (512 KB + 512 KB)
# 3 : 2048 KB (512 KB + 512 KB)
# 4 : 4096 KB (512 KB + 512 KB)
# 5 : 2048 KB (1024 KB + 1024 KB)
# 6 : 4096 KB (1024 KB + 1024 KB)
SPI_SIZE_MAP ?= 1

ifeq ($(SPI_SPEED), 26.7)
    freqdiv = 1
    flashimageoptions = -ff 26m
else
    ifeq ($(SPI_SPEED), 20)
        freqdiv = 2
        flashimageoptions = -ff 20m
    else
        ifeq ($(SPI_SPEED), 80)
            freqdiv = 15
            flashimageoptions = -ff 80m
        else
            freqdiv = 0
            flashimageoptions = -ff 40m
        endif
    endif
endif

ifeq ($(SPI_MODE), QOUT)
    mode = 1
    flashimageoptions += -fm qout
else
    ifeq ($(SPI_MODE), DIO)
		mode = 2
		flashimageoptions += -fm dio
    else
        ifeq ($(SPI_MODE), DOUT)
            mode = 3
            flashimageoptions += -fm dout
        else
            mode = 0
            flashimageoptions += -fm qio
        endif
    endif
endif

ifeq ($(SPI_SIZE_MAP), 1)
  size_map = 1
  flash = 256
  flashimageoptions += -fs 2m
  blankaddr = 0xFC000
else
  ifeq ($(SPI_SIZE_MAP), 2)
    size_map = 2
    flash = 1024
    flashimageoptions += -fs 8m
    blankaddr = 0xFE000
  else
    ifeq ($(SPI_SIZE_MAP), 3)
      size_map = 3
      flash = 2048
      flashimageoptions += -fs 16m
      blankaddr = 0x1FE000
    else
      ifeq ($(SPI_SIZE_MAP), 4)
		size_map = 4
		flash = 4096
		flashimageoptions += -fs 32m
                blankaddr = 0x3FE000
      else
        ifeq ($(SPI_SIZE_MAP), 5)
          size_map = 5
          flash = 2048
          flashimageoptions += -fs 16m
          blankaddr = 0x1FE000
        else
          ifeq ($(SPI_SIZE_MAP), 6)
            size_map = 6
            flash = 4096
            flashimageoptions += -fs 32m
            blankaddr = 0x3FE000
          else
            size_map = 0
            flash = 512
            flashimageoptions += -fs 4m
            blankaddr = 0x7E000
          endif
        endif
      endif
    endif
  endif
endif

ifndef PDIR # {
GEN_IMAGES= eagle.app.v7.out
GEN_BINS= eagle.app.v7.bin
SPECIAL_MKTARGETS=$(APP_MKTARGETS)
SUBDIRS=    \
    driver	\
    user  	

endif # } PDIR

LDDIR = $(SDK_PATH)/ld

CCFLAGS += -Os

TARGET_LDFLAGS =    \
    -nostdlib       \
    -Wl,-EL         \
    --longcalls     \
    --text-section-literals

ifeq ($(FLAVOR),debug)
    TARGET_LDFLAGS += -g -O2
endif

ifeq ($(FLAVOR),release)
    TARGET_LDFLAGS += -g -O0
endif

COMPONENTS_eagle.app.v7 =   \
    driver/libdriver.a			\
    user/libuser.a

LINKFLAGS_eagle.app.v7 =    \
    -L$(SDK_PATH)/lib       \
    -nostdlib               \
    -T$(LD_FILE)            \
    -Wl,--no-check-sections \
    -u call_user_start      \
    -Wl,-static             \
    -Wl,--start-group       \
    -lc                     \
    -lgcc                   \
    -lhal                   \
    -lm                     \
    -lcrypto                \
    -lfreertos              \
    -llwip                  \
    -lmain                  \
    -lnet80211              \
    -lphy                   \
    -lpp                    \
    -lrtc                   \
    -lwpa                   \
    $(DEP_LIBS_eagle.app.v7)\
    -Wl,--end-group

DEPENDS_eagle.app.v7 = $(LD_FILE)

#############################################################
# Configuration i.e. compile options etc.
# Target specific stuff (defines etc.) goes in here!
# Generally values applying to a tree are captured in the
#   makefile at its root level - these are then overridden
#   for a subtree within the makefile rooted therein
#

#UNIVERSAL_TARGET_DEFINES =     \

# Other potential configuration flags include:
#	-DTXRX_TXBUF_DEBUG
#	-DTXRX_RXBUF_DEBUG
#	-DWLAN_CONFIG_CCX
CONFIGURATION_DEFINES =	-DICACHE_FLASH

DEFINES +=      \
    $(UNIVERSAL_TARGET_DEFINES) \
    $(CONFIGURATION_DEFINES)

DDEFINES +=     \
    $(UNIVERSAL_TARGET_DEFINES) \
    $(CONFIGURATION_DEFINES)


#############################################################
# Recursion Magic - Don't touch this!!
#
# Each subtree potentially has an include directory
#   corresponding to the common APIs applicable to modules
#   rooted at that subtree. Accordingly, the INCLUDE PATH
#   of a module can only contain the include directories up
#   its parent path, and not its siblings
#
# Required for each makefile to inherit from the parent
#

INCLUDES := $(INCLUDES) -I $(PDIR)include
sinclude $(SDK_PATH)/Makefile

.PHONY: checkpath
checkpath:
	@if test -z $(SDK_PATH); then	\
		echo "Please export SDK_PATH firstly!!!";	\
		exit 1;	\
	else	\
		if test ! -d $(SDK_PATH)/include/espressif/esp32; then \
			echo "$(SDK_PATH) is not a ESP32_RTOS_SDK path, please check!!!";	\
			exit 1;	\
		fi;	\
	fi; \
	echo "$(SDK_PATH) is all good." \

flash: all
	python $(ESPTOOL) -p $(ESPPORT) -b $(BAUD) write_flash $(flashimageoptions) 0x00000 $(SDK_PATH)/bin/boot.bin 0x04000 $(BIN_PATH)/irom1.bin 0x40000 $(BIN_PATH)/irom0_flash.bin $(blankaddr) $(SDK_PATH)/bin/blank.bin

rebuild: clean all

