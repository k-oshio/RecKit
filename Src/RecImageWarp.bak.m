//
//	RecImageWarp
//
//	--- plan ---
//  move (save) param array version to rtf3Recon
//  make everything single-param

#import "RecImage.h"
#import "RecLoop.h"
#import "RecLoopControl.h"
#import "RecOperations.h"

int warp_mode = 1;	// 0:CPU (OK) (use vDSP ###), 1:Op (OK), 2:CL (not done yet ##)

@implementation RecImage (Warp)

// param is param array. loop(s) of param image must be part of loops of src image.

// map is 2D/2-plane image (inverse map of pixel position, from dst to src)
// map has same dim with dst
// range of map values is [-0.5 .. 0.5]. this is scaled to src at later stage

- (void)scaleByX:(float)x andY:(float)y
{
	RecImage	*param, *map, *tmp;
	tmp = [self copy];
	param = [RecImage pointImageOfType:RECIMAGE_MAP];
	[param setVal1:1.0/x val2:1.0/y];
	map = [self mapForScale:param];
    //[map saveAsKOImage:@"../test_img/test_map.img"];
	[self resample:tmp withMap:map];
}

- (RecImage *)oversample
{
	RecLoop		*xLp, *yLp;
	RecLoop		*xLp2, *yLp2;
	RecImage	*img, *param, *map;

	img = [self copy];
	xLp = [img xLoop];
	yLp = [img yLoop];
	xLp2 = [xLp copy];
	[xLp2 setDataLength:[xLp dataLength] * 2];
	yLp2 = [yLp copy];
	[yLp2 setDataLength:[yLp dataLength] * 2];
	[img replaceLoop:xLp withLoop:xLp2];
	[img replaceLoop:yLp withLoop:yLp2];

	param = [RecImage pointImageOfType:RECIMAGE_MAP];
	[param setVal1:1.0 val2:1.0];
	map = [img mapForScale:param];
    //[map saveAsKOImage:@"../test_img/test_map.img"];
	[img resample:self withMap:map];

	return img;
}

- (RecImage *)oversampleLoop:(RecLoop *)lp factor:(int)n
{
	RecLoop		*lp2;
	RecImage	*img, *param, *map;

	img = [self copy];
	lp2 = [lp copy];
	[lp2 setDataLength:[lp dataLength] * n];
	[img replaceLoop:lp withLoop:lp2];

	param = [RecImage pointImageOfType:RECIMAGE_MAP];
	[param setVal1:1.0 val2:1.0];
	map = [img mapForScale:param];
	[img resample:self withMap:map];

	return img;
}

- (RecImage *)toPolarWithNTheta:(int)nTheta nRad:(int)nRad
{
    RecImage        *img = nil;
    RecImage        *map;
    NSMutableArray  *lpArray = [NSMutableArray arrayWithArray:[self loops]];
    int             dim = (int)[lpArray count];
    RecLoop         *tLoop = [RecLoop loopWithDataLength:nTheta];
    RecLoop         *rLoop = [RecLoop loopWithDataLength:nRad];

    [lpArray removeObjectAtIndex:dim-1];
    [lpArray removeObjectAtIndex:dim-2];
    [lpArray addObject:rLoop];
    [lpArray addObject:tLoop];
    img = [RecImage imageOfType:[self type] withLoopArray:lpArray];
    map = [img mapForPolar];
    [img resample:self withMap:map];
    return img;
}

- (RecImage *)mapForScale:(RecImage *)param
{
    void (^proc)(float *mx, float *my, int xDim, int yDim, float *a, int n);
    
    proc = ^(float *mx, float *my, int xDim, int yDim, float *a, int n) {
        int     i, j, ix;
        float   x, y, fx, fy;

        fx = a[0];
        fy = a[1];
        for (i = ix = 0; i < yDim; i++) {
            y = ((float)i - yDim/2) / yDim;
            for (j = 0; j < xDim; j++, ix++) {
                x = ((float)j - xDim/2) / xDim;
                mx[ix] = x * fx;
                my[ix] = y * fy;
             }
        }
    };
    return [self createMapWithParam:param  usingProc:proc];
}

