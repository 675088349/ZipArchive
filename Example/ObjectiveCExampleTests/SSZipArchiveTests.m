//
//  SSZipArchiveTests.m
//  SSZipArchiveTests
//
//  Created by Sam Soffes on 10/3/11.
//  Copyright (c) 2011-2014 Sam Soffes. All rights reserved.
//


#if COCOAPODS
#import <SSZipArchive.h>
#else
#import <ZipArchive.h>
#endif

#import <XCTest/XCTest.h>
#import <CommonCrypto/CommonDigest.h>

#import "CollectingDelegate.h"
#import "CancelDelegate.h"
#import "ProgressDelegate.h"

@interface SSZipArchiveTests : XCTestCase
@end

@interface NSString (SSZipArchive)
- (NSString *)_sanitizedPath;
@end

@interface SSZipArchive (XCTest)
+ (NSDate *)_dateWithMSDOSFormat:(UInt32)msdosDateTime;
@end

@implementation SSZipArchiveTests

int twentyMB = 20 * 1024 * 1024;

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
    [[NSFileManager defaultManager] removeItemAtPath:[self _cachesPath:nil] error:nil];
}


- (void)testZipping {
    // use extracted files from [-testUnzipping]
    [self testUnzipping];
    
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"],
                            [inputPath stringByAppendingPathComponent:@"LICENSE"]];

    NSString *outputPath = [self _cachesPath:@"Zipped"];

    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];
    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths];
    
    XCTAssertTrue(success, @"create zip failure");
    // TODO: Make sure the files are actually zipped. They are, but the test should be better.
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive created");
    
    BOOL protected = [SSZipArchive isFilePasswordProtectedAtPath:archivePath];
    XCTAssertFalse(protected, @"has no password");
}


- (void)testZippingWithPassword {
    // use extracted files from [-testUnzipping]
    [self testUnzipping];
    
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"],
                            [inputPath stringByAppendingPathComponent:@"LICENSE"]];
    
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];
    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths withPassword:@"dolphins🐋"];
    
    XCTAssertTrue(success, @"create zip failure");
    // TODO: Make sure the files are actually zipped. They are, but the test should be better.
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive created");
    
    BOOL protected = [SSZipArchive isFilePasswordProtectedAtPath:archivePath];
    XCTAssertTrue(protected, @"has password");
}


- (void)testZippingWithZeroLengthPassword {
    // use extracted files from [-testUnzipping]
    [self testUnzipping];
    
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"],
                            [inputPath stringByAppendingPathComponent:@"LICENSE"]];
    
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];
    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths withPassword:@""];
    
    XCTAssertTrue(success, @"create zip failure");
    // TODO: Make sure the files are actually zipped. They are, but the test should be better.
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive created");
    
    BOOL protected = [SSZipArchive isFilePasswordProtectedAtPath:archivePath];
    XCTAssertTrue(protected, @"has password");
}


- (void)testDirectoryZipping {
    // use Unicode as folder (has a file in root and a file in subfolder)
    [self testUnzippingWithUnicodeFilenameInside];
    NSString *inputPath = [self _cachesPath:@"Unicode"];

    NSString *outputPath = [self _cachesPath:@"FolderZipped"];
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"ArchiveWithFolders.zip"];

    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withContentsOfDirectory:inputPath];
    XCTAssertTrue(success, @"create zip failure");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Folder Archive created");
}

- (void)testMultipleZippping{
    NSArray *inputPaths = @[[[NSBundle bundleForClass:[self class]] pathForResource:@"0" ofType:@"m4a"],
                            [[NSBundle bundleForClass:[self class]] pathForResource:@"1" ofType:@"m4a"],
                            [[NSBundle bundleForClass:[self class]] pathForResource:@"2" ofType:@"m4a"],
                            [[NSBundle bundleForClass:[self class]] pathForResource:@"3" ofType:@"m4a"],
                            [[NSBundle bundleForClass:[self class]] pathForResource:@"4" ofType:@"m4a"],
                            [[NSBundle bundleForClass:[self class]] pathForResource:@"5" ofType:@"m4a"],
                            [[NSBundle bundleForClass:[self class]] pathForResource:@"6" ofType:@"m4a"],
                            [[NSBundle bundleForClass:[self class]] pathForResource:@"7" ofType:@"m4a"]
                            ];
    NSString *outputPath = [self _cachesPath:@"Zipped"];

    // ~Comment from August 2013 (4cd142a39c9f18556a845e0bb545166f818058b0), meaning iPhone 4/5 on iOS 6/7~
    // if testing on iOS, within 30 loops it will fail; however, on OS X, it may take about 900 loops
    for (int test = 0; test < 20; test++)
    {
        // Zipping
        NSString *archivePath = [outputPath stringByAppendingPathComponent:[NSString stringWithFormat:@"queue_test_%d.zip", test]];

        BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths];
        XCTAssertTrue(success, @"create zip failure");
        
        long long threshold = 510000; // 510kB:size slightly smaller than a successful zip, but much larger than a failed one
        long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:archivePath error:nil][NSFileSize] longLongValue];
        XCTAssertTrue(fileSize > threshold, @"zipping failed at %@!", archivePath);
    }
}

