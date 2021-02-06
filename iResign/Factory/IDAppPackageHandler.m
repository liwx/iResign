//
//  ViewController.h
//  iResign
//
//  Created by liwx on 2021/2/5.
//


#import "IDAppPackageHandler.h"
#import "IDRunLoop.h"
#import "IDFileHelper.h"
#import "IDManualQueue.h"
#import "IDDateFormatterUtil.h"

@implementation IDAppPackageHandler {
    // blocks
    SuccessBlock successLocalBlock;
    ErrorBlock errorLocalBlock;
    LogBlock logLocalBlock;
    
    // blocks
    SuccessBlock successResignBlock;
    ErrorBlock errorResignBlock;
    LogBlock logResignBlock;
    
    // 全局文件管理
    NSFileManager *manager;
    // 创建 entitlements 任务的结果
    NSString *entitlementsResult;
    // codesign 任务结果
    NSString *codesigningResult;
    // codesign 验证任务的结果
    NSString *verificationResult;
}

@synthesize embeddedMobileprovision = _embeddedMobileprovision;

- (instancetype)initWithPackagePath:(NSString *)path {
    if (self == [super init]) {
        manager = [NSFileManager defaultManager];
        
        self.packagePath = path;
        
        NSString *dateString = [[IDDateFormatterUtil sharedFormatter] timestampForDate:[NSDate date]];
        self.workPath = [[[TEMP_PATH stringByAppendingPathComponent:@"unzip"] stringByAppendingPathComponent:[[self.packagePath lastPathComponent] stringByDeletingPathExtension]] stringByAppendingPathComponent:dateString];
    }
    return self;
}

#pragma mark - Utility
- (BOOL)removeWorkDirectory {
    BOOL success = FALSE;
    if (self.workPath != nil && [manager fileExistsAtPath:self.workPath]) {
        NSError *error = nil;
        success = [manager removeItemAtPath:self.workPath error:&error];
    }
    
    return success;
}

- (BOOL)removeCodeSignatureDirectory {
    BOOL success = NO;
    NSString* codeSignaturePath = [self.appPath stringByAppendingPathComponent:kCodeSignatureDirectory];
    
    if (codeSignaturePath != nil && [manager fileExistsAtPath:codeSignaturePath]) {
        NSError *error = nil;
        success = [manager removeItemAtPath:codeSignaturePath error:&error];
    } else if (![manager fileExistsAtPath:codeSignaturePath])
        success = YES;
    
    return success;
}

#pragma mark - Provisioning Profiles
- (NSString*)getEmbeddedProvisioningProfilePath {
    NSString *provisioningPath = nil;
    NSArray *provisioningProfiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.appPath error:nil];
    provisioningProfiles = [provisioningProfiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension IN %@", @[@"mobileprovision", @"provisionprofile"]]];
    for (NSString *path in provisioningProfiles) {
        BOOL isDirectory;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", self.appPath, path] isDirectory:&isDirectory])
            provisioningPath = [NSString stringWithFormat:@"%@/%@", self.appPath, path];
    }
    
    return provisioningPath;
}

- (void)editEmbeddedProvision:(IDProvisioningProfile *)provisioningprofile
                          log:(LogBlock)logBlock
                        error:(ErrorBlock)errorBlock
                      success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock) logLocalBlock(@"Generating Embedded.mobileprovision...");
    
    NSString *payloadPath = [self.workPath stringByAppendingPathComponent:kPayloadDirName];
    NSArray *payloadContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
    
    // 删除 embedded provisioning
    for (NSString *file in payloadContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            NSString *provisioningPath = [self getEmbeddedProvisioningProfilePath];
            if (provisioningPath != nil) {
                [[NSFileManager defaultManager] removeItemAtPath:provisioningPath error:nil];
            }
            break;
        }
    }
    
    NSString *targetPath = [[self.appPath stringByAppendingPathComponent:kEmbeddedProvisioningFilename] stringByAppendingPathExtension:@"mobileprovision"];
    if ([manager copyItemAtPath:provisioningprofile.path toPath:targetPath error:nil]) {
        if (successLocalBlock != nil)
            successLocalBlock(@"Successfully created Embedded.mobileprovision");
    }else{
        if (errorLocalBlock != nil)
            errorLocalBlock(@"Create new Embedded.mobileprovision failed.");
    }
    
}

