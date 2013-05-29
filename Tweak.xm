#import "SpringBoard.h"

static NSMutableSet *runningIcons;
static BOOL showCloseButtons;
static BOOL showInSwitcher;

static int (*BKSTerminateApplicationForReasonAndReportWithDescription)(NSString *displayIdentifier, int reason, int something, int something2);

%hook SBAppSwitcherController

static SBIconModel *SharedIconModel(void)
{
	return [%c(SBIconViewMap) instancesRespondToSelector:@selector(iconModel)] ? [[%c(SBIconViewMap) homescreenMap] iconModel] : [%c(SBIconModel) sharedInstance];
}

static void ApplicationLaunched(SBApplication *application)
{
	SBIcon *icon = [SharedIconModel() applicationIconForDisplayIdentifier:[application displayIdentifier]];
	if (icon) {
		[runningIcons addObject:icon];
		SBIconView *iconView = %c(SBIconViewMap) ? [[%c(SBIconViewMap) homescreenMap] mappedIconViewForIcon:icon] : (SBIconView *)icon;
		if (iconView) {
			if ([icon respondsToSelector:@selector(setShowsImages:)])
				[icon setShowsImages:YES];
			[iconView prepareDropGlow];
			UIImageView *dropGlow = [iconView dropGlow];
			dropGlow.image = [UIImage imageNamed:@"RunningGlow"];
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:1.0];
			[iconView showDropGlow:YES];
			[iconView setShowsCloseBox:showCloseButtons];
			[UIView commitAnimations];
		}
	}
}

static void ApplicationDied(SBApplication *application)
{
	SBIcon *icon = [SharedIconModel() applicationIconForDisplayIdentifier:[application displayIdentifier]];
	if (icon) {
		[runningIcons removeObject:icon];
		SBIconView *iconView = %c(SBIconViewMap) ? [[%c(SBIconViewMap) homescreenMap] mappedIconViewForIcon:icon] : (SBIconView *)icon;
		if (iconView) {
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:1.0];
			[iconView showDropGlow:NO];
			[iconView setShowsCloseBox:NO];
			[UIView commitAnimations];
		}
	}
}

static void KillApplication(SBApplication *app)
{
	if (BKSTerminateApplicationForReasonAndReportWithDescription != NULL) {
		BKSTerminateApplicationForReasonAndReportWithDescription([app displayIdentifier], 1, 0, 0);
	} else {
		[app kill];
	}
}

- (void)applicationLaunched:(SBApplication *)application
{
	ApplicationLaunched(application);
	%orig;
}

- (void)applicationDied:(SBApplication *)application
{
	ApplicationDied(application);
	%orig;
}

- (void)_appActivationStateDidChange:(NSNotification *)notification
{
	SBApplication *app = notification.object;
	if ([app isRunning])
		ApplicationLaunched(app);
	else
		ApplicationDied(app);
	%orig();
}

%end

%hook SBApplicationIcon

- (void)closeBoxTapped
{
	if (showCloseButtons && [runningIcons containsObject:self]) {
		SBIconController *iconController = [%c(SBIconController) sharedInstance];
		if (![iconController isEditing] || ![iconController canUninstallIcon:self]) {
			KillApplication([self application]);
			return;
		}
	}
	%orig;
}

- (void)setShowsCloseBox:(BOOL)newValue
{
	%orig(newValue || ([runningIcons containsObject:self] && showCloseButtons));
}

%end

%hook SBIconView

- (void)closeBoxTapped
{
	SBApplicationIcon *icon = (SBApplicationIcon *)self.icon;
	if (showCloseButtons && [runningIcons containsObject:icon]) {
		SBIconController *iconController = [%c(SBIconController) sharedInstance];
		if (![iconController isEditing] || ![iconController canUninstallIcon:icon]) {
			KillApplication([icon application]);
			return;
		}
	}
	%orig;
}

- (void)setShowsCloseBox:(BOOL)newValue animated:(BOOL)animated
{
	%orig(newValue || ([runningIcons containsObject:self.icon] && showCloseButtons), animated);
}

%end

%hook SBIconViewMap

- (void)_addIconView:(SBIconView *)iconView forIcon:(SBIcon *)icon
{
	%orig;
	if ([runningIcons containsObject:icon] && (showInSwitcher || self == [%c(SBIconViewMap) homescreenMap])) {
		[iconView prepareDropGlow];
		UIImageView *dropGlow = [iconView dropGlow];
		dropGlow.image = [UIImage imageNamed:@"RunningGlow"];
		[iconView showDropGlow:YES];
		[iconView setShowsCloseBox:showCloseButtons];
	}
}

%end

static void LoadSettings()
{
	NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.rpetrich.runningindicator.plist"];
	id temp = [settings objectForKey:@"RIShowCloseButtons"];
	showCloseButtons = temp ? [temp boolValue] : YES;
	temp = [settings objectForKey:@"RIShowInSwitcher"];
	showInSwitcher = temp ? [temp boolValue] : YES;
	[settings release];
}

static void SettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	LoadSettings();
	if (%c(SBIconViewMap)) {
		SBIconViewMap *map = [%c(SBIconViewMap) homescreenMap];
		for (SBIcon *icon in runningIcons)
			[[map mappedIconViewForIcon:icon] setShowsCloseBox:showCloseButtons];
	} else {
		for (SBIcon *icon in runningIcons)
			[icon setShowsCloseBox:showCloseButtons];
	}
}

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	%init;
	void *bk = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
	if (bk) {
		BKSTerminateApplicationForReasonAndReportWithDescription = (int (*)(NSString*, int, int, int))dlsym(bk, "BKSTerminateApplicationForReasonAndReportWithDescription");
	}
	LoadSettings();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, SettingsChanged, CFSTR("com.rpetrich.runningindicator/settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	runningIcons = [[NSMutableSet alloc] init];
	[pool drain];
}