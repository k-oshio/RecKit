//
//	RecImageWarp
//
//	--- plan ---
//  refactor ###
//      making map is ok -> conv method to make param imgs

#import "RecImage.h"
#import "RecLoop.h"
#import "RecLoopControl.h"
#import "RecResampler.h"

@implementation RecImage (Warp)

// ### design principle ### 8-14-2013
// - param is param array. loop(s) of param image must be part of loops of src image.
// - point image should work as param (should be point image in most cases)
// - map is 2D/2-plane image (inverse map of pixel position, from dst to src)
// - map has same dim with dst
// - range of map values is [-0.5 .. 0.5]. this is scaled to src at later stage

- (RecImage *)weight							// return density image (real)
{
	RecImage	*wt;
	float		*p, *q;
	int			i, n = [self dataLength];
	
	wt = [RecImage imageOfType:RECIMAGE_REAL xDim:[self xDim] yDim:[self yDim]];
	p = [self data] + n * 2;
	q = [wt data];
	for (i = 0; i < n; i++) {
		q[i] = p[i];
	}
	return wt;
}

- (RecImage *)scaleXYBy:(float)scale
{
    return [self scaleXBy:scale andYBy:scale crop:NO];
}

// real 2D version is faster
- (RecImage *)scaleXBy:(float)x andYBy:(float)y crop:(BOOL)flg
{
	RecImage	*tmp;
	tmp = [self copy];
    tmp = [tmp scale1dLoop:[tmp xLoop] by:x crop:flg];
    tmp = [tmp scale1dLoop:[tmp yLoop] by:y crop:flg];

    return tmp;
}


- (RecImage *)scaleXBy:(float)x andYBy:(float)y
{
	RecImage	*param, *map, *tmp;
	tmp = [self copy];
	param = [RecImage pointImageOfType:RECIMAGE_MAP];
	[param setVal1:1.0/x val2:1.0/y];
	map = [self mapForScale:param];
	[tmp resample:self withMap:map];

    return tmp;
}

- (RecImage *)scale1dLoop:(RecLoop *)lp by:(float)scale to:(int)newDim
{
	RecImage	*map, *tmp;
    RecLoop     *newLp;
    int         dim, index;

    dim = [lp dataLength];
    newLp = [RecLoop loopWithDataLength:newDim];
    tmp = [RecImage imageWithImage:self];
    [tmp replaceLoop:lp withLoop:newLp];

	map = [tmp mapFor1dScale:1.0/scale forLoop:newLp];
    index = [self indexOfLoop:lp];
    [tmp resample1d:self forLoopIndex:index map:map];

    return tmp;
}

- (RecImage *)scale1dLoop:(RecLoop *)lp to:(int)newDim
{
	float	scale = (float)newDim / [lp dataLength];
	return [self scale1dLoop:lp by:scale to:newDim];
}

- (RecImage *)scale1dLoop:(RecLoop *)lp by:(float)scale
{
	int	newDim = [lp dataLength] * scale;
	return [self scale1dLoop:lp by:scale to:newDim];
//    return [self scale1dLoop:lp by:scale crop:NO];
}

- (RecImage *)scale1dLoop:(RecLoop *)lp by:(float)scale crop:(BOOL)crop
{
	RecImage	*map, *tmp;
    RecLoop     *newLp;
    int         dim, newDim, index;

    dim = [lp dataLength];
    if (crop) {
        newDim = dim;
    } else {
        newDim = dim * scale;
    }
    newLp = [RecLoop loopWithDataLength:newDim];
    tmp = [RecImage imageWithImage:self];
    [tmp replaceLoop:lp withLoop:newLp];

	map = [tmp mapFor1dScale:1.0/scale forLoop:newLp];
    index = [self indexOfLoop:lp];
    [tmp resample1d:self forLoopIndex:index map:map];

    return tmp;
}

- (RecImage *)scaleZBy:(float)z
{
    return [self scale1dLoop:[self zLoop] by:z];
}

- (RecImage *)scaleZByX:(float)z
{
	RecImage	*map, *tmp;
    int         zDim, newZDim, zLoopIndex;

    zDim = [self zDim];
    newZDim = zDim * z;
    zLoopIndex = [self dim] - 2;
    tmp = [RecImage imageWithImage:self];
    [tmp replaceLoop:[tmp zLoop] withLoop:[RecLoop loopWithDataLength:newZDim]];

	map = [tmp mapForZScale:1.0/z];
    [tmp resample1d:self forLoopIndex:zLoopIndex map:map];

    return tmp;
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
    [map removePointLoops];
	[img resample:self withMap:map];

	return img;
}

