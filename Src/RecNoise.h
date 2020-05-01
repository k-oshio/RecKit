//
//	Noise generator
//

#import <Foundation/Foundation.h>

@interface RecNoise : NSObject
{
	int		x;	// seed
	int		y;	// seed
	int		z;	// seed
}

+ (id)noise;
- (id)initWithSeed:(int)sd;
- (void)setX:(int)sd;
- (void)setY:(int)sd;
- (void)setZ:(int)sd;
- (void)setSeed:(int)sd;
- (float)unif;	// [0..1)
- (float)nrml;	// N(0, 1)

@end

