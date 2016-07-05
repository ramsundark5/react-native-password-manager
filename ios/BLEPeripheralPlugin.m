
#import "BLEPeripheralPlugin.h"
#import "RCTBridge.h"
#import "RCTConvert.h"
#import "RCTEventDispatcher.h"
#import "NSData+Conversion.h"
#import "RCTUtils.h"


@implementation BLEPeripheralPlugin
RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

@synthesize manager;


- (instancetype)init
{
  
  if (self = [super init]) {
    NSLog(@"BLEPeripheralPlugin initialized");
    manager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    services = [NSMutableDictionary new];
    
    bluetoothStates = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"unknown", @(CBPeripheralManagerStateUnknown),
                       @"resetting", @(CBPeripheralManagerStateResetting),
                       @"unsupported", @(CBPeripheralManagerStateUnsupported),
                       @"unauthorized", @(CBPeripheralManagerStateUnauthorized),
                       @"off", @(CBPeripheralManagerStatePoweredOff),
                       @"on", @(CBPeripheralManagerStatePoweredOn),
                       nil];
  }
  
  return self;
}

RCT_EXPORT_METHOD(createService:(NSString *)uuidString
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  
  CBUUID *serviceUUID = [CBUUID UUIDWithString: uuidString];
  CBMutableService *service = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];
  [services setObject:service forKey:uuidString];
  
  resolve(uuidString);
}

RCT_EXPORT_METHOD(addCharacteristic:(NSString *)serviceUUIDString
                  characteristicUUIDString:(NSString*)characteristicUUIDString
                  properties:(nonnull NSNumber*)properties
                  permissions:(nonnull NSNumber*)permissions
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  
  CBMutableService *service = [services objectForKey:serviceUUIDString];
  
  if (service) {
    CBUUID *characteristicUUID = [CBUUID UUIDWithString: characteristicUUIDString];
    
    CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc]
                                               initWithType:characteristicUUID
                                               properties: CBCharacteristicPropertyNotify//properties.intValue & 0xff
                                               value:nil
                                               permissions: 0];//permissions.intValue & 0xff];
    
    //appending characteristic to existing list
    NSMutableArray *characteristics = [NSMutableArray arrayWithArray:[service characteristics]];
    [characteristics addObject:characteristic];
    service.characteristics = characteristics;
  
    resolve(@"added characteristics");
  }else {
    NSString *errorText = [NSString stringWithFormat:@"Service not found for UUID %@", serviceUUIDString];
    NSError *error = RCTErrorWithMessage(errorText);
    reject(errorText, nil, error);
  }
}

RCT_EXPORT_METHOD(publishService:(NSString *)serviceUUIDString
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  NSLog(@"%@", @"calling publishService");
  CBMutableService *service = [services objectForKey:serviceUUIDString];
  [manager addService:service];
  resolve(@"published Service");
}

RCT_EXPORT_METHOD(setCharacteristicValue:(NSString *)serviceUUIDString
                  characteristicUUIDString:(NSString*)characteristicUUIDString
                  message:(NSString*)message
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  NSLog(@"%@", @"setCharacteristicValue");
  CBMutableService *service = [services objectForKey:serviceUUIDString];
  
  CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDString];
  
  NSData* data = [message dataUsingEncoding:NSUTF8StringEncoding];
  
  if (service) {
    CBMutableCharacteristic *characteristic  = (CBMutableCharacteristic*)[self findCharacteristicByUUID: characteristicUUID service:service];
    
    [characteristic setValue:data];
    
    // if notify && value has changed
    [manager updateValue:data forCharacteristic:characteristic onSubscribedCentrals:nil];
    
    resolve(@"characteristic value set");
    
  } else {
    NSString *errorText = [NSString stringWithFormat:@"Service not found for UUID %@", serviceUUIDString];
    NSError *error = RCTErrorWithMessage(errorText);
    reject(errorText, nil, error);
  }
}

RCT_EXPORT_METHOD(createServiceFromJSON:(NSDictionary *)dictionary
                    resolver:(RCTPromiseResolveBlock)resolve
                    rejecter:(RCTPromiseRejectBlock)reject){
  NSLog(@"%@", @"addServiceFromJSON");
  
  // This might be a problem when the data contains nested ArrayBuffers
  CBMutableService *service = [self serviceFromJSON: dictionary];
  [manager addService:service];
  resolve(@"created service from json");
}

RCT_EXPORT_METHOD(startAdvertising:(NSString *)serviceUUIDString
                    localName:(NSString*)localName
                    resolver:(RCTPromiseResolveBlock)resolve
                    rejecter:(RCTPromiseRejectBlock)reject){
  CBUUID *serviceUUID = [CBUUID UUIDWithString: serviceUUIDString];
  [manager startAdvertising:@{
                              CBAdvertisementDataServiceUUIDsKey : @[serviceUUID],
                              CBAdvertisementDataLocalNameKey : localName
                              }];
  resolve(@"started advertising service");
}

#pragma mark - CBPeripheralManagerDelegate
  
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
  NSString *state = [bluetoothStates objectForKey:@(peripheral.state)];
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"ble.stateChange" body:state];
}

