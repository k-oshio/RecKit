//
//	RecCoilProfile.h
//	1-27-2010
//	plan:
//		optimize for speed (cache, return size)
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

@class RecImage;

enum {
	Coil_None = 0,
	GE_Card_8_old = 1,
	GE_Card_8_new,
	TOSHIBA_15		// Q & D version
};


@interface RecCoilProfile : NSObject
{
	int         coilID;
    RecImage    *weight;        // real, [ch, z, y, x]
}

// ============ public ==============
+ (RecCoilProfile *)profileForCoil:(int)coilID;
- (void)setCoilID:(int)anID;
- (int)coilID;
- (void)initWithImage:(RecImage *)img;
- (void)initWithPWImage:(RecImage *)img;
- (RecImage *)weight;

// ============ private ==============
- (float *)xWeightForCh:(int)ch dim:(int)xDim;
- (float *)yWeightForCh:(int)ch dim:(int)yDim;
- (float *)zWeightForCh:(int)ch dim:(int)zDim;

@end

