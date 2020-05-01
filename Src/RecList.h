//
//  list structures (fifo, stack etc)
//

#import <Foundation/Foundation.h>

// === FIFO (ring buffer) ===
@interface RecIntFIFO : NSObject
{
    int     *data;
    int     bufLen; // size of buffer
    int     length;    // length of data in buf
    int     st;     // index of first-in data
}

+ (RecIntFIFO *)fifo;
+ (RecIntFIFO *)fifoWithLength:(int)n;
- (id)initWithLength:(int)n;
- (void)expand;

- (void)push:(int)anInt;
- (int)pop;
- (int)length;
- (BOOL)empty;

//===
- (void)dump;

@end

// === LIFO (stack) ===
@interface RecIntLIFO : NSObject
{
    int     *data;
    int     bufLen; // size of buffer
    int     length;    // length of data in buf
//    int     st;     // index of first-in data
}

+ (RecIntLIFO *)lifo;
+ (RecIntLIFO *)lifoWithLength:(int)n;
- (id)initWithLength:(int)n;
- (void)expand;

- (void)push:(int)anInt;
- (int)pop;
- (int)length;
- (BOOL)empty;

//===
- (void)dump;

@end