- (void)testUnzipping {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Regular"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");

    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}

- (void)testUnzippingIncorrectNumberEntries {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"IncorrectNumberEntries" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"IncorrectNumberEntries"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"hello"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"hello unzipped");
}

- (void)testSmallFileUnzipping {
    NSString *zipPath = [[NSBundle bundleForClass: [self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Regular"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");

    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}

-(void)testAppendingToZip {
    // zip files and create "CreatedArchive.zip"
    [self testZipping];
    
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];
    long long initialFileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:archivePath error:NULL][NSFileSize] longLongValue];
    
    SSZipArchive* zip = [[SSZipArchive alloc] initWithPath:archivePath];
    
    BOOL didOpenForAppending = [zip openForAppending];
    XCTAssertTrue(didOpenForAppending, @"Opened for appending");
    
    NSData* testData = [@"test contents" dataUsingEncoding:NSUTF8StringEncoding];
    BOOL didAppendFile = [zip writeData:testData filename:@"testData.txt" withPassword:NULL];
    XCTAssertTrue(didAppendFile, @"Did add file");
    
    BOOL didClose = [zip close];
    XCTAssertTrue(didClose, @"Can close zip");
    
    // TODO: Make sure the files are actually zipped. They are, but the test should be better.
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive created");
    
    long long fileSizeAfterAppend = [[[NSFileManager defaultManager] attributesOfItemAtPath:archivePath error:NULL][NSFileSize] longLongValue];
    XCTAssertGreaterThan(fileSizeAfterAppend, initialFileSize);    
}

- (void)testUnzippingProgress {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Progress"];

    ProgressDelegate *delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    // 4 events: the first, then for each of the two files one, then the final event
    XCTAssertTrue(4 == [delegate->progressEvents count], @"Expected 4 progress events");
    XCTAssertTrue(0 == [delegate->progressEvents[0] intValue]);
    XCTAssertTrue(619 == [delegate->progressEvents[1] intValue]);
    XCTAssertTrue(1114 == [delegate->progressEvents[2] intValue]);
    XCTAssertTrue(1436 == [delegate->progressEvents[3] intValue]);

    XCTAssertTrue(2 == [delegate->fileInfos count], @"Expected 2 files");
    unz_file_info info;
    [delegate->fileInfos[0] getValue:&info];
    // This test is to ensure that ZipArchive 2.x keeps support of `dos_date` instead of `dosDate`, despite the legacy name at:
    // https://github.com/madler/zlib/blame/643e17b7498d12ab8d15565662880579692f769d/contrib/minizip/unzip.h#L138
    // In ZipArchive 3, we should hide this outdated structure from public.
    XCTAssertNotEqual(info.dos_date, 0);
}


- (void)testUnzippingWithPassword {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Password"];

    NSError *error = nil;
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:@"passw0rd" error:&error delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");

    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}

- (void)testUnzippingWithAESPassword {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestAESPasswordArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Password"];
    
    NSError *error = nil;
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:@"passw0rd" error:&error delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"README.md"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");
    
    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE.txt"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}

- (void)testUnzippingWithInvalidPassword {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Password"];
    
    NSError *error = nil;
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    // correct password is "passw0rd", so "passw0rd123" should be incorrect
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:@"passw0rd123" error:&error delegate:delegate];
    XCTAssertFalse(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertFalse([fileManager fileExistsAtPath:testPath], @"Readme not unzipped");
    
    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertFalse([fileManager fileExistsAtPath:testPath], @"LICENSE not unzipped");
}

- (void)testUnzippingWithInvalidPassword2 {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive2" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Password"];
    
    NSError *error = nil;
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    // correct password is "aaabbb", so "1989" should be incorrect
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:@"1989" error:&error delegate:delegate];
    XCTAssertFalse(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"test.txt"];
    XCTAssertFalse([fileManager fileExistsAtPath:testPath], @"test.txt not unzipped");
}

