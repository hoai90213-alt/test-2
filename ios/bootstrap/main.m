#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef int (*zd_init_fn_t)(void);
typedef void (*zd_start_game_fn_t)(const char* game_dir_path,
                                   const char* library_dir_path,
                                   int jvm_argc,
                                   const char** jvm_argv,
                                   const char* main_class_name,
                                   int argc,
                                   const char** argv);

typedef struct {
  int argc;
  char** argv;
} ZDCStringArray;

typedef struct {
  zd_start_game_fn_t start_game;
  char* game_dir;
  char* library_dir;
  int jvm_argc;
  char** jvm_argv;
  char* main_class;
  int app_argc;
  char** app_argv;
} ZDLaunchContext;

typedef NS_ENUM(NSInteger, ZDImportTarget) {
  ZDImportTargetNone = 0,
  ZDImportTargetGame = 1,
  ZDImportTargetDeps = 2,
  ZDImportTargetRuntime = 3,
};

static NSString* ZDFrameworksPath(void) {
  return [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks"];
}

static NSString* ZDDocumentsPath(void) {
  NSArray<NSString*>* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  return paths.firstObject ?: NSHomeDirectory();
}

static NSString* ZDBasePath(void) {
  return [ZDDocumentsPath() stringByAppendingPathComponent:@"zomdroid"];
}

static NSString* ZDGamePath(void) {
  return [ZDBasePath() stringByAppendingPathComponent:@"game"];
}

static NSString* ZDDepsPath(void) {
  return [ZDBasePath() stringByAppendingPathComponent:@"deps"];
}

static NSString* ZDConfigPath(void) {
  return [ZDBasePath() stringByAppendingPathComponent:@"config"];
}

static NSString* ZDRuntimePath(void) {
  return [ZDBasePath() stringByAppendingPathComponent:@"runtime"];
}

static BOOL ZDFileExists(NSString* path) {
  return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

static void ZDEnsureDirectory(NSString* path) {
  [[NSFileManager defaultManager] createDirectoryAtPath:path
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
}

static void ZDWriteFileIfMissing(NSString* path, NSString* content) {
  if (ZDFileExists(path)) {
    return;
  }
  [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static void ZDEnsureFilesystemLayout(void) {
  NSString* basePath = ZDBasePath();
  NSString* gamePath = ZDGamePath();
  NSString* depsPath = ZDDepsPath();
  NSString* runtimePath = ZDRuntimePath();
  NSString* configPath = ZDConfigPath();
  NSString* homePath = [basePath stringByAppendingPathComponent:@"home"];
  NSString* cachePath = [basePath stringByAppendingPathComponent:@"cache"];
  NSString* jarsPath = [depsPath stringByAppendingPathComponent:@"jars"];

  ZDEnsureDirectory(basePath);
  ZDEnsureDirectory(gamePath);
  ZDEnsureDirectory(depsPath);
  ZDEnsureDirectory(configPath);
  ZDEnsureDirectory(runtimePath);
  ZDEnsureDirectory(homePath);
  ZDEnsureDirectory(cachePath);
  ZDEnsureDirectory(jarsPath);

  NSString* readmePath = [basePath stringByAppendingPathComponent:@"README.txt"];
  NSString* readmeText =
      @"Copy game files to ./game\n"
      "Copy dependencies to ./deps (libs, jars)\n"
      "Copy iOS Java runtime (Mach-O) to ./runtime\n"
      "Optional config files in ./config: main_class.txt, jvm_args.txt, app_args.txt\n";
  ZDWriteFileIfMissing(readmePath, readmeText);
}

static NSString* ZDDirectoryStateLine(NSString* path) {
  BOOL isDir = NO;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
  return [NSString stringWithFormat:@"%@ => %@",
                                    path,
                                    (exists && isDir) ? @"ok" : @"missing"];
}

static NSString* ZDFilesystemStatus(void) {
  NSArray<NSString*>* lines = @[
    ZDDirectoryStateLine(ZDBasePath()),
    ZDDirectoryStateLine(ZDGamePath()),
    ZDDirectoryStateLine(ZDDepsPath()),
    ZDDirectoryStateLine(ZDConfigPath()),
    ZDDirectoryStateLine(ZDRuntimePath()),
    ZDDirectoryStateLine([ZDBasePath() stringByAppendingPathComponent:@"home"]),
    ZDDirectoryStateLine([ZDBasePath() stringByAppendingPathComponent:@"cache"]),
  ];
  return [lines componentsJoinedByString:@"\n"];
}

static NSArray<NSString*>* ZDReadLines(NSString* path) {
  if (!ZDFileExists(path)) {
    return @[];
  }

  NSError* error = nil;
  NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
  if (content == nil || error != nil) {
    return @[];
  }

  NSMutableArray<NSString*>* lines = [NSMutableArray array];
  for (NSString* rawLine in [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
    NSString* trimmed = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length > 0) {
      [lines addObject:trimmed];
    }
  }
  return lines;
}

static NSString* ZDReadFirstLine(NSString* path, NSString* fallback) {
  NSArray<NSString*>* lines = ZDReadLines(path);
  if (lines.count > 0) {
    return lines.firstObject;
  }
  return fallback;
}

static NSArray<NSString*>* ZDListJarFiles(NSString* directoryPath) {
  NSError* error = nil;
  NSArray<NSString*>* entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:&error];
  if (entries == nil || error != nil) {
    return @[];
  }

  NSMutableArray<NSString*>* jars = [NSMutableArray array];
  for (NSString* entry in entries) {
    if ([entry.pathExtension.lowercaseString isEqualToString:@"jar"]) {
      [jars addObject:[directoryPath stringByAppendingPathComponent:entry]];
    }
  }
  return jars;
}

static NSString* ZDNormalizeMainClassPath(NSString* mainClassName) {
  if (mainClassName == nil || mainClassName.length == 0) {
    return @"zombie/gameStates/MainScreenState";
  }
  return [mainClassName stringByReplacingOccurrencesOfString:@"." withString:@"/"];
}

static BOOL ZDHasSuffixCaseInsensitive(NSString* value, NSString* suffix) {
  if (value == nil || suffix == nil || value.length < suffix.length) {
    return NO;
  }
  return [value.lowercaseString hasSuffix:suffix.lowercaseString];
}

static NSString* ZDResolveCandidateRootFromRelativeClassPath(NSString* searchRoot,
                                                             NSString* relativePath,
                                                             NSString* classFileRelativePath) {
  if (!ZDHasSuffixCaseInsensitive(relativePath, classFileRelativePath)) {
    return nil;
  }

  NSString* candidateRoot = searchRoot;
  if (relativePath.length > classFileRelativePath.length) {
    NSUInteger prefixLength = relativePath.length - classFileRelativePath.length;
    NSString* prefix = [relativePath substringToIndex:prefixLength];
    prefix = [prefix stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    if (prefix.length > 0) {
      candidateRoot = [searchRoot stringByAppendingPathComponent:prefix];
    }
  }
  return candidateRoot;
}

static NSString* ZDResolveGameRoot(NSString* baseGamePath,
                                   NSString* mainClassRelativePath,
                                   NSMutableArray<NSString*>* lines) {
  NSString* classFileRelativePath = [mainClassRelativePath stringByAppendingString:@".class"];
  NSString* directClassFile = [baseGamePath stringByAppendingPathComponent:classFileRelativePath];
  if (ZDFileExists(directClassFile)) {
    return baseGamePath;
  }

  NSDirectoryEnumerator<NSString*>* enumerator =
      [[NSFileManager defaultManager] enumeratorAtPath:baseGamePath];
  for (NSString* relativePath in enumerator) {
    if ([relativePath.lastPathComponent caseInsensitiveCompare:@"MainScreenState.class"] != NSOrderedSame) {
      continue;
    }

    NSString* candidateRoot = ZDResolveCandidateRootFromRelativeClassPath(baseGamePath,
                                                                          relativePath,
                                                                          classFileRelativePath);
    if (candidateRoot != nil) {
      [lines addObject:[NSString stringWithFormat:@"[ok] Auto-detected game root: %@", candidateRoot]];
      return candidateRoot;
    }

    NSString* looseRoot = [baseGamePath stringByAppendingPathComponent:[relativePath stringByDeletingLastPathComponent]];
    if (looseRoot.length > 0) {
      [lines addObject:[NSString stringWithFormat:@"[ok] Auto-detected loose class match: %@", looseRoot]];
      return looseRoot;
    }
  }

  return nil;
}

static NSString* ZDFindGameRootContainingClass(NSString* searchRoot,
                                               NSString* mainClassRelativePath,
                                               NSMutableArray<NSString*>* lines,
                                               NSString* label) {
  if (searchRoot == nil || searchRoot.length == 0) {
    return nil;
  }

  NSString* classFileRelativePath = [mainClassRelativePath stringByAppendingString:@".class"];
  NSDirectoryEnumerator<NSString*>* enumerator =
      [[NSFileManager defaultManager] enumeratorAtPath:searchRoot];
  for (NSString* relativePath in enumerator) {
    if ([relativePath.lastPathComponent caseInsensitiveCompare:@"MainScreenState.class"] != NSOrderedSame) {
      continue;
    }

    NSString* candidateRoot = ZDResolveCandidateRootFromRelativeClassPath(searchRoot,
                                                                          relativePath,
                                                                          classFileRelativePath);
    if (candidateRoot != nil) {
      if (label.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"[ok] Fallback located game root in %@: %@", label, candidateRoot]];
      } else {
        [lines addObject:[NSString stringWithFormat:@"[ok] Fallback located game root: %@", candidateRoot]];
      }
      return candidateRoot;
    }

    NSString* looseRoot = [searchRoot stringByAppendingPathComponent:[relativePath stringByDeletingLastPathComponent]];
    if (looseRoot.length > 0) {
      if (label.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"[ok] Fallback loose class match in %@: %@", label, looseRoot]];
      } else {
        [lines addObject:[NSString stringWithFormat:@"[ok] Fallback loose class match: %@", looseRoot]];
      }
      return looseRoot;
    }
  }

  return nil;
}

static ZDCStringArray ZDMakeCStringArray(NSArray<NSString*>* strings) {
  ZDCStringArray result;
  result.argc = (int)strings.count;
  result.argv = NULL;

  if (result.argc <= 0) {
    return result;
  }

  result.argv = (char**)calloc((size_t)result.argc, sizeof(char*));
  if (result.argv == NULL) {
    result.argc = 0;
    return result;
  }

  for (int i = 0; i < result.argc; ++i) {
    result.argv[i] = strdup(strings[(NSUInteger)i].UTF8String);
  }
  return result;
}

static void ZDFreeCStringArray(int argc, char** argv) {
  if (argv == NULL) {
    return;
  }
  for (int i = 0; i < argc; ++i) {
    free(argv[i]);
  }
  free(argv);
}

static void ZDFreeLaunchContext(ZDLaunchContext* context) {
  if (context == NULL) {
    return;
  }
  free(context->game_dir);
  free(context->library_dir);
  free(context->main_class);
  ZDFreeCStringArray(context->jvm_argc, context->jvm_argv);
  ZDFreeCStringArray(context->app_argc, context->app_argv);
  free(context);
}

static void ZDSetEnv(NSString* key, NSString* value) {
  if (key.length == 0 || value.length == 0) {
    return;
  }
  setenv(key.UTF8String, value.UTF8String, 1);
}

static NSString* ZDReadMagicHex4(NSString* path) {
  NSData* data = [NSData dataWithContentsOfFile:path options:0 error:nil];
  if (data == nil || data.length < 4) {
    return @"????";
  }
  const uint8_t* bytes = (const uint8_t*)data.bytes;
  return [NSString stringWithFormat:@"%02X-%02X-%02X-%02X", bytes[0], bytes[1], bytes[2], bytes[3]];
}

static BOOL ZDIsLikelyMachOFile(NSString* path) {
  NSData* data = [NSData dataWithContentsOfFile:path options:0 error:nil];
  if (data == nil || data.length < 4) {
    return NO;
  }
  const uint8_t* b = (const uint8_t*)data.bytes;
  uint32_t m = ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) | ((uint32_t)b[2] << 8) | ((uint32_t)b[3]);
  switch (m) {
    case 0xFEEDFACEu:
    case 0xCEFAEDFEu:
    case 0xFEEDFACFu:
    case 0xCFFAEDFEu:
    case 0xCAFEBABEu:
    case 0xBEBAFECAu:
    case 0xCAFEBABFu:
    case 0xBFBAFECAu:
      return YES;
    default:
      return NO;
  }
}

