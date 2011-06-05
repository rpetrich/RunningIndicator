#import <SpringBoard/SpringBoard.h>

@interface SBIconModel (iOS40)
- (SBApplicationIcon *)applicationIconForDisplayIdentifier:(NSString *)displayIdentifier;
@end

@interface SBIcon (iOS40)
- (void)prepareDropGlow;
- (UIImageView *)dropGlow;
- (void)showDropGlow:(BOOL)showDropGlow;
- (void)setShowsCloseBox:(BOOL)showsCloseBox;
@end

@interface SBIconController (iOS40)
- (BOOL)canUninstallIcon:(SBIcon *)icon;
@end
