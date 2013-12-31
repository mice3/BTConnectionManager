//
//  BTConnectionManager.m
//  flykly
//
//  Created by Rok Cresnik on 4/24/13.
//  Copyright (c) 2013 Rok Cresnik. All rights reserved.
//

#import "BTConnectionManager.h"
#import <Foundation/NSException.h>
#import <CoreBluetooth/CBPeripheral.h>
#import <CoreBluetooth/CBUUID.h>
#import <CoreBluetooth/CBService.h>
#import <CoreBluetooth/CBCharacteristic.h>

@interface BTConnectionManager ()

@end

static BTConnectionManager *instanceOfBTConnectionManager;

@implementation BTConnectionManager

+ (BTConnectionManager *)sharedInstance
{
    if (instanceOfBTConnectionManager) {
        return instanceOfBTConnectionManager;
    } else {
        return [[BTConnectionManager alloc] init];
    }
}

- (id)init
{
    if (self = [super init]) {
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
            self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:nil];
        } else {
            self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        }
        self.deviceArray = [[NSMutableArray alloc] init];
        
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
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            [self scan];
            break;
        case CBCentralManagerStatePoweredOff:
            if ([self.delegate respondsToSelector:@selector(errorHandler:)]) {
                NSDictionary *errorDict = @{@"errorCode": @"CBCentralManagerStatePoweredOff", NSLocalizedString(@"errorDescription", nil): @"BluetoothTurnedOff"};
                [self.delegate errorHandler:errorDict];
            }
            [self scan];
            break;
            
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    if(![self.deviceArray containsObject:peripheral]) {
        NSLog(@"%@ discovered", peripheral.name);
        [self.deviceArray addObject:peripheral];
        peripheral.delegate = self;
        
        if ([self.delegate respondsToSelector:@selector(peripheralDiscovered)]) {
            [self.delegate peripheralDiscovered];
        }
    }
}

// further method implementation needs to be done in the subclass
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral connected!");
    
    if ([self.delegate respondsToSelector:@selector(peripheralConnected)]) {
        [self.delegate performSelector:@selector(peripheralConnected) withObject:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%@ disconnected", peripheral.name);
    if ([self.delegate respondsToSelector:@selector(peripheralDisconnected)]) {
        [self.delegate performSelector:@selector(peripheralDisconnected) withObject:nil];
    }
    
    if ([self.deviceArray containsObject:peripheral]) {
        [self.deviceArray removeObject:peripheral];
        peripheral.delegate = nil;
    }
    
    [self scan];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if ([self.deviceArray containsObject:peripheral]) {
        [self.deviceArray removeObject:peripheral];
        peripheral.delegate = nil;
        
        NSLog(@"%@ failed to connect", peripheral.name);
    }
}

#pragma mark - Other methods
- (NSArray *)discoveredDeviceArray
{
    return self.deviceArray;
}

- (void)connectPeripheral:(CBPeripheral *)peripheral withOptions:(NSDictionary *)options
{
    self.connectedPeripheral = peripheral;
    
    [self.centralManager connectPeripheral:peripheral options:options];
}

- (void)disconnectPeripheral
{
    if (self.connectedPeripheral) {
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
}

@end