static NSArray<NSString*>* ZDJvmCandidatePaths(void) {
  return @[
    [ZDRuntimePath() stringByAppendingPathComponent:@"lib/server/libjvm.dylib"],
    [ZDRuntimePath() stringByAppendingPathComponent:@"lib/libjvm.dylib"],
    [ZDDepsPath() stringByAppendingPathComponent:@"jre/lib/server/libjvm.dylib"],
    [ZDDepsPath() stringByAppendingPathComponent:@"jre/lib/server/libjvm.so"],
  ];
}

static NSString* ZDFindJvmLibraryPath(NSMutableArray<NSString*>* lines) {
  for (NSString* candidate in ZDJvmCandidatePaths()) {
    if (!ZDFileExists(candidate)) {
      continue;
    }
    NSString* magic = ZDReadMagicHex4(candidate);
    if (ZDIsLikelyMachOFile(candidate)) {
      if (lines != nil) {
        [lines addObject:[NSString stringWithFormat:@"[ok] JVM candidate accepted: %@ (magic=%@)", candidate, magic]];
      }
      return candidate;
    }
    if (lines != nil) {
      [lines addObject:[NSString stringWithFormat:@"[warn] JVM candidate rejected (not Mach-O): %@ (magic=%@)", candidate, magic]];
    }
  }
  return nil;
}

