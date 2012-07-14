/*
 * This file is part of Bit Slicer.
 *
 * Bit Slicer is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 
 * Bit Slicer is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * You should have received a copy of the GNU General Public License
 * along with Bit Slicer.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Created by Mayur Pawashe on 2/5/10.
 * Copyright 2010 zgcoder. All rights reserved.
 */

#import "ZGAppController.h"
#import "ZGDocumentController.h"
#import <SecurityFoundation/SFAuthorization.h>
#import <Security/AuthorizationTags.h>
#import "ZGPreferencesController.h"
#import "ZGMemoryViewer.h"
#import "ZGProcess.h"
#import "ZGCalculator.h"

@interface ZGAppController (Private)

- (void)openPreferences:(id)sender
             showWindow:(BOOL)shouldShowWindow;

- (void)openMemoryViewer:(id)sender
              showWindow:(BOOL)shouldShowWindow;

@end

@implementation ZGAppController

@synthesize applicationIsAuthenticated;

#pragma mark Singleton & Accessors

static ZGAppController *sharedInstance = nil;

+ (BOOL)isRunningLaterThanLion
{
    SInt32 majorVersion;
    SInt32 minorVersion;
    
    if (Gestalt(gestaltSystemVersionMajor, &majorVersion) != noErr)
    {
        return NO;
    }
    
    if (Gestalt(gestaltSystemVersionMinor, &minorVersion) != noErr)
    {
        return NO;
    }
    
    return (majorVersion == 10 && minorVersion >= 7) || majorVersion > 10;
}

+ (ZGAppController *)sharedController
{
	return sharedInstance;
}

- (id)init
{
	self = [super init];
	
	if (self)
	{
		sharedInstance = self;
	}
	
	return self;
}

- (ZGPreferencesController *)preferencesController
{
    return preferencesController;
}

- (ZGMemoryViewer *)memoryViewer
{
	return memoryViewer;
}

- (ZGDocumentController *)documentController
{
	return documentController;
}

#pragma mark Authenticating

int acquireTaskportRight(void)
{
	OSStatus stat;
	AuthorizationItem taskport_item[1];
	taskport_item[0].name = "system.privilege.taskport:";
	taskport_item[0].valueLength = 0;
	taskport_item[0].value = NULL;
	taskport_item[0].flags = 0;
	
	AuthorizationRights rights = {1, taskport_item}, *out_rights = NULL;
	AuthorizationRef author;
	
	AuthorizationFlags auth_flags = kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize | kAuthorizationFlagInteractionAllowed | ( 1 << 5);
	
	stat = AuthorizationCreate (NULL, kAuthorizationEmptyEnvironment,auth_flags,&author);
	if (stat != errAuthorizationSuccess)
    {
		NSLog(@"Failure on AuthorizationCreate");
		return 0;
    }
	
	stat = AuthorizationCopyRights ( author, &rights, kAuthorizationEmptyEnvironment, auth_flags,&out_rights);
	if (stat != errAuthorizationSuccess)
    {
		NSLog(@"Failure on AuthorizationCopyRights");
		return 1;
    }
	return 0;
}

#pragma mark Pausing and Unpausing processes

OSStatus pauseOrUnpauseHotKeyHandler(EventHandlerCallRef nextHandler,EventRef theEvent, void *userData)
{
	for (NSRunningApplication *runningApplication in [[NSWorkspace sharedWorkspace] runningApplications])
	{
		if ([runningApplication isActive] && [runningApplication processIdentifier] != getpid())
		{
			[ZGProcess pauseOrUnpauseProcess:[runningApplication processIdentifier]];
		}
	}
	
	return noErr;
}