- (RecImage *)mapForShift:(RecImage *)param        // shift only (warp based)
{
    void (^proc)(float *mx, float *my, int xDim, int yDim, float *a, int n);
    
    proc = ^(float *mx, float *my, int xDim, int yDim, float *a, int n) {
        int     i, j, ix;
        float   x, y, dx, dy;

        dx = a[0];
        dy = a[1];
        for (i = ix = 0; i < yDim; i++) {
            y = ((float)i - yDim/2) / yDim;
            for (j = 0; j < xDim; j++, ix++) {
                x = ((float)j - xDim/2) / xDim;
                mx[ix] = x + dx;
                my[ix] = y + dy;
             }
        }
    };
    return [self createMapWithParam:param  usingProc:proc];
}

- (RecImage *)mapForShiftScale:(RecImage *)param
{
    void (^proc)(float *mx, float *my, int xDim, int yDim, float *a, int n);
    
    proc = ^(float *mx, float *my, int xDim, int yDim, float *a, int n) {
        int     i, j, ix;
        float   x, y, fx, fy, dx, dy;

        fx = a[0];
        fy = a[1];
        dx = a[2];
        dy = a[3];
        for (i = ix = 0; i < yDim; i++) {
            y = ((float)i - yDim/2) / yDim;
            for (j = 0; j < xDim; j++, ix++) {
                x = ((float)j - xDim/2) / xDim;
                mx[ix] = x * fx + dx;
                my[ix] = y * fy + dy;
             }
        }
    };
    return [self createMapWithParam:param  usingProc:proc];
}

- (RecImage *)mapForRotate:(RecImage *)param
{
    void (^proc)(float *mx, float *my, int xDim, int yDim, float *a, int n);
    
    proc = ^(float *mx, float *my, int xDim, int yDim, float *a, int n) {
        int     i, j, ix;
        float   x, y, th, cs, sn;

        th = a[0];
        cs = cos(th);
        sn = sin(th);
        for (i = ix = 0; i < yDim; i++) {
            y = ((float)i - yDim/2) / yDim;
            for (j = 0; j < xDim; j++, ix++) {
                x = ((float)j - xDim/2) / xDim;
                mx[ix] = (x * cs + y * sn);
                my[ix] = (y * cs - x * sn);
             }
        }
    };
    return [self createMapWithParam:param  usingProc:proc];
}


- (RecImage *)mapForAffine:(RecImage *)param 
{
    void (^proc)(float *mx, float *my, int xDim, int yDim, float *a, int n);
    
    proc = ^(float *mx, float *my, int xDim, int yDim, float *a, int n) {
        int     i, j, ix;
        float   x, y;

        for (i = ix = 0; i < yDim; i++) {
            y = ((float)i - yDim/2) / yDim;
            for (j = 0; j < xDim; j++, ix++) {
                x = ((float)j - xDim/2) / xDim;
				mx[ix] = (a[0] * x + a[1] * y + a[2]);
				my[ix] = (a[3] * x + a[4] * y + a[5]);
             }
        }
    };
    return [self createMapWithParam:param  usingProc:proc];
}

// projective (homography)
- (RecImage *)mapForHomog:(RecImage *)param
{
    void (^proc)(float *mx, float *my, int xDim, int yDim, float *a, int n);
    
    proc = ^(float *mx, float *my, int xDim, int yDim, float *a, int n) {
        int     i, j, ix;
        float   x, y, denom;

        for (i = ix = 0; i < yDim; i++) {
            y = ((float)i - yDim/2) / yDim;
            for (j = 0; j < xDim; j++, ix++) {
                x = ((float)j - xDim/2) / xDim;
                denom = a[6] * x + a[7] * y + 1;
				mx[ix] = (a[0] * x + a[1] * y + a[2]) / denom;
				my[ix] = (a[3] * x + a[4] * y + a[5]) / denom;
             }
        }
    };
    return [self createMapWithParam:param  usingProc:proc];
}