- (void)testIsPasswordInvalidForArchiveAtPath {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive" ofType:@"zip"];
    
    NSError *error = nil;
    
    BOOL fileHasValidPassword = [SSZipArchive isPasswordValidForArchiveAtPath:zipPath password:@"passw0rd" error:&error];
    
    XCTAssertTrue(fileHasValidPassword, @"Valid password reports false.");
    
    BOOL fileHasInvalidValidPassword = [SSZipArchive isPasswordValidForArchiveAtPath:zipPath password:@"passw0rd123" error:&error];
    
    XCTAssertFalse(fileHasInvalidValidPassword, @"Invalid password reports true.");
}

- (void)testIsPasswordInvalidForArchiveAtPath2 {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive2" ofType:@"zip"];

    NSError *error = nil;

    BOOL fileHasValidPassword = [SSZipArchive isPasswordValidForArchiveAtPath:zipPath password:@"aaabbb" error:&error];

    XCTAssertTrue(fileHasValidPassword, @"Valid password reports false.");

    BOOL fileHasInvalidValidPassword = [SSZipArchive isPasswordValidForArchiveAtPath:zipPath password:@"1989" error:&error];

    XCTAssertFalse(fileHasInvalidValidPassword, @"Invalid password reports true.");
}

- (void)testIsPasswordValidForDirectory {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"PasswordArchiveWithFolder" ofType:@"zip"];

    BOOL fileHasValidPassword = [SSZipArchive isPasswordValidForArchiveAtPath:zipPath password:@"passw0rd" error:nil];
    XCTAssertTrue(fileHasValidPassword, @"is Password Valid");
}

- (void)testIsFilePasswordProtectedAtPath {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    
    BOOL protected = [SSZipArchive isFilePasswordProtectedAtPath:zipPath];
    XCTAssertFalse(protected, @"has no password");
    
    
    NSString *zipWithPasswordPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive" ofType:@"zip"];
    
    protected = [SSZipArchive isFilePasswordProtectedAtPath:zipWithPasswordPath];
    XCTAssertTrue(protected, @"has password");
}

- (void)testZippingAndUnzippingWithUnicodePassword {
    
    /**** Zipping **/
    
    // use extracted files from [-testUnzipping]
    [self testUnzipping];
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"],
                            [inputPath stringByAppendingPathComponent:@"LICENSE"]];
    
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedUnicodePasswordArchive.zip"];
    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths withPassword:@"ꊐ⌒Ⅳ🤐"];
    
    XCTAssertTrue(success, @"create zip failure");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive created");
    
    /**** Unzipping **/
    
    outputPath = [self _cachesPath:@"UnicodePassword"];
    
    NSError *error = nil;
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    success = [SSZipArchive unzipFileAtPath:archivePath toDestination:outputPath overwrite:YES password:@"ꊐ⌒Ⅳ🤐" error:&error delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");
    
    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}


- (void)testUnzippingTruncatedFileFix {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"IncorrectHeaders" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"IncorrectHeaders"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");

    NSString *intendedReadmeTxtSHA256 = @"b389c1b182306c9fa68a38f667a6ac35863b6d670ae98954403c265ffe67e9bc";

    NSString *filePath = [outputPath stringByAppendingPathComponent:@"IncorrectHeaders/Readme.txt"];
    NSData *data = [NSData dataWithContentsOfFile:filePath];

    NSString *actualReadmeTxtSHA256 = [self _calculateSHA256Hash:data];
    XCTAssertTrue([actualReadmeTxtSHA256 isEqualToString:intendedReadmeTxtSHA256], @"Readme.txt SHA256 digest should match original.");
}


- (void)testUnzippingWithSymlinkedFileInside {

    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"SymbolicLink" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"SymbolicLink"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath preserveAttributes:YES overwrite:YES symlinksValidWithin:nil nestedZipLevel:0 password:nil error:nil delegate:delegate progressHandler:nil completionHandler:nil];
    XCTAssertTrue(success, @"unzip failure");
    
    NSString *testSymlink = [outputPath stringByAppendingPathComponent:@"SymbolicLink/Xcode.app"];

    NSError *error = nil;
    NSDictionary *info = [[NSFileManager defaultManager] attributesOfItemAtPath: testSymlink error: &error];
    BOOL fileIsSymbolicLink = info[NSFileType] == NSFileTypeSymbolicLink;
    XCTAssertTrue(fileIsSymbolicLink, @"Symbolic links should persist from the original archive to the outputted files.");
}

- (void)testUnzippingWithSymlinkedFileEscapingOutputDirectory {

    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"SymbolicLink" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"SymbolicLink"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    NSError *error = nil;
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:nil error:&error delegate:delegate];
    
    XCTAssertFalse(success, @"Escaping symlink unpacked");
    XCTAssertNotNil(error, @"Error not reported");
    XCTAssertEqualObjects(error.domain, SSZipArchiveErrorDomain, @"Invalid error domain");
    XCTAssertEqual(error.code, SSZipArchiveErrorCodeSymlinkEscapesTargetDirectory, @"Invalid error code");
}

