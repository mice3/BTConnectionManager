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

// speed limits
#define kMinSpeed 0
// instructions
#define kMotorSpeed @"motorSpeed"
#define kMotorDistance @"motorDistance"
#define kMotorBattery @"motorBattery"
#define kMotorError @"motorError"

typedef enum
{
    CHAT_S_NOT_LOADED,
    CHAT_S_DISAPPEARED,
    CHAT_S_APPEARED_IDLE,
    CHAT_S_APPEARED_WAIT_TX,
    CHAT_S_APPEARED_NO_CONNECT_PERIPH
    
} CHAT_State;

@protocol BTConnectionManagerDelegate <NSObject>
-(void)useRecievedDict:(NSDictionary *)dataDict;
-(void)readyToScanForPeripherals;
@optional
-(void)peripheralConnected;
-(void)peripheralDisconnected;
@end

@interface BTConnectionManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
{
    CHAT_State      state;
}
@property (nonatomic, strong) id<BTConnectionManagerDelegate> delegate;

+(BTConnectionManager *)sharedInstance;
-(void)scan;
-(NSString *)getDiscoveredPeripheralId;
-(double)getMass;

@end