// radial (y = theta)
- (RecImage *)mapForRadial
{
	RecImage	*map;
    int         xDim = [self xDim];
    int         yDim = [self yDim];
	float		*mapX, *mapY;
	int			i, j, ix, len;
	float		r, th;

	map = [RecImage imageOfType:RECIMAGE_MAP xDim:xDim yDim:yDim];	// outer loop first
	len = [map dataLength];
	mapX = [map data];
	mapY = mapX + len;
	
	for (i = ix = 0; i < yDim; i++) {
		th = i * M_PI / yDim;
		for (j = 0; j < xDim; j++, ix++) {
			r = ((float)j - xDim/2) / xDim;	//	[-0.5 .. 0.5]
			mapX[ix] = r * cos(th);
			mapY[ix] = r * sin(th);
		}
	}
	return map;
}

// polar (y = r)
- (RecImage *)mapForPolar
{
    int         nTheta = [self xDim];
    int         nRad = [self yDim];
    RecImage    *img = [RecImage imageOfType:RECIMAGE_MAP xDim:nTheta yDim:nRad];
	int         i, j;
	float       r, th;
	float       x, y;
	float       *p, *q;

    p = [img data];
    q = p + [img dataLength];
	for (i = 0; i < nRad; i++) {
		r = (float)i * 0.5 / nRad; // * rad / nrad;
		for (j = 0; j < nTheta; j++) {
			th = (float)j * 2 * M_PI / nTheta;
			x = r * cos(th);
			y = r * sin(th);
            p[j] = x;
            q[j] = y;
		}
        p += nTheta;
        q += nTheta;
	}
    return img;
}

// FFT based shift without making map
// unit is pixel (different from warp map)
- (RecImage *)ftShiftBy:(RecImage *)param
{
	RecImage		*img;
	int				xDim = [self xDim];
	int				yDim = [self yDim];
	int				nImg = [self outerLoopDim];	// outerLoopDim for xy
	int				i, j, k;
	RecLoopControl	*srcLc;				// param
	int				srcLen;
	RecLoopControl	*dstLc;				// self
	float			*srcX, *srcY;
	float			*dstRe, *dstIm, *reP, *imP;
	float			xShift, yShift, re, im;
	float			thy, th, cs, sn;

    img = [self copy];
    [img makeComplex];
	[img fft2d:REC_INVERSE];

	dstLc = [img control];
	[dstLc deactivateXY];		// Phase:1, Slice:0, rd_zf:0
	srcLc = [RecLoopControl controlWithControl:dstLc forImage:param];	// Phase
	srcLen = [param dataLength];	// 300
	[dstLc rewind];
	for (k = 0; k < nImg; k++) {
		srcX = [param currentDataWithControl:srcLc];
		srcY = srcX + srcLen;
		xShift = *srcX;		// xsfhit: real
		yShift = *srcY;		// yshift: imag
		dstRe = [img currentDataWithControl:dstLc];
		dstIm = dstRe + dataLength;
		for (i = 0; i < yDim; i++) {
			thy = ((float)i - yDim/2) / yDim * yShift * M_PI;
			reP = dstRe + i * xDim;
			imP = dstIm + i * xDim;
			for (j = 0; j < xDim; j++) {
				// lin-phase
				th = thy + ((float)j - xDim/2) / xDim * xShift * M_PI;
				cs = cos(th);
				sn = sin(th);
				re = reP[j];
				im = imP[j];
				reP[j] = re * cs + im * sn;
				imP[j] =-re * sn + im * cs;
			}
		}
		[dstLc increment];
	}

	[img fft2d:REC_FORWARD];
	if (type != RECIMAGE_COMPLEX) {	// if self is not complex
		[img takeRealPart];
	}
	return img;
}

