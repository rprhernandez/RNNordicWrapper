#import "RNNordicWrapper.h"
#import <iOSDFULibrary/iOSDFULibrary-Swift.h>
#import "NORScannedPeripheral.h"

static CBCentralManager * (^getCentralManager)();
static void (^onDFUComplete)();
static void (^onDFUError)();

@implementation RNNordicWrapper

static NSString *const EVENT_TAG = @"EVENT_TAG";
static NSString *const ON_DEVICE_ADDED = @"ON_DEVICE_ADDED";
static NSString *const ON_DEVICE_CONNECTION_ERROR = @"ON_DEVICE_CONNECTION_ERROR";
static NSString *const ON_RSSI_VALUE_CHANGED = @"ON_RSSI_VALUE_CHANGED";
static NSString *const ON_BATTERY_LEVEL_CHANGED = @"ON_BATTERY_LEVEL_CHANGED";
static NSString *const ON_DEVICE_CONNECTED = @"ON_DEVICE_CONNECTED";
static NSString *const ON_DEVICE_CONNECTING = @"ON_DEVICE_CONNECTING";
static NSString *const ON_DEVICE_DISCONNECTING = @"ON_DEVICE_DISCONNECTING";
static NSString *const ON_DEVICE_DISCONNECTED = @"ON_DEVICE_DISCONNECTED";
static NSString *const ON_DEVICE_OUT_OF_RANGE = @"ON_DEVICE_OUT_OF_RANGE";
static NSString *const ON_BEEP_CHANGED = @"ON_BEEP_CHANGED";
static NSString *const ON_CHANGE_IN_DEVICE = @"ON_CHANGE_IN_DEVICE";
static NSString *const ON_SET_UDID = @"ON_SET_UDID";
static NSString *const BLUETOOTH_ON = @"ON_BLUETOOTH_ON";
static NSString *const BLUETOOTH_OFF = @"ON_BLUETOOTH_OFF";

NSString *batteryServiceUUIDString = @"0000180F-0000-1000-8000-00805F9B34FB";
NSString *batteryLevelCharacteristicUUIDString = @"00002A19-0000-1000-8000-00805F9B34FB";
NSString *dfuServiceUUIDString  = @"00001530-1212-EFDE-1523-785FEABCD123";
NSString *ANCSServiceUUIDString = @"7905F431-B5CE-4E99-A40F-4B1E122D00D0";

static NSString *proximityImmediateAlertServiceUUIDString             = @"00001802-0000-1000-8000-00805F9B34FB";
static NSString *proximityLinkLossServiceUUIDString                   = @"00001803-0000-1000-8000-00805F9B34FB";
static NSString *proximityAlertLevelCharacteristicUUIDString          = @"00002A06-0000-1000-8000-00805F9B34FB";

CBCentralManager *bluetoothManager = nil;
CBUUID *proximityImmediateAlertServiceUUID = nil;
CBUUID *proximityLinkLossServiceUUID = nil;
CBUUID *proximityAlertLevelCharacteristicUUID = nil;
CBUUID *batteryServiceUUID = nil;
CBUUID *batteryLevelCharacteristicUUID = nil;
CBUUID *filterUUID = nil;
BOOL isImmidiateAlertOn = NO;
BOOL isBackButtonPressed = NO;
CBPeripheral *proximityPeripheral = nil;
CBPeripheralManager *peripheralManager = nil;
CBCharacteristic *immidiateAlertCharacteristic = nil;
AVAudioPlayer *audioPlayer = nil;
NSMutableArray *peripherals = nil;

NSString *battery = @"";

