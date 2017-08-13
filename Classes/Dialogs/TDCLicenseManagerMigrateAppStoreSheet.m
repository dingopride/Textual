/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Textual and/or "Codeux Software, LLC", nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

#import <CoreServices/CoreServices.h>

NS_ASSUME_NONNULL_BEGIN

/* 
 * TDCLicenseManagerMigrateAppStoreSheet presents an open dialog to
 * find a copy of Textual with a receipt then presents a sheet asking
 * for the user's e-mail address as long as a valid receipt is present.
 */

#if TEXTUAL_BUILT_WITH_LICENSE_MANAGER == 1
#define _licenseOwnerNameMaximumLength						125
#define _licenseOwnerContactAddressMaximumLength			125

@interface TDCLicenseManagerMigrateAppStoreSheet ()
@property (nonatomic, weak) IBOutlet TVCTextFieldWithValueValidation *licenseOwnerNameTextField;
@property (nonatomic, weak) IBOutlet TVCTextFieldWithValueValidation *licenseOwnerContactAddressTextField;
@property (nonatomic, copy) NSString *cachedReceiptData;
@end

@implementation TDCLicenseManagerMigrateAppStoreSheet

#pragma mark -
#pragma mark Contact Address Sheet

- (instancetype)init
{
	if ((self = [super init])) {
		[self prepareInitialState];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[RZMainBundle() loadNibNamed:@"TDCLicenseManagerMigrateAppStoreSheet" owner:self topLevelObjects:nil];
}

- (void)startContactAddressSheet
{
	/* E-mail address text field configuration */
	self.licenseOwnerContactAddressTextField.stringValueIsInvalidOnEmpty = YES;
	self.licenseOwnerContactAddressTextField.stringValueUsesOnlyFirstToken = YES;

	self.licenseOwnerContactAddressTextField.onlyShowStatusIfErrorOccurs = YES;

	self.licenseOwnerContactAddressTextField.textDidChangeCallback = self;

	self.licenseOwnerContactAddressTextField.stringValue = [XRAddressBook myEmailAddress];

	self.licenseOwnerContactAddressTextField.validationBlock = ^BOOL(NSString *currentValue) {
		return (currentValue.length < _licenseOwnerContactAddressMaximumLength);
	};

	/* First & last name text field configuration */
	self.licenseOwnerNameTextField.stringValueIsInvalidOnEmpty = YES;
	self.licenseOwnerNameTextField.stringValueUsesOnlyFirstToken = NO;

	self.licenseOwnerNameTextField.onlyShowStatusIfErrorOccurs = YES;

	self.licenseOwnerNameTextField.textDidChangeCallback = self;

	self.licenseOwnerNameTextField.stringValue = [XRAddressBook myName];

	self.licenseOwnerNameTextField.validationBlock = ^BOOL(NSString *currentValue) {
		return (currentValue.length < _licenseOwnerNameMaximumLength);
	};

	/* Begin sheet... */
	[self startSheet];
}

- (void)validatedTextFieldTextDidChange:(id)sender
{
	self.okButton.enabled = (self.licenseOwnerNameTextField.valueIsValid &&
							 self.licenseOwnerContactAddressTextField.valueIsValid);
}

- (void)start
{
	[self findTextualUsingLaucnhServices];
}

- (void)ok:(id)sender
{
	NSString *receiptData = self.cachedReceiptData;

	NSString *licenseOwnerName = self.licenseOwnerNameTextField.value;

	NSString *licenseOwnerContactAddress = self.licenseOwnerContactAddressTextField.value;

	[self.delegate licenseManagerMigrateAppStoreSheet:self
									   convertReceipt:receiptData
									 licenseOwnerName:licenseOwnerName
						   licenseOwnerContactAddress:licenseOwnerContactAddress];

	[super ok:sender];
}

#pragma mark -
#pragma mark Open Dialog

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
	NSString *applicationName = nil;

	if ([self canUseApplicationAtURL:url applicationName:&applicationName] == NO) {
		if (outError) {
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

			userInfo[NSURLErrorKey] = url;
			
			userInfo[NSLocalizedDescriptionKey] = TXTLS(@"TLOLicenseManager[1009][1]", applicationName);

			userInfo[NSLocalizedRecoverySuggestionErrorKey] = TXTLS(@"TLOLicenseManager[1009][2]");

			*outError = [NSError errorWithDomain:TXErrorDomain code:27984 userInfo:userInfo];
		}

		return NO;
	}

	return YES;
}

