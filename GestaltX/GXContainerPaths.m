/*
     pathleak - The dumbest arbitrary path enumeration.
     Copyright (C) 2026 Taj C (forcequit)

     This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with this program. If not, see <https://www.gnu.org/licenses/>.

     GestaltX adaptation (2026-11-10) of Erosion-CN pathleak.m:
     restricted to application data containers; bounded scan with cancellation.
*/
#import <Foundation/Foundation.h>
#include <sys/fsgetpath.h>
#include <sys/mount.h>
#include <string.h>
#include <limits.h>

NSArray<NSString *> *GXContainerPaths(uint64_t maximumInode, BOOL (^shouldContinue)(uint64_t)) {
    if (maximumInode < 1 || maximumInode > 30000000) return nil;
    struct statfs filesystem;
    if (statfs("/private/var", &filesystem) != 0) return nil;
    fsid_t identifier = filesystem.f_fsid;
    const char *prefix = "/var/mobile/Containers/Data/Application/";
    size_t prefixLength = strlen(prefix);
    NSMutableSet<NSString *> *paths = [NSMutableSet set];
    char buffer[PATH_MAX];
    for (uint64_t inode = 1; inode <= maximumInode; inode++) {
        if (inode % 16384 == 1 && !shouldContinue(inode)) return nil;
        ssize_t count = fsgetpath(buffer, sizeof(buffer), &identifier, inode);
        if (count <= 0) continue;
        char *path = buffer;
        if (strncmp(path, "/private/var/", 13) == 0) path += 8;
        if (strncmp(path, prefix, prefixLength) != 0) continue;
        if (strchr(path + prefixLength, '/')) continue;
        NSString *value = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:path length:strlen(path)];
        if (value && [[NSUUID alloc] initWithUUIDString:value.lastPathComponent]) [paths addObject:value];
    }
    if (!shouldContinue(maximumInode)) return nil;
    return paths.allObjects;
}