//
//	Noise generator
//	straight port from old lib
//	optimize for speed later
//

#import "RecNoise.h"

@implementation RecNoise

+ (id)noise
{
//	return [[RecNoise alloc] initWithSeed:1];
	return [[RecNoise alloc] initWithSeed:(int)random()];
}

- (id)initWithSeed:(int)sd
{
    self = [super init];
    if (!self) return nil;

	[self setSeed:sd];
    return self;
}

- (void)setX:(int)sd
{
	x = sd;
}

- (void)setY:(int)sd
{
	y = sd;
}

- (void)setZ:(int)sd
{
	z = sd;
}

- (void)setSeed:(int)sd
{
	x = y = z = sd;
}

// Byte Vol.12, No.3, 127-128, 1987 , rn uniformly dist. in [0, 1)
- (float)unif
{
	float	tmp;

	x = 171 * (x % 177) - 2 * (x / 177);
	if (x < 0) x += 30269;
	y = 172 * (y % 176) - 35 * (y / 176);
	if (y < 0) y += 30307;
	z = 170 * (z % 178) - 63 * (z / 178);
	if (z < 0) z += 30323;
	tmp = x/30269.0 + y/30307.0 + z/30323.0;
	tmp -= floor((double)tmp);

	return tmp;
}

// Gaussian, N(0.0, 1.0)
- (float)nrml
{
	int		i, n = 10;
	float	r = 0;
	float	sqrn = sqrt(12.0/n);
	float	n2 = n/2.0;

	for (i = 0; i < n; i++) {
		r += [self unif];
	}
	r = (r - n2) * sqrn;

	return r;
}

@end
