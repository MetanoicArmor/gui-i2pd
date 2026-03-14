# Compiler and basic flags
CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra -O2

# --- libsam3 Paths ---
SAM3_INC = -I./libsam3/src/libsam3
SAM3_A   = ./libsam3/libsam3.a

# FTXUI не используется в коде (опционально для будущего)
FTXUI_INC ?=
FTXUI_STATIC ?=

TARGET = termchat-i2p
SRC = termchat-i2p.cpp

# Standard system libraries; -static-libgcc/-static-libstdc++ are GCC-only (not supported on macOS/clang)
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  SYSTEM_LIBS = -lpthread
else
  SYSTEM_LIBS = -lpthread -static-libgcc -static-libstdc++
endif

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(SAM3_INC) $(FTXUI_INC) $(SRC) -o $(TARGET) \
	$(SAM3_A) $(FTXUI_STATIC) $(SYSTEM_LIBS)

clean:
	rm -f $(TARGET)

.PHONY: all clean

