//
//  1D resampler
//  (merge with 2D later)
//

#import "RecResampler1d.h"
#import "RecUtil.h"
#import "RecImage.h"
#import "RecLoop.h"
#import "RecLoopControl.h"
#import "RecOperations.h"

@implementation	RecResampler1d

+ (id)resamplerWithSrc:(RecImage *)src dst:(RecImage *)dst loopAt:(int)ix map:(RecImage *)map
{
    return [RecResampler1d resamplerWithSrc:src dst:dst loopAt:ix map:map beta:1.0];
}

+ (id)resamplerWithSrc:(RecImage *)src dst:(RecImage *)dst loopAt:(int)ix map:(RecImage *)map beta:(float)bt
{
    return [[RecResampler1d alloc] initWithSrc:src dst:dst loopAt:ix map:map beta:bt];
}

- (id)initWithSrc:(RecImage *)srcImg dst:(RecImage *)dstImg loopAt:(int)ix map:(RecImage *)mapImg
{
    return [self initWithSrc:srcImg dst:dstImg loopAt:ix map:mapImg beta:1.0];
}

- (id)initWithSrc:(RecImage *)srcImg dst:(RecImage *)dstImg loopAt:(int)ix map:(RecImage *)mapImg beta:(float)bt
{
    self = [super init];
    if (!self) return nil;

    mode = 1;   // 0:cpu, 1:op
    loop_index = ix;
    src = srcImg;
    dst = dstImg;
    map = mapImg;
    beta = bt;
    [self setLoopControls];
    [self createWarpTab];
//[self dumpKernel];
//[self dumpWarpTab];

    return self;
}

- (void)dealloc
{
    [self freeWarpTab];
}

// same as 2D version (... 2D uses 1D table)
// 1-sided table... truncation direction is significant
int
warp_kernel_index_1d(float dist, int step, int len)
{
	int		ix;

    ix = floor(dist * step);    // two-sided
    ix = abs(ix);

	if (ix < 0) ix = 0;
	if (ix > len)  ix = len;

	return ix;
}

- (void)createWarpTab
{
	float			*map_p;
	int				i, k, kern_ix;
	int				dim;
    int             srcDim, dstDim;
	float			x, w, dist;
	int				xi;

	dstDim = [map xDim];
    srcDim = [[srcLc loopAtIndex:loop_index] dataLength];

// make kernel (one-sided)
    kern_len = 120; //120;
	kern_step = kern_len / LANCZ_ORDER_1D;

    kernel = Rec_lanczos_kern(kern_len, LANCZ_ORDER_1D);  // actual length = kern_len + 1 (including 0 and kern_len)
//    kernel = Rec_said_kern(kern_len, LANCZ_ORDER_1D, 0.284, 0.65);

// init warp tab
	warp_tab_len = dstDim;
	dim = LANCZ_ORDER_1D * 2;
    map_p = [map data];
	kern_size = dim;
	warp_tab = (RecWarpTab1d *)malloc(sizeof(RecWarpTab1d) * warp_tab_len);

    // tab_len == dst_looplen
    for (k = 0; k < warp_tab_len; k++) {
        x = map_p[k] * dstDim + srcDim/2; // [-0.5..0.5] -> [0..srcDim-1] (float) (+ overrange covering dstdim)
        xi = (int)ceil(x) - LANCZ_ORDER_1D;  // index of 1st point, relative to src origin (could be negative)
        x = xi - x; // float position within kernel (negative)
        warp_tab[k].leftIx = xi;    // src ix of leftmost point
        for (i = 0; i < dim; i++) {
            if (xi + i < 0 || xi + i >= srcDim) {   // was dstDim ###
                w = 0;
            } else {
            //    dist = fabs(x + i);     // float dist from origin of kernel (positive only)
                dist = x + i;
                kern_ix = warp_kernel_index_1d(dist, kern_step, kern_len);  // index into kernel tab
                w = kernel[kern_ix];    // weight value [0..1.0]
            }
            warp_tab[k].wt[i] = w;
        }
    }
}

- (void)freeWarpTab
{
	if (kernel) {
		free(kernel);
		kernel = NULL;
	}
	if (warp_tab) {
		free(warp_tab);
		warp_tab = NULL;
	}
	kern_len = 0;
	warp_tab_len = 0;
}