- (void) peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
  
    NSLog(@"Added a service");
    if (error) {
      NSLog(@"There was an error adding service");
      NSLog(@"%@", error);
      [self.bridge.eventDispatcher sendDeviceEventWithName:@"serviceAddError"
                                                      body:[error localizedDescription]];
    }
  
    //dispatch success
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"serviceAdded"
                                                    body:@{ @"serviceUuid": service.UUID.UUIDString}];

}

- (void) peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
  NSLog(@"Started advertising");
  if (error) {
    NSLog(@"There was an error advertising");
    NSLog(@"%@", error);
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"advertisingStartError"
                                                    body:[error localizedDescription]];
  }
  
  [self.bridge.eventDispatcher sendDeviceEventWithName:@"advertisingStarted"
                                                  body:@"advertisingStarted"];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
  NSLog(@"Central subscribed to characteristic");
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral
                        didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
  NSLog(@"Received %lu write requests", (unsigned long)[requests count]);
  
  for (CBATTRequest *request in requests) {
    CBCharacteristic *characteristic = [request characteristic];
    
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    [dictionary setObject:[[[characteristic service] UUID] UUIDString] forKey:@"service"];
    [dictionary setObject:[[characteristic UUID] UUIDString] forKey:@"characteristic"];
    if ([request value]) {
      [dictionary setObject:[self dataToArrayBuffer: [request value]] forKey:@"value"];
    }
    
    //dispatch messageAsDictionary:dictionary
    
    [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
  }
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request {
  NSLog(@"Received read request for %@", [request characteristic]);
  
  // FUTURE if there is a callback, call into JavaScript for a value
  // otherwise, grab the current value of the characteristic and send it back
  
  CBCharacteristic *requestedCharacteristic = request.characteristic;
  CBService *requestedService = [requestedCharacteristic service];
  
  CBCharacteristic *characteristic  = [self findCharacteristicByUUID: [requestedCharacteristic UUID] service:requestedService];
  
  request.value = [characteristic.value
                   subdataWithRange:NSMakeRange(request.offset,
                                                characteristic.value.length - request.offset)];
  
  [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
  NSLog(@"Central unsubscribed from characteristic");
}


- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
  NSLog(@"peripheralManagerIsReadyToUpdateSubscribers");
}

#pragma mark - Internal Implementation

// Find a characteristic in service with a specific property
-(CBCharacteristic *) findCharacteristicByUUID:(CBUUID *)UUID service:(CBService*)service
{
  NSLog(@"Looking for %@", UUID);
  for(int i=0; i < service.characteristics.count; i++)
  {
    CBCharacteristic *c = [service.characteristics objectAtIndex:i];
    if ([c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
      return c;
    }
  }
  return nil; //Characteristic not found on this service
}

// TODO need errors here to call error callback
- (CBMutableService*) serviceFromJSON:(NSDictionary *)serviceDict {
  
  NSString *serviceUUIDString = [serviceDict objectForKey:@"uuid"];
  CBUUID *serviceUUID = [CBUUID UUIDWithString: serviceUUIDString];
  
  // TODO primary should be in the JSON
  CBMutableService *service = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];
  
  // create characteristics
  NSMutableArray *characteristics = [NSMutableArray new];
  NSArray *characteristicList = [serviceDict objectForKey:@"characteristics"];
  for (NSDictionary *characteristicData in characteristicList) {
    
    NSString *characteristicUUIDString = [characteristicData objectForKey:@"uuid"];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString: characteristicUUIDString];
    
    NSNumber *properties = [characteristicData objectForKey:@"properties"];
    NSString *permissions = [characteristicData objectForKey:@"permissions"];
    
    CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc] initWithType:characteristicUUID properties:[properties intValue] value:nil permissions:[permissions intValue]];
    
    // add descriptors
    NSMutableArray *descriptors = [NSMutableArray new];
    NSArray *descriptorsList = [characteristicData objectForKey:@"descriptors"];
    for (NSDictionary *descriptorData in descriptorsList) {
      
      // CBUUIDCharacteristicUserDescriptionString
      NSString *descriptorUUIDString = [descriptorData objectForKey:@"uuid"];
      CBUUID *descriptorUUID = [CBUUID UUIDWithString: descriptorUUIDString];
      
      // TODO this won't always be a String
      NSString *descriptorValue = [descriptorData objectForKey:@"value"];
      
      CBMutableDescriptor *descriptor = [[CBMutableDescriptor alloc]
                                         initWithType: descriptorUUID
                                         value:descriptorValue];
      [descriptors addObject:descriptor];
    }
    
    characteristic.descriptors = descriptors;
    
    [characteristics addObject: characteristic];
  }
  
  [service setCharacteristics:characteristics];
  [services setObject:service forKey:[[service UUID] UUIDString]];
  
  return service;
  
}

#pragma mark - Helper Functions

// Borrowed from Cordova messageFromArrayBuffer since Cordova doesn't handle NSData in NSDictionary
- (NSString*) dataToArrayBuffer: (NSData*) data
{
  return [data base64EncodedStringWithOptions:0];
}

@end