- (dispatch_queue_t)methodQueue{
    return dispatch_get_main_queue();
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        immidiateAlertCharacteristic = nil;
        isImmidiateAlertOn = false;
        isBackButtonPressed = false;
        peripherals = [[NSMutableArray alloc] init];
        proximityImmediateAlertServiceUUID      = [CBUUID UUIDWithString:proximityImmediateAlertServiceUUIDString];
        proximityLinkLossServiceUUID            = [CBUUID UUIDWithString:proximityLinkLossServiceUUIDString];
        proximityAlertLevelCharacteristicUUID   = [CBUUID UUIDWithString:proximityAlertLevelCharacteristicUUIDString];
        batteryServiceUUID                      = [CBUUID UUIDWithString:batteryServiceUUIDString];
        batteryLevelCharacteristicUUID          = [CBUUID UUIDWithString: batteryLevelCharacteristicUUIDString];
    }
    return self;
}
    
RCT_EXPORT_MODULE()
    
- (NSArray<NSString *> *)supportedEvents{
        return @[EVENT_TAG,ON_DEVICE_ADDED,ON_DEVICE_CONNECTION_ERROR,ON_RSSI_VALUE_CHANGED,ON_BATTERY_LEVEL_CHANGED,ON_DEVICE_CONNECTED,ON_DEVICE_CONNECTING,ON_DEVICE_DISCONNECTING,ON_DEVICE_DISCONNECTED,ON_DEVICE_OUT_OF_RANGE,ON_BEEP_CHANGED,ON_CHANGE_IN_DEVICE,ON_SET_UDID,BLUETOOTH_ON,BLUETOOTH_OFF];
}
    
    
RCT_EXPORT_METHOD(startScan: (RCTResponseSenderBlock)callback){
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackgroundCallback) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActiveCallback) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self initGattServer];
    [self initPlayer];
    [self scanForPeripherals:YES];
    
    switch (peripheralManager.state)
    {
        case CBManagerStateUnknown:
            callback(@[@true]);
            break;
        case CBManagerStatePoweredOn:
            
            callback(@[@true]);
            break;
        default:
            callback(@[@false]);
            break;
    }
}

RCT_EXPORT_METHOD(stopScan){
    UInt8 val = 0;
    NSData *data = [[NSData alloc] initWithBytes:&val length:1];
    [proximityPeripheral writeValue:data forCharacteristic:immidiateAlertCharacteristic type:CBCharacteristicWriteWithoutResponse];
    isImmidiateAlertOn = NO;
    if(bluetoothManager){
        [bluetoothManager stopScan];
    }
    immidiateAlertCharacteristic = nil;
    isImmidiateAlertOn = false;
    isBackButtonPressed = false;
    dispatch_queue_t centralQueue = dispatch_queue_create("no.nordicsemi.nRFToolBox", nil);
    bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self queue:centralQueue];
}