- (RecImage *)rotBy:(RecImage *)param
{
    RecImage    *img = [self copy];
    [img resample:self withMap:[self mapForRotate:param]];
    return img;
}

int
kern_index(float dist, 	WarpParam *wpr)
{
	int		ix;

	ix = (int)(dist * wpr->kern_step);
	if (ix < 0) ix = 0;
	if (ix >= wpr->kern_tab_len)  ix = wpr->kern_tab_len - 1;

	return ix;
}

// map is 2D only
// src is necessary for dim only (data is not used yet)
// ## add wrap around mode (not so easy)
- (WarpParam *)warpTabForSrc:(RecImage *)src map:(RecImage *)map andControl:(RecLoopControl *)lc
{
	WarpParam		*wpr;
	WarpTab			*tab;
	float			*kern;
	float			*mapX, *mapY;
	int				i, j, k, kern_ix, kern_tab_len = 120;
	int				ix, tab_len;
	int				dim;
	float			x, y, w, wx, wy, dist;
	int				xi, yi, xpos, ypos;
	int				xdim, ydim;
	int				srcXdim, srcYdim;

//[lc dumpLoops];
	xdim = [map xDim];
	ydim = [map yDim];
	wpr = (WarpParam *)malloc(sizeof(WarpParam));

	srcXdim = [src xDim];
	srcYdim = [src yDim];

// make kernel (one-sided)
	kern = (float *)malloc(sizeof(float) * kern_tab_len);
	for (i = 0; i < kern_tab_len; i++) {
		if (i == 0) {
			kern[i] = 1.0;
		} else {
			x = (float)i * LANCZ_ORDER * M_PI / kern_tab_len;
			w = (sin(x) / x) * (sin(x/LANCZ_ORDER) / (x/LANCZ_ORDER));
			kern[i] = w;
		}
	}
	wpr->kernel = kern;
	wpr->kern_tab_len = kern_tab_len;
	wpr->kern_step = kern_tab_len / LANCZ_ORDER;
	wpr->warp_tab_len = xdim * ydim;	// dst dim

// init warp tab
	dim = LANCZ_ORDER * 2;
	mapX = [map currentDataWithControl:lc];
	mapY = mapX + [map dataLength];
	wpr->kern_size = dim * dim;
	tab_len = wpr->warp_tab_len;
	tab = (WarpTab *)malloc(sizeof(WarpTab) * tab_len);

    ix = 0;
    // dim = 6, ix = 0..35
    for (i = 0; i < dim; i++) {
        for (j = 0; j < dim; j++, ix++) {
            wpr->posOffset[ix] = i * srcXdim + j;
        }
    }
    // tab_len = dst_xdim * dst_ydim
    for (k = 0; k < tab_len; k++) {
        x = mapX[k] * srcXdim + srcXdim/2;
        xi = (int)ceil(x) - LANCZ_ORDER;
        x = xi - x;
        y = mapY[k] * srcYdim + srcYdim/2;
        yi = (int)ceil(y) - LANCZ_ORDER;
        y = yi - y;
        tab[k].cornerIx = yi * srcXdim + xi;
        for (i = 0; i < dim; i++) {
            ypos = yi + i;
            if (ypos < 0 || ypos >= srcYdim) {
                wy = 0;
            } else {
                dist = fabs(y + i);
                kern_ix = kern_index(dist, wpr);
                wy = wpr->kernel[kern_ix];
            }
            for (j = 0; j < dim; j++) {
                xpos = xi + j;
                if (xpos < 0 || xpos >= srcXdim) {
                    wx = 0;
                } else {
                    dist = fabs(x + j);
                    kern_ix = kern_index(dist, wpr);
                    wx = wpr->kernel[kern_ix];
                }
                tab[k].wt[i * dim + j] = wx * wy;
            }
        }
    }

	wpr->warp_tab = tab;

	return wpr;
}