static NSString* ZDRuntimeReadinessSummary(void) {
  NSMutableArray<NSString*>* lines = [NSMutableArray array];
  NSString* jvmPath = ZDFindJvmLibraryPath(lines);
  if (jvmPath == nil) {
    [lines addObject:[NSString stringWithFormat:@"runtimeDir=%@", ZDRuntimePath()]];
    [lines addObject:@"status=missing_valid_macho_jvm"];
  } else {
    [lines addObject:@"status=ready"];
  }
  return [lines componentsJoinedByString:@"\n"];
}

static BOOL ZDClearDirectoryContents(NSString* directoryPath, NSError** error) {
  NSFileManager* fileManager = [NSFileManager defaultManager];
  [fileManager createDirectoryAtPath:directoryPath
         withIntermediateDirectories:YES
                          attributes:nil
                               error:error];
  if (error != nil && *error != nil) {
    return NO;
  }

  NSArray<NSString*>* entries = [fileManager contentsOfDirectoryAtPath:directoryPath error:error];
  if (entries == nil) {
    return NO;
  }
  for (NSString* entry in entries) {
    NSString* path = [directoryPath stringByAppendingPathComponent:entry];
    if (![fileManager removeItemAtPath:path error:error]) {
      return NO;
    }
  }
  return YES;
}

