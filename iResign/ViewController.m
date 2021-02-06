//
//  ViewController.m
//  iResign
//
//  Created by liwx on 2021/2/5.
//

#import "ViewController.h"
#import "IDAppPackageHandler.h"
#import "IDFileHelper.h"
#import "IDProvisioningProfile.h"
#import "IDDateFormatterUtil.h"

@interface ViewController () <NSComboBoxDataSource,NSComboBoxDelegate>

@property (strong, nonatomic) IDAppPackageHandler *package;
@property (assign, nonatomic) BOOL useMobileprovisionBundleID;

@property (strong, nonatomic) NSFileManager *fileManager;
@property (copy,   nonatomic) NSArray *provisioningArray;
@property (copy,   nonatomic) NSArray *certificatesArray;


@property (weak) IBOutlet NSTextField   *ipaPathField;
@property (weak) IBOutlet NSButton      *browseIpaPathButton;
@property (weak) IBOutlet NSComboBox    *certificateComboBox;
@property (weak) IBOutlet NSComboBox    *provisioningComboBox;
@property (weak) IBOutlet NSTextField   *appNameField;
@property (weak) IBOutlet NSTextField   *destinationPathField;
@property (weak) IBOutlet NSButton      *browseSavePathButton;
@property (weak) IBOutlet NSTextField   *bundleIdField;
@property (weak) IBOutlet NSButton      *cacheFolderButton;
@property (weak) IBOutlet NSButton      *resignButton;
@property (weak) IBOutlet NSButton      *cleanButton;
@property        IBOutlet NSTextView    *logField;



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    
    self.fileManager = [NSFileManager defaultManager];
    
    self.certificateComboBox.delegate = self;
    self.certificateComboBox.dataSource = self;
    
    self.provisioningComboBox.delegate = self;
    self.provisioningComboBox.dataSource = self;
    
    [self.resignButton setKeyEquivalent:@"\r"];
    
    //[self refreshCerAndProv];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:NSApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSApplicationDidBecomeActiveNotification
                                                  object:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self refreshCerAndProv];
}

- (void)refreshCerAndProv {
    NSArray *lackSupportUtility = [[IDFileHelper sharedInstance] lackSupportUtility];
    if ([lackSupportUtility count] == 0) {
        //获取本机证书
        [self getCertificates];
        //获取本级描述文件
        [self getProvisioningProfiles];
    } else {
        for (NSString *path in lackSupportUtility) {
            [self addLog:[NSString stringWithFormat:@"This command requires the support of %@", path] withColor:[NSColor redColor]];
        }
    }
}

- (void)viewDidDisappear {
    [super viewDidDisappear];
    [self clearAll];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark - Control Action
- (IBAction)browseIPAFilePathButtonAction:(id)sender {
    // 作为第一响应
    [self.view.window makeFirstResponder:nil];
    
    // 浏览 ipa 文件
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:NO];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setAllowsOtherFileTypes:NO];
    [openDlg setAllowedFileTypes:@[@"IPA"]];
    
    if ([openDlg runModal] == NSModalResponseOK) {
        if ([self.destinationPathField.stringValue isEqualToString:@""]) {
            self.destinationPathField.stringValue = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) lastObject];
        }
        
        // 移除之前包的解压文件
        if (self.package.workPath) [self.fileManager removeItemAtPath:self.package.workPath error:nil];
        
        NSString* fileNameOpened        = [[[openDlg URLs] objectAtIndex:0] path];
        self.ipaPathField.stringValue   = fileNameOpened;
        
        self.package = [[IDAppPackageHandler alloc] initWithPackagePath:fileNameOpened];
        
        [self unzipIpa];
    }
}

- (IBAction)browseSavePathButtonAction:(id)sender {
    // 作为第一响应
    [self.view.window makeFirstResponder:nil];
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:NO];
    [openDlg setCanChooseDirectories:YES];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setAllowsOtherFileTypes:NO];
    
    if ([openDlg runModal] == NSModalResponseOK) {
        self.destinationPathField.stringValue = [[[openDlg URLs] objectAtIndex:0] path];
    }
}