- (void)findTextualUsingLaucnhServices
{
	CFURLRef searchScopeURL = (__bridge CFURLRef)[NSURL URLWithString:@"textual://knowledge-base"];

	NSArray *matchedApplications = (__bridge_transfer NSArray *)LSCopyApplicationURLsForURL(searchScopeURL, kLSRolesViewer);

	NSURL *matchedApplication = nil;

	for (NSURL *applicationURL in matchedApplications) {
		if ([self canUseApplicationAtURL:applicationURL applicationName:NULL]) {
			matchedApplication = applicationURL;

			LogToConsoleInfo("Automatically detected Mac App Store Textual 7 at the following path: %{public}@",
					matchedApplication.path)

			break;
		}
	}

	if (matchedApplication) {
		[self haveApplicationAtURL:matchedApplication];
	} else {
		[self presentOpenDialog];
	}
}

- (void)presentOpenDialog
{
	NSOpenPanel *d = [NSOpenPanel openPanel];

	NSURL *applicationsPath = [TPCPathInfo systemApplicationFolderURL];

	if (applicationsPath) {
		d.directoryURL = applicationsPath;
	}

	d.allowedFileTypes = @[@"app"];

	d.delegate = (id)self;

	d.allowsMultipleSelection = NO;
	d.canChooseDirectories = NO;
	d.canChooseFiles = YES;
	d.canCreateDirectories = NO;
	d.resolvesAliases = YES;

	d.message = TXTLS(@"TLOLicenseManager[1008]");

	d.prompt = TXTLS(@"Prompts[0006]");

	[d beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
		if (result == NSModalResponseOK) {
			[self haveApplicationAtURL:d.URL];
		} else {
			[self cancel:nil];
		}
	}];
}

- (void)haveApplicationAtURL:(NSURL *)applicationURL
{
	NSParameterAssert(applicationURL != nil);

	NSString *receiptData = [self receiptDataForApplicationAtURL:applicationURL];

	if (receiptData) {
		self.cachedReceiptData = receiptData;

		XRPerformBlockAsynchronouslyOnMainQueue(^{
			[self startContactAddressSheet];
		});

		return;
	}

	[self cancel:nil];
}

#pragma mark -
#pragma mark Helper Methods

- (nullable NSString *)receiptDataForApplicationAtURL:(NSURL *)applicationURL
{
	NSParameterAssert(applicationURL != nil);

	/* Locate application bundle and determine whether the receipt
	 file is even contained within it. */
	NSBundle *applicationBundle = [NSBundle bundleWithURL:applicationURL];

	if (applicationBundle == nil) {
		return nil;
	}

	NSURL *receiptFileURL = applicationBundle.appStoreReceiptURL;

	if (receiptFileURL == nil) {
		return nil;
	}

	if ([RZFileManager() fileExistsAtPath:receiptFileURL.path] == NO) {
		return nil;
	}

	/* If the receipt file exists, request the data and cache the base64
	 value of the receipt data. */
	NSError *receiptDataReadError = nil;

	NSData *receiptData = [NSData dataWithContentsOfURL:receiptFileURL options:0 error:&receiptDataReadError];

	if (receiptData == nil) {
		LogToConsoleError("Failed to read the contents of the receipt file: %{public}@",
				receiptDataReadError.localizedDescription)

		return nil;
	}

	return [XRBase64Encoding encodeData:receiptData];
}

- (BOOL)canUseApplicationAtURL:(NSURL *)applicationURL applicationName:(NSString * _Nullable * _Nullable)applicationName
{
	/* The license API performs validation of the uploaded receipt which
	 means that the the only thing we need to know at this point is that
	 the bundlen identifier of the application is a known value and that
	 the receipt file actually does exist in the application. */
	NSBundle *applicationBundle = [NSBundle bundleWithURL:applicationURL];

	if (applicationBundle == nil) {
		return NO;
	}

	/* Pass to caller the application name of the bundle. */
	if ( applicationName) {
		*applicationName = applicationBundle.displayName;
	}

	/* Compare bundle identifier. */
	/* The bundle identifier used for comparison is hard coded is because
	 the bundle identifier for the running copy can be different than the
	 value that we are expecting from an older copy which we cannot change. */
	NSString *applicationBundleID = [applicationBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];

	if (NSObjectsAreEqual(applicationBundleID, @"com.codeux.irc.textual5") == NO &&
		NSObjectsAreEqual(applicationBundleID, @"com.codeux.apps.textual-mas") == NO)
	{
		return NO;
	}

	/* Determine whether a receipt file exists. */
	NSURL *receiptFileURL = applicationBundle.appStoreReceiptURL;

	if (receiptFileURL == nil) {
		return NO;
	}

	if ([RZFileManager() fileExistsAtPath:receiptFileURL.path] == NO) {
		return NO;
	}

	/* Return successful result */
	return YES;
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self.delegate licenseManagerMigrateAppStoreSheetWillClose:self];
}

@end
#endif

NS_ASSUME_NONNULL_END
