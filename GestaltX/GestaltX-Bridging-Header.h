//
//  GestaltX-Bridging-Header.h
//  GestaltX
//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include "worse_query.h"

#import "GXEntitlementsReader.h"

#import "GXMobileGestaltImage.h"

NSArray<NSString *> * _Nullable GXContainerPaths(uint64_t maximumInode, BOOL (^ _Nonnull shouldContinue)(uint64_t));
#import "GXDeviceIdentity.h"
#import "GXCustomizationAccess.h"

// Native device console (gx_device_console). Declarations only; the symbols are
// linked when the app is built with the GXDEVICECONSOLE compilation condition and
// the GXDeviceConsole xcframework. See Native/DeviceConsole/INTEGRATION.md.
#import "GXDeviceConsole.h"