static BOOL ZDImportFolderFromURLToPath(NSURL* sourceURL,
                                        NSString* destinationPath,
                                        NSString* label,
                                        NSMutableArray<NSString*>* lines,
                                        NSError** outError) {
  if (sourceURL == nil || destinationPath == nil || destinationPath.length == 0) {
    if (outError != nil) {
      *outError = [NSError errorWithDomain:@"ZomdroidImport"
                                      code:1
                                  userInfo:@{NSLocalizedDescriptionKey : @"Invalid import source or destination"}];
    }
    return NO;
  }

  BOOL securityScope = [sourceURL startAccessingSecurityScopedResource];
  @try {
    NSError* clearError = nil;
    if (!ZDClearDirectoryContents(destinationPath, &clearError)) {
      if (outError != nil) {
        *outError = clearError;
      }
      return NO;
    }

    NSFileManager* fileManager = [NSFileManager defaultManager];
    __block NSError* copyError = nil;
    __block NSUInteger fileCount = 0;
    __block NSUInteger dirCount = 0;
    NSFileCoordinator* coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    NSError* coordinatorError = nil;
    [coordinator coordinateReadingItemAtURL:sourceURL
                                    options:NSFileCoordinatorReadingWithoutChanges
                                      error:&coordinatorError
                                 byAccessor:^(NSURL* newURL) {
      NSString* basePath = newURL.path;
      NSDirectoryEnumerator<NSURL*>* enumerator =
          [fileManager enumeratorAtURL:newURL
             includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                options:0
                           errorHandler:^BOOL(NSURL* url, NSError* error) {
        (void)url;
        copyError = error;
        return NO;
      }];

      for (NSURL* itemURL in enumerator) {
        NSNumber* isDirectory = nil;
        [itemURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        NSString* itemPath = itemURL.path;
        if (itemPath.length <= basePath.length) {
          continue;
        }
        NSString* relativePath = [itemPath substringFromIndex:basePath.length];
        if ([relativePath hasPrefix:@"/"]) {
          relativePath = [relativePath substringFromIndex:1];
        }
        if (relativePath.length == 0) {
          continue;
        }

        NSString* destinationItemPath = [destinationPath stringByAppendingPathComponent:relativePath];
        if (isDirectory.boolValue) {
          if (![fileManager createDirectoryAtPath:destinationItemPath
                      withIntermediateDirectories:YES
                                       attributes:nil
                                            error:&copyError]) {
            break;
          }
          dirCount += 1;
          continue;
        }

        NSString* parentPath = [destinationItemPath stringByDeletingLastPathComponent];
        if (![fileManager createDirectoryAtPath:parentPath
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&copyError]) {
          break;
        }
        if ([fileManager fileExistsAtPath:destinationItemPath]) {
          [fileManager removeItemAtPath:destinationItemPath error:nil];
        }
        if (![fileManager copyItemAtURL:itemURL
                                  toURL:[NSURL fileURLWithPath:destinationItemPath]
                                  error:&copyError]) {
          break;
        }
        fileCount += 1;
      }
    }];

    if (coordinatorError != nil) {
      if (outError != nil) {
        *outError = coordinatorError;
      }
      return NO;
    }
    if (copyError != nil) {
      if (outError != nil) {
        *outError = copyError;
      }
      return NO;
    }

    [lines addObject:[NSString stringWithFormat:@"[ok] Imported %@ to %@", label ?: @"folder", destinationPath]];
    [lines addObject:[NSString stringWithFormat:@"[ok] created_dirs=%lu copied_files=%lu",
                                                (unsigned long)dirCount,
                                                (unsigned long)fileCount]];
    return YES;
  } @finally {
    if (securityScope) {
      [sourceURL stopAccessingSecurityScopedResource];
    }
  }
}

static NSString* ZDProbeRuntimeLibraries(void) {
  NSArray<NSString*>* libraryNames = @[
    @"libbox64.dylib",
    @"libzomdroid.dylib",
    @"libzomdroidlinker.dylib",
  ];

  NSString* frameworksPath = ZDFrameworksPath();
  NSMutableArray<NSString*>* statusLines = [NSMutableArray array];

  for (NSString* name in libraryNames) {
    NSString* fullPath = [frameworksPath stringByAppendingPathComponent:name];
    if (!ZDFileExists(fullPath)) {
      [statusLines addObject:[NSString stringWithFormat:@"%@: missing", name]];
      continue;
    }

    void* handle = dlopen(fullPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
    if (handle != NULL) {
      [statusLines addObject:[NSString stringWithFormat:@"%@: loaded", name]];
    } else {
      const char* err = dlerror();
      NSString* errText = err ? @(err) : @"unknown error";
      [statusLines addObject:[NSString stringWithFormat:@"%@: failed (%@)", name, errText]];
    }
  }

  return [statusLines componentsJoinedByString:@"\n"];
}

static NSString* ZDPrepareAndLaunchRuntime(void) {
  NSMutableArray<NSString*>* lines = [NSMutableArray array];

  ZDEnsureFilesystemLayout();

  NSString* frameworksPath = ZDFrameworksPath();
  NSString* gamePath = ZDGamePath();
  NSString* depsPath = ZDDepsPath();
  NSString* runtimePath = ZDRuntimePath();
  NSString* configPath = ZDConfigPath();
  NSString* homePath = [ZDBasePath() stringByAppendingPathComponent:@"home"];
  NSString* cachePath = [ZDBasePath() stringByAppendingPathComponent:@"cache"];
  NSString* linuxLibPath = [depsPath stringByAppendingPathComponent:@"libs/linux-x86_64"];
  NSString* javaLibPathLwjgl = [depsPath stringByAppendingPathComponent:@"libs/android-arm64-v8a/lwjgl-3.3.6"];
  NSString* javaLibPathFmod = [depsPath stringByAppendingPathComponent:@"libs/android-arm64-v8a/fmod-2.02.24"];
  NSString* runtimeLibPath = [runtimePath stringByAppendingPathComponent:@"lib"];
  NSString* runtimeServerLibPath = [runtimeLibPath stringByAppendingPathComponent:@"server"];
  NSString* linkerLibPath = [frameworksPath stringByAppendingPathComponent:@"libzomdroidlinker.dylib"];
  NSString* librarySearchPath = [NSString stringWithFormat:@"%@:%@:%@:%@:%@:%@",
                                 frameworksPath,
                                 linuxLibPath,
                                 runtimeLibPath,
                                 runtimeServerLibPath,
                                 [depsPath stringByAppendingPathComponent:@"jre/lib"],
                                 [depsPath stringByAppendingPathComponent:@"jre/lib/server"]];

  NSArray<NSString*>* requiredLibraries = @[
    @"libbox64.dylib",
    @"libzomdroid.dylib",
    @"libzomdroidlinker.dylib",
  ];

  void* zomdroidHandle = NULL;
  for (NSString* libName in requiredLibraries) {
    NSString* fullPath = [frameworksPath stringByAppendingPathComponent:libName];
    if (!ZDFileExists(fullPath)) {
      [lines addObject:[NSString stringWithFormat:@"[error] Missing %@", fullPath]];
      return [lines componentsJoinedByString:@"\n"];
    }
    void* handle = dlopen(fullPath.UTF8String, RTLD_NOW | RTLD_GLOBAL);
    if (handle == NULL) {
      const char* err = dlerror();
      [lines addObject:[NSString stringWithFormat:@"[error] dlopen %@ failed: %s", libName, err ? err : "unknown"]];
      return [lines componentsJoinedByString:@"\n"];
    }
    if ([libName isEqualToString:@"libzomdroid.dylib"]) {
      zomdroidHandle = handle;
    }
  }

  if (zomdroidHandle == NULL) {
    [lines addObject:@"[error] libzomdroid.dylib handle not found"];
    return [lines componentsJoinedByString:@"\n"];
  }

  zd_init_fn_t zomdroidInit = (zd_init_fn_t)dlsym(zomdroidHandle, "zomdroid_init");
  zd_start_game_fn_t zomdroidStartGame = (zd_start_game_fn_t)dlsym(zomdroidHandle, "zomdroid_start_game");
  if (zomdroidInit == NULL || zomdroidStartGame == NULL) {
    const char* err = dlerror();
    [lines addObject:[NSString stringWithFormat:@"[error] dlsym failed: %s", err ? err : "unknown"]];
    return [lines componentsJoinedByString:@"\n"];
  }

  ZDSetEnv(@"LIBGL_MIPMAP", @"1");
  ZDSetEnv(@"BOX64_LOG", @"1");
  ZDSetEnv(@"BOX64_SHOWBT", @"1");
  ZDSetEnv(@"BOX64_LD_LIBRARY_PATH", [NSString stringWithFormat:@"%@:.", linuxLibPath]);

  ZDSetEnv(@"ZOMDROID_CACHE_DIR", cachePath);
  ZDSetEnv(@"ZOMDROID_RENDERER", @"GL4ES");
  ZDSetEnv(@"ZOMDROID_LIBRARY_DIR", librarySearchPath);
  ZDSetEnv(@"ZOMDROID_LINKER_LIB", linkerLibPath);
  NSString* selectedJvmPath = ZDFindJvmLibraryPath(lines);
  if (selectedJvmPath == nil) {
    [lines addObject:@"[error] Missing valid iOS JVM (Mach-O libjvm.dylib)."];
    [lines addObject:[NSString stringWithFormat:@"[hint] Import runtime folder to %@", runtimePath]];
    return [lines componentsJoinedByString:@"\n"];
  }
  ZDSetEnv(@"ZOMDROID_JVM_LIB", selectedJvmPath);

  NSString* mainClass = ZDReadFirstLine([configPath stringByAppendingPathComponent:@"main_class.txt"],
                                        @"zombie/gameStates/MainScreenState");
  NSString* mainClassRelativePath = ZDNormalizeMainClassPath(mainClass);
  NSString* resolvedGamePath = ZDResolveGameRoot(gamePath, mainClassRelativePath, lines);
  if (resolvedGamePath == nil) {
    resolvedGamePath = ZDFindGameRootContainingClass(ZDBasePath(), mainClassRelativePath, lines, @"zomdroid");
  }
  if (resolvedGamePath == nil) {
    resolvedGamePath = ZDFindGameRootContainingClass(ZDDocumentsPath(), mainClassRelativePath, lines, @"Documents");
  }

  NSString* mainClassFile = [gamePath stringByAppendingPathComponent:[mainClassRelativePath stringByAppendingString:@".class"]];
  if (resolvedGamePath != nil) {
    mainClassFile = [resolvedGamePath stringByAppendingPathComponent:[mainClassRelativePath stringByAppendingString:@".class"]];
  }
  if (!ZDFileExists(mainClassFile)) {
    [lines addObject:[NSString stringWithFormat:@"[error] Missing main class file: %@", mainClassFile]];
    [lines addObject:[NSString stringWithFormat:@"[debug] searched game=%@ base=%@ documents=%@",
                                                gamePath,
                                                ZDBasePath(),
                                                ZDDocumentsPath()]];
    NSMutableArray<NSString*>* classMatches = [NSMutableArray array];
    NSDirectoryEnumerator<NSString*>* allDocsEnumerator =
        [[NSFileManager defaultManager] enumeratorAtPath:ZDDocumentsPath()];
    for (NSString* relativePath in allDocsEnumerator) {
      if ([relativePath.lastPathComponent caseInsensitiveCompare:@"MainScreenState.class"] == NSOrderedSame) {
        [classMatches addObject:[ZDDocumentsPath() stringByAppendingPathComponent:relativePath]];
        if (classMatches.count >= 5) {
          break;
        }
      }
    }
    if (classMatches.count > 0) {
      [lines addObject:[NSString stringWithFormat:@"[debug] found MainScreenState.class at: %@", [classMatches componentsJoinedByString:@" | "]]];
    } else {
      [lines addObject:@"[debug] no MainScreenState.class found under Documents"];
    }
    NSError* listError = nil;
    NSArray<NSString*>* gameEntries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:gamePath error:&listError];
    if (gameEntries != nil && listError == nil && gameEntries.count > 0) {
      NSUInteger previewCount = gameEntries.count < 8 ? gameEntries.count : 8;
      NSArray<NSString*>* preview = [gameEntries subarrayWithRange:NSMakeRange(0, previewCount)];
      [lines addObject:[NSString stringWithFormat:@"[debug] game entries (%lu total): %@",
                                                  (unsigned long)gameEntries.count,
                                                  [preview componentsJoinedByString:@", "]]];
    }
    [lines addObject:@"Hint: if you copied the whole folder, keep contents directly in game/ or let app auto-detect one nested folder."];
    return [lines componentsJoinedByString:@"\n"];
  }

  int initResult = zomdroidInit();
  if (initResult != 0) {
    [lines addObject:[NSString stringWithFormat:@"[error] zomdroid_init failed: %d", initResult]];
    return [lines componentsJoinedByString:@"\n"];
  }

  NSMutableArray<NSString*>* classPathParts = [NSMutableArray arrayWithObject:@"."];
  [classPathParts addObjectsFromArray:ZDListJarFiles(resolvedGamePath ?: gamePath)];
  [classPathParts addObjectsFromArray:ZDListJarFiles([depsPath stringByAppendingPathComponent:@"jars"])];
  NSString* classPath = [classPathParts componentsJoinedByString:@":"];

  NSMutableArray<NSString*>* jvmArgs = [NSMutableArray array];
  [jvmArgs addObject:[NSString stringWithFormat:@"-Duser.home=%@", homePath]];
  [jvmArgs addObject:[NSString stringWithFormat:@"-Djava.io.tmpdir=%@", cachePath]];
  [jvmArgs addObject:[NSString stringWithFormat:@"-Djava.library.path=%@:%@:%@:%@:.",
                                                runtimeLibPath,
                                                runtimeServerLibPath,
                                                javaLibPathLwjgl,
                                                javaLibPathFmod]];
  [jvmArgs addObject:[NSString stringWithFormat:@"-Djava.class.path=%@", classPath]];
  [jvmArgs addObject:@"-Dorg.lwjgl.opengl.libname=libGL.so.1"];
  [jvmArgs addObject:@"-Dzomdroid.renderer=GL4ES"];
  [jvmArgs addObject:@"-XX:ErrorFile=/dev/stdout"];
  [jvmArgs addObjectsFromArray:ZDReadLines([configPath stringByAppendingPathComponent:@"jvm_args.txt"])];

  NSMutableArray<NSString*>* appArgs = [NSMutableArray arrayWithObject:@"-novoip"];
  [appArgs addObjectsFromArray:ZDReadLines([configPath stringByAppendingPathComponent:@"app_args.txt"])];

  ZDCStringArray jvmCStringArray = ZDMakeCStringArray(jvmArgs);
  ZDCStringArray appCStringArray = ZDMakeCStringArray(appArgs);
  if ((jvmArgs.count > 0 && jvmCStringArray.argv == NULL) || (appArgs.count > 0 && appCStringArray.argv == NULL)) {
    ZDFreeCStringArray(jvmCStringArray.argc, jvmCStringArray.argv);
    ZDFreeCStringArray(appCStringArray.argc, appCStringArray.argv);
    [lines addObject:@"[error] Failed to allocate launch arguments"];
    return [lines componentsJoinedByString:@"\n"];
  }

  ZDLaunchContext* context = (ZDLaunchContext*)calloc(1, sizeof(ZDLaunchContext));
  if (context == NULL) {
    ZDFreeCStringArray(jvmCStringArray.argc, jvmCStringArray.argv);
    ZDFreeCStringArray(appCStringArray.argc, appCStringArray.argv);
    [lines addObject:@"[error] Failed to allocate launch context"];
    return [lines componentsJoinedByString:@"\n"];
  }

  context->start_game = zomdroidStartGame;
  context->game_dir = strdup((resolvedGamePath ?: gamePath).UTF8String);
  context->library_dir = strdup(librarySearchPath.UTF8String);
  context->main_class = strdup(mainClass.UTF8String);
  context->jvm_argc = jvmCStringArray.argc;
  context->jvm_argv = jvmCStringArray.argv;
  context->app_argc = appCStringArray.argc;
  context->app_argv = appCStringArray.argv;

  if (context->game_dir == NULL || context->library_dir == NULL || context->main_class == NULL) {
    ZDFreeLaunchContext(context);
    [lines addObject:@"[error] Failed to copy launch strings"];
    return [lines componentsJoinedByString:@"\n"];
  }

  [lines addObject:[NSString stringWithFormat:@"[ok] gameDir=%@", resolvedGamePath ?: gamePath]];
  [lines addObject:[NSString stringWithFormat:@"[ok] depsDir=%@", depsPath]];
  [lines addObject:[NSString stringWithFormat:@"[ok] mainClass=%@", mainClass]];
  [lines addObject:[NSString stringWithFormat:@"[ok] jvmArgs=%d appArgs=%d", context->jvm_argc, context->app_argc]];
  [lines addObject:@"[ok] start_game dispatched on background thread"];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    context->start_game(context->game_dir,
                        context->library_dir,
                        context->jvm_argc,
                        (const char**)context->jvm_argv,
                        context->main_class,
                        context->app_argc,
                        (const char**)context->app_argv);
    ZDFreeLaunchContext(context);
  });

  return [lines componentsJoinedByString:@"\n"];
}