static EventHotKeyRef hotKeyRef;
static BOOL didRegisteredHotKey = NO;
+ (void)registerPauseAndUnpauseHotKey
{
	if (didRegisteredHotKey)
	{
		UnregisterEventHotKey(hotKeyRef);
	}
	
	NSNumber *hotKeyCodeNumber = [[NSUserDefaults standardUserDefaults] objectForKey:ZG_HOT_KEY];
    NSNumber *hotKeyModifier = [[NSUserDefaults standardUserDefaults] objectForKey:ZG_HOT_KEY_MODIFIER];
    
	if (hotKeyCodeNumber && [hotKeyCodeNumber intValue] > INVALID_KEY_CODE)
	{
		EventTypeSpec eventType;
		eventType.eventClass = kEventClassKeyboard;
		eventType.eventKind = kEventHotKeyPressed;
		
		InstallApplicationEventHandler(&pauseOrUnpauseHotKeyHandler, 1, &eventType, NULL, NULL);
		
		EventHotKeyID hotKeyID;
		hotKeyID.signature = 'htk1';
		hotKeyID.id = 1;
		
		RegisterEventHotKey([hotKeyCodeNumber intValue], [hotKeyModifier intValue], hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef);
		
		didRegisteredHotKey = YES;
	}
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	// Make sure that we unfreeze all processes that we may have frozen
	for (NSRunningApplication *runningApplication in [[NSWorkspace sharedWorkspace] runningApplications])
	{
		if ([[ZGProcess frozenProcesses] containsObject:[NSNumber numberWithInt:[runningApplication processIdentifier]]])
		{
			[ZGProcess pauseOrUnpauseProcess:[runningApplication processIdentifier]];
		}
	}
}

#pragma mark Controller behavior

- (void)checkForUpdates
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:ZG_CHECK_FOR_UPDATES])
	{
		__block NSDictionary *latestVersionDictionary = nil;
		
		dispatch_block_t compareVersionsBlock = ^
		{
			if (latestVersionDictionary)
			{
				NSString *currentShortVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
				NSString *currentBuildString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
				double currentVersion = [currentBuildString doubleValue];
				double latestStableVersion = [[latestVersionDictionary objectForKey:@"Build-Stable"] doubleValue];
				double latestAlphaVersion = [[latestVersionDictionary objectForKey:@"Build-Alpha"] doubleValue];
				
				BOOL checkForAlphas = [[NSUserDefaults standardUserDefaults] boolForKey:ZG_CHECK_FOR_ALPHA_UPDATES];
				if (!checkForAlphas && (floor(currentVersion) != currentVersion))
				{
					// we are in an alpha version, so we should check for alpha updates since we're already checking for regular updates
					[[NSUserDefaults standardUserDefaults] setBool:YES
															forKey:ZG_CHECK_FOR_ALPHA_UPDATES];
					[preferencesController updateAlphaUpdatesUI];
					checkForAlphas = YES;
				}
				
				NSString *latestShortVersion = nil;
				NSString *latestVersionURL = nil;
				
				if (checkForAlphas && (latestAlphaVersion > latestStableVersion) && (latestAlphaVersion > currentVersion))
				{
					latestShortVersion = [latestVersionDictionary objectForKey:@"Version-Alpha"];
					latestVersionURL = [latestVersionDictionary objectForKey:@"URL-Alpha"];
				}
				else if (latestStableVersion > currentVersion)
				{
					latestShortVersion = [latestVersionDictionary objectForKey:@"Version-Stable"];
					latestVersionURL = [latestVersionDictionary objectForKey:@"URL-Stable"];
				}
				
				if (latestShortVersion && latestVersionURL)
				{
					switch (NSRunAlertPanel(@"A new version is available", @"You currently have version %@. Do you want to update to %@?", @"Yes", @"No", @"Don't ask me again", currentShortVersion, latestShortVersion))
					{
						case NSAlertDefaultReturn: // yes, I want update
							[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:latestVersionURL]];
							break;
						case NSAlertOtherReturn: // don't ask again
							[[NSUserDefaults standardUserDefaults] setBool:NO
																	forKey:ZG_CHECK_FOR_UPDATES];
							[[NSUserDefaults standardUserDefaults] setBool:NO
																	forKey:ZG_CHECK_FOR_ALPHA_UPDATES];
							break;
					}
				}
			}
			else
			{
				NSLog(@"Cannot find latest version of Bit Slicer");
			}
			
			[latestVersionDictionary release];
		};
		
		dispatch_block_t queryLatestVersionBlock = ^
		{
			latestVersionDictionary = [[NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:BIT_SLICER_VERSION_FILE]] retain];
			dispatch_async(dispatch_get_main_queue(), compareVersionsBlock);
		};
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), queryLatestVersionBlock);
	}
}