- (RecImage *)subsample		// x-y subsample by 2 (resampler-based)
{
	RecLoop		*xLp, *yLp;
	RecLoop		*xLp2, *yLp2;
	RecImage	*img, *param, *map;

	img = [self copy];
	xLp = [img xLoop];
	yLp = [img yLoop];
	xLp2 = [xLp copy];
	[xLp2 setDataLength:[xLp dataLength] / 2];
	yLp2 = [yLp copy];
	[yLp2 setDataLength:[yLp dataLength] / 2];
	[img replaceLoop:xLp withLoop:xLp2];
	[img replaceLoop:yLp withLoop:yLp2];

	param = [RecImage pointImageOfType:RECIMAGE_MAP];
	[param setVal1:1.0 val2:1.0];
	map = [img mapForScale:param];
    [map removePointLoops];
	[img resample:self withMap:map];

	return img;
}

- (RecImage *)ftSubsample	// x-y subsample by 2 (FT-based)
{
	RecImage	*img = [self copy];

	[img fft2d:REC_INVERSE];
	[img crop:[img xLoop] to:[img xDim]/2];
	[img crop:[img yLoop] to:[img yDim]/2];
	[img fft2d:REC_FORWARD];
	[img takeRealPart];
	
	return img;
}

- (RecImage *)mapFor1dShift:(float)sft forLoop:(RecLoop *)lp
{
    RecImage        *map;
    int             i, dim;	// dst dim
    float           *p;

    map = [RecImage imageOfType:RECIMAGE_REAL withLoops:lp, nil];
    dim = [lp dataLength];

    p = [map data];
    for (i = 0; i < dim; i++) {
        p[i] = ((float)i + sft - dim/2) / dim;
    }
    return map;
}

- (RecImage *)shift1dLoop:(RecLoop *)lp by:(float)sft
{
	RecImage	*map, *dst;
    int         index;

	dst = [RecImage imageWithImage:self];
	map = [dst mapFor1dShift:sft forLoop:lp];
    index = [self indexOfLoop:lp];
    [dst resample1d:self forLoopIndex:index map:map];

    return dst;
}

- (RecImage *)toPolarWithNTheta:(int)nTheta nRad:(int)nRad rMin:(int)ofs logR:(BOOL)lgr
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
    map = [img mapForPolarWithRMin:ofs logR:lgr];
    [img resample:self withMap:map];
    return img;
}

// not tested yet ###
- (RecImage *)to3dPolarWithNTheta:(int)nTheta nPhi:(int)nPhi nRad:(int)nRad rMin:(int)rMin logR:(BOOL)lgr
{
    RecImage        *img = nil;
    RecImage        *map;
    NSMutableArray  *lpArray = [NSMutableArray arrayWithArray:[self loops]];
    int             dim = (int)[lpArray count];
    RecLoop         *tLoop = [RecLoop loopWithDataLength:nTheta];
    RecLoop         *pLoop = [RecLoop loopWithDataLength:nPhi];
    RecLoop         *rLoop = [RecLoop loopWithDataLength:nRad];

    [lpArray removeObjectAtIndex:dim-1];
    [lpArray removeObjectAtIndex:dim-2];
    [lpArray removeObjectAtIndex:dim-3];
    [lpArray addObject:pLoop];
    [lpArray addObject:rLoop];
    [lpArray addObject:tLoop];
    img = [RecImage imageOfType:[self type] withLoopArray:lpArray];

    map = [img mapFor3dPolarWithRMin:rMin logR:lgr];
    [img resample3d:self withMap:map];
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

// pixels
- (RecImage *)mapForShiftX:(RecImage *)param        // shift only (warp based)
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

// unit: frac of FOV
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
                mx[ix] = x + dx;	// fixed ## (1/26/2017)
                my[ix] = y + dy;
             }
        }
    };
    return [self createMapWithParam:param  usingProc:proc];
}

// 
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

