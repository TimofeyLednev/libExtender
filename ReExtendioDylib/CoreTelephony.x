@import Foundation;

// CoreTelephony radio access technology strings.
//
// The CoreTelephony framework itself exists on iOS 6, but these
// CTRadioAccessTechnology* string constants were introduced in iOS 7.
// Brawl Stars (built against the iOS 8 SDK) strong-links them, so dyld
// aborts at launch on iOS 6.1.3 with:
//
//   Symbol not found: _CTRadioAccessTechnologyWCDMA
//   Expected in: .../CoreTelephony.framework/CoreTelephony
//
// Exporting them from this shim satisfies dyld before the process starts.
// Values mirror Apple's real constant strings so any code comparing against
// CTTelephonyNetworkInfo.currentRadioAccessTechnology still behaves.

#define RE_CT_EXPORT __attribute__((visibility("default"))) NSString * const

RE_CT_EXPORT CTRadioAccessTechnologyDidChangeNotification = @"CTRadioAccessTechnologyDidChangeNotification";
RE_CT_EXPORT CTRadioAccessTechnologyGPRS = @"CTRadioAccessTechnologyGPRS";
RE_CT_EXPORT CTRadioAccessTechnologyEdge = @"CTRadioAccessTechnologyEdge";
RE_CT_EXPORT CTRadioAccessTechnologyWCDMA = @"CTRadioAccessTechnologyWCDMA";
RE_CT_EXPORT CTRadioAccessTechnologyHSDPA = @"CTRadioAccessTechnologyHSDPA";
RE_CT_EXPORT CTRadioAccessTechnologyHSUPA = @"CTRadioAccessTechnologyHSUPA";
RE_CT_EXPORT CTRadioAccessTechnologyCDMA1x = @"CTRadioAccessTechnologyCDMA1x";
RE_CT_EXPORT CTRadioAccessTechnologyCDMAEVDORev0 = @"CTRadioAccessTechnologyCDMAEVDORev0";
RE_CT_EXPORT CTRadioAccessTechnologyCDMAEVDORevA = @"CTRadioAccessTechnologyCDMAEVDORevA";
RE_CT_EXPORT CTRadioAccessTechnologyCDMAEVDORevB = @"CTRadioAccessTechnologyCDMAEVDORevB";
RE_CT_EXPORT CTRadioAccessTechnologyeHRPD = @"CTRadioAccessTechnologyeHRPD";
RE_CT_EXPORT CTRadioAccessTechnologyLTE = @"CTRadioAccessTechnologyLTE";

#undef RE_CT_EXPORT