// create warp tab and resample
- (void)resample
{
    switch (mode) {
    case 0: // ref
        [self resample_ref];
        break;
    case 1: // op
        [self resample_op];
        break;
    }
}

- (void)resample_op
{
    int                 j, m = [dstLc loopLength];
    float               *sp, *dp;
	NSOperation			*op;
	NSOperationQueue	*queue = [[NSOperationQueue alloc] init];;

//    [self createWarpTab];
    // resample
    [dstLc rewind];
    for (j = 0; j < m; j++) {   // dst loop
        sp = [src currentDataWithControl:srcLc];
        dp = [dst currentDataWithControl:dstLc];
       // [self resampleAtSrc:sp dst:dp];
        op = [RecResampler1dOp opWithResampler:self src:sp dst:dp];
        [queue addOperation:op];
        [dstLc increment];
    }
    [queue waitUntilAllOperationsAreFinished];
//    [self freeWarpTab];
}

- (void)resample_ref
{
    int     j, m = [dstLc loopLength];
    float   *sp, *dp;

//    [self createWarpTab];
    // resample
    [dstLc rewind];
    for (j = 0; j < m; j++) {
        sp = [src currentDataWithControl:srcLc];
        dp = [dst currentDataWithControl:dstLc];
        [self resampleAtSrc:sp dst:dp];
        [dstLc increment];
    }
//    [self freeWarpTab];
}

- (void)resampleAtSrc:(float *)sp dst:(float *)dp
{
    float           *p;
    RecWarpTab1d    *tab;
    float           sum;
    int             plane, pixSize = [dst pixSize];
    int             i, j, ix;

    for (plane = 0; plane < pixSize; plane++) {
        for (i = 0; i < warp_tab_len; i++) {
            tab = &(warp_tab[i]);
            p = sp + tab->leftIx * skip;
            sum = 0;

            for (j = ix = 0; j < kern_size; j++, ix += skip) {	// kern_size = 6
                if (tab->wt[j] != 0) {
                    sum += p[ix] * tab->wt[j];
                }
            }
            dp[i * skip] = sum;
        }
        sp += [src dataLength];
        dp += [dst dataLength];
    }
}

- (void)setLoopControls
{
    NSMutableArray  *loops = [NSMutableArray array];
    RecLoop         *lp, *targetLp;
    int             i, n;

// contains all loops
    // src
    n = [src dim];
    for (i = 0; i < n; i++) {
        [loops addObject:[src loopAtIndex:i]];
    }
    // dst
    n = [dst dim];
    for (i = 0; i < n; i++) {
        lp = [dst loopAtIndex:i];
        if (![loops containsObject:lp]) {
            [loops addObject:lp];
        }
    }
    // map
    n = [map dim];
    for (i = 0; i < n; i++) {
        lp = [dst loopAtIndex:i];
        if (![loops containsObject:lp]) {
            [loops addObject:lp];
        }
    }
    // make loopControl (loop order doesn't matter)
    control = [RecLoopControl controlWithLoopArray:loops];      // [ch, sl, pe, y, x]

    // dst outer (dst loop counter)
    dstLc = [RecLoopControl controlWithControl:control forImage:dst];    // [ch, sl, pe-, y-, x-]
//    zLp = [dst zLoop];
    targetLp = [dst loopAtIndex:loop_index];
    [dstLc deactivateLoop:targetLp];

    // src (passive)
    srcLc = [RecLoopControl controlWithControl:control forImage:src];
    skip = [src skipSizeForLoop:[src loopAtIndex:loop_index]];
}

- (void)dumpKernel
{
    int     i;

    for (i = 0; i < kern_len; i++) {
        printf("%d %f\n", i, kernel[i]);
    }
}

- (void)dumpWarpTab
{
    int     i, k;
    float   w;

    for (i = 0; i < 6; i++) {
        printf("%d ", i);
        for (k = 10; k < 20; k++) {
            printf("%5.3f ", warp_tab[k].wt[i]);
        }
        printf("\n");
    }
    printf("!====\n");
    for (k = 5; k < 15; k++) {
        w = 0;
        for (i = 0; i < 6; i++) {
            w += warp_tab[k].wt[i];
        }
        printf("%d %f\n", k, w);
    }
}

@end
