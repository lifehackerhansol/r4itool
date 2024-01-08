# SPDX-License-Identifier: CC0-1.0
#
# SPDX-FileContributor: Antonio Niño Díaz, 2023
# SPDX-FileContributor: lifehackerhansol, 2023

# User config
# ===========

NAME		:= $(shell basename $(CURDIR))

# Source code paths
# -----------------

SOURCEDIRS	:= source
INCLUDEDIRS	:= include source

# Defines passed to all files
# ---------------------------

DEFINES		:=

# Libraries
# ---------

LIBS		:= 
LIBDIRS		:= 

# Build artifacts
# ---------------

BUILDDIR	:= build
ELF		:= $(NAME)
DUMP		:= build/$(NAME).dump
MAP		:= build/$(NAME).map

# Tools
# -----

PREFIX		:= 
CC		:= $(PREFIX)gcc
CXX		:= $(PREFIX)g++
OBJDUMP		:= $(PREFIX)objdump
MKDIR		:= mkdir
RM		:= rm -rf

# Verbose flag
# ------------

ifeq ($(VERBOSE),1)
V		:=
else
V		:= @
endif

# Source files
# ------------

ifneq ($(BINDIRS),)
    SOURCES_BIN	:= $(shell find -L $(BINDIRS) -name "*.bin")
    INCLUDEDIRS	+= $(addprefix $(BUILDDIR)/,$(BINDIRS))
endif

SOURCES_C	:= $(shell find -L $(SOURCEDIRS) -name "*.c")
SOURCES_CPP	:= $(shell find -L $(SOURCEDIRS) -name "*.cpp")

# Compiler and linker flags
# -------------------------

DEFINES		+=

ARCH		:=

WARNFLAGS	:= -Wall

ifeq ($(SOURCES_CPP),)
    LD		:= $(CC)
    LIBS	+= -lc
else
    LD		:= $(CXX)
    LIBS	+= -lstdc++
endif

INCLUDEFLAGS	:= $(foreach path,$(INCLUDEDIRS),-I$(path)) \
		   $(foreach path,$(LIBDIRS),-I$(path)/include)

LIBDIRSFLAGS	:= $(foreach path,$(LIBDIRS),-L$(path)/lib)

CFLAGS		+= -std=gnu11 $(WARNFLAGS) $(DEFINES) $(ARCH) \
		   $(INCLUDEFLAGS) -O2 \
		   -ffunction-sections -fdata-sections \
		   -fomit-frame-pointer

CXXFLAGS	+= -std=c++20 $(WARNFLAGS) $(DEFINES) $(ARCH) \
		   $(INCLUDEFLAGS) -O2 \
		   -ffunction-sections -fdata-sections \
		   -fno-exceptions -fno-rtti \
		   -fomit-frame-pointer

LDFLAGS		:= $(LIBDIRSFLAGS) \
		   -Wl,-Map,$(MAP) -Wl,--gc-sections \
		   -Wl,--start-group $(LIBS) -lgcc -Wl,--end-group

# Force static linking on Windows, we don't want to make everyone use MSYS2
# Honestly, static linking is always the answer, but some people don't like 
# that for reasons I'll never understand
ifeq ($(OS),Windows_NT)
	LDFLAGS += -static -static-libgcc -static-libstdc++
endif

# Intermediate build files
# ------------------------

OBJS_ASSETS	:= $(addsuffix .o,$(addprefix $(BUILDDIR)/,$(SOURCES_BIN)))

HEADERS_ASSETS	:= $(patsubst %.bin,%_bin.h,$(addprefix $(BUILDDIR)/,$(SOURCES_BIN)))

OBJS_SOURCES	:= $(addsuffix .o,$(addprefix $(BUILDDIR)/,$(SOURCES_C))) \
		   $(addsuffix .o,$(addprefix $(BUILDDIR)/,$(SOURCES_CPP)))

OBJS		:= $(OBJS_ASSETS) $(OBJS_SOURCES)

DEPS		:= $(OBJS:.o=.d)

# Targets
# -------

.PHONY: all clean dump

all: $(ELF)

$(ELF): $(OBJS)
	@echo "  LD      $@"
	$(V)$(LD) -o $@ $(OBJS) $(LDFLAGS)

$(DUMP): $(ELF)
	@echo "  OBJDUMP   $@"
	$(V)$(OBJDUMP) -h -C -S $< > $@

dump: $(DUMP)

clean:
	@echo "  CLEAN"
	$(V)$(RM) $(ELF) $(ELF).exe $(DUMP) $(BUILDDIR)

# Rules
# -----

$(BUILDDIR)/%.c.o : %.c
	@echo "  CC      $<"
	@$(MKDIR) -p $(@D)
	$(V)$(CC) $(CFLAGS) -MMD -MP -c -o $@ $<

$(BUILDDIR)/%.cpp.o : %.cpp
	@echo "  CXX     $<"
	@$(MKDIR) -p $(@D)
	$(V)$(CXX) $(CXXFLAGS) -MMD -MP -c -o $@ $<

$(BUILDDIR)/%.bin.o $(BUILDDIR)/%_bin.h : %.bin
	@echo "  BIN2C   $<"
	@$(MKDIR) -p $(@D)
	$(V)$(BLOCKSDS)/tools/bin2c/bin2c $< $(@D)
	$(V)$(CC) $(CFLAGS) -MMD -MP -c -o $(BUILDDIR)/$*.bin.o $(BUILDDIR)/$*_bin.c

# All assets must be built before the source code
# -----------------------------------------------

$(SOURCES_C) $(SOURCES_CPP): $(HEADERS_ASSETS)

# Include dependency files if they exist
# --------------------------------------

-include $(DEPS)