// polar
- (RecImage *)mapForPolarWithRMin:(int)ofs logR:(BOOL)lgr
{
    int         nTheta = [self xDim];
    int         nRad = [self yDim];
    RecImage    *img = [RecImage imageOfType:RECIMAGE_MAP xDim:nTheta yDim:nRad];
	int         i, j;
	float       r, th;
    float       rMin =0.01, rMax = 0.2;
	float       x, y;
	float       *p, *q;

    p = [img data];
    q = p + [img dataLength];
	for (i = 0; i < nRad; i++) {
        if (lgr) {  // log polar
            r = ofs + (float)i * rMax / nRad; // * rad / nrad [0..0.5]
            r = rMax * exp(- (rMax - r) * 2);
        } else {    // linear R
        //    r = rMin + (float)i * (rMax - rMin) / nRad; // * rad / nrad [0..0.5]
			r = rMin + (float)i * 0.5 / nRad; // * rad / nrad [0..0.5]
        }

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

// 3D polar ### not working yet
- (RecImage *)mapFor3dPolarWithRMin:(int)ofs logR:(BOOL)lgr
{
    int         nTheta = [self xDim];
    int         nRad = [self yDim];
    int         nPhi = [self zDim];
    RecImage    *img = [RecImage imageOfType:RECIMAGE_VECTOR xDim:nTheta yDim:nRad zDim:nPhi];
	int         i, j, k;
	float       r, th, phi;
    float       rMin =0.01, rMax = 0.2;
	float       x, y, z;
	float       *xp, *yp, *zp;

    xp = [img data];
    yp = xp + [img dataLength];
    zp = yp + [img dataLength];
	for (k = 0; k < nPhi; k++) {
		for (i = 0; i < nRad; i++) {
			if (lgr) {  // log polar
				r = ofs + (float)i * rMax / nRad; // * rad / nrad [0..0.5]
				r = rMax * exp(- (rMax - r) * 2);
			} else {    // linear R
				r = rMin + (float)i * (rMax - rMin) / nRad; // * rad / nrad [0..0.5]
			}

			for (j = 0; j < nTheta; j++) {
				th = (float)j * 2 * M_PI / nTheta;
				phi = ((float)k - nPhi/2) * M_PI / nPhi;
				x = r * cos(phi) * cos(th);
				y = r * cos(phi) * sin(th);
				z = r * sin(phi);
				xp[i * nTheta + j] = x;
				yp[i * nTheta + j] = y;
				zp[i * nTheta + j] = z;
			}
		}
        xp += nTheta * nRad;
        yp += nTheta * nRad;
		zp += nTheta * nRad;
	}
    return img;
}

- (RecImage *)trajToMap         // for inv of gridding
{
    RecImage    *map = [RecImage imageOfType:RECIMAGE_MAP withImage:self];
    int         len = [map dataLength];
    float       *mapX,  *mapY;
    float       *trajX, *trajY;
    int         i;

    if (type != RECIMAGE_KTRAJ) return nil;
    mapX = [map data];
    mapY = mapX + len;
    trajX = [self data];
    trajY = trajX + len;
    for (i = 0; i < len; i++) {
        mapX[i] = trajX[i];
        mapY[i] = trajY[i];
    }

    return map;
}

// ### chk scale, offs
- (RecImage *)mapFor1dScale:(float)scale forLoop:(RecLoop *)lp    // 1D scale for lp
{
    RecImage        *map;
    int             i, dim;	// dst dim
    float           *p;

    map = [RecImage imageOfType:RECIMAGE_REAL withLoops:lp, nil];
    dim = [lp dataLength];

    p = [map data];
    for (i = 0; i < dim; i++) {
        p[i] = (i - (float)(dim - 1)/2) * scale / dim;
    }
    return map;
}

- (RecImage *)mapForZScale:(float)scale
{
    return [self mapFor1dScale:scale forLoop:[self zLoop]];
}

- (RecImage *)mapForRot:(RecImage *)rotParam shift:(RecImage *)sftParam
{
    RecImage    *map;
    float       *mx, *my, *rotP, *sftXP, *sftYP;
    float       x, y, dx, dy, th, cs, sn;
    int         i, j, k, n, ix;
    int         xDim, yDim; // dst dim

    n = [rotParam dataLength];
    rotP = [rotParam data];
    sftXP = [sftParam data];
    sftYP = sftXP + [sftParam dataLength];
    xDim = [self xDim];
    yDim = [self yDim];
    map = [RecImage imageOfType:RECIMAGE_MAP withImage:self];
    mx = [map data];
    my = mx + [map dataLength];

    for (k = 0; k < n; k++) {
        th = rotP[k];
//    printf("%d %f\n", k, th);
        dx = sftXP[k];
        dy = sftYP[k];
        cs = cos(th);
        sn = sin(th);
        ix = k * xDim * yDim;
        for (i = 0; i < xDim; i++) {
        for (j = 0; j < yDim; j++, ix++) {
            // calc combined coeff from rotP[i], sftP[i], scale
            x = ((float)j - xDim/2) / xDim;
            y = ((float)i - yDim/2) / yDim;
            // sft
            x += dx;
            y += dy;
            // rot
            mx[ix] = (x * cs + y * sn);
            my[ix] = (y * cs - x * sn);
            
/*
    createMapWithParam:: assumes param is 1D array, which might not be the case ... chk / fix

*/
        }
        }
    }
    return map;
}

// FFT based shift without making map
// unit is pixel (different from warp map)
- (RecImage *)ftShiftBy:(RecImage *)param
{
	RecImage		*img;
	int				xDim, yDim;
	int				nImg = [self nImages];	// outerLoopDim for xy
	int				i, j, k;
	RecLoopControl	*srcLc;				// param
	int				srcLen;
	RecLoopControl	*dstLc;				// self
	float			*srcX, *srcY;
	float			*dstRe, *dstIm, *reP, *imP;
	float			xShift, yShift, re, im;
	float			thy, th, cs, sn;

    img = [self copy];

	xDim = [img xDim];
	yDim = [img yDim];

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
		xShift = srcX[0];		// xsfhit: real
		yShift = srcY[0];		// yshift: imag
	//printf("%d %f %f\n", k, xShift, yShift);
		dstRe = [img currentDataWithControl:dstLc];
		dstIm = dstRe + [img dataLength];
		for (i = 0; i < yDim; i++) {
			thy = ((float)i - yDim/2) / yDim * yShift * M_PI * 2.0;
			reP = dstRe + i * xDim;
			imP = dstIm + i * xDim;
			for (j = 0; j < xDim; j++) {
				// lin-phase
				th = thy + ((float)j - xDim/2) / xDim * xShift * M_PI * 2.0;
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

// ### not done yet (1-24)
// unit: pixels
- (RecImage *)ftShift1d:(RecLoop *)lp by:(RecImage *)param // FFT based shift without making map
{
	RecImage		*img;
	int				xDim;
	int				j, k;
	RecLoopControl	*srcLc;				// param
	int				srcLen;
	RecLoopControl	*dstLc;				// self
	float			*srcX;
	float			*dstRe, *dstIm;
	float			xShift, re, im;
	float			th, cs, sn;

    img = [self copy];

	xDim = [img xDim];
//	yDim = [img yDim];

    [img makeComplex];
	[img fft1d:lp direction:REC_INVERSE];

	dstLc = [img control];
	[dstLc deactivateLoop:lp];
	srcLc = [RecLoopControl controlWithControl:dstLc forImage:param];	// Phase
	srcLen = [param dataLength];
	srcX = [param data];
	[dstLc rewind];
	for (k = 0; k < srcLen; k++) {
	//printf("%d %f %f\n", k, xShift, yShift);
		xShift = srcX[k];
		dstRe = [img currentDataWithControl:dstLc];
		dstIm = dstRe + [img dataLength];
		for (j = 0; j < xDim; j++) {
			// lin-phase
			th = ((float)j - xDim/2) / xDim * xShift * M_PI * 2.0;
			cs = cos(th);
			sn = sin(th);
			re = dstRe[j];
			im = dstIm[j];
			dstRe[j] = re * cs + im * sn;
			dstIm[j] =-re * sn + im * cs;
		}
		[dstLc increment];
	}
	[img fft1d:lp direction:REC_FORWARD];
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

- (RecImage *)rotByTheta:(float)th
{
    RecImage    *img = [self copy];
    RecImage    *map = [self mapForRotate:[RecImage pointImageWithReal:th]];
    [img resample:self withMap:map];
    return img;
}

//
- (void)resample:(RecImage *)src withMap:(RecImage *)map
{
    RecResampler    *resampler = [RecResampler resamplerWithSrc:src dst:self map:map];
    [resampler resample];
}

- (void)resample:(RecImage *)src withTraj:(RecImage *)ktraj    // inv of gridding
{
    // make map from ktraj ###
    // resample with map ###
}

- (void)resample1d:(RecImage *)src forLoopIndex:(int)ix map:(RecImage *)map
{
    RecResampler1d  *resampler = [RecResampler1d resamplerWithSrc:src dst:self loopAt:ix map:map];
    [resampler resample];
}

- (void)resample3d:(RecImage *)src withMap:(RecImage *)map     // xyz
{
    RecResampler3d  *resampler = [RecResampler3d resamplerWithSrc:src dst:self map:map];
    [resampler resample];
}

// making map...
- (RecImage *)createMapWithParam:(RecImage *)param usingProc:
    (void (^)(float *mx, float *my, int xDim, int yDim, float *a, int dim))proc
{
	RecImage		*map;
	RecLoopControl	*mapLc, *paramLc;
	float			*mapX, *mapY;
	float			*aP, *a;
	int				k, n, ix, len, paramDim;
	int				xDim = [self xDim];
    int             yDim = [self yDim];

	map = [RecImage imageOfType:RECIMAGE_MAP withLoops:[param xLoop], [self yLoop], [self xLoop], nil];

	mapLc = [map control];
	[mapLc deactivateXY];
	len = [map dataLength];
	n = [mapLc loopLength];

	paramLc = [param controlWithControl:mapLc];
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
    int     n = [self dataLength];
    int     m = [self pixSize];
    int     i, j;
    float   *p = [self data];

    for (i = 0; i < n; i++) {
        printf("%d ", i);
        for (j = 0; j < m; j++) {
            printf("%e ", p[j * n + i]);
        }
        printf("\n");
    }
}

@end
