//
//  simple vector math
//

#import <Foundation/Foundation.h>

@class RecImage, RecLoopControl;

@interface RecMatrix : NSObject
{
}

+ (RecMatrix *)matrixOfType:(int)type nCol:(int)nCol nRow:(int)nRow;

- (id)copyWithZone:(NSZone *)zone;



//== debug
- (void)dump;

@end

@interface RecVector : NSObject
{
}

+ (RecVector *)vectorOfType:(int)type nRow:(int)nRow;

- (id)copyWithZone:(NSZone *)zone;

@end