- (void)testUnzippingWithRelativeSymlink {

    NSString *resourceName = @"RelativeSymbolicLink";
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:resourceName ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:resourceName];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    // Determine where the symlinks are
    NSString *subfolderName = @"symlinks";
    NSString *testBasePath = [NSString pathWithComponents:@[outputPath]];
    NSString *testSymlinkFolder = [NSString pathWithComponents:@[testBasePath, subfolderName, @"folderSymlink"]];
    NSString *testSymlinkFile = [NSString pathWithComponents:@[testBasePath, subfolderName, @"fileSymlink"]];

    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:testSymlinkFile error: nil];
    BOOL fileIsSymbolicLink = fileAttributes[NSFileType] == NSFileTypeSymbolicLink;
    XCTAssertTrue(fileIsSymbolicLink, @"Relative symbolic links should persist from the original archive to the outputted files.");

    NSDictionary *folderAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:testSymlinkFolder error: nil];
    BOOL folderIsSymbolicLink = folderAttributes[NSFileType] == NSFileTypeSymbolicLink;
    XCTAssertTrue(folderIsSymbolicLink, @"Relative symbolic links should persist from the original archive to the outputted files.");
}

- (void)testUnzippingWithUnicodeFilenameInside {

    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Unicode" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Unicode"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    bool unicodeFilenameWasExtracted = [[NSFileManager defaultManager] fileExistsAtPath:[outputPath stringByAppendingPathComponent:@"Accént.txt"]];

    bool unicodeFolderWasExtracted = [[NSFileManager defaultManager] fileExistsAtPath:[outputPath stringByAppendingPathComponent:@"Fólder/Nothing.txt"]];

    XCTAssertTrue(unicodeFilenameWasExtracted, @"Files with filenames in unicode should be extracted properly.");
    XCTAssertTrue(unicodeFolderWasExtracted, @"Folders with names in unicode should be extracted propertly.");
}

/// Issue #507
- (void)testZippingWithUnicodeFilenameInside {
    
    NSString *workPath = [self _cachesPath:@"UnicodeZipping"];
    NSString *filePath = [workPath stringByAppendingPathComponent:@"17 What I’ve Been Looking For.pdf"];
    NSString *zipPath = [workPath stringByAppendingPathComponent:@"UnicodeZipping.zip"];
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    
    BOOL success = [SSZipArchive createZipFileAtPath:zipPath withFilesAtPaths:@[filePath]];
    XCTAssertTrue(success, @"zip failure");
    
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    success = [SSZipArchive unzipFileAtPath:zipPath toDestination:workPath delegate:nil];
    XCTAssertTrue(success, @"unzip failure");
    
    bool unicodeFilenameWasExtracted = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    XCTAssertTrue(unicodeFilenameWasExtracted, @"Files with filenames in unicode should be extracted properly.");
}

- (void)testZippingEmptyArchive {
    
    NSString *inputPath = [self _cachesPath:@"Empty"];
    XCTAssert(![[NSFileManager defaultManager] enumeratorAtPath:inputPath].nextObject, @"The Empty cache folder should always be empty.");
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    NSString *zipPath = [outputPath stringByAppendingPathComponent:@"Empty.zip"];
    NSString *zipPath2 = [outputPath stringByAppendingPathComponent:@"EmptyWithParentDirectory.zip"];
    
    BOOL success = [SSZipArchive createZipFileAtPath:zipPath withContentsOfDirectory:inputPath keepParentDirectory:NO];
    XCTAssertTrue(success, @"create zip failure");
    success = [SSZipArchive createZipFileAtPath:zipPath2 withContentsOfDirectory:inputPath keepParentDirectory:YES];
    XCTAssertTrue(success, @"create zip failure");
    long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:zipPath error:nil][NSFileSize] longLongValue];
    long long fileSize2 = [[[NSFileManager defaultManager] attributesOfItemAtPath:zipPath2 error:nil][NSFileSize] longLongValue];
    XCTAssert(fileSize < fileSize2, @"keepParentDirectory should produce a strictly bigger archive.");
}

/// <https://github.com/ZipArchive/ZipArchive/issues/621>
- (void)testZippingNonDirectoryWithContentsOfDirectory {
    NSString *inputPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"ZippingNonDirectory"];
    NSString *zipPath = [outputPath stringByAppendingPathComponent:@"ZippingNonDirectory.zip"];

    BOOL success = [SSZipArchive createZipFileAtPath:zipPath withContentsOfDirectory:inputPath];
    XCTAssertTrue(!success, @"create zip success");
}

