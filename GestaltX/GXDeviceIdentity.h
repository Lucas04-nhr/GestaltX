// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

// The physical hardware model (hw.machine, hw.model) from sysctl, which a
// modified MobileGestalt cache cannot change. Only available answers are returned.
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> * _Nonnull GXCopyPhysicalHardwareIdentity(void);
