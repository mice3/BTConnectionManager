//
//  BTConnectionManager.h
//  flykly
//
//  Created by Rok Cresnik on 4/24/13.
//  Copyright (c) 2013 Rok Cresnik. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CBCentralManager.h>
#import "SerialPort.h"

typedef enum
{
    CHAT_S_NOT_LOADED,
    CHAT_S_DISAPPEARED,
    CHAT_S_APPEARED_IDLE,
    CHAT_S_APPEARED_WAIT_TX,
    CHAT_S_APPEARED_NO_CONNECT_PERIPH
    
} CHAT_State;

@protocol BTConnectionManagerDelegate <NSObject>
- (void)useMotorDict:(NSDictionary *)dataDict;
@end

@interface BTConnectionManager : NSObject <CBCentralManagerDelegate, SerialPortDelegate>
{
    CHAT_State      state;
}
@property (nonatomic, strong) id<BTConnectionManagerDelegate> delegate;


-(void)scan;

// setters
-(NSString *)instructionLock;
-(NSString *)instructionUnlock;
-(NSString *)instructionSetSpeed:(int)speed;
-(NSString *)instructionSetSpeed:(int)speed
                            lock:(int)lock;
// getters
-(void)requestMotorDict;
-(int)instructionGetSpeed:(NSString *)instruction;
-(int)instructionGetDistance:(NSString *)instruction;
-(int)instructionGetBatteryLevel:(NSString *)instruction;
-(int)instructionGetError:(NSString *)instruction;
-(int)instructionGetRange:(NSRange)range
          fromInstruction:(NSString *)instruction;

@end