#pragma mark - App Info
- (void)setAppPath {
    NSString *payloadPath = [self.workPath stringByAppendingPathComponent:kPayloadDirName];
    NSArray *payloadContents = [manager contentsOfDirectoryAtPath:payloadPath error:nil];
    
    [payloadContents enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *file = (NSString*)obj;
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            self.appPath = [[self.workPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
            *stop = YES;
        }
    }];
}

- (NSString *)bundleDisplayName {
    NSString* infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFilename];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:infoPlistPath]) {
        NSMutableDictionary* infoPlistDict = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistPath];
        NSString *displayName = infoPlistDict[kCFBundleDisplayName];
        if (displayName) {
            return displayName;
        } else {
            return @"\"CFBundleDisplayName\" is missing from the info.plist file.";
        }
    } else {
        return @"Not found info.plist";
    }
}

- (NSString *)bundleID {
    NSString* infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFilename];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:infoPlistPath]) {
        NSDictionary* infoPlistDict = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
        NSString *bundleID = infoPlistDict[kCFBundleIdentifier];
        return bundleID;
    } else {
        return @"Not found info.plist";
    }
}

- (IDProvisioningProfile *)embeddedMobileprovision {
    if (!_embeddedMobileprovision) {
        _embeddedMobileprovision = [[IDProvisioningProfile alloc] initWithPath:[self getEmbeddedProvisioningProfilePath]];
    }
    return _embeddedMobileprovision;
}

#pragma mark - Zip Method
- (void)unzipIpa:(void (^)(void))success error:(void (^)(NSString *error))error {
    if (![[[self.packagePath pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
        error([NSString stringWithFormat:@"File extension is not \".ipa\""]);
        return;
    }
    
    [manager removeItemAtPath:self.workPath error:nil];
    [manager createDirectoryAtPath:self.workPath withIntermediateDirectories:TRUE attributes:nil error:nil];
    
    [[IDFileHelper sharedInstance] unzip:self.packagePath toPath:self.workPath complete:^(BOOL result) {
        if (result) {
            [self setAppPath];
            if (success != nil) success();
        } else {
            [self removeWorkDirectory];
            if (error != nil) error(@"File extraction failed.");
        }
    }];
}

- (void)zipPackageToDirPath:(NSString *)zipDirPath
                        log:(LogBlock)logBlock
                      error:(ErrorBlock)errorBlock
                    success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    NSString *displayName = self.bundleDisplayName;
    NSString *zippedIpaPath = [[zipDirPath stringByAppendingPathComponent:displayName] stringByAppendingPathExtension:@"ipa"];
    if (logLocalBlock)
        logLocalBlock([NSString stringWithFormat:@"Compressing file to path: %@", zippedIpaPath]);
    
    [manager createDirectoryAtPath:zipDirPath withIntermediateDirectories:TRUE attributes:nil error:nil];
    [[IDFileHelper sharedInstance] zip:self.workPath toPath:zippedIpaPath complete:^(BOOL result) {
        if (result) {
            if (self->successLocalBlock)
                self->successLocalBlock([NSString stringWithFormat:@"Resign result: %@", [[self->codesigningResult stringByAppendingString:@"\n\n"] stringByAppendingString:self->verificationResult]]);
        } else {
            if (self->errorLocalBlock)
                self->errorLocalBlock(@"ERROR: File save failed.");
        }
    }];
}

#pragma mark - Entitlements
- (void)createEntitlementsWithProvisioning:(IDProvisioningProfile *)provisioningprofile
                                       log:(LogBlock)logBlock
                                     error:(ErrorBlock)errorBlock
                                   success:(SuccessBlock)successBlock {
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock)
        logLocalBlock(@"Generating entitlements...");
    
    // 检查是否存在 Entitlements，然后删掉
    NSString* entitlementsPath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFilename];
    if (entitlementsPath != nil && [manager fileExistsAtPath:entitlementsPath]) {
        NSError *error = nil;
        if (![manager removeItemAtPath:entitlementsPath error:&error]) {
            if (errorLocalBlock != nil)
                errorLocalBlock(@"ERROR: Delete old Entitlements.plist failed.");
            return;
        }
    }
    // 使用 provisioningprofile 作为新的 Entitlements
    if ([manager fileExistsAtPath:provisioningprofile.path]) {
        NSTask *generateEntitlementsTask = [[NSTask alloc] init];
        [generateEntitlementsTask setLaunchPath:@"/usr/bin/security"];
        [generateEntitlementsTask setArguments:@[@"cms", @"-D", @"-i", provisioningprofile.path]];
        [generateEntitlementsTask setCurrentDirectoryPath:self.workPath];
        
        NSPipe *pipe = [NSPipe pipe];
        [generateEntitlementsTask setStandardOutput:pipe];
        [generateEntitlementsTask setStandardError:pipe];
        NSFileHandle *handle = [pipe fileHandleForReading];
        [generateEntitlementsTask launch];
        
        IDRunLoop *checkEntitlementsLoop = [IDRunLoop new];
        [checkEntitlementsLoop run:^{
            if (generateEntitlementsTask.isRunning == 0) {
                
                [checkEntitlementsLoop stop:^{
                    int terminationStatus = generateEntitlementsTask.terminationStatus;
                    if (terminationStatus == 0) {
                        [self doEntitlements:provisioningprofile];
                    } else {
                        if (self->errorLocalBlock != nil)
                            self->errorLocalBlock(@"Create new Entitlements.plist failed.");
                    }
                }];
            }
        }];
        [NSThread detachNewThreadSelector:@selector(watchEntitlements:) toTarget:self withObject:handle];
    } else {
        if (errorLocalBlock != nil)
            errorLocalBlock(@"ERROR: Selected provisioning profile does not exist.");
        return;
    }
}

