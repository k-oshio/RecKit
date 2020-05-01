//
//  simple vector math
//  # not done yet

#import "RecMatrix.h"

@class RecImage, RecLoopControl;

@implementation RecMatrix

+ (RecMatrix *)matrixOfType:(int)type nCol:(int)nCol nRow:(int)nRow
{
    RecMatrix *m = nil;

    return m;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}



//== debug
- (void)dump
{
}

@end

@implementation RecVector

+ (RecVector *)vectorOfType:(int)tp nRow:(int)nRow
{
    RecVector   *v;

    v = [[RecVector alloc] init];

    return v;
}

- (id)copyWithZone:(NSZone *)zone
{
    RecVector   *new = nil;
    return new;
}

@end