@interface ZDAppDelegate : UIResponder <UIApplicationDelegate, UIDocumentPickerDelegate>
@property(nonatomic, strong) UIWindow* window;
@property(nonatomic, strong) UITextView* statusView;
@property(nonatomic, strong) UIButton* launchButton;
@property(nonatomic, strong) UIButton* importGameButton;
@property(nonatomic, strong) UIButton* importDepsButton;
@property(nonatomic, strong) UIButton* importRuntimeButton;
@property(nonatomic, strong) UIViewController* rootViewController;
@property(nonatomic, assign) ZDImportTarget pendingImportTarget;
@end

@implementation ZDAppDelegate

- (void)appendStatus:(NSString*)text {
  NSString* previous = self.statusView.text ?: @"";
  if (previous.length == 0) {
    self.statusView.text = text ?: @"";
  } else {
    self.statusView.text = [NSString stringWithFormat:@"%@\n\n%@", previous, text ?: @""];
  }
}

- (void)setControlsEnabled:(BOOL)enabled {
  self.launchButton.enabled = enabled;
  self.importGameButton.enabled = enabled;
  self.importDepsButton.enabled = enabled;
  self.importRuntimeButton.enabled = enabled;
}

- (void)presentFolderPickerForTarget:(ZDImportTarget)target {
  self.pendingImportTarget = target;
  UIDocumentPickerViewController* picker =
      [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.folder"]
                                                             inMode:UIDocumentPickerModeOpen];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self.rootViewController presentViewController:picker animated:YES completion:nil];
}

