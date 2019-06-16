
//#if __has_include("RCTBridgeModule.h")
//#import "RCTBridgeModule.h"
//#else
//#import <React/RCTBridgeModule.h>
//#endif
#import <CoreBluetooth/CoreBluetooth.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>

@interface RNNordicWrapper : RCTEventEmitter <RCTBridgeMethod, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>

@end
  