- (void)freeWarpTab:(WarpParam *)wpr
{
	if (wpr->kernel) {
		free(wpr->kernel);
		wpr->kernel = NULL;
	}
	if (wpr->warp_tab) {
		free(wpr->warp_tab);
		wpr->warp_tab = NULL;
	}

	wpr->kern_tab_len = 0;
	wpr->warp_tab_len = 0;
	free(wpr);
}

// always 2D. 
// in genral, dim of src and self (dst) is different
- (void)resample:(RecImage *)src withMap:(RecImage *)map
{
	switch (warp_mode) {
	case 0:
	default :
		[self resample_ref:src withMap:map];
		break;
	case 1:
		if ([src realDimension] > 2) {
			[self resample_op:src withMap:map];
		} else {
			[self resample_ref:src withMap:map];
		}
		break;
	case 2:	// OpenCL version, not done yet
		[self resample_ref:src withMap:map];
		break;
	}
}

// outer loop (single thread version)
- (void)resample_ref:(RecImage *)src withMap:(RecImage *)map
{
	RecLoopControl	*outer, *inner;
	RecLoop			*paramLp, *lp;
	int				i, j, ix, n;
    BOOL            found = NO;

	printf("single CPU version\n");

// outer should be param loop, inner is the rest (minus xy)
    [map removePointLoops];
	outer = [self control]; // [ch z y x]
	if ([map dimension] > 2) {	// param loop exists
		paramLp = [map topLoop];
        n = [self dimension];
        for (j = 0; j < n; j++) {
            lp = [[dimensions objectAtIndex:j] loop];
            if ([lp isEqual:paramLp]) {
                found = YES;
                ix = j;
            }
        }
        if (!found) return;
        [[outer loopIndexAtIndex:ix] setActive:NO];
	}
	[outer invertActive];

	inner = [outer complementaryControl];						// [*ch pw y x]
	[inner deactivateXY];										// [*ch pw *y *x]

	[outer rewind];
	n = [outer loopLength];

	for (i = 0; i < n; i++) {	// param loop
		[self resample_inner:src map:map andControl:inner];
		[outer increment];
	}
}

// outer loop for op version
// ## loop structure assumption is not always true ##### (rotation for tip doens't work)
- (void)resample_op:(RecImage *)src withMap:(RecImage *)map
{
	RecLoopControl		*outer, *inner;
	RecLoop				*paramLp, *lp;
	int					i, j, ix, n;
    BOOL                found = NO;
	NSOperation			*op;
	NSOperationQueue	*queue = [[NSOperationQueue alloc] init];;

	printf("op version\n");
	[queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];

// outer should be param loop, inner is the rest (minus xy)
    [map removePointLoops];
	outer = [self control]; // [ch z y x]
	if ([map dimension] > 2) {	// param loop exists
		paramLp = [[map loops] objectAtIndex:0];
        n = [self dimension];
        for (j = 0; j < n; j++) {
            lp = [[dimensions objectAtIndex:j] loop];
            if ([lp isEqual:paramLp]) {
                found = YES;
                ix = j;
            }
        }
        if (!found) return;
        [[outer loopIndexAtIndex:ix] setActive:NO];
	}
	[outer invertActive];

	inner = [outer complementaryControl];						// [*ch pw y x]
	[inner deactivateXY];										// [*ch pw *y *x]

	[outer rewind];
	n = [outer loopLength];
	for (i = 0; i < n; i++) {	// param loop
		op = [RecWarpOp opWithSrc:src dst:self map:map control:[inner copy]];
		[queue addOperation:op];
		[outer increment];
	}
	[queue waitUntilAllOperationsAreFinished];
}

