//
//  1D resampler
//

#import <Foundation/Foundation.h>

@class RecImage, RecLoop, RecLoopControl;

#define LANCZ_ORDER_1D 3
#define LANCZ_BUFSIZE_1D 6

typedef struct RecWarpTab1d {
	int			leftIx;
	float		wt[LANCZ_BUFSIZE_1D];		// order * 2
} RecWarpTab1d;

int warp_kernel_index_1d(float dist, int step, int len);

@interface	RecResampler1d:NSObject
{
    int             mode;          // 0: ref, 1: op, 2: CL
    RecImage        *src;           // input
    RecImage        *dst;           // output
    int             loop_index;      // index of target loop
    int             skip;           // skip for target loop (same for src/dst)
    RecImage        *map;           // warp map

    RecLoopControl  *dstLc;         // inner to map, outer to xy (dst loop counter)
    RecLoopControl  *srcLc;         // (passive)
    RecLoopControl  *control;       // contains all loops (states)

// Lanczos kernel
	int             kern_len;       // length of kernel LUT tab
	int             kern_step;      // step size corresponding to 1.0 interval
	int             kern_size;		// order*2 (1D) or order*2 * order*2 (2D)
	float           *kernel;
    float           beta;
// WarpTab
	RecWarpTab1d    *warp_tab;
	int             warp_tab_len;
}


// initializer (tab is not generated yet)
+ (id)resamplerWithSrc:(RecImage *)src dst:(RecImage *)dst loopAt:(int)ix map:(RecImage *)map;
+ (id)resamplerWithSrc:(RecImage *)src dst:(RecImage *)dst loopAt:(int)ix map:(RecImage *)map beta:(float)bt;
- (id)initWithSrc:(RecImage *)src dst:(RecImage *)dst loopAt:(int)ix map:(RecImage *)map beta:(float)bt;

// actual resampling (to dst)
- (void)resample;
// for NSOperation
- (void)resampleAtSrc:(float *)sp dst:(float *)dp;

// private
- (void)setLoopControls;
- (void)createWarpTab;
- (void)freeWarpTab;

@end