/// Using `keepParentDirectory:YES`
- (void)testZippingAndUnzippingEmptyDirectoryWithPassword {
    
    NSString *inputPath = [self _cachesPath:@"Empty"];
    XCTAssert(![[NSFileManager defaultManager] enumeratorAtPath:inputPath].nextObject, @"The Empty cache folder should always be empty.");
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    NSString *zipPath = [outputPath stringByAppendingPathComponent:@"EmptyWithParentDirectory.zip"];
    
    BOOL success = [SSZipArchive createZipFileAtPath:zipPath withContentsOfDirectory:inputPath keepParentDirectory:YES withPassword:@"password"];
    XCTAssertTrue(success, @"create zip failure");
    
    outputPath = [self _cachesPath:@"EmptyOutput"];
    
    // unzipping a directory doesn't require a password
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:nil error:nil delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");

    NSString *emptyPath = [outputPath stringByAppendingPathComponent:@"Empty"];
    BOOL isDirectory;
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:emptyPath isDirectory:&isDirectory], @"Empty unzipped");
    XCTAssertTrue(isDirectory, @"Empty is a directory");
}

/// Using `withFilesAtPaths:`
- (void)testZippingAndUnzippingEmptyDirectoryWithFilesAtPaths {

    NSString *inputPath = [self _cachesPath:@"EmptyWithSubdirectory"];
    NSString *emptySubdirectory = [inputPath stringByAppendingPathComponent:@"Empty"];
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:emptySubdirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    XCTAssertTrue(success, @"create folder failure");

    // zipping files
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    NSString *zipPath = [outputPath stringByAppendingPathComponent:@"EmptyWithSubdirectory.zip"];
    success = [SSZipArchive createZipFileAtPath:zipPath withFilesAtPaths:@[emptySubdirectory]];
    XCTAssertTrue(success, @"create zip failure");

    // unzipping files
    outputPath = [self _cachesPath:@"EmptyWithSubdirectoryOutput"];
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:nil error:nil delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");

    NSString *emptyPath = [outputPath stringByAppendingPathComponent:@"Empty"];
    BOOL isDirectory;
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:emptyPath isDirectory:&isDirectory], @"Empty unzipped");
    XCTAssertTrue(isDirectory, @"Empty is a directory");
}

- (void)testUnzippingEmptyArchive {
    
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Empty" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Empty"];
    
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:nil];
    XCTAssertTrue(success, @"unzip failure");
}

- (void)testZippingAndUnzippingForDate {

    // use extracted files from [-testUnzipping]
    [self testUnzipping];
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"]];

    NSDictionary *originalFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[inputPath stringByAppendingPathComponent:@"Readme.markdown"] error:nil];

    NSString *outputPath = [self _cachesPath:@"ZippedDate"];
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];

    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths];
    XCTAssertTrue(success, @"create zip failure");
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    success = [SSZipArchive unzipFileAtPath:archivePath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");

    NSDictionary *createdFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[outputPath stringByAppendingPathComponent:@"Readme.markdown"] error:nil];

    XCTAssertEqualObjects(originalFileAttributes[NSFileCreationDate], createdFileAttributes[@"NSFileCreationDate"], @"Original file creationDate should match created one");
}


- (void)testZippingAndUnzippingForPermissions {
    // File we're going to test permissions on before and after zipping
    NSString *targetFile = @"/Contents/MacOS/TestProject";

    /**** Zipping **/

    // The .app file we're going to zip up
    NSString *inputFile = [[NSBundle bundleForClass: [self class]] pathForResource:@"PermissionsTestApp" ofType:@"app"];

    // The path to the target file in the app before zipping
    NSString *targetFilePreZipPath = [inputFile stringByAppendingPathComponent:targetFile];

    // Atribtues for the target file before zipping
    NSDictionary *preZipAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:targetFilePreZipPath error:nil];

    // Directory to output our created zip file
    NSString *outputDir = [self _cachesPath:@"PermissionsTest"];
    // The path to where the archive shall be created
    NSString *archivePath = [outputDir stringByAppendingPathComponent:@"TestAppArchive.zip"];

    // Create the zip file using the contents of the .app file as the input
    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withContentsOfDirectory:inputFile];
    XCTAssertTrue(success, @"create zip failure");

    /**** Un-zipping **/

    // Using this newly created zip file, unzip it
    success = [SSZipArchive unzipFileAtPath:archivePath toDestination:outputDir];
    XCTAssertTrue(success, @"unzip failure");
    
    // Get the path to the target file after unzipping
    NSString *targetFilePath = [outputDir stringByAppendingPathComponent:@"/Contents/MacOS/TestProject"];

    // Get the file attributes of the target file following the unzipping
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:targetFilePath error:nil];

    
    NSInteger permissions = ((NSNumber *)fileAttributes[NSFilePosixPermissions]).longValue;
    NSInteger preZipPermissions = ((NSNumber *)preZipAttributes[NSFilePosixPermissions]).longValue;

    // Compare the value of the permissions attribute to assert equality
    XCTAssertEqual(permissions, preZipPermissions, @"File permissions should be retained during compression and de-compression");
}