#define CHECK_PROCESSES_TIME_INTERVAL 0.5
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{	
	acquireTaskportRight();
    
    // Initialize preference defaults
    [self openPreferences:nil
               showWindow:NO];
    
	[[self class] registerPauseAndUnpauseHotKey];
	[ZGCalculator initializeCalculator];
	
	[self checkForUpdates];
	
	[NSTimer scheduledTimerWithTimeInterval:CHECK_PROCESSES_TIME_INTERVAL
									 target:self
								   selector:@selector(checkProcesses:)
								   userInfo:nil
									repeats:YES];
}

#pragma mark Actions

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    if ([identifier isEqualToString:ZGMemoryViewerIdentifier])
    {
        [[self sharedController] openMemoryViewer:nil
                                       showWindow:NO];
        
        completionHandler([[[self sharedController] memoryViewer] window], nil);
    }
    else if ([identifier isEqualToString:ZGPreferencesIdentifier])
    {
        [[self sharedController] openPreferences:nil
                                      showWindow:NO];
        
        completionHandler([[[self sharedController] preferencesController] window], nil);
    }
}

- (void)openPreferences:(id)sender
             showWindow:(BOOL)shouldShowWindow
{
    if (!preferencesController)
	{
		preferencesController = [[ZGPreferencesController alloc] init];
	}
	
    if (shouldShowWindow)
    {
        [preferencesController showWindow:nil];
    }
}

- (IBAction)openPreferences:(id)sender
{
    [self openPreferences:sender
               showWindow:YES];
}

- (void)openMemoryViewer:(id)sender
              showWindow:(BOOL)shouldShowWindow
{
    if (!memoryViewer)
	{
		memoryViewer = [[ZGMemoryViewer alloc] init];
	}
	
    if (shouldShowWindow)
    {
        [memoryViewer showWindow:nil];
    }
}

- (IBAction)openMemoryViewer:(id)sender
{
    [self openMemoryViewer:sender
                showWindow:YES];
}

- (IBAction)jumpToMemoryAddress:(id)sender
{
	[memoryViewer jumpToMemoryAddressRequest];
}

#define FAQ_URL @"http://portingteam.com/index.php/topic/4454-faq-information/"
- (IBAction)help:(id)sender
{	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:FAQ_URL]];
}

#pragma mark Menu Item Validation

- (BOOL)validateMenuItem:(NSMenuItem *)theMenuItem
{
	if ([theMenuItem action] == @selector(jumpToMemoryAddress:))
	{
		if (!memoryViewer || ![memoryViewer canJumpToAddress])
		{
			return NO;
		}
	}
	
	return YES;
}

#pragma mark Watching processes

- (void)checkProcesses:(NSTimer *)timer
{
	// So basically, NSWorkspace's methods for notifying us of processes terminating and launching,
	// don't notify us of processes that main applications spawn
	// So we check every few seconds if any new process spawns
	// In my experience, an example of this is with Chrome processes
	
	NSArray *newRunningApplications = [[NSWorkspace sharedWorkspace] runningApplications];
	BOOL anApplicationLaunchedOrTerminated = NO;
	
	for (NSRunningApplication *runningApplication in newRunningApplications)
	{
		// Check if a process spawned
		if (![runningApplications containsObject:runningApplication])
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:ZGProcessLaunched
																object:self
															  userInfo:[NSDictionary dictionaryWithObject:runningApplication
																								   forKey:ZGRunningApplication]];
			anApplicationLaunchedOrTerminated = YES;
		}
	}
	
	for (NSRunningApplication *runningApplication in runningApplications)
	{
		// Check if a process terminated
		if (![newRunningApplications containsObject:runningApplication])
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:ZGProcessTerminated
																object:self
															  userInfo:[NSDictionary dictionaryWithObject:runningApplication
																								   forKey:ZGRunningApplication]];
			anApplicationLaunchedOrTerminated = YES;
		}
	}
	
	if (anApplicationLaunchedOrTerminated)
	{
		[runningApplications release];
		runningApplications = [newRunningApplications retain];
	}
}

@end