RCT_EXPORT_METHOD(connectDevice: (NSString *)macAddress){
    for (NORScannedPeripheral *norPeripheral in peripherals){
        if ([norPeripheral.peripheral.identifier.UUIDString isEqualToString:macAddress] && bluetoothManager != nil){
            NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
            proximityPeripheral = norPeripheral.peripheral;
            [options setValue:[NSNumber numberWithBool:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
            [bluetoothManager connectPeripheral:norPeripheral.peripheral options:options];
        }
    }
}

RCT_EXPORT_METHOD(connectDevices: (NSString *)macAddress){
    for (NORScannedPeripheral *norPeripheral in peripherals){
        if ([norPeripheral.peripheral.identifier.UUIDString isEqualToString:macAddress] && bluetoothManager != nil){
            NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
            [options setValue:[NSNumber numberWithBool:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
            [bluetoothManager connectPeripheral:norPeripheral.peripheral options:options];
        }
    }
}

RCT_EXPORT_METHOD(beep: (NSString *)macAddress){
    for (NORScannedPeripheral *norPeripheral in peripherals){
        if ([norPeripheral.peripheral.identifier.UUIDString isEqualToString:macAddress] && bluetoothManager != nil){
            if (immidiateAlertCharacteristic){
                if (isImmidiateAlertOn) {
                    UInt8 val = 0;
                    proximityPeripheral = norPeripheral.peripheral;
                    NSData *data = [[NSData alloc] initWithBytes:&val length:1];
                    [proximityPeripheral writeValue:data forCharacteristic:immidiateAlertCharacteristic type:CBCharacteristicWriteWithoutResponse];
                    isImmidiateAlertOn = NO;
                    [self stopSound];
                }else{
                    UInt8 val = 2;
                    proximityPeripheral = norPeripheral.peripheral;
                    NSData *data = [[NSData alloc] initWithBytes:&val length:1];
                    [proximityPeripheral writeValue:data forCharacteristic:immidiateAlertCharacteristic type:CBCharacteristicWriteWithoutResponse];
                    isImmidiateAlertOn = YES;
                }
            }
        }
    }
}


RCT_EXPORT_METHOD(disconnectDevice: (NSString *)macAddress){
    for (NORScannedPeripheral *norPeripheral in peripherals){
        if ([norPeripheral.peripheral.identifier.UUIDString isEqualToString:macAddress] && bluetoothManager != nil){
            [bluetoothManager cancelPeripheralConnection:norPeripheral.peripheral];
        }
    }
}

RCT_EXPORT_METHOD(isBlutoothEnabled:(RCTResponseSenderBlock)callback)
{
    switch (peripheralManager.state)
    {
        case CBManagerStateUnknown:
            callback(@[@true]);
            break;
        case CBManagerStatePoweredOn:
            callback(@[@true]);
            break;
        default:
            callback(@[@false]);
            break;
    }
}

RCT_EXPORT_METHOD(isConnected: (NSString *)macAddress callback:(RCTResponseSenderBlock)callback){
    for (NORScannedPeripheral *norPeripheral in peripherals){
        if ([norPeripheral.peripheral.identifier.UUIDString isEqualToString:macAddress] && bluetoothManager != nil){
            callback(@[[NSNumber numberWithBool:norPeripheral.isConnected]]);
            return;
        }
    }
    callback(@[@false]);
}

RCT_EXPORT_METHOD(getBatteryLevel: (NSString *)macAddress callback:(RCTResponseSenderBlock)callback){
    for (NORScannedPeripheral *norPeripheral in peripherals){
        if ([norPeripheral.peripheral.identifier.UUIDString isEqualToString:macAddress] && bluetoothManager != nil){
            [self sendEvents:ON_BATTERY_LEVEL_CHANGED macAddress:norPeripheral.peripheral.identifier.UUIDString params:norPeripheral.battery];
            callback(@[battery]);
            return;
        }
    }
    callback(@[@false]);
}


RCT_EXPORT_METHOD(playSoundOnce){
    if(audioPlayer){
        audioPlayer.numberOfLoops = 1;
        [audioPlayer play];
    }
}
    
RCT_EXPORT_METHOD(playLoopingSound){
    if(audioPlayer){
        audioPlayer.numberOfLoops = -1;
        [audioPlayer play];
    }
}
    
RCT_EXPORT_METHOD(stopSound){
    if (audioPlayer){
        [audioPlayer stop];
    }
}

   
- (void) initGattServer{
    if(!peripheralManager){
        peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    }
}

- (void) showBackgroundNotification:(NSString *)aMessage{
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    localNotification.alertAction = @"Show";
    localNotification.alertBody = aMessage;
    localNotification.hasAction = NO;
    localNotification.fireDate = [NSDate dateWithTimeIntervalSince1970:1];
    localNotification.timeZone = [NSTimeZone systemTimeZone];
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}

- (BOOL) isApplicationInactive{
    return UIApplication.sharedApplication.applicationState != UIApplicationStateActive;
}



- (NSArray *)getConnectedPeripherals {
    if(bluetoothManager == nil){
        return @[];
    }
    NSArray * retreivedPeripherals = nil;
    CBUUID * dfuServiceUUID = [CBUUID UUIDWithString:dfuServiceUUIDString];
    CBUUID * ancsServiceUUID = [CBUUID UUIDWithString:ANCSServiceUUIDString];
    if(filterUUID == nil){
        retreivedPeripherals = [bluetoothManager retrievePeripheralsWithIdentifiers:@[dfuServiceUUID,ancsServiceUUID]];
    }else{
        retreivedPeripherals = [bluetoothManager retrievePeripheralsWithIdentifiers:@[filterUUID]];
    }
    return retreivedPeripherals;
}


-(NSString*) bv_jsonStringWithPrettyPrint:(BOOL) prettyPrint dictObj:(NSDictionary *)dict{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:(NSJSONWritingOptions)    (prettyPrint ? NSJSONWritingPrettyPrinted : 0)
                                                         error:&error];
    
    if (! jsonData) {
        NSLog(@"%s: error: %@", __func__, error.localizedDescription);
        return @"{}";
    } else {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
}

- (BOOL)scanForPeripherals:(BOOL) enable{
    if(bluetoothManager == nil){
        dispatch_queue_t centralQueue = dispatch_queue_create("no.nordicsemi.nRFToolBox", nil);
        bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self queue:centralQueue];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if(enable) {
            NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
            [options setValue:[NSNumber numberWithBool:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
            if(filterUUID != nil){
                [bluetoothManager scanForPeripheralsWithServices:@[filterUUID] options:options];
            }else{
                [bluetoothManager scanForPeripheralsWithServices:nil options:options];
            }
        }else{
            [bluetoothManager stopScan];
        }
    });
    return YES;
}

- (void) addServices {
    CBMutableService *service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:@"1802"] primary:YES];
    CBMutableCharacteristic *characteristic = [self createCharacteristic];
    service.characteristics = @[characteristic];
    [peripheralManager addService:service];
}
    
- (CBMutableCharacteristic *) createCharacteristic {
    return [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:@"2A06"] properties:CBCharacteristicPropertyWriteWithoutResponse value:nil permissions:CBAttributePermissionsWriteable];
}
    
    
- (void) initPlayer{
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    NSError * error = nil;
    audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"high" ofType:@"mp3"]] error:&error];
    if(audioPlayer){
        [audioPlayer prepareToPlay];
    }
}
    