- (void)doEntitlements:(IDProvisioningProfile *)provisioningprofile {
    if ([entitlementsResult respondsToSelector:@selector(containsString:)] && [entitlementsResult containsString:@"SecPolicySetValue"]) {
        NSMutableArray *linesInOutput = [entitlementsResult componentsSeparatedByString:@"\n"].mutableCopy;
        [linesInOutput removeObjectAtIndex:0];
        entitlementsResult = [linesInOutput componentsJoinedByString:@"\n"];
    }
    
    NSMutableDictionary* entitlements = [[NSMutableDictionary alloc] initWithDictionary:entitlementsResult.propertyList[@"Entitlements"]];
    
    NSString* filePath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFilename];
    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:entitlements format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
    
    if([xmlData writeToFile:filePath atomically:YES]) {
        if (successLocalBlock != nil)
            successLocalBlock(@"Entitlements.plist was created successfully.");
    } else {
        if (errorLocalBlock != nil)
            errorLocalBlock(@"ERROR: Unable to write data to Entitlements.plist file.");
    }
}

- (void)watchEntitlements:(NSFileHandle*)streamHandle
{
    @autoreleasepool {
        entitlementsResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}

#pragma mark - Info.plist
- (void)editInfoPlistWithIdentifier:(NSString *)bundleIdentifier displayName:(NSString *)displayName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if (logLocalBlock)
        logLocalBlock(@"Editing Info.plist...");
    NSString* infoPlistPath = [self.appPath stringByAppendingPathComponent:kInfoPlistFilename];
    // 找 Info.plist
    if ([[NSFileManager defaultManager] fileExistsAtPath:infoPlistPath]) {
        // 修改 kCFBundleDisplayName/kCFBundleIdentifier 到 Info.plist
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:infoPlistPath];
        [plist setObject:bundleIdentifier forKey:kCFBundleIdentifier];
        [plist setObject:displayName forKey:kCFBundleDisplayName];
        
        // 保存
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
        if ([xmlData writeToFile:infoPlistPath atomically:YES]) {
            if (successLocalBlock != nil)
                successBlock(@"Info.plist saved.");
            
        } else {
            if (errorLocalBlock != nil)
                errorLocalBlock(@"ERROR: Cannot write data to Info.plist.");
        }
    } else {
        if (errorLocalBlock != nil)
            errorLocalBlock(@"ERROR: Info.plist not found.");
    }
}

