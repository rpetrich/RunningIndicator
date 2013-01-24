#import "SpringBoard.h"
#include <sys/stat.h>

static NSMutableSet *runningIcons;
static BOOL showCloseButtons;

%hook SBAppSwitcherController

- (void)applicationLaunched:(SBApplication *)application
{
	SBIconModel *iconModel = [%c(SBIconModel) sharedInstance];
	SBIcon *icon = [iconModel applicationIconForDisplayIdentifier:[application displayIdentifier]];
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
			[iconView setShowsCloseBox:NO];
			[UIView commitAnimations];
		}
	}
	%orig;
}

- (void)applicationDied:(SBApplication *)application
{
	SBIconModel *iconModel = [%c(SBIconModel) sharedInstance];
	SBIcon *icon = [iconModel applicationIconForDisplayIdentifier:[application displayIdentifier]];
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
	%orig;
}

%end

%hook SBApplicationIcon

- (void)closeBoxTapped
{
	if (showCloseButtons && [runningIcons containsObject:self]) {
		SBIconController *iconController = [%c(SBIconController) sharedInstance];
		if (![iconController isEditing] || ![iconController canUninstallIcon:self]) {
			[[self application] kill];
			return;
		}
	}
	%orig;
}

- (void)setShowsCloseBox:(BOOL)newValue {
	struct stat st;
	if (stat([[[[self application] bundle] executablePath] UTF8String], &st) == -1)
		%orig;
	else
		%orig(newValue || ([runningIcons containsObject:self] && showCloseButtons && st.st_uid!=0));
}

%end

%hook SBIconView

- (void)closeBoxTapped
{
	SBApplicationIcon *icon = (SBApplicationIcon *)[self icon];
	if (showCloseButtons && [runningIcons containsObject:icon]) {
		SBIconController *iconController = [%c(SBIconController) sharedInstance];
		if (![iconController isEditing] || ![iconController canUninstallIcon:icon]) {
			[[icon application] kill];
			return;
		}
	}
	%orig;
}

- (void)setShowsCloseBox:(BOOL)newValue animated:(BOOL)animated
{
	struct stat st;
	if (stat([[[[(SBApplicationIcon *)[self icon] application] bundle] executablePath] UTF8String], &st) == -1)
		%orig;
	else
		%orig(newValue || ([runningIcons containsObject:[self icon]] && showCloseButtons && st.st_uid!=0), animated);
}

%end

%hook SBIconViewMap

- (void)_addIconView:(SBIconView *)iconView forIcon:(SBIcon *)icon
{
	%orig;
	if ([runningIcons containsObject:icon]) {
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
	NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Library/Preferences/com.rpetrich.runningindicator.plist", NSHomeDirectory()]];
	id temp = [settings objectForKey:@"RIShowCloseButtons"];
	showCloseButtons = temp ? [temp boolValue] : YES;
	[settings release];
}

static void SettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	LoadSettings();
	if (%c(SBIconViewMap)) {
		SBIconViewMap *map = [%c(SBIconViewMap) homescreenMap];
		for (SBIcon *icon in runningIcons)
			[[map mappedIconViewForIcon:icon] setShowsCloseBox:NO];
	} else {
		for (SBIcon *icon in runningIcons)
			[icon setShowsCloseBox:NO];
	}
}

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	%init;
	LoadSettings();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, SettingsChanged, CFSTR("com.rpetrich.runningindicator/settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	runningIcons = [[NSMutableSet alloc] init];
	[pool drain];
}