// single 2D image processing. call this within loop or in parallel
// #### not correct for non-symmetric map
// ------------- restarted ... ---------------
//	-> src != dst, map is 2D different dim
//	-> dst, map have common xy dim
// pLc is [param loop]
- (void)resample_inner:(RecImage *)src map:(RecImage *)map andControl:(RecLoopControl *)inner
{
	RecLoopControl	*sLc, *dLc, *mLc;
	float			*src_p, *dst_p;
	int				i, j, k, n, m;
	float			sum;
	float			*vbuf;
	WarpParam		*wpr;
	WarpTab			*tab;
	float			*p;
	int				plane;

	// dLc has most of original states (other than param loop)
	dLc = [RecLoopControl controlWithControl:inner forImage:self];	// []
	sLc = [RecLoopControl controlWithControl:dLc forImage:src];
	mLc = [RecLoopControl controlWithControl:dLc forImage:map];

	wpr = [self warpTabForSrc:src map:map andControl:mLc];
	m = wpr->kern_size;
	vbuf = (float *)malloc(sizeof(float) * m);

	n = [dLc loopLength];
	[dLc rewind];
//printf("inner [dLc] = %d\n", n);
	for (k = 0; k < n; k++) {	// inner loop, resample with same map
		src_p = [src currentDataWithControl:sLc];	// -> real/img -> planes
		dst_p = [self currentDataWithControl:dLc];
		for (plane = 0; plane < pixSize; plane++) {
			for (i = 0; i < wpr->warp_tab_len; i++) {
				tab = &(wpr->warp_tab[i]);
				p = src_p + tab->cornerIx;
				sum = 0;
				// vDSP (slower, and wt as flag doesn't work)
				/*
				for (j = 0; j < m; j++) {
					vbuf[j] = p[wpr->posOffset[j]];
				}
				vDSP_dotpr(vbuf, 1, tab->wt, 1,  &dst_p[i], m);
				*/
				/* ref */
				for (j = 0; j < wpr->kern_size; j++) {	// kern_size = 36
					if (tab->wt[j] != 0) {
						sum += p[wpr->posOffset[j]] * tab->wt[j];
					//	sumi += q[wpr->posOffset[j]] * tab->wt[j];
					}
				}
				dst_p[i] = sum;
			}
			src_p += [src dataLength];
			dst_p += [self dataLength];
		}
		[dLc increment];	// inner
	}
	[self freeWarpTab:wpr];
	free(vbuf);
}

// making map...
- (RecImage *)createMapWithParam:(RecImage *)param usingProc:
    (void (^)(float *mx, float *my, int xDim, int yDim, float *a, int dim))proc
{
	RecImage		*map;
    RecLoop         *xLoop = [self xLoop];
    RecLoop         *yLoop = [self yLoop];
    RecLoop         *pLoop = [param xLoop];
	RecLoopControl	*mapLc, *paramLc;
	float			*mapX, *mapY;
	float			*aP, *a;
	int				k, n, ix, len, paramDim;
	int				xDim = [self xDim];
    int             yDim = [self yDim];

	map = [RecImage imageOfType:RECIMAGE_MAP withLoops:pLoop, yLoop, xLoop, nil];

	mapLc = [map control];
	[mapLc deactivateXY];
	len = [map dataLength];
	n = [mapLc loopLength];

	paramLc = [param controlWithControl:mapLc];
//    paramLen = [param dataLength];
    paramDim = [param pixSize];
    a = (float *)malloc(paramDim * sizeof(float));

    [mapLc rewind];
	for (k = 0; k < n; k++) {
		aP = [param currentDataWithControl:paramLc];
        for (ix = 0; ix < paramDim; ix++) {
            a[ix] = *aP;
            aP += n; //paramLen;
        }
		mapX = [map currentDataWithControl:mapLc];
		mapY = mapX + len;

    // call proc
        proc(mapX, mapY, xDim, yDim, a, paramDim);

		[mapLc increment];
	}
    free(a);

	return map;
}

//=== debug
- (void)dumpParam
{
    int     n = [self xDim];
    int     m = [self pixSize];
    int     i, j, len = [self dataLength];
    float   *p = [self data];

    for (i = 0; i < n; i++) {
        printf("%d ", i);
        for (j = 0; j < m; j++) {
            printf("%f ", p[j * len + i]);
        }
        printf("\n");
    }
}

@end
