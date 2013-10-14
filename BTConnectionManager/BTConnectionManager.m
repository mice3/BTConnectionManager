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

@end

#define kGetDistancedRange NSMakeRange(1, 4)
#define kGetSpeedRange NSMakeRange(6, 3)
#define kGetBatteryLevelRange NSMakeRange(10, 3)
#define kGetErrorRange NSMakeRange(14, 3)

static BTConnectionManager *instanceOfBTConnectionManager;

@implementation BTConnectionManager

+(BTConnectionManager *)sharedInstance
{
    if (instanceOfBTConnectionManager) {
        return instanceOfBTConnectionManager;
    } else {
        return [[BTConnectionManager alloc] init];
    }
}

-(id)init
{
    if (self = [super init]) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:nil];
        self.messageQueue = [[NSMutableArray alloc] init];
        instanceOfBTConnectionManager = self;
    }
    return self;
}

- (void) scan
{
#if !TARGET_IPHONE_SIMULATOR
    NSLog(@"Started scanning");
    
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];

    [self.centralManager scanForPeripheralsWithServices:nil options:dictionary];
#endif
}

#pragma mark - CBCentraManagerDelegate
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral connected!");
    state = CHAT_S_APPEARED_IDLE;
//    [self initConnectedPeripheral];

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

- (void)peripheral:(CBPeripheral *)periph didWriteValueForCharacteristic:(CBCharacteristic *)charact error:(NSError *)error
{
    if(periph == self.connectedPeripheral) {
        [periph readValueForCharacteristic: charact];
    }
}

-(NSString *)getDiscoveredPeripheralId
{
    return @"";
//    return self.connectedPeripheral.identifier.UUIDString;
}


@end
