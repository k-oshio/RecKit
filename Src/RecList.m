//
//  list structures (fifo, stack etc)
//

#import "RecList.h"

// === FIFO (ring buffer) ===
@implementation RecIntFIFO

+ (RecIntFIFO *)fifo
{
    return [RecIntFIFO fifoWithLength:10];
}

+ (RecIntFIFO *)fifoWithLength:(int)n
{
    RecIntFIFO  *fifo = [[RecIntFIFO alloc] initWithLength:n];
    return fifo;
}

- (id)initWithLength:(int)n
{
    if ((self = [super init]) == nil) return nil;

    data = (int *)malloc(sizeof(int) * n);
    bufLen = n;
    st = 0;     // first in data pos
    length = 0;    // no data

    return self;
}

- (void)expand
{
    int     i;
    data = (int *)realloc(data, sizeof(int) * bufLen * 2);

    // move data
    if (st + length >= bufLen) {
        for (i = 0; i < st + length - bufLen; i++) {
            data[i + bufLen] = data[i];
        }
    } // else no need for copying
    bufLen = bufLen * 2;  // new length
}

- (void)dealloc
{
    free(data);
}

- (void)push:(int)anInt
{
    int pos;
    if ([self length] == bufLen) {
        [self expand];
    }
    pos = (st + length) % bufLen;
    data[pos] = anInt;
    length++;
}

- (int)pop
{
    int val;

    if (length == 0) return 0;
    val = data[st];
    st++;
    if (st == bufLen) {
        st = 0;
    }
    length--;
    return val;
}

- (int)length
{
    return length;
}

//- (int)bufLen
//{
//    return bufLen;
//}

- (BOOL)empty
{
    return (length == 0);
}

- (void)dump
{
    int i;

    printf("=== bufLen = %d, length = %d\n", bufLen, length);
    for (i = 0; i < bufLen; i++) {
        if (i == st) printf("st ");
        printf("%d %d\n", i, data[i]);
    }
}

@end

// === LIFO (stack) === ### not done yet (header should be OK)
@implementation RecIntLIFO

+ (RecIntLIFO *)lifo
{
    return [RecIntLIFO lifoWithLength:10];
}

+ (RecIntLIFO *)lifoWithLength:(int)n
{
    RecIntLIFO  *fifo = [[RecIntLIFO alloc] initWithLength:n];
    return fifo;
}

- (id)initWithLength:(int)n
{
    if ((self = [super init]) == nil) return nil;

    data = (int *)malloc(sizeof(int) * n);
    bufLen = n;
    length = 0;    // no data

    return self;
}

- (void)expand
{
    data = (int *)realloc(data, sizeof(int) * length * 2);
    bufLen = bufLen * 2;  // new length
}

- (void)dealloc
{
    free(data);
}

- (void)push:(int)anInt
{
    if (length == bufLen) {
        [self expand];
    }
    data[length] = anInt;
    length++;
}

- (int)pop
{
    int val;

    if (length == 0) return 0;
    val = data[length - 1];
    length--;
    return val;
}

- (int)length
{
    return length;
}

- (BOOL)empty
{
    return (length == 0);
}

- (void)dump
{
    int i;

    printf("=== bufLen = %d, length = %d\n", bufLen, length);
    for (i = 0; i < bufLen; i++) {
        printf("%d %d\n", i, data[i]);
    }
}

@end