#pragma mark - Codesign
- (void)doCodesign:(NSString *)certificateName log:(LogBlock)logBlock error:(ErrorBlock)errorBlock success:(SuccessBlock)successBlock {
    logLocalBlock = [logBlock copy];
    errorLocalBlock = [errorBlock copy];
    successLocalBlock = [successBlock copy];
    
    if ([manager fileExistsAtPath:self.appPath]) {
        NSMutableArray *waitSignPathArray = @[].mutableCopy;
        
        NSArray *subpaths = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:self.appPath error:nil];
        for (NSString *subpath in subpaths) {
            NSString *extension = [[subpath pathExtension] lowercaseString];
            if ([extension isEqualTo:@"framework"] || [extension isEqualTo:@"dylib"]) {
                [waitSignPathArray addObject:[self.appPath stringByAppendingPathComponent:subpath]];
            }
            if ([extension isEqualTo:@"appex"]) {
                // TODO: 待添加支持
            }
        }
        
        // 最后对 appPath 进行签名
        [waitSignPathArray addObject:self.appPath];
        IDManualQueue *queue = [[IDManualQueue alloc] init];
        __block NSString *failurePath;
        
        for (NSString *signPath in waitSignPathArray) {
            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                NSString* entitlementsPath = [self.workPath stringByAppendingPathComponent:kEntitlementsPlistFilename];
                
                NSTask *codesignTask = [[NSTask alloc] init];
                [codesignTask setLaunchPath:@"/usr/bin/codesign"];
                [codesignTask setArguments:@[@"-vvv",@"-fs", certificateName, signPath, [NSString stringWithFormat:@"--entitlements=%@", entitlementsPath]]];
                NSPipe *pipe = [NSPipe pipe];
                [codesignTask setStandardOutput:pipe];
                [codesignTask setStandardError:pipe];
                NSFileHandle *handle = [pipe fileHandleForReading];
                [codesignTask launch];
                [NSThread detachNewThreadSelector:@selector(watchCodesigning:) toTarget:self withObject:handle];
                
                if (self->logLocalBlock) self->logLocalBlock([NSString stringWithFormat:@"Codesigning file: %@", [signPath lastPathComponent]]);
                
                IDRunLoop *verifyCodesigning = [IDRunLoop new];
                [verifyCodesigning run:^{
                    if ([codesignTask isRunning] == 0) {
                        // 该队列签名完成，等待验证
                        [verifyCodesigning stop:^{
                            [self verifySignature:signPath complete:^(NSString *error) {
                                if (error) {
                                    if (self->errorLocalBlock) {
                                        failurePath = signPath;
                                        self->errorLocalBlock([NSString stringWithFormat:@"Signing failed with error: %@", error]);
                                        [queue cancelAll];
                                    }
                                } else {
                                    if (self->logLocalBlock) {
                                        self->logLocalBlock([NSString stringWithFormat:@"%@ signing is complete.", [signPath lastPathComponent]]);
                                        [queue next];
                                    }
                                }
                                
                            }];
                        }];
                    }
                }];
            }];
            [queue addOperation:operation];
        }
        
        [queue next];
        queue.noOperationPerform = ^{
            if (self->successLocalBlock && failurePath == nil)
                self->successLocalBlock(@"Signature verification is complete.");
        };
        
    } else {
        if (errorLocalBlock) errorLocalBlock([NSString stringWithFormat:@"Not found %@ folder", self.appPath]);
    }
}

- (void)watchCodesigning:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        codesigningResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}

