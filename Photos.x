@import Foundation;
//stubby stub stubs
// iOS 6 has no Photos.framework (added in iOS 8). Apps that merely *link*
// against it — without actually calling into it — abort at dyld load time with
// "Library not loaded: .../Photos.framework/Photos". This empty stub satisfies
// the load command so the app can launch. If an app actually references Photos
// classes/symbols, add matching stub interfaces here (see GameController.x).
@interface PHPhotoLibrary : NSObject
@end

@implementation PHPhotoLibrary
@end

@interface PHAsset : NSObject
@end

@implementation PHAsset
@end