- (void) applicationDidEnterBackgroundCallback{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (NORScannedPeripheral *norPeripheral in peripherals){
        if (norPeripheral.isConnected){
            [self showBackgroundNotification:[NSString stringWithFormat:@"You are still connected to %@",norPeripheral.name]];
        }else{
            [self showBackgroundNotification:[NSString stringWithFormat:@"You are not connected to %@",norPeripheral.name]];
        }
        [array addObject:[CBUUID UUIDWithString:norPeripheral.peripheral.identifier.UUIDString]];
    }
    [bluetoothManager scanForPeripheralsWithServices:array options:nil];
}
 
- (void) applicationDidBecomeActiveCallback {
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
}


- (void)sendEvents:(NSString *)eventName macAddress:(NSString *)macAddress params:(NSString *)params{
    NSDictionary* bodyDict = @{@"mAddress":macAddress,@"param":params,@"type":eventName};
    [self sendEventWithName:ON_CHANGE_IN_DEVICE body:bodyDict];
}

- (void) showAlert:(NSString *)title message:(NSString *)aMessage{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:aMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral{
    if (peripheralManager.state == CBPeripheralManagerStatePoweredOn){
        [self sendEventWithName:BLUETOOTH_ON body:@{}];
        [self addServices];
    }else if (peripheralManager.state == CBPeripheralManagerStatePoweredOff){
        [self sendEventWithName:BLUETOOTH_OFF body:@{}];
    }else {
        [self sendEventWithName:BLUETOOTH_OFF body:@{}];
    }
}
    
- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *,id> *)dict{
    
}
    
- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error{
    if ( error != nil ){
        NSLog(@"Services did not added");
    }else{
        NSLog(@"Services added Successfully");
    }
}
    
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests{
    CBATTRequest *attributeRequest = requests[0];
    if ([attributeRequest.characteristic.UUID.UUIDString isEqualToString:@"2A06"])  {
        NSData *data = attributeRequest.value;
        int value = *(int *) [data bytes];
        switch (value) {
            case 0:
                [self stopSound];
                break;
            case 1:
                [self playLoopingSound];
                break;
            case 2:
                [self playSoundOnce];
                break;
            default:
                break;
        }
    }
}
    
#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    if (central.state == CBCentralManagerStatePoweredOff){
        [self sendEventWithName:BLUETOOTH_OFF body:@{}];
    }else{
        NSArray *connectedPeripherals = [self getConnectedPeripherals];
        NSMutableArray *newScannedPeripherals = [[NSMutableArray alloc] init];
        filterUUID = [CBUUID UUIDWithString:@"00001803-0000-1000-8000-00805F9B34FB"];
        for (CBPeripheral *connectedPeripheral in connectedPeripherals) {
            BOOL connected = connectedPeripheral.state == CBPeripheralStateConnected;
            NORScannedPeripheral *scannedPeripheral = [[NORScannedPeripheral alloc] initWithPeripheral:connectedPeripheral andRSSI:0 andIsConnected:connected];
            //connectedPeripheral.identifier.UUIDString
            [newScannedPeripherals addObject:scannedPeripheral];
        }
        peripherals = newScannedPeripherals;
        BOOL success = [self scanForPeripherals:YES];
        if (!success) {
            [self sendEventWithName:BLUETOOTH_OFF body:@{}];
        }
    }
}
    
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    [self sendEvents:ON_DEVICE_CONNECTED macAddress:peripheral.identifier.UUIDString params:@""];
    for (NORScannedPeripheral *norPeripheral in peripherals){
        if ([norPeripheral.peripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]){
            norPeripheral.isConnected = YES;
        }
    }
    peripheral.delegate = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIApplication instancesRespondToSelector:@selector(isRegisteredForRemoteNotifications)]){
            [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert ) categories:nil]];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackgroundCallback) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActiveCallback) name:UIApplicationDidBecomeActiveNotification object:nil];
        [peripheral discoverServices:@[proximityLinkLossServiceUUID, proximityImmediateAlertServiceUUID, batteryServiceUUID]];
    });
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    [self sendEvents:ON_DEVICE_CONNECTION_ERROR macAddress:peripheral.identifier.UUIDString params:@""];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    if (error != nil){
        if([self isApplicationInactive]){
            [self showBackgroundNotification:[NSString stringWithFormat:@"%@  is out of range!",peripheral.name]];
        }else{
            [self showAlert:@"PROXIMITY" message:[NSString stringWithFormat:@"%@  is out of range!",peripheral.name]];
        }
        [self sendEvents:ON_DEVICE_OUT_OF_RANGE macAddress:peripheral.identifier.UUIDString params:@""];
        [self playSoundOnce];
    }else{
        [self sendEvents:ON_DEVICE_DISCONNECTED macAddress:peripheral.identifier.UUIDString params:@""];
    }
    for (NORScannedPeripheral *norPeripheral in peripherals){
        if ([norPeripheral.peripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]){
            norPeripheral.isConnected = NO;
        }
    }
}
    
    
#pragma mark - CBPeripheralDelegate


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if (error != nil){
        [bluetoothManager cancelPeripheralConnection:peripheral];
        return;
    }
    if ([proximityLinkLossServiceUUID.UUIDString containsString:service.UUID.UUIDString] ){
        for (CBCharacteristic *aCharacteristic in service.characteristics){
            if ([proximityAlertLevelCharacteristicUUID.UUIDString containsString:aCharacteristic.UUID.UUIDString] ){
                UInt8 buffer[1];
                NSData *data = [[NSData alloc] initWithBytes:&buffer length:1];
                [peripheral writeValue:data forCharacteristic:aCharacteristic type:CBCharacteristicWriteWithResponse];
            }
        }
        
    }else if ([proximityImmediateAlertServiceUUID.UUIDString containsString:service.UUID.UUIDString] ){
        for (CBCharacteristic *aCharacteristic in service.characteristics){
            if ([proximityAlertLevelCharacteristicUUID.UUIDString containsString:aCharacteristic.UUID.UUIDString] ){
                immidiateAlertCharacteristic = aCharacteristic;
            }
        }
    }else if ([batteryServiceUUID.UUIDString containsString:service.UUID.UUIDString] ){
        for (CBCharacteristic *aCharacteristic in service.characteristics){
            if ([batteryLevelCharacteristicUUID.UUIDString containsString:aCharacteristic.UUID.UUIDString] ){
                [peripheral readValueForCharacteristic:aCharacteristic];
            }
        }
    }
    
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(NSError *)error{
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    dispatch_async(dispatch_get_main_queue(), ^{
        NORScannedPeripheral *sensor  = [[NORScannedPeripheral alloc] initWithPeripheral:peripheral andRSSI:[RSSI integerValue] andIsConnected:NO];
        if (![peripherals containsObject:sensor]){
            [peripherals addObject:sensor];
            //"device":{"mAddress":"0E:0A:A0:01:AA:FA"}
            
            NSDictionary *paramsDict = @{@"rssi":[NSNumber numberWithInt:[RSSI intValue]],@"connection_status":[NSNumber numberWithBool:(peripheral.state == CBPeripheralStateConnected)],@"device":@{@"mAddress":peripheral.identifier.UUIDString},@"scanRecord":@{@"deviceName":peripheral.name},@"serviceUuids":@[@{@"mUuid":peripheral.identifier.UUIDString}],@"udid":peripheral.identifier.UUIDString};
            [self sendEvents:ON_DEVICE_ADDED macAddress:peripheral.identifier.UUIDString params:[self bv_jsonStringWithPrettyPrint:YES dictObj:paramsDict]];
        }else{
            sensor = [peripherals objectAtIndex:[peripherals indexOfObject:sensor]];
            sensor.RSSI = [RSSI integerValue];
        }
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    for (CBService *aService in peripheral.services){
        if ([proximityLinkLossServiceUUID.UUIDString containsString:aService.UUID.UUIDString] ){
            peripheral.delegate = self;
            [peripheral discoverCharacteristics:@[proximityAlertLevelCharacteristicUUID] forService:aService];
        }else if ([proximityImmediateAlertServiceUUID.UUIDString containsString:aService.UUID.UUIDString] ){
            peripheral.delegate = self;
            [peripheral discoverCharacteristics:@[proximityAlertLevelCharacteristicUUID] forService:aService];
        }else if ([batteryServiceUUID.UUIDString containsString:aService.UUID.UUIDString] ){
            peripheral.delegate = self;
            [peripheral discoverCharacteristics:@[batteryLevelCharacteristicUUID] forService:aService];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    dispatch_async(dispatch_get_main_queue(), ^{
       
        if([batteryLevelCharacteristicUUID.UUIDString containsString:characteristic.UUID.UUIDString]){
            NSData *batteryData = characteristic.value;
            int value = *(int *) [batteryData bytes];
            //Battery *bObj = [[Battery alloc] init];
            battery = [NSString stringWithFormat:@"%d",value];
            for (NORScannedPeripheral *norPeripheral in peripherals){
                if ([norPeripheral.peripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString] && bluetoothManager != nil){
                    norPeripheral.battery = battery;
                    [self sendEvents:ON_BATTERY_LEVEL_CHANGED macAddress:norPeripheral.peripheral.identifier.UUIDString params:battery];
                    return;
                }
            }
            [self sendEvents:ON_BATTERY_LEVEL_CHANGED macAddress:peripheral.identifier.UUIDString params:battery];
        }
    });
}
    
@end