- (void)onImportGameTapped {
  [self appendStatus:@"Select GAME folder in Files..."];
  [self presentFolderPickerForTarget:ZDImportTargetGame];
}

- (void)onImportDepsTapped {
  [self appendStatus:@"Select DEPS folder in Files..."];
  [self presentFolderPickerForTarget:ZDImportTargetDeps];
}

- (void)onImportRuntimeTapped {
  [self appendStatus:@"Select RUNTIME folder in Files (must contain Mach-O libjvm.dylib)..."];
  [self presentFolderPickerForTarget:ZDImportTargetRuntime];
}

- (void)onLaunchTapped {
  [self setControlsEnabled:NO];
  [self appendStatus:@"Launching runtime..."];
  ZDEnsureFilesystemLayout();
  [self appendStatus:[NSString stringWithFormat:@"Filesystem status:\n%@", ZDFilesystemStatus()]];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSString* launchResult = ZDPrepareAndLaunchRuntime();
    dispatch_async(dispatch_get_main_queue(), ^{
      [self appendStatus:launchResult];
      [self setControlsEnabled:YES];
    });
  });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller {
  (void)controller;
  self.pendingImportTarget = ZDImportTargetNone;
  [self appendStatus:@"[info] Import cancelled"];
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
  (void)controller;
  NSURL* selectedURL = urls.firstObject;
  ZDImportTarget target = self.pendingImportTarget;
  self.pendingImportTarget = ZDImportTargetNone;
  if (selectedURL == nil || target == ZDImportTargetNone) {
    [self appendStatus:@"[error] No folder selected"];
    return;
  }

  NSString* targetPath = nil;
  NSString* targetLabel = nil;
  if (target == ZDImportTargetGame) {
    targetPath = ZDGamePath();
    targetLabel = @"game";
  } else if (target == ZDImportTargetDeps) {
    targetPath = ZDDepsPath();
    targetLabel = @"deps";
  } else if (target == ZDImportTargetRuntime) {
    targetPath = ZDRuntimePath();
    targetLabel = @"runtime";
  }
  if (targetPath == nil) {
    [self appendStatus:@"[error] Unknown import target"];
    return;
  }

  [self appendStatus:[NSString stringWithFormat:@"Importing %@ from %@", targetLabel, selectedURL.path ?: selectedURL.absoluteString]];
  [self setControlsEnabled:NO];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSMutableArray<NSString*>* importLines = [NSMutableArray array];
    NSError* importError = nil;
    BOOL ok = ZDImportFolderFromURLToPath(selectedURL, targetPath, targetLabel, importLines, &importError);
    dispatch_async(dispatch_get_main_queue(), ^{
      if (ok) {
        [self appendStatus:[importLines componentsJoinedByString:@"\n"]];
        if (target == ZDImportTargetRuntime) {
          [self appendStatus:[NSString stringWithFormat:@"Runtime readiness:\n%@", ZDRuntimeReadinessSummary()]];
        }
      } else {
        NSString* errorText = importError.localizedDescription ?: @"unknown import error";
        [self appendStatus:[NSString stringWithFormat:@"[error] Import %@ failed: %@", targetLabel, errorText]];
      }
      [self appendStatus:[NSString stringWithFormat:@"Filesystem status:\n%@", ZDFilesystemStatus()]];
      [self setControlsEnabled:YES];
    });
  });
}