- (void)testUnzippingWithCancel {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Cancel1"];

    CancelDelegate *delegate = [[CancelDelegate alloc] init];
    delegate.numFilesToUnzip = 1;

    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertFalse(success);
    XCTAssertEqual(delegate.numFilesUnzipped, 1);
    XCTAssertFalse(delegate.didUnzipArchive);
    XCTAssertNotEqual(delegate.loaded, delegate.total);

    outputPath = [self _cachesPath:@"Cancel2"];

    delegate = [[CancelDelegate alloc] init];
    delegate.numFilesToUnzip = 1000;

    success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    XCTAssertEqual(delegate.numFilesUnzipped, 2);
    XCTAssertTrue(delegate.didUnzipArchive);
    XCTAssertEqual(delegate.loaded, delegate.total);
}

// Commented out to avoid checking in several gig file into the repository. Simply add a file named
// `LargeArchive.zip` to the project and uncomment out these lines to test.
//
//- (void)testUnzippingLargeFiles {
//    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"LargeArchive" ofType:@"zip"];
//    NSString *outputPath = [self _cachesPath:@"Large"];
//
//    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath];
//    XCTAssertTrue(success, @"unzip failure");
//}

- (void)testShouldProvidePathOfUnzippedFileInDelegateCallback {
    CollectingDelegate *collector = [CollectingDelegate new];
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Regular"];
    
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:collector];
    XCTAssertTrue(success, @"unzip failure");
    
    XCTAssertEqualObjects(collector.files[0], [outputPath stringByAppendingString:@"/LICENSE"]);
    XCTAssertEqualObjects(collector.files[1], [outputPath stringByAppendingString:@"/Readme.markdown"]);
}

- (void)testUnzippingFileWithPathTraversalName {
    
    // This zip archive contains a file titled '../../../../../../../../../../..//tmp/test.txt'. SSZipArchive should
    // ignore the path traversing and write the file to "tmp/test.txt"
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"PathTraversal" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Traversal"];
    
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSString *expectedFile = [outputPath stringByAppendingPathComponent:@"tmp/test.txt"];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:expectedFile];
    
    XCTAssertTrue(fileExists, @"Path traversal characters should not be followed when unarchiving a file");
}

- (void)testPathSanitation {
    NSDictionary<NSString *, NSString *> *tests =
    @{
      // directory path starting with slash
      @"/a/": @"/a/",
      // directory path not starting with slash
      @"a/": @"a/",
      // path traversal
      @"../../../../../../../../../../../tmp/test.txt": @"tmp/test.txt",
      // path traversal, Windows style
      @"..\\..\\..\\..\\..\\..\\..\\..\\..\\..\\..\\tmp\\test.txt": @"..\\..\\..\\..\\..\\..\\..\\..\\..\\..\\..\\tmp\\test.txt",
      // relative path
      @"a/b/../c.txt": @"a/c.txt",
      // path traversal with slash (#680)
      @"/..": @"",
      // path traversal without slash
      @"..": @"",
      // permissions override
      @"./": @"",
      @".": @"",
      // unicode and spaces in folder name and file name
      @"example/../à: 𝚨 󌞑/你 好.txt": @"à: 𝚨 󌞑/你 好.txt",
      // unicode that looks like '.' or '/' in ascii decomposition
      @"a/ğ/../b": @"a/b",
      @"a/⸮/b/.ⸯ/c/⼮./d": @"a/⸮/b/.ⸯ/c/⼮./d",
      // scheme in name
      @"file:a/../../../usr/bin": @"usr/bin",
      };
    for (NSString *str in tests) {
        XCTAssertTrue([tests[str] isEqualToString:[str _sanitizedPath]], @"Path should be sanitized for traversal: %@", str);
    }
}