- (void)verifySignature:(NSString *)filePath complete:(void(^)(NSString *error))complete {
    if (self.appPath) {
        if (logLocalBlock)
            logLocalBlock([NSString stringWithFormat:@"Verifying codesign: %@", [filePath lastPathComponent]]);
        
        // 创建验证任务，验证结果
        NSTask *verifyTask = [[NSTask alloc] init];
        [verifyTask setLaunchPath:@"/usr/bin/codesign"];
        [verifyTask setArguments:[NSArray arrayWithObjects:@"-v", filePath, nil]];
        NSPipe *pipe = [NSPipe pipe];
        [verifyTask setStandardOutput:pipe];
        [verifyTask setStandardError:pipe];
        NSFileHandle *handle = [pipe fileHandleForReading];
        [verifyTask launch];
        [NSThread detachNewThreadSelector:@selector(watchVerificationProcess:) toTarget:self withObject:handle];
        
        IDRunLoop *checkVerification = [IDRunLoop new];
        [checkVerification run:^{
            if ([verifyTask isRunning] == 0) {
                
                [checkVerification stop:^{
                    if ([self->verificationResult length] == 0) {
                        if (complete) complete(nil);
                    } else {
                        NSString *error = [[self->codesigningResult stringByAppendingString:@"\n\n"] stringByAppendingString:self->verificationResult];
                        if (complete) complete(error);
                    }
                }];
            }
        }];
    }
}

- (void)watchVerificationProcess:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        verificationResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}

#pragma mark - Resign
- (void)resignWithProvisioningProfile:(IDProvisioningProfile *)provisioningprofile
                          certificate:(NSString *)certificateName
                     bundleIdentifier:(NSString *)bundleIdentifier
                          displayName:(NSString *)displayName
                      destinationPath:(NSString *)destinationPath
                                  log:(LogBlock)logBlock
                                error:(ErrorBlock)errorBlock
                              success:(SuccessBlock)successBlock {
    
    logResignBlock = [logBlock copy];
    errorResignBlock = [errorBlock copy];
    successResignBlock = [successBlock copy];
    
    // create Entitlements
    [self createEntitlementsWithProvisioning:provisioningprofile log:^(NSString *logString) {
        if (self->logResignBlock) self->logResignBlock(logString);
    } error:^(NSString *errorString) {
        if (self->errorResignBlock) self->errorResignBlock(errorString);
    } success:^(id message) {
        if (self->logResignBlock) self->logResignBlock(message);
        
        // edit info.plist
        [self editInfoPlistWithIdentifier:bundleIdentifier displayName:displayName log:^(NSString *logString) {
            if (self->logResignBlock) self->logResignBlock(logString);
        } error:^(NSString *errorString) {
            if (self->errorResignBlock) self->errorResignBlock(errorString);
        } success:^(id message) {
            if (self->logResignBlock) self->logResignBlock(message);
            
            // edit Embedded Provision
            [self editEmbeddedProvision:provisioningprofile log:^(NSString *logString) {
                if (self->logResignBlock) self->logResignBlock(logString);
            } error:^(NSString *errorString) {
                if (self->errorResignBlock) self->errorResignBlock(errorString);
            } success:^(id message) {
                if (self->logResignBlock) self->logResignBlock(message);
                
                // Do the codesign
                [self doCodesign:certificateName log:^(NSString *logString) {
                    if (self->logResignBlock) self->logResignBlock(logString);
                } error:^(NSString *errorString) {
                    if (self->errorResignBlock) self->errorResignBlock(errorString);
                } success:^(id message) {
                    if (self->logResignBlock) self->logResignBlock(message);
                    
                    // zip
                    [self zipPackageToDirPath:destinationPath log:^(NSString *logString) {
                        if (self->logResignBlock) self->logResignBlock(logString);
                    } error:^(NSString *errorString) {
                        if (self->errorResignBlock) self->errorResignBlock(errorString);
                    } success:^(id message) {
                        if (self->successResignBlock)
                            self->successResignBlock(message);
                    }];
                }];
            }];
        }]; 
    }];
}

@end