- (IBAction)bundleIdRadioAction:(id)sender {
    NSButtonCell *button = sender;
    if (button.tag == 101 && button.state == 0) {
        // 用文本框里面的 BundleID
        self.useMobileprovisionBundleID = NO;
    } else if (button.tag == 102 && button.state == 1) {
        // 使用 mobileprovision 中的 BundleID
        self.useMobileprovisionBundleID = YES;
    }
}

- (IBAction)openCacheFolderClick:(id)sender {
    NSArray *fileURLs = [NSArray arrayWithObjects:[NSURL fileURLWithPath:TEMP_PATH], nil];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}

- (IBAction)resignClick:(id)sender {
    if (![self.fileManager fileExistsAtPath:self.ipaPathField.stringValue]) {
        [self addLog:[NSString stringWithFormat:@"Not found ipa file %@", self.ipaPathField.stringValue] withColor:[NSColor redColor]];
        return;
    }
    
    if ([self.certificateComboBox indexOfSelectedItem] == -1) {
        [self addLog:[NSString stringWithFormat:@"No select certificate"] withColor:[NSColor redColor]];
        return;
    }
    
    if ([self.provisioningComboBox indexOfSelectedItem] == -1) {
        [self addLog:[NSString stringWithFormat:@"No select provisioning profile"] withColor:[NSColor redColor]];
        return;
    }
    
    if (self.appNameField.stringValue.length == 0) {
        [self addLog:[NSString stringWithFormat:@"This app cann't have no name"] withColor:[NSColor redColor]];
        return;
    }
    
    if (self.destinationPathField.stringValue.length == 0) {
        self.destinationPathField.stringValue = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) lastObject];
        [self addLog:[NSString stringWithFormat:@"Default Save the file to Desktop folder"] withColor:[NSColor orangeColor]];
        return;
    }
    
    NSString *bundleIdentifier = @"";
    if (self.useMobileprovisionBundleID) {
        IDProvisioningProfile *file = self.provisioningArray[self.provisioningComboBox.indexOfSelectedItem];
            bundleIdentifier = file.bundleIdentifier;
    } else {
        if (self.bundleIdField.stringValue.length == 0) {
            [self addLog:[NSString stringWithFormat:@"This app cann't have no bundleIdentifier"] withColor:[NSColor redColor]];
            return;
        } else {
            bundleIdentifier = self.bundleIdField.stringValue;
        }
    }
    
    [self disableControls];
    
    [self.package removeCodeSignatureDirectory];
    // 开始尝试签名
    [self.package resignWithProvisioningProfile:self.provisioningArray[self.provisioningComboBox.indexOfSelectedItem]
                                    certificate:self.certificatesArray[self.certificateComboBox.indexOfSelectedItem]
                               bundleIdentifier:bundleIdentifier
                                    displayName:self.appNameField.stringValue
                                destinationPath:self.destinationPathField.stringValue
                                            log:^(NSString *logString) {
                                                [self addLog:logString withColor:[NSColor blackColor]];
                                            } error:^(NSString *errorString) {
                                                [self enableControls];
                                                [self addLog:errorString withColor:[NSColor redColor]];
                                            } success:^(id object) {
                                                [self enableControls];
                                                [self addLog:[NSString stringWithFormat:@"Successful signed, File saved in path: %@", self.destinationPathField.stringValue] withColor:[NSColor colorWithRed:90/255. green:196/255. blue:96/255. alpha:1]];
                                            }];
}

- (IBAction)cleanClick:(id)sender {
    [self clearAll];
}

#pragma mark - ZIP/IPA Methods
- (void)unzipIpa {
    [self addLog:[NSString stringWithFormat:@"Extracting files to: %@", self.package.workPath] withColor:[NSColor blackColor]];
    
    [self disableControls];
    //解压包
    [self.package unzipIpa:^{
        [self addLog:@"Extraction is complete." withColor:[NSColor blackColor]];
        [self showIpaInfo];
        [self enableControls];
    } error:^(NSString *error) {
        [self enableControls];
        [self addLog:error withColor:[NSColor redColor]];
    }];
}

