//
//  BTConnectionManager.h
//  flykly
//
//  Created by Rok Cresnik on 4/24/13.
//  Copyright (c) 2013 Rok Cresnik. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CBCentralManager.h>
#import <CoreBluetooth/CBPeripheral.h>
#import "BLEDefinitions.h"

@protocol BTConnectionManagerDelegate <NSObject>
-(void)useRecievedDict:(NSDictionary *)dataDict;
@optional
-(void)peripheralConnected;
-(void)peripheralDisconnected;
-(void)peripheralDiscovered;
@end

@interface BTConnectionManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) id<BTConnectionManagerDelegate> delegate;
@property (nonatomic, strong) NSMutableArray  *deviceArray;
@property (nonatomic, strong) CBPeripheral  *connectedPeripheral;

+ (BTConnectionManager *)sharedInstance;
- (void)scan;
- (NSArray *)discoveredDeviceArray;
- (void)connectPeripheral:(CBPeripheral *)peripheral withOptions:(NSDictionary *)options;
- (void)disconnectPeripheral;

@end