- (void)testDateSanitation {
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    struct tm ptm;

    /* Test min date is in year 1979 */

    UInt32 dos_date_min = 1;
    NSDate *minDate = [SSZipArchive _dateWithMSDOSFormat:dos_date_min];

    components.year = 1979;
    components.month = 11;
    components.day = 30;
    components.hour = 0;
    components.minute = 0;
    components.second = 2;
    NSDate *gregorianMinDate = [gregorian dateFromComponents:components];
    XCTAssertEqual(minDate, gregorianMinDate);

    /* Test our implementation is equivalent to `[NSDate dateWithTimeIntervalSince1970:mz_zip_dosdate_to_time_t(msdosDateTime)]` */

    // copy of mz_zip_dosdate_to_time_t implementation
    uint64_t date_min = (uint64_t)(dos_date_min >> 16);
    ptm.tm_mday  = (int16_t)(date_min & 0x1f);
    ptm.tm_mon   = (int16_t)(((date_min & 0x1E0) / 0x20) - 1);
    ptm.tm_year  = (int16_t)(((date_min & 0x0FE00) / 0x0200) + 80);
    ptm.tm_hour  = (int16_t)((dos_date_min & 0xF800) / 0x800);
    ptm.tm_min   = (int16_t)((dos_date_min & 0x7E0) / 0x20);
    ptm.tm_sec   = (int16_t)(2 * (dos_date_min & 0x1f));
    ptm.tm_isdst = -1;
    XCTAssertEqual(minDate, [NSDate dateWithTimeIntervalSince1970:mktime(&ptm)]);

    /* Test max date is in year 2108 */

    UInt32 dos_date_max = -1;
    NSDate *maxDate = [SSZipArchive _dateWithMSDOSFormat:dos_date_max];

    components.year = 2108;
    components.month = 4;
    components.day = 1;
    components.hour = 8;
    components.minute = 4;
    components.second = 2;
    NSDate *gregorianMaxDate = [gregorian dateFromComponents:components];
    XCTAssertEqual(maxDate, gregorianMaxDate);

    /* Test our implementation is equivalent to `[NSDate dateWithTimeIntervalSince1970:mz_zip_dosdate_to_time_t(msdosDateTime)]` */

    // copy of mz_zip_dosdate_to_time_t implementation
    uint64_t date_max = (uint64_t)(dos_date_max >> 16);
    ptm.tm_mday  = (int16_t)(date_max & 0x1f);
    ptm.tm_mon   = (int16_t)(((date_max & 0x1E0) / 0x20) - 1);
    ptm.tm_year  = (int16_t)(((date_max & 0x0FE00) / 0x0200) + 80);
    ptm.tm_hour  = (int16_t)((dos_date_max & 0xF800) / 0x800);
    ptm.tm_min   = (int16_t)((dos_date_max & 0x7E0) / 0x20);
    ptm.tm_sec   = (int16_t)(2 * (dos_date_max & 0x1f));
    ptm.tm_isdst = -1;
    XCTAssertEqual(maxDate, [NSDate dateWithTimeIntervalSince1970:mktime(&ptm)]);
}

// This tests whether the payload size of the zip file containing 4.8Gb of files with compression 0 is correct,
// and creates a zip file containing 240 20Mb sized files with multiple compression levels. It then unpacks the file and checks whether
// the same number of files is present in the unpacked folder.
- (void)testPayloadSizeCorrectAndUnpackFileNo {
    long long int iterations = 240;
    NSString *unpackPath = [self _cachesPath:@"Unpacked/testFile"];
    NSNumber *goldenSize = [NSNumber numberWithLongLong:iterations * twentyMB];
    NSData *data = [self getRandomNSData:twentyMB];
    NSString *filenName = @"TestFile.zip";
    NSString *filePath = [NSString stringWithFormat:@"%@%@", [self _cachesPath:@""], filenName];
    NSString *password = @"TestPW";
    
    SSZipArchive *archive = [[SSZipArchive alloc] initWithPath:filePath];
    [archive open];
    
    for (int i = 0; i < iterations; i++) {
        NSString *fileName = [NSString stringWithFormat:@"File_%i", i];
        [archive writeData:data filename:fileName compressionLevel:0 password:password AES:true];
    }
    
    bool close = [archive close];
    
    NSNumber *fileSize = [SSZipArchive payloadSizeForArchiveAtPath:filePath error:nil];
    
    XCTAssertTrue(close, "Should be able to close the archive.");
    XCTAssertTrue(fileSize.longLongValue == goldenSize.longLongValue,
                  "Payload size should be equal to the sum of the size of all files included.");
    
    [SSZipArchive unzipFileAtPath:filePath toDestination:unpackPath overwrite:true password:password error:nil];
    long int noFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:unpackPath error:nil].count;
    
    XCTAssertTrue(iterations == noFiles, "All files should be present in the exported directory");
}

