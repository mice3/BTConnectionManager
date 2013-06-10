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

@interface BTConnectionManager ()

@property (nonatomic, retain) UIView *transparentView;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral  *discoveredPeripheral;
@property (nonatomic, strong) SerialPort *serialPort;
@property (nonatomic, strong) NSMutableArray  *messageQueue;
@property (nonatomic, retain) NSTimer *timer;

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

- (void) scan {
    NSLog(@"Started scanning");
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];

    [self.centralManager scanForPeripheralsWithServices:nil options:dictionary];
}

#pragma mark - CBCentraManagerDelegate

-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral connected!");
    self.serialPort = [[SerialPort alloc] initWithPeripheral:self.discoveredPeripheral andDelegate:self];
    [self.serialPort open];
    state = CHAT_S_APPEARED_IDLE;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(requestMotorDict) userInfo:nil repeats:YES];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
//    self.discoveredPeripheral = nil;
    NSLog(@"Peripheral disconnected!");
    self.discoveredPeripheral = nil;
    [self.serialPort close];
    state = CHAT_S_APPEARED_NO_CONNECT_PERIPH;
    self.serialPort = nil;
    [self.timer invalidate];
    self.timer = nil;
    
    [self scan];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Peripheral discovered!");
    if(peripheral && !self.discoveredPeripheral) {
        self.discoveredPeripheral = peripheral;
        
        NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey];
        
        [self.centralManager connectPeripheral:self.discoveredPeripheral options:dictionary];
        
        [self.centralManager stopScan];
    }
}


- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    self.discoveredPeripheral = nil;
    NSLog(@"Peripheral failed to connect!");
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    //NSLog(@"Central Manager State: %d", [central state]);
    
    if(central.state == CBCentralManagerStatePoweredOn) {
        [self.centralManager retrieveConnectedPeripherals];
    }
}

- (void) writeFromFifo
{
    unsigned char   buf[SP_MAX_WRITE_SIZE];
    NSUInteger      len;
    
    if(state == CHAT_S_APPEARED_IDLE && self.messageQueue.count > 0)
    {
        NSString *message = [self.messageQueue objectAtIndex:0];
        NSRange range;
        range.location = 0;
        range.length = message.length;
        
        BOOL ok = [message getBytes:buf maxLength:SP_MAX_WRITE_SIZE usedLength:&len encoding:NSUTF8StringEncoding options:NSStringEncodingConversionAllowLossy range:range remainingRange:&range];
        
        NSData *data = [NSData  dataWithBytes:buf length:len];
        
        
        NSInteger nWrites = 0;
        if(self.serialPort.isOpen)  {
            ok = [self.serialPort write:data];
            
            if(ok)
                nWrites++;
        }
        
        if(nWrites > 0) {
            [self.messageQueue removeObjectAtIndex:0];
//            state = CHAT_S_APPEARED_WAIT_TX;
        }
    }
}

- (void)sendMessage:(NSString *)message
{
    if((state == CHAT_S_APPEARED_IDLE || state == CHAT_S_APPEARED_WAIT_TX)
       && message.length > 0
       && self.serialPort) {
        [self.messageQueue addObject:message];
        
        if(state == CHAT_S_APPEARED_IDLE) {
            [self writeFromFifo];
        }
    }
}

- (void) port: (SerialPort*) sp event : (SPEvent) ev error: (NSInteger)err
{
    switch(ev)
    {
        case SP_EVT_OPEN:
            [self writeFromFifo];
            break;
            
        default:
            break;
    }
}

- (void) writeComplete: (SerialPort*) serialPort withError:(NSInteger)err
{
    BOOL done = TRUE;
    
//    NSAssert2(state == CHAT_S_APPEARED_WAIT_TX, @"%s, %d", __FILE__, __LINE__);
    
    if(self.serialPort.isWriting) {
        done = FALSE;
    }
    
    if(done) {
        state = CHAT_S_APPEARED_IDLE;
        [self writeFromFifo];
    }
}

- (void) port: (SerialPort*) sp receivedData: (NSData*)data
{    
    NSString *str = [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding];
    if (str.length == 17) {
        NSDictionary *instructionDict = @{kMotorSpeed: [NSNumber numberWithInt:[self instructionGetSpeed:str]],
                                          kMotorDistance: [NSNumber numberWithInt:[self instructionGetDistance:str]],
                                          kMotorBattery: [NSNumber numberWithInt:[self instructionGetBatteryLevel:str]],
                                          kMotorError: [NSNumber numberWithInt:[self instructionGetError:str]]};
        
        [self.delegate useMotorDict:instructionDict];
    }
}


#pragma mark - Write instructions
-(NSString *)instructionLock
{
    NSString *message = [self instructionSetSpeed:0 lock:1];
    [self sendMessage:message];

    return message;
}

-(NSString *)instructionUnlock
{

    NSString *message = [self instructionSetSpeed:0 lock:0];
    [self sendMessage:message];
    
    return message;
}

-(NSString *)instructionSetSpeed:(int)speed
{
    NSString *message = [self instructionSetSpeed:speed lock:0];
    [self sendMessage:message];
    
    return message;
}

-(NSString *)instructionSetSpeed:(int)speed
                            lock:(int)lock
{
    NSString *message = [NSString stringWithFormat:@"H%03dZ%02d", speed, lock];
    
    return message;
}

#pragma mark - Read instructions
-(void)requestMotorDict
{
#warning RokC the sendMessage part is only intended for test purposes. Afterwards the motor will send periodic messages
    if (self.discoveredPeripheral) {

        //    d1000s100b100e100
        int distance = arc4random() % 10001;
        int speed = arc4random() % ((int)kMaxSpeed + 1);
        int battery = arc4random() % 101;
        int error = arc4random() % 11;
        NSString *instruction = [NSString stringWithFormat:@"d%04ds%03db%03de%03d", distance, speed, battery, error];
        
        [self sendMessage:instruction];
        NSLog(@"%@", instruction);
    } else {
        NSLog(@"Peripheral not connected!");
    }
}


-(int)instructionGetSpeed:(NSString *)instruction
{
    int speed = [self instructionGetRange:kGetSpeedRange fromInstruction:instruction];
    

    NSString *message = [NSString stringWithFormat:@"%i", speed];
    [self sendMessage:message];
    
    return speed;
}

-(int)instructionGetDistance:(NSString *)instruction
{
    int distance = [self instructionGetRange:kGetDistancedRange fromInstruction:instruction];
    

    NSString *message = [NSString stringWithFormat:@"%i", distance];
    [self sendMessage:message];
    
    return distance;
}

-(int)instructionGetBatteryLevel:(NSString *)instruction
{
    int batteryLevel = [self instructionGetRange:kGetBatteryLevelRange fromInstruction:instruction];
    

    NSString *message = [NSString stringWithFormat:@"%i", batteryLevel];
    [self sendMessage:message];
    
    return batteryLevel;
}

-(int)instructionGetError:(NSString *)instruction
{  
    int error = [self instructionGetRange:kGetErrorRange fromInstruction:instruction];
    

    NSString *message = [NSString stringWithFormat:@"%i", error];
    [self sendMessage:message];
    
    return error;
}

-(int)instructionGetRange:(NSRange)range
          fromInstruction:(NSString *)instruction
{
    return [[instruction substringWithRange:range] intValue];
}
@end
