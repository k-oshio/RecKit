//
//	Gridding object
//

#import <Foundation/Foundation.h>

#define	GRID_ALPHA		3.5		// KAISER	... 3.5

float besseli0(float x);

@class RecImage, RecLoopControl;

typedef struct {
	int			x0;		// upper-left corner
	int			y0;		// upper-left corner
	float		wt[16];
	float		den;
} RecGridTab;

typedef struct {
	int			ix;
	float		w;
} RecWtEntry;

typedef struct {
	int			tab_len;		// # of entries (traj length)
	int			total_len;		// # of points
	RecWtEntry	*buf;			// 1-d data
	RecWtEntry	**p;			// pointer array pointing to buf
	int			*nent;			// # of points in p[i]
} RecWtTab;

@interface RecGridder : NSObject
{
    int         mode;               // 0: ref, 1: op, 2: CL
	int			recdim;             // image size
	int			ft_dim;				// recdim * nop
	int			nop;
	int			kern_width;			//
	float		kern_b;				//
	int			kern_step;			// step size corresponding to 1.0 interval
	float		*kern_tab;			// 1D kernel (kern_tab_len)
	int			kern_tab_len;		// dim of kernel LUT
	RecImage	*traj;
	RecImage	*inverse_kernel;    // 2D inverse kernel (recdim x recdim)
	RecGridTab	*grid_tab;			// new version
	int			*grid_ix_tab;	// used by mktab and grid1
	int			grid_tab_len;
	BOOL		mask;				// circular mask for final image
	BOOL		dumpRaw;			// for debugging
}

// alloc/init/dealloc
+ (RecGridder *)gridderWithTrajectory:(RecImage *)traj andRecDim:(int)recDim;
+ (RecGridder *)gridderWithTrajectory:(RecImage *)traj andRecDim:(int)recDim nop:(int)np densityCorrection:(BOOL)corr;
- (id)initWithTrajectory:(RecImage *)theTraj andRecDim:(int)theRecDim nop:(int)np densityCorrection:(BOOL)corr;
- (void)dealloc;
- (void)freeGridTab;

// mult-processing mode
- (void)setMode:(int)mode;
// circular mask
- (void)setMask:(BOOL)maskOn;
// debug
- (void)setDumpRaw:(BOOL)rawOn;

// gridding
- (void)grid2d:(RecImage *)dat to:(RecImage *)img;
// update weight
- (void)updateWeight:(RecImage *)traj;

// accessor
- (int)nop;
- (void)setNop:(int)nop;
- (int)ftDim;
- (float *)kernTab;
- (int)kernTabLen;
//- (float *)kernel1d;
- (RecImage *)traj;
- (int)kernWidth;

// private
- (RecImage *)createTmp;
- (void)grid2d_ref:(RecImage *)dat to:(RecImage *)img;
- (void)grid2d_op:(RecImage *)dat to:(RecImage *)img;
- (void)grid1Data:(RecImage *)src withControl:(RecLoopControl *)lc to:(RecImage *)dst;	// KAISER2
- (void)grid2WithControl:(RecLoopControl *)lc from:(RecImage *)src to:(RecImage *)dst;
- (void)makeGridTab;
- (void)makeGridKernel;
- (void)makeGridInverseKernel;
- (void)densityCorrection2D;
- (RecWtTab *)makeWtTabFromIndex:(int)st length:(int)len;	// low level, actual proc
- (RecWtTab *)makeWtTab2D;
- (RecWtTab *)makeWtTabOp;
- (void)freeWtTab:(RecWtTab *)tab;
- (void)gridToTraj:(RecWtTab *)tab in:(float *)inBuf out:(float *)outBuf;

// debug
- (void)dumpKernel;			// kern_tab_len (1-sided)
- (RecImage *)gridWeight;	// 3rd plane of ktraj

@end

// =========== gridding ==================
@interface RecGridding2dOp : NSOperation
{
	RecImage		*grid_tmp;      // work area (per operation)
	RecImage		*srcImage;		// raw data (common)
	RecImage		*dstImage;		// result (common)
	RecLoopControl	*srcLc;         // per operation
	RecLoopControl	*dstLc;         // per operation
    RecGridder      *grid;          // common
	BOOL			dumpRaw;
}
+ (id)opWithSrc:(RecImage *)src dst:(RecImage *)dst srcLc:(RecLoopControl *)srcLc dstLc:(RecLoopControl *)dstLc gridder:(RecGridder *)gr;
- (id)initWithSrc:(RecImage *)src dst:(RecImage *)dst srcLc:(RecLoopControl *)srcLc dstLc:(RecLoopControl *)dstLc gridder:(RecGridder *)gr;
- (void)setDumpRaw:(BOOL)rawOn;
- (void)main;
@end

// ======== gridding density correction (### optimize for single first) ======
@interface RecMakeWtTabOp : NSOperation
{
    RecGridder      *grid;          // common
	RecWtTab		**tabP;			// out
	int				start;			// in
	int				length;			// in
}
+ (id)opWithGridder:(RecGridder *)gr tab:(RecWtTab **)tb start:(int)st length:(int)len;
- (id)initWithGridder:(RecGridder *)gr tab:(RecWtTab **)tb start:(int)st length:(int)len;
- (void)main;
@end