- (void)showIpaInfo {
    //显示包的一些信息
    self.appNameField.stringValue = self.package.bundleDisplayName;
    self.bundleIdField.stringValue = self.package.bundleID;
    if (self.provisioningComboBox.indexOfSelectedItem == -1) {
        for (NSInteger i = 0; i < self.provisioningArray.count; i++) {
            IDProvisioningProfile *provisioning = self.provisioningArray[i];
            if ([self.package.embeddedMobileprovision.bundleIdentifier isEqualToString:provisioning.bundleIdentifier]) {
                [self.provisioningComboBox selectItemAtIndex:i];
                break;
            }
        }
    }
}

#pragma mark - LogField
- (void)addLog:(NSString *)log withColor:(NSColor *)color {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 添加时间
        NSString *dateString = [[IDDateFormatterUtil sharedFormatter] MMddHHmmssSSSForDate:[NSDate date]];
        NSAttributedString *dateAttributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"[%@]", dateString] attributes:@{NSForegroundColorAttributeName: [NSColor grayColor]}];

        // 添加log
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@\n", log] attributes:@{NSForegroundColorAttributeName: color}];
        
        [[self.logField textStorage] appendAttributedString:dateAttributedString];
        [[self.logField textStorage] appendAttributedString:attributedString];
        [self.logField scrollRangeToVisible:NSMakeRange([[self.logField string] length], 0)];
    });
}

#pragma mark - Certificate Methods
- (void)getCertificates {
    __weak typeof(self) weakSelf = self;
    [[IDFileHelper sharedInstance] getCertificatesSuccess:^(NSArray *certificateNames) {
        __strong typeof(weakSelf) strongSelf = self;
        strongSelf.certificatesArray = certificateNames;
        [strongSelf.certificateComboBox reloadData];
    } error:^(NSString *errString) {
        __strong typeof(weakSelf) strongSelf = self;
        [strongSelf addLog:errString withColor:[NSColor redColor]];
    }];
}

#pragma mark - ProvisioningProfile Methods
- (void)getProvisioningProfiles {
    self.provisioningArray = [[IDFileHelper sharedInstance] getProvisioningProfiles];
    [self.provisioningComboBox reloadData];
}

#pragma mark - NSComboBox
- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    NSInteger count = 0;
    
    if ([comboBox isEqual:self.provisioningComboBox])
        count = [self.provisioningArray count];
    else if ([comboBox isEqual:self.certificateComboBox])
        count = [self.certificatesArray count];
    
    return count;
}

- (nullable id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index; {
    id item = nil;
    
    if ([comboBox isEqual:self.provisioningComboBox]) {
        IDProvisioningProfile *profile = self.provisioningArray[index];
        item = [NSString stringWithFormat:@"%@ (%@)", profile.name, profile.bundleIdentifier];
    } else if ([comboBox isEqual:self.certificateComboBox]) {
        item = self.certificatesArray[index];
    }
    
    return item;
}

#pragma mark - UI

- (void)disableControls {
    [self.ipaPathField setEnabled:NO];
    [self.browseIpaPathButton setEnabled:NO];
    [self.provisioningComboBox setEnabled:NO];
    [self.certificateComboBox setEnabled:NO];
    [self.appNameField setEnabled:NO];
    [self.destinationPathField setEnabled:NO];
    [self.browseSavePathButton setEnabled:NO];
    [self.bundleIdField setEnabled:NO];
    [self.resignButton setEnabled:NO];
    [self.cleanButton setEnabled:NO];
}

- (void)enableControls {
    [self.ipaPathField setEnabled:YES];
    [self.browseIpaPathButton setEnabled:YES];
    [self.provisioningComboBox setEnabled:YES];
    [self.certificateComboBox setEnabled:YES];
    [self.appNameField setEnabled:YES];
    [self.destinationPathField setEnabled:YES];
    [self.browseSavePathButton setEnabled:YES];
    [self.bundleIdField setEnabled:YES];
    [self.resignButton setEnabled:YES];
    [self.cleanButton setEnabled:YES];
}

- (void)clearAll {
    self.ipaPathField.stringValue = @"";
    self.appNameField.stringValue = @"";
    self.destinationPathField.stringValue = @"";
    self.bundleIdField.stringValue = @"";
    self.logField.string = @"";
    
    [self.fileManager removeItemAtPath:TEMP_PATH error:nil];
    self.package = nil;
}

@end
