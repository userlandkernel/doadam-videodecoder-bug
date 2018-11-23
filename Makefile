IOS_SDK_VERSION =
CC_BIN = $(shell xcrun --sdk iphoneos --find clang++)
XCODE_PATH = $(shell xcode-select --print-path)
IOS_SDK = $(XCODE_PATH)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(IOS_SDK_VERSION).sdk
OBJS = heap_spray.o iosurface_utils.o log.o video_decoder.o
BIN = d5500_poc
CC = $(CC_BIN) -g -arch arm64 -isysroot $(IOS_SDK) -ObjC -Wall -I.

all: $(OBJS)
	$(CC) -fno-strict-aliasing -Wno-format \
                -miphoneos-version-min=9.0 $(OBJS) \
                main.m -o $(BIN) \
                -F$(IOS_SDK)/System/Library/Frameworks \
		-stdlib=libc++ \
		-framework Foundation \
		-framework IOKit \
		-framework CoreMedia \
		-framework CoreVideo \
		-framework VideoToolbox \
		-framework IOSurface \
                -framework IOKit -lobjc
clean:
	rm -rf $(BIN) $(BIN).dSYM $(OBJS)

# EOF
