// SPDX-License-Identifier: GPL-3.0-only
#import "GXDeviceIdentity.h"
#import <sys/sysctl.h>

NSDictionary<NSString *, NSString *> *GXCopyPhysicalHardwareIdentity(void) {
    NSMutableDictionary *identity = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"hw.machine", @"hw.model"]) {
        char value[128] = {0};
        size_t size = sizeof(value);
        if (sysctlbyname(key.UTF8String, value, &size, NULL, 0) == 0 &&
            size > 1 && size <= sizeof(value) && value[size - 1] == '\0') {
            NSString *text = [NSString stringWithUTF8String:value];
            if (text.length > 0) identity[key] = text;
        }
    }
    return identity;
}