- (void)testSymlinkZippingWithFilesAtPaths {
    NSString *outputDir = [self _cachesPath:@"ZippingSymlinkWithFilesAtPaths"];

    //directory
    NSString *directory = [outputDir stringByAppendingPathComponent:@"directory"];
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    XCTAssertTrue(success);

    //write real file
    NSString *realFilePath = [directory stringByAppendingPathComponent:@"originfile"];
    success = [@"Hello World!" writeToFile:realFilePath atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertTrue(success);

    //create symlink to real file
    NSString *symlinkPath = [directory stringByAppendingPathComponent:@"linkfile"];
    success = [[NSFileManager defaultManager] createSymbolicLinkAtPath:symlinkPath withDestinationPath:realFilePath error:NULL];
    XCTAssertTrue(success);

    NSArray *files = @[realFilePath,symlinkPath];

    //zipping
    NSString *archivePath = [outputDir stringByAppendingPathComponent:@"SymlinkZippingWithFilesAtPaths.zip"];
    success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:files withPassword:nil keepSymlinks:YES];
    XCTAssertTrue(success);
        
    //remove files in directory dir, to make sure what we check is unzipped
    success = [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
    XCTAssertTrue(success);
    success = [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    XCTAssertTrue(success);

    //unzip
    success = [SSZipArchive unzipFileAtPath:archivePath toDestination:directory];
    XCTAssertTrue(success);
    
    //check if it's still a symlink
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:symlinkPath error:NULL];
    NSString *fileType = attr[NSFileType];
    XCTAssertTrue([fileType isEqualToString:NSFileTypeSymbolicLink]);

    //check symlink points correctly
    NSString *realFilePathUnzip = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:symlinkPath error:NULL];
    XCTAssertEqualObjects(realFilePath, realFilePathUnzip);
}

- (void)testSymlinkZippingWithContentsOfDirectory {
    NSString *outputDir = [self _cachesPath:@"ZippingSymlinkWithContentsOfDirectory"];

    //directory
    NSString *directory = [outputDir stringByAppendingPathComponent:@"directory"];
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    XCTAssertTrue(success);

    //write real file
    NSString *realFilePath = [directory stringByAppendingPathComponent:@"origin"];
    success = [@"Hello World!" writeToFile:realFilePath atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertTrue(success);

    //create symlink to real file
    NSString *symlinkPath = [directory stringByAppendingPathComponent:@"link"];
    success = [[NSFileManager defaultManager] createSymbolicLinkAtPath:symlinkPath withDestinationPath:realFilePath error:NULL];
    XCTAssertTrue(success);

    //zipping
    NSString *archivePath = [outputDir stringByAppendingPathComponent:@"SymlinkZippingWithContentsOfDirectory.zip"];
    success = [SSZipArchive createZipFileAtPath:archivePath
                       withContentsOfDirectory:directory
                           keepParentDirectory:NO
                              compressionLevel:-1
                                      password:nil
                                           AES:YES
                               progressHandler:nil
                                  keepSymlinks:YES];
    XCTAssertTrue(success);
        
    //remove files in directory dir, to make sure what we check is unzipped
    success = [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
    XCTAssertTrue(success);
    success = [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    XCTAssertTrue(success);

    //unzip
    success = [SSZipArchive unzipFileAtPath:archivePath toDestination:directory];
    XCTAssertTrue(success);
    
    //check if it's still a symlink
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:symlinkPath error:NULL];
    NSString *fileType = attr[NSFileType];
    XCTAssertTrue([fileType isEqualToString:NSFileTypeSymbolicLink]);

    //check symlink points correctly
    NSString *realFilePathUnzip = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:symlinkPath error:NULL];
    XCTAssertEqualObjects(realFilePath, realFilePathUnzip);
}



#pragma mark - Private

/// Returns sizeInBytes of random data
- (NSData*)getRandomNSData:(size_t)sizeInBytes {
    void *buff = malloc(sizeInBytes);
    arc4random_buf(buff, sizeInBytes);
    return [NSData dataWithBytesNoCopy:buff length:sizeInBytes freeWhenDone:YES];
}


- (NSString *)_cachesPath:(NSString *)directory {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject
                      stringByAppendingPathComponent:@"com.samsoffes.ssziparchive.tests"];
    if (directory) {
        path = [path stringByAppendingPathComponent:directory];
    }

    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    XCTAssertTrue(success, @"%@", path);

    return path;
}


- (NSString *)_calculateSHA256Hash:(NSData *)data {
    
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];

    CC_SHA256(data.bytes, (CC_LONG) data.length, digest);

    //convert the SHA hash to a string
    
    NSMutableString* ms = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH];
    
    for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [ms appendFormat:@"%02x", digest[i]];
    }

    return [ms copy];
}
@end
