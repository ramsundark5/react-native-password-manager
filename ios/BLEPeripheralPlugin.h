#import "RCTBridgeModule.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface BLEPeripheralPlugin : NSObject <RCTBridgeModule, CBPeripheralManagerDelegate> {
  NSMutableDictionary* services;
  NSDictionary *bluetoothStates;
}

@property (strong, nonatomic) CBPeripheralManager *manager;

@end
