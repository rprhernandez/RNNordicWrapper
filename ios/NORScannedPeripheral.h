//
//  NORScannedPeripheral.h
//  RNNordicWrapper
//
//  Created by macBook08 on 01/06/19.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <sys/socket.h>
#import <sys/sysctl.h>
#import <net/if.h>
#import <net/if_dl.h>

NS_ASSUME_NONNULL_BEGIN

@interface NORScannedPeripheral : NSObject
@property (nonatomic) CBPeripheral *peripheral;
@property (nonatomic) NSInteger RSSI;
@property (nonatomic) BOOL isConnected;
@property (nonatomic) NSString *battery;
- (instancetype)initWithPeripheral:(CBPeripheral *)aPeripheral andRSSI:(NSInteger )anRSSI andIsConnected:(BOOL )aConnectionStatus;
- (NSString *)name;
- (BOOL) isEqual:(id)object;
- (NSString *)macAddress:(NSString *)uuid;


@end

NS_ASSUME_NONNULL_END
