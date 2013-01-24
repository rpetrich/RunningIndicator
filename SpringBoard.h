@interface SBApplication : NSObject
- (void)kill;
- (NSBundle *)bundle;
- (NSString *)displayIdentifier;
@end

@interface SBIcon : NSObject
@end

@interface SBIcon (iOS4)
- (void)setShowsImages:(BOOL)shows;
- (void)setShowsCloseBox:(BOOL)show;
@end

@interface SBIconController : NSObject
+ (id)sharedInstance;
- (BOOL)isEditing;
- (BOOL)canUninstallIcon:(SBIcon *)icon;
@end

@interface SBApplicationIcon : SBIcon
- (SBApplication *)application;
- (void)closeBoxTapped;
@end

@interface SBIconView : UIView
- (void)setShowsImages:(BOOL)shows;
- (void)prepareDropGlow;
- (UIImageView *)dropGlow;
- (void)showDropGlow:(BOOL)show;
- (void)setShowsCloseBox:(BOOL)show;
- (SBIcon *)icon;
@end

@interface SBIconViewMap : NSObject
+ (id)homescreenMap;
- (SBIconView *)mappedIconViewForIcon:(SBIcon *)icon;
@end

@interface SBIconModel : NSObject
+ (id)sharedInstance;
- (SBApplicationIcon *)applicationIconForDisplayIdentifier:(NSString *)displayID;
@end