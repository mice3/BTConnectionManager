//
//  BTConnectionManager.m
//  flykly
//
//  Created by Rok Cresnik on 4/24/13.
//  Copyright (c) 2013 Rok Cresnik. All rights reserved.
//

#import "BTConnectionManager.h"
#import "DiscoveredPeripheral.h"
#import <Foundation/NSException.h>
#import <CoreBluetooth/CBPeripheral.h>
#import <CoreBluetooth/CBUUID.h>
#import <CoreBluetooth/CBService.h>
#import <CoreBluetooth/CBCharacteristic.h>

@interface BTConnectionManager ()

@property (nonatomic, retain) UIView *transparentView;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray  *messageQueue;
@property (nonatomic, retain) NSTimer *timer;

@property (nonatomic, retain) CBService *massService;
@property (nonatomic, retain) CBCharacteristic *massCharact;

@property (nonatomic, strong) CBPeripheral  *connectedPeripheral;

@end

#define kGetDistancedRange NSMakeRange(1, 4)
#define kGetSpeedRange NSMakeRange(6, 3)
#define kGetBatteryLevelRange NSMakeRange(10, 3)
#define kGetErrorRange NSMakeRange(14, 3)

@implementation BTConnectionManager


-(id)init
{
    if (self = [super init]) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        self.messageQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) scan
{
    NSLog(@"Started scanning");
    
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];

    [self.centralManager scanForPeripheralsWithServices:nil options:dictionary];
}

#pragma mark - CBCentraManagerDelegate
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral connected!");
    state = CHAT_S_APPEARED_IDLE;
    [self initConnectedPeripheral];

    if ([self.delegate respondsToSelector:@selector(peripheralConnected)]) {
        [self.delegate performSelector:@selector(peripheralConnected) withObject:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral disconnected!");
    if ([self.delegate respondsToSelector:@selector(peripheralDisconnected)]) {
        [self.delegate performSelector:@selector(peripheralDisconnected) withObject:nil];
    }
    self.connectedPeripheral = nil;
    self.connectedPeripheral.delegate = nil;
    state = CHAT_S_APPEARED_NO_CONNECT_PERIPH;
//    [self.timer invalidate];
    self.timer = nil;
    
    [self scan];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Peripheral discovered!");
    if(peripheral && !self.connectedPeripheral) {
        self.connectedPeripheral = peripheral;
        NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey];
        
        [self.centralManager connectPeripheral:self.connectedPeripheral options:dictionary];
        
        [self.centralManager stopScan];
    }
}


- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    self.connectedPeripheral = nil;
    self.connectedPeripheral.delegate = nil;
    NSLog(@"Peripheral failed to connect!");
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    //NSLog(@"Central Manager State: %d", [central state]);
    
    if(central.state == CBCentralManagerStatePoweredOn) {
        if ([self.delegate respondsToSelector:@selector(readyToScanForPeripherals)]) {
            [self.delegate performSelector:@selector(readyToScanForPeripherals) withObject:nil];
        }
        [self.centralManager retrieveConnectedPeripherals];
    }
}

#pragma mark - Peripheral delegate methods
- (BOOL)displayPeripheral: (CBPeripheral*)periph andCharacteristic: (CBCharacteristic*) charact
{
    char *p = (char*)charact.value.bytes;
    //    NSInteger val;
    BOOL ok = NO;
    
    if (charact == self.massCharact) {
        NSArray *dataArray = [NSArray arrayWithObjects:
                              [NSNumber numberWithUnsignedChar:p[3]],
                              [NSNumber numberWithUnsignedChar:p[2]],
                              [NSNumber numberWithUnsignedChar:p[1]],
                              [NSNumber numberWithUnsignedChar:p[0]], nil];
        int totalValue = 0;
        int dataArrayLength = [dataArray count] - 1;
        for (int i = dataArrayLength; i >= 0; i--) {
            int tmpValue = [[dataArray objectAtIndex:i] intValue] * pow(16, dataArrayLength - i);
            totalValue += tmpValue * pow(16, dataArrayLength - i);
        }
        
        NSDictionary *instructionDict = @{@"value": [NSNumber numberWithInt:totalValue]};
        [self.delegate userRecievedDict:instructionDict];
        ok = YES;
    }
    
    
    return ok;
}

- (BOOL) initCharacteristicForService:(CBService*)serv andCharact:(CBCharacteristic*)charact
{
    BOOL done = NO;
    
    //BOOL updated;
    if((self.connectedPeripheral != nil) && (self.connectedPeripheral.isConnected == TRUE))
    {
        if((serv.UUID.data.length == SERVICE_UUID_DEFAULT_LEN) &&
           (memcmp(serv.UUID.data.bytes, massServiceUuid, SERVICE_UUID_DEFAULT_LEN) == 0))
        {
            self.massService = serv;
            
            if((charact != nil) &&
               (charact.UUID.data.length == CHARACT_UUID_DEFAULT_LEN) &&
               (memcmp(charact.UUID.data.bytes, massCharactUuid, CHARACT_UUID_DEFAULT_LEN) == 0))
            {
                self.massCharact = charact;
                [self.connectedPeripheral setNotifyValue:YES forCharacteristic:charact];
                //updated = [self displayPeripheral: connectedPeripheral andCharacteristic: accRangeCharact];
                
                //if(updated == FALSE)
                [self.connectedPeripheral readValueForCharacteristic: charact];
                
                done = YES;
            }
        }
    }
    
    return done;
}

- (void) initConnectedPeripheral
{
    CBService*          service;
    CBCharacteristic*   charact;
    BOOL                ok;
    
    self.massCharact = nil;
    
    self.connectedPeripheral.delegate = self;
    
    if(self.connectedPeripheral.services != nil) {
        for(int i = 0; i < self.connectedPeripheral.services.count; i++) {
            service = [self.connectedPeripheral.services objectAtIndex:i];
            
            if((service.characteristics != nil) && (service.characteristics.count > 0)) {
                for(int j = 0; j < service.characteristics.count; j++) {
                    charact = [service.characteristics objectAtIndex:j];
                    
                    ok = [self initCharacteristicForService:service andCharact:charact];
                }
            }
            else {
                ok = [self initCharacteristicForService:service andCharact:nil];
            }
        }
    }
    
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    NSData *data;
    CBUUID *uuid;
    
    if(self.massService == nil) {
        data = [NSData dataWithBytes:massServiceUuid length:SERVICE_UUID_DEFAULT_LEN];
        uuid = [CBUUID UUIDWithData: data];
        [arr addObject:uuid];
    } else if(self.massCharact == nil) {
        [self.connectedPeripheral discoverCharacteristics:nil forService:self.massService];
    }
    
    if(arr.count > 0) {
        [self.connectedPeripheral discoverServices:arr];
    }
}



- (void)peripheral:(CBPeripheral *)periph didDiscoverServices:(NSError *)error
{
    CBService   *s;
    
    if(periph == self.connectedPeripheral) {
        for(int i = 0; i < periph.services.count; i++) {
            s = [[periph services] objectAtIndex:i];
            [periph discoverCharacteristics:nil forService:s];
        }
    }
}

- (void)peripheral:(CBPeripheral *)periph didDiscoverCharacteristicsForService:(CBService *)serv error:(NSError *)error
{
    CBCharacteristic* charact;
    BOOL ok;
    
    if(periph == self.connectedPeripheral)
    {
        for(int i = 0; i < serv.characteristics.count; i++)
        {
            charact = [serv.characteristics objectAtIndex:i];
            
            ok = [self initCharacteristicForService:serv andCharact:charact];
        }
    }
}

- (void)peripheral:(CBPeripheral *)periph didUpdateValueForCharacteristic:(CBCharacteristic *)charact error:(NSError *)error
{
    if(!error) {
        [self displayPeripheral: periph andCharacteristic: charact];
    }
}

- (void)peripheral:(CBPeripheral *)periph didWriteValueForCharacteristic:(CBCharacteristic *)charact error:(NSError *)error
{
    if(periph == self.connectedPeripheral) {
        [periph readValueForCharacteristic: charact];
    }
}

-(NSString *)getDiscoveredPeripheralId
{
    return self.connectedPeripheral.identifier.UUIDString;
}

@end
