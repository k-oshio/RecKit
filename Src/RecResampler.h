//
//  Redesigned RecImage (Warp)
//  2D resampler
//

#import <Foundation/Foundation.h>

@class RecImage, RecLoop, RecLoopControl;

#define KERN_LEN            300
#define LANCZ_ORDER         3
#define LANCZ_KERNSIZE      36
#define LANCZ_KERNSIZE_1D   6
#define LANCZ_KERNSIZE_3D   216

typedef struct RecWarpTab {
	int			cornerIx;
	float		wt[LANCZ_KERNSIZE];		// order * 2 ^ 2
} RecWarpTab;

typedef struct RecWarpTab1d {
	int			leftIx;
	float		wt[LANCZ_KERNSIZE_1D];		// order * 2
} RecWarpTab1d;

typedef struct RecWarpTab3d {
	int			cornerIx;
	float		wt[LANCZ_KERNSIZE_3D];		// order * 2 ^ 3
} RecWarpTab3d;

// kernel generation
float   *Rec_lanczos_kern(int len, int order);
float   *Rec_said_kern(int len, int order, float chi, float eta);
int     warp_kernel_index(float dist, int step, int len);

// ==== 2-D ======
// default ... for xy images
@interface	RecResampler:NSObject
{
    int             mode;           // 0: ref, 1: op, 2: CL
    RecImage        *src;           // input
    RecImage        *dst;           // output
    RecImage        *map;           // warp map

    RecLoopControl  *mapLc;         // outer loops for map (map loop counter)
    RecLoopControl  *dstLc;         // inner to map, outer to xy (dst loop counter)
    RecLoopControl  *srcLc;         // (passive)

// WarpTab
	RecWarpTab      *warp_tab;
	int             kern_size;		// order*2 (1D) or order*2 * order*2 (2D)
	int             warp_tab_len;
	int             posOffset[LANCZ_KERNSIZE];	// src pos
}


// initializer (tab is not generated yet)
+ (id)resamplerWithSrc:(RecImage *)src dst:(RecImage *)dst map:(RecImage *)map;
- (id)initWithSrc:(RecImage *)src dst:(RecImage *)dst map:(RecImage *)map;

// mult-processing mode
- (void)setMode:(int)mode;

// actual resampling (to dst)
- (void)resample;
- (void)resample_ref;
- (void)resample_op;
- (void)resample_cl_1;
- (void)resample_cl_2;
- (void)resampleSrc:(float *)sp dst:(float *)dp; // declared for RecOperations.m

// private
- (void)setLoopControls;
- (void)createWarpTab;
- (void)freeWarpTab;

// debug
- (void)chkWarpTab;

@end

// ==== 1-D ======
// for any loop
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

// WarpTab
	RecWarpTab1d    *warp_tab;
	int             warp_tab_len;
	int             kern_size;		// order*2 (1D) or order*2 * order*2 (2D)
}


// initializer (tab is not generated yet)
+ (id)resamplerWithSrc:(RecImage *)src dst:(RecImage *)dst loopAt:(int)ix map:(RecImage *)map;- (id)initWithSrc:(RecImage *)src dst:(RecImage *)dst loopAt:(int)ix map:(RecImage *)map;

// actual resampling (to dst)
- (void)resample;
- (void)resample_ref;
- (void)resample_op;
- (void)resample_cl_1;
- (void)resample_cl_2;
- (void)resampleSrc:(float *)sp dst:(float *)dp;    // declared for RecOperations.m

// private
- (void)setLoopControls;
- (void)createWarpTab;
- (void)freeWarpTab;

// debug
- (void)dumpWarpTab;
- (void)chkWarpTab;

@end

// ==== 3-D ======
// xyz images only
// no point in making warp tab ... direct resampling
// ### not done yet
@interface	RecResampler3d:NSObject
{
    int             mode;          // 0: ref, 1: op, 2: CL
    RecImage        *src;           // input
    RecImage        *dst;           // output
    RecImage        *map;           // warp map

	float           *kernel;
	int             kern_size;		// order*2 (1D) or order*2 * order*2 (2D)
	int             posOffset[LANCZ_KERNSIZE_3D];	// src pos
}


// initializer (tab is not generated yet)
+ (id)resamplerWithSrc:(RecImage *)src dst:(RecImage *)dst map:(RecImage *)map;
- (id)initWithSrc:(RecImage *)src dst:(RecImage *)dst map:(RecImage *)map;

// actual resampling (to dst)
- (void)resample;
- (void)resample_ref;
- (void)resample_op;
- (void)resampleSliceAt:(int)z;    // declared for RecOperations.m

@end

// =========== resampler2d ==================
@interface RecResamplerOp : NSOperation
{
    RecResampler    *resampler;
	float           *sp;
	float           *dp;
}
+ (id)opWithResampler:(RecResampler *)resampler src:(float *)sp dst:(float *)dp;
- (id)initWithResampler:(RecResampler *)resampler src:(float *)sp dst:(float *)dp;
- (void)main;
@end

// =========== resampler1d ==================
@interface RecResampler1dOp : NSOperation
{
    RecResampler1d  *resampler;
	float           *sp;
	float           *dp;
}
+ (id)opWithResampler:(RecResampler1d *)resampler src:(float *)sp dst:(float *)dp;
- (id)initWithResampler:(RecResampler1d *)resampler src:(float *)sp dst:(float *)dp;
- (void)main;

@end

// =========== resampler3d ==================
@interface RecResampler3dOp : NSOperation
{
    RecResampler3d  *resampler;
	int				slice;
}
+ (id)opWithResampler:(RecResampler3d *)resampler slice:(int)sl;
- (id)initWithResampler:(RecResampler3d *)resampler slice:(int)sl;
- (void)main;

@end