- (BOOL)application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  (void)application;
  (void)launchOptions;

  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

  UIViewController* rootViewController = [UIViewController new];
  rootViewController.view.backgroundColor = [UIColor systemBackgroundColor];
  self.rootViewController = rootViewController;

  UILabel* titleLabel = [UILabel new];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.numberOfLines = 0;
  titleLabel.textAlignment = NSTextAlignmentCenter;
  titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
  titleLabel.text = @"Zomdroid iOS Main Menu PoC";

  UIButton* launchButton = [UIButton buttonWithType:UIButtonTypeSystem];
  launchButton.translatesAutoresizingMaskIntoConstraints = NO;
  launchButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
  [launchButton setTitle:@"Launch Runtime" forState:UIControlStateNormal];
  [launchButton addTarget:self action:@selector(onLaunchTapped) forControlEvents:UIControlEventTouchUpInside];
  self.launchButton = launchButton;

  UIButton* importGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
  importGameButton.translatesAutoresizingMaskIntoConstraints = NO;
  importGameButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
  [importGameButton setTitle:@"Import Game Folder" forState:UIControlStateNormal];
  [importGameButton addTarget:self action:@selector(onImportGameTapped) forControlEvents:UIControlEventTouchUpInside];
  self.importGameButton = importGameButton;

  UIButton* importDepsButton = [UIButton buttonWithType:UIButtonTypeSystem];
  importDepsButton.translatesAutoresizingMaskIntoConstraints = NO;
  importDepsButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
  [importDepsButton setTitle:@"Import Deps Folder" forState:UIControlStateNormal];
  [importDepsButton addTarget:self action:@selector(onImportDepsTapped) forControlEvents:UIControlEventTouchUpInside];
  self.importDepsButton = importDepsButton;

  UIButton* importRuntimeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  importRuntimeButton.translatesAutoresizingMaskIntoConstraints = NO;
  importRuntimeButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
  [importRuntimeButton setTitle:@"Import Runtime Folder" forState:UIControlStateNormal];
  [importRuntimeButton addTarget:self action:@selector(onImportRuntimeTapped) forControlEvents:UIControlEventTouchUpInside];
  self.importRuntimeButton = importRuntimeButton;

  UITextView* statusView = [UITextView new];
  statusView.translatesAutoresizingMaskIntoConstraints = NO;
  statusView.editable = NO;
  statusView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  statusView.backgroundColor = [UIColor secondarySystemBackgroundColor];
  statusView.layer.cornerRadius = 10.0;
  self.statusView = statusView;

  [rootViewController.view addSubview:titleLabel];
  [rootViewController.view addSubview:importGameButton];
  [rootViewController.view addSubview:importDepsButton];
  [rootViewController.view addSubview:importRuntimeButton];
  [rootViewController.view addSubview:launchButton];
  [rootViewController.view addSubview:statusView];

  UILayoutGuide* guide = rootViewController.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [titleLabel.topAnchor constraintEqualToAnchor:guide.topAnchor constant:16.0],
    [titleLabel.centerXAnchor constraintEqualToAnchor:guide.centerXAnchor],
    [titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:guide.leadingAnchor constant:16.0],
    [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:guide.trailingAnchor constant:-16.0],

    [importGameButton.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],
    [importGameButton.centerXAnchor constraintEqualToAnchor:guide.centerXAnchor],

    [importDepsButton.topAnchor constraintEqualToAnchor:importGameButton.bottomAnchor constant:10.0],
    [importDepsButton.centerXAnchor constraintEqualToAnchor:guide.centerXAnchor],

    [importRuntimeButton.topAnchor constraintEqualToAnchor:importDepsButton.bottomAnchor constant:10.0],
    [importRuntimeButton.centerXAnchor constraintEqualToAnchor:guide.centerXAnchor],

    [launchButton.topAnchor constraintEqualToAnchor:importRuntimeButton.bottomAnchor constant:12.0],
    [launchButton.centerXAnchor constraintEqualToAnchor:guide.centerXAnchor],

    [statusView.topAnchor constraintEqualToAnchor:launchButton.bottomAnchor constant:12.0],
    [statusView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:12.0],
    [statusView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-12.0],
    [statusView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-12.0],
  ]];

  ZDEnsureFilesystemLayout();
  NSString* runtimeStatus = ZDProbeRuntimeLibraries();
  NSString* runtimeReadiness = ZDRuntimeReadinessSummary();
  NSString* documentsPath = ZDDocumentsPath();
  NSString* filesystemStatus = ZDFilesystemStatus();
  NSString* intro = [NSString stringWithFormat:
                     @"Documents=%@\nUse Import Game / Deps / Runtime before Launch.\n\nFilesystem status:\n%@\n\nRuntime readiness:\n%@\n\nRuntime probe:\n%@\n\nExpected paths:\n- %@\n- %@\n- %@\n- %@",
                     documentsPath,
                     filesystemStatus,
                     runtimeReadiness,
                     runtimeStatus,
                     ZDGamePath(),
                     ZDDepsPath(),
                     ZDConfigPath(),
                     ZDRuntimePath()];
  self.statusView.text = intro;

  self.window.rootViewController = rootViewController;
  [self.window makeKeyAndVisible];
  return YES;
}

@end

int main(int argc, char* argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([ZDAppDelegate class]));
  }
}
