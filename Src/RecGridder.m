//
//	Gridding object
//

#import "RecGridder.h"
#import "RecImage.h"
#import "RecLoop.h"
#import "RecLoopControl.h"

// (Numerical Recipe in C)
float
bessel_nr(float x)
{
	float	ax, ans;
	double	y;

	if ((ax = fabs(x)) < 3.75) {
		y = x / 3.75;
		y *= y;
		ans = 1.0	+ y * (3.5156229
					+ y * (3.0899424
					+ y * (1.2067492
					+ y * (0.2659732
					+ y * (0.3607768e-1
					+ y * (0.45813e-2))))));
	} else {
		y = 3.75 / ax;
		ans = (exp(ax) / sqrt(ax)) * (0.39894228
					+ y * ( 0.1328592e-1
					+ y * ( 0.225319e-2
					+ y * (-0.157565e-2
					+ y * ( 0.916281e-2
					+ y * (-0.2057706e-1
					+ y * ( 0.2635537e-1
					+ y * (-0.1647633e-1
					+ y * ( 0.392377e-2)))))))));
	}
	return ans;
}

// iterative
#define BIZ_EPS 1e-20 // Max error acceptable 
float
bessel_iter(float x)
{ 
	float	sum, u, uu, x2 = x / 2.0;
	int		i;

	sum = u = 1.0;
	for (i = 1; (i < 100) && (u >= BIZ_EPS); i++) {
		uu = x2 / i;
		u *= uu * uu;
		sum += u;
	}

	return(sum);
}

// modified bessel function of first kind
float
besseli0(float x)
{
	return bessel_iter(x);
//	return bessel_nr(x);
}

@implementation RecGridder

+ (RecGridder *)gridderWithTrajectory:(RecImage *)traj andRecDim:(int)recDim
{
	RecGridder	*gr = [[RecGridder alloc] init];
	return [gr initWithTrajectory:traj andRecDim:recDim nop:2 densityCorrection:YES];
}

+ (RecGridder *)gridderWithTrajectory:(RecImage *)traj andRecDim:(int)recDim nop:(int)np densityCorrection:(BOOL)corr
{
    RecGridder  *gr = [[RecGridder alloc] init];
    return [gr initWithTrajectory:traj andRecDim:recDim nop:np densityCorrection:corr];
}

- (id)initWithTrajectory:(RecImage *)theTraj andRecDim:(int)theRecDim nop:(int)np densityCorrection:(BOOL)corr
{
    mode = 1;  // 0: ref, 1: op, 2: CL (not implemented)
	mask = YES;
	dumpRaw = NO;

// cache
	traj = theTraj;
	recdim = theRecDim;

// calc dimentions
	kern_width = 4;			// fixed
	nop = np;

    ft_dim = recdim * nop;	// 256 * 2
	kern_tab_len = 256;
    kern_step = kern_tab_len / kern_width;		// 256 / 16

// calc grid_kernel, grid_recdim
	[self makeGridKernel];			// 1D (forward)
	[self makeGridInverseKernel];   // 2D (inverse)

// iterative density correction
	if (corr) {
		[self densityCorrection2D];
	}

	[self makeGridTab];

	return self;
}

- (void)updateWeight:(RecImage *)newTraj
{
	int		i, n;
	float	*den;

	traj = newTraj;

// re-initialize density
	n = [traj dataLength];
	den = [traj data] + n * 2;
	for (i = 0; i < n; i++) {
		if (den[i] != 0) {
			den[i] = 1.0;
		}
	}
	[self densityCorrection2D];
	[self makeGridTab];
}

- (void)dealloc
{
    [self freeGridTab];
}

- (void)freeGridTab
{
	if (kern_tab) {
        free(kern_tab);
        kern_tab = NULL;
    }
	if (grid_tab) {
		free(grid_tab);
		grid_tab = NULL;
	}
	if (grid_ix_tab) {
		free(grid_ix_tab);
		grid_ix_tab = NULL;
	}
}

- (void)setMode:(int)grid_mode
{
    mode = grid_mode;
}

- (void)setMask:(BOOL)maskOn
{
	mask = maskOn;
}

- (void)setDumpRaw:(BOOL)rawOn
{
	dumpRaw = rawOn;
}

- (void)setNop:(int)np
{
	nop = np;
}

- (int)nop
{
    return nop;
}

- (int)ftDim
{
    return ft_dim;
}

- (int)kernTabLen
{
    return kern_tab_len;
}

- (float *)kernTab
{
    return kern_tab;
}

- (RecImage *)traj
{
	return traj;
}

- (int)kernWidth
{
	return kern_width;
}

- (void)grid2d:(RecImage *)dat to:(RecImage *)img
{
	switch (mode) {
	case REC_REF :	// 0: ref
	default :
		[self grid2d_ref:dat to:img];
		break;
	case REC_OP :	// 1: NSOperation
		if ([img dim] > 2) {
			[self grid2d_op:dat to:img];
		} else {
			[self grid2d_ref:dat to:img];
		}
		break;
	case REC_CL :	// OpenCL, not implemented yet
		[self grid2d_op:dat to:img];
		break;
	}
}

- (RecImage *)createTmp
{
	RecLoop			*xLoop = [RecLoop loopWithName:nil dataLength:ft_dim];
	RecLoop			*yLoop = [RecLoop loopWithName:nil dataLength:ft_dim];
    RecImage        *img = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:yLoop, xLoop, nil];
    return img;
}

- (void)grid2d_ref:(RecImage *)dat to:(RecImage *)img
{
    RecImage        *grid_tmp = [self createTmp];
	RecLoop			*kx_lp = [grid_tmp xLoop];
    RecLoop         *ky_lp = [grid_tmp yLoop];
	RecLoopControl	*srcLc, *dstLc;
	int				i, n;

    @autoreleasepool {
		[inverse_kernel copyLoopsOf:img]; //##
		[grid_tmp copyLoopsOf:img];	//##
        srcLc = [dat control];
        dstLc = [img control];
        [srcLc rewind];
        [dstLc rewind];
        [srcLc deactivateXY];
        [dstLc deactivateXY];
        n = [dstLc loopLength];
        for (i = 0; i < n; i++) {
        // grid1 (2n)
            [grid_tmp clear];
			[self grid1Data:dat withControl:srcLc to:grid_tmp]; // to grid_tmp
			if (dumpRaw) {
				[grid_tmp saveAsKOImage:@"IMG_grid_raw.img"];
			}
        // fft (2n), for single image FT, OP is slower
            [grid_tmp fft1d_ref:kx_lp direction:REC_FORWARD];
            [grid_tmp fft1d_ref:ky_lp direction:REC_FORWARD];
//[grid_tmp saveAsKOImage:@"../test_img/test3_grid1f.img"];
        // copy back to orig
			[self grid2WithControl:dstLc from:grid_tmp to:img];
            [srcLc increment];
            [dstLc increment];
        }
    }
}

- (void)grid2d_op:(RecImage *)dat to:(RecImage *)img
{
	int					i, n;
	RecLoopControl		*srcLc, *dstLc;
// NSOperation
	NSArray				*srcSub, *dstSub;
	NSOperationQueue	*queue = [[NSOperationQueue alloc] init];
	RecGridding2dOp		*op;

    @autoreleasepool {
        [queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];

    // loop control
        srcLc = [dat control];
        dstLc = [img control];
        [srcLc rewind];
        [dstLc rewind];
        [srcLc deactivateXY];
        [dstLc deactivateXY];
        srcSub = [srcLc subControls];
        dstSub = [dstLc subControls];
        n = (int)[srcSub count];
        for (i = 0; i < n; i++) {
            srcLc = [srcSub objectAtIndex:i];
            dstLc = [dstSub objectAtIndex:i];
            op = [RecGridding2dOp opWithSrc:dat dst:img srcLc:srcLc dstLc:dstLc gridder:self];
			if (i == n/2) {
				[op setDumpRaw:dumpRaw];
			}
            [queue addOperation:op];
        }
        [queue waitUntilAllOperationsAreFinished];
    }
}

- (void)grid1Data:(RecImage *)dat withControl:(RecLoopControl *)lc to:(RecImage *)dst
{
// grid_tmp
	float			*grid_data;
	float			*pp, *qq;		// image ptr
	int				tmpDataLength;
	int				x0, y0;
	float			*re, *im;		// k-space data ptr
	float			retmp, imtmp;
	int				i, j, ix;

	grid_data = [dst data];
	tmpDataLength = [dst dataLength];

	re = [dat currentDataWithControl:lc];
	im = re + [dat dataLength];

	for (i = 0; i < grid_tab_len; i++) {
        x0 = grid_tab[i].x0; // upper-left corner
        y0 = grid_tab[i].y0;
        if (x0 < 0) continue;   // out-of-bounds flag

		pp = grid_data + y0 * ft_dim + x0;
		qq = pp + tmpDataLength;
		retmp = re[i];
		imtmp = im[i];

		for (j = 0; j < 16; j++) {
			ix = grid_ix_tab[j];
			pp[ix] += retmp * grid_tab[i].wt[j];
			qq[ix] += imtmp * grid_tab[i].wt[j];
		}
	}
}

- (void)grid2WithControl:(RecLoopControl *)lc from:(RecImage *)grid_tmp to:(RecImage *)img
{
	float			*srcData = [grid_tmp data];			// dim * nop
	float			*dstData = [img currentDataWithControl:lc];		// dim
	float			*wt = [inverse_kernel data];	// dim
	int				srcDataLength, dstDataLength;
	int				srcDim;
	int				dstDim;
	int				i, j;
	int				ofs;
	int				src_r, dst_r;
	int				src_i, dst_i;

	srcDataLength = [grid_tmp dataLength];
    dstDataLength = [img dataLength];
	srcDim = [[grid_tmp xLoop] dataLength];
	dstDim = [[img xLoop] dataLength];
	ofs = (srcDim - dstDim) / 2;

	for (i = 0; i < dstDim; i++) {
		src_r = (i + ofs) * srcDim + ofs;
		src_i = src_r + srcDataLength;
		dst_r = i * dstDim;
		dst_i = dst_r + dstDataLength;
		for (j = 0; j < dstDim; j++, src_r++, dst_r++, src_i++, dst_i++) {
			dstData[dst_r] = srcData[src_r]	* wt[dst_r];
			dstData[dst_i] = srcData[src_i] * wt[dst_r];
		}
	}
}

// === low level methods

#import "timer_macros.h"

void test_tab(RecWtTab *tab, RecWtTab *tab_ref)
{	// compare tab / tab_ref
	int			ii, jj;
	int			n;
	RecWtEntry	et, et_ref;
	int			ne;

	n = tab->tab_len;
	if (n != tab_ref->tab_len) {
		printf("tab_len not equal\n");
		exit(0);
	}
	for (ii = 0; ii < n; ii++) {
		ne = tab->nent[ii];
		if (ne != tab_ref->nent[ii]) {
			printf("nent %d not equal\n", ii);
			exit(0);
		}
		et = tab->buf[ii];
		et_ref = tab_ref->buf[ii];
		for (jj = 0; jj < ne; jj++) {
			if (et.ix != et_ref.ix) {
				printf("ix %d not equal\n", ii);
				exit(0);
			}
			if (et.w != et_ref.w) {
				printf("w %d not equal\n", ii);
				exit(0);
			}
		}
	}
	printf("end of tab\n");
}

// view selection
// self is gridder
- (void)densityCorrection2D		// full 2D version
{
	RecWtTab	*tab;
	RecImage	*tab_i, *tab_o;
	float		*tmp_i, *tmp_o;	// density buffer
	float		*den = [traj data] + [traj dataLength] * 2;	// in:reject flag, out:final weight
	float		*wt = den + [traj dataLength];
	int			iter, i, max_iter = 1000;
	float		mn, mx, er, prev_er = 2.0;
	int			tabLen, xDim,yDim;

//TIMER_ST
//	tab = [self makeWtTab2D];
	tab = [self makeWtTabOp];

//TIMER_END("tab");

	tabLen = tab->tab_len;
	xDim = [traj xDim];
	yDim = [traj yDim];
printf("x/y/len = %d/%d/%d\n", xDim, yDim, tabLen);
	tab_i = [RecImage imageOfType:RECIMAGE_REAL xDim:xDim yDim:yDim];
	tab_o = [RecImage imageOfType:RECIMAGE_REAL xDim:xDim yDim:yDim];
	tmp_i = [tab_i data];
	tmp_o = [tab_o data];
	for (i = 0; i < tabLen; i++) {
		if (den[i] == 0) {
			tmp_i[i] = 0;
		} else {
			tmp_i[i] = 1.0;
			tmp_i[i] *= wt[i];
		}
	}

// ### first iteration
	prev_er = 2.0;
	for (iter = 0; iter < max_iter; iter++) {
		[self gridToTraj:tab in:tmp_i out:tmp_o];
		for (i = 0; i < tabLen; i++) {	// tab index == traj index
			if (tmp_o[i] != 0) {
				tmp_i[i] /= tmp_o[i];
			}
		//	tmp_i[i] *= wt[i];	// ######
		}
		mx = 0.0; mn = 2.0;
		for (i = 0; i < tabLen; i++) {
			if (mx < tmp_o[i]) mx = tmp_o[i];
			if (tmp_o[i] > 0 && mn > tmp_o[i]) mn = tmp_o[i];
		}
		er = (mx - mn) / mx;
		if (er < 1.0e-2) break;
		if (er > prev_er) break;
		prev_er = er;
	}
	printf("gridding density correction: max diff:%8.4f (iter = %d)\n", er, iter);
	printf("min = %f, max = %f\n", mn, mx);

	// write result
	for (i = 0; i < tabLen; i++) {
		if (den[i] != 0) {
			den[i] = tmp_i[i];
		} // else den[0] = 0
	}

	[self freeWtTab:tab];
}

// view selection ### mem access
- (RecWtTab *)makeWtTabFromIndex:(int)st length:(int)len
{
	RecWtTab	*tab;
	int			trajLen = [traj dataLength];
	int			k;
	int			xDim = [traj xDim];
	int			i, ix;
	float		*kx = [traj data];
	float		*ky = kx + trajLen;
	float		*den = ky + trajLen;	// used as flag to exclude data
//	float		*wt = den + trajLen;
	int			cur_pos, nentry;
	int			buf_len = 1024;
	float		x0, y0, d;
	float		xd, yd;
	float		kern_d = kern_width / 2.0;
	float		kd = kern_d / xDim;	

	tab = (RecWtTab *)malloc(sizeof(RecWtTab));
	tab->buf = (RecWtEntry *)malloc(sizeof(RecWtEntry) * buf_len);	// initial buf size
	tab->tab_len = len;
	tab->p = (RecWtEntry **)malloc(sizeof(RecWtEntry *) * len);
	tab->nent = (int *)malloc(sizeof(int) * len);

	cur_pos = 0;
	ix = st;
	for (k = 0; k < len; k++, ix++) {	// len: # of tab entries per proc (== trajLen for single proc)
		nentry = 0;
		x0 = kx[ix];
		y0 = ky[ix];
	//	if (den[ix] == 0) continue;	// ### chk
		for (i = 0; i < trajLen; i++) {
			// reject
		//	if (den[i] == 0) continue;	// ### chk
			// fast square limits
			xd = kx[i] - x0;
			if (xd > kd) continue;
			if (xd < -kd) continue;
			yd = ky[i] - y0;
			if (yd > kd) continue;
			if (yd < -kd) continue;
			// calc distance (slower)
			d = xd * xd + yd * yd;
			d = sqrt(d) * xDim;
			// calc weight
			if (d < kern_d) {
				if (den[ix] == 0 || den[i] == 0) {
					d = 0;
				} else {
					d = kern_tab[(int)(d * kern_tab_len / kern_d)];
				}
			// add entry
				tab->buf[cur_pos].ix = i;
				tab->buf[cur_pos].w = d;
			// adjust buffer
				cur_pos++;
				nentry++;
				if (cur_pos >= buf_len) {
					buf_len *= 2;
					tab->buf = (RecWtEntry *)reallocf(tab->buf, sizeof(RecWtEntry) * buf_len);
				}
			}
		}
		tab->nent[k] = nentry;
	}
	// pointer array
	cur_pos = 0;
	for (k = 0; k < len; k++) {
		tab->p[k] = tab->buf + cur_pos;
		cur_pos += tab->nent[k];
	}
	tab->total_len = cur_pos;

	return tab;
}

// ref:	16.412929 (sec) tab
// rect: 6.763551 (sec) tab
// op:	 1.054568 (sec) tab	
// tabLen = 51200
// bufLen = 1768616

- (RecWtTab *)makeWtTab2D
{
	return [self makeWtTabFromIndex:0 length:[traj dataLength]];
}

#define	NPROC	12 //12

// view selection ### mem access
- (RecWtTab *)makeWtTabOp
{
	NSOperationQueue	*queue = [[NSOperationQueue alloc] init];
	RecMakeWtTabOp		*op;
	RecWtTab			*tbP[NPROC], *tb, *tab;
	int					i, j, nproc;
	int					st, len, len1;
	int					tabLen, bufLen;
	int					bufIx, tbIx;

    @autoreleasepool {
    //    [queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
        [queue setMaxConcurrentOperationCount:NPROC];

		nproc = NPROC;
		tabLen = [traj dataLength];
		len = tabLen / nproc;				// nominal length per proc
		len1 = tabLen - len * (nproc - 1);	// length of last proc
        for (i = 0; i < nproc; i++) {	// nproc
			st = i * len;
			if (i == nproc-1) len = len1;
            op = [RecMakeWtTabOp opWithGridder:self tab:&tbP[i] start:st length:len];
            [queue addOperation:op];
        }
        [queue waitUntilAllOperationsAreFinished];
		tab = (RecWtTab *)malloc(sizeof(RecWtTab));
		// count total number of entries
		bufLen = 0;
		for (i = 0; i < nproc; i++) {	// nproc
			tb = tbP[i];
			len = 0;	// # of points in each tab
			for (j = 0; j < tb->tab_len; j++) {
				len += tb->nent[j];
			}
			bufLen += len;	// total # of points
		}
		// create new tab
		tab->buf = (RecWtEntry *)malloc(sizeof(RecWtEntry) * bufLen);
		tab->tab_len = tabLen;
		tab->total_len = bufLen;
		tab->p = (RecWtEntry **)malloc(sizeof(RecWtEntry *) * tabLen);
		tab->nent = (int *)malloc(sizeof(int) * tabLen);

		// copy data
		bufIx = tbIx = 0;
		for (i = 0; i < nproc; i++) {	// for each proc
			tb = tbP[i];
			for (j = 0; j < tb->tab_len; j++, tbIx++) {
				tab->nent[tbIx] = tb->nent[j];	// ok
			}
			for (j = 0; j < tb->total_len; j++, bufIx++) {		// #### chk
				tab->buf[bufIx] = tb->buf[j];
			}
		}
		// make ptr array
		bufIx = 0;
		for (i = 0; i < tab->tab_len; i++) {
			tab->p[i] = tab->buf + bufIx;
			bufIx += tab->nent[i];
		}
		for (i = 0; i < nproc; i++) {
			[self freeWtTab:tbP[i]];
		}
	}
	return tab;
}

#undef NPROC

- (void)freeWtTab:(RecWtTab *)tab
{
	if (tab == NULL) return;
	if (tab->buf)	free(tab->buf);
	if (tab->p)		free(tab->p);
	if (tab->nent)	free(tab->nent);
	free(tab);
}

// ### index into buf == index into tab !!!!
- (void)gridToTraj:(RecWtTab *)tab in:(float *)inBuf out:(float *)outBuf
{
	int			i, j, n = tab->tab_len;
	RecWtEntry	*en;

	for (i = 0; i < n; i++) {
		outBuf[i] = 0;
		en = tab->p[i];
		for (j = 0; j < tab->nent[i]; j++) {
			outBuf[i] += inBuf[en[j].ix] * en[j].w;
		}
	}
}

- (void)makeGridTab
{
	int         i, j, k, ix;
    int         nk2;
	int			kLength = [traj dataLength];
	float		*kx = [traj data];
	float		*ky = kx + kLength;
	float		*den = ky + kLength;
	int			kx0, ky0;		// upper left corner
	float		kxf, kyf;		// sample point
	float		kxtmp, kytmp;
	float		dist;
	RecGridTab	*tab;

	// make ix tab ... maybe not necessary
	grid_ix_tab = (int *)malloc(sizeof(int) * kern_width * kern_width);
	for (i = ix = 0; i < kern_width; i++) {
		for (j = 0; j < kern_width; j++, ix++) {
			grid_ix_tab[ix] = i * ft_dim + j;
		}
	}
	// make weight tab
	nk2 = kern_width / 2;	// index range
    tab = (RecGridTab *)malloc(sizeof(RecGridTab) * kLength);
	for (k = 0; k < kLength; k++) {
		// upper left corner
		kxtmp = kx[k] * nop * recdim;	// [-224 .. 224]
		kytmp = ky[k] * nop * recdim;
		kx0 = ceil((double)kxtmp) + ft_dim/2 - nk2;
		ky0 = ceil((double)kytmp) + ft_dim/2 - nk2;
		// sample point (in raw data cood)
		kxf = kx[k] * nop * recdim + ft_dim/2;
		kyf = ky[k] * nop * recdim + ft_dim/2;

		// upper left corner
		if (kx0 < 0 || kx0 + kern_width > ft_dim) {
			tab[k].x0 = -1;   // flag
            tab[k].y0 = -1;
		} else {
			tab[k].x0 = kx0;
		}
		if (ky0 < 0 || ky0 + kern_width > ft_dim) {
			tab[k].x0 = -1;	// flag
            tab[k].y0 = -1;
		} else {
			tab[k].y0 = ky0;
		}
		// wt tab
		for (i = 0; i < kern_width; i++) {
			kytmp = ky0 + i;
			for (j = 0; j < kern_width; j++) {
				kxtmp = kx0 + j;
				// calc dist
				dist = (kxtmp - kxf) * (kxtmp - kxf) + (kytmp - kyf) * (kytmp - kyf);
				dist = sqrt(dist);
				// kern tab
				ix = (int)(dist * kern_tab_len / 2.0);
				if (ix >= kern_tab_len) ix = kern_tab_len - 1;
				tab[k].wt[i*kern_width + j] = kern_tab[ix] * den[k];
			}
		}
	}
	grid_tab_len = kLength;
	grid_tab = tab;
}

// 2-sided table
- (void)makeGridKernel
{
	float			*kern;		// 1D
	int				i;
	float			a0, u; // kk;

// two sided tab
	kern = (float *)malloc((kern_tab_len + 1) * sizeof(float));	// intermediate 1D tab
    kern[kern_tab_len] = 0;                      // safety margin... this is necessary
	kern_b = GRID_ALPHA * M_PI;
	a0 = besseli0(kern_b);
	for (i = 0; i < kern_tab_len; i++) {	// tab len different
		u = (float)i / (kern_tab_len - 1);		// x = [0 .. 1]
		kern[i] = besseli0(kern_b * sqrt(1.0 - u * u)) / a0;
	}
	kern_tab = kern;
}

- (void)makeGridInverseKernel
{
	float			*kern;		// 1D
	RecImage		*kernImage;	// 2D
	int				ofs;
	int				i, j, dim2 = recdim/2;
	float			rx, ry, r, x;
	float			a0, kk;
	float			*p;
	int				rowSize;
	RecLoop			*xLoop = [RecLoop loopWithName:nil dataLength:recdim];
	RecLoop			*yLoop = [RecLoop loopWithName:nil dataLength:recdim];

// inverse kernel
// make 1D tab first
	kern = (float *)malloc(ft_dim * sizeof(float));	// intermediate 1D tab
	kern_b = GRID_ALPHA * M_PI;
	a0 = sinh(kern_b) / kern_b;
	for (i = 0; i < ft_dim; i++) {
		x = (float)i * 4 / (ft_dim - 1);
		kk = GRID_ALPHA * GRID_ALPHA - x * x;
		if (kk == 0) {
			kern[i] = 1.0 / a0;
		} else
		if (kk > 0) {
			kk = M_PI * sqrt(kk);
			kern[i] = sinh(kk) / kk / a0;
		} else {
			kk = M_PI * sqrt(-kk);
			kern[i] = sin(kk) / kk / a0;
		}
	}

// make 2D
	kernImage = [RecImage imageOfType:RECIMAGE_REAL withLoops:yLoop, xLoop, nil];
	[kernImage setName:@"kernImage"];
	p = [kernImage data];
	rowSize = [xLoop dataLength];
	ofs = (ft_dim - recdim) / 2;
	for (i = 0; i < recdim; i++) {
		ry = (i - dim2) * (i - dim2);
		for (j = 0; j < recdim; j++) {
			rx = (j - dim2) * (j - dim2);
			r = sqrt(rx + ry);
			if (mask && r >= dim2) {
				p[j] = 0;
			} else {
				p[j] = 1.0 / kern[(int)r];
			}
		}
		p += rowSize;
	}

	free(kern);
	inverse_kernel = kernImage;
//	[kernImage saveAsKOImage:@"../test_img/psf_inv.img"];
}

- (void)dumpKernel		// kern_tab_len (1-sided)
{
	int		i;
	for (i = 0; i < kern_tab_len; i++) {
		printf("%d %16.12f\n", i, kern_tab[i]);
	}
}

- (RecImage *)gridWeight	// 3rd plane of ktraj
{
	RecImage	*wt;

	wt = [traj copy];
	[wt takePlaneAtIndex:2];
	return wt;
}

@end

// =========== gridding ==================
@implementation RecGridding2dOp

+ (id)opWithSrc:(RecImage *)src dst:(RecImage *)dst
	srcLc:(RecLoopControl *)srcLc dstLc:(RecLoopControl *)dstLc gridder:(RecGridder *)gp;
{
	RecGridding2dOp		*op = [[RecGridding2dOp alloc] init];
	return [op initWithSrc:src dst:dst srcLc:srcLc dstLc:dstLc gridder:gp];
}

- (id)initWithSrc:(RecImage *)src dst:(RecImage *)dst
	srcLc:(RecLoopControl *)sLc dstLc:(RecLoopControl *)dLc gridder:(RecGridder *)gr
{
	srcImage = src;
	dstImage = dst;
	srcLc = sLc;
	dstLc = dLc;
    grid = gr;

	grid_tmp = [gr createTmp];

	return self;
}

- (void)setDumpRaw:(BOOL)rawOn
{
	dumpRaw = rawOn;
}

- (void)main
{
	RecLoop		*xLoop = [grid_tmp xLoop];
	RecLoop		*yLoop = [grid_tmp yLoop];
	int			i, n;

	n = [srcLc loopLength];
	for (i = 0; i < n; i++) {
	// grid1 (2n)
		[grid_tmp clear];
		[grid grid1Data:srcImage withControl:srcLc to:grid_tmp];
		if (dumpRaw) {
			if (i == n/2) {
				[grid_tmp saveAsKOImage:@"IMG_grid_raw.img"];
			}
		}
	// fft (2n), for single image FT, OP is slower
		[grid_tmp fft1d_ref:xLoop direction:REC_FORWARD];
		[grid_tmp fft1d_ref:yLoop direction:REC_FORWARD];
	// copy back to orig
		[grid grid2WithControl:dstLc from:grid_tmp to:dstImage];
		[srcLc increment];
		[dstLc increment];
	}
}

@end

// ======== gridding density correction ======
@implementation RecMakeWtTabOp

+ (id)opWithGridder:(RecGridder *)gr tab:(RecWtTab **)tb start:(int)st length:(int)len
{
    return [[RecMakeWtTabOp alloc] initWithGridder:gr tab:tb start:st length:len];
}

- (id)initWithGridder:(RecGridder *)gr tab:(RecWtTab **)tb start:(int)st length:(int)len
{
    self = [super init];
    if (!self) return nil;
    grid = gr;
	tabP = tb;
	start = st;
	length = len;
    return self;
}

- (void)main
{
	*tabP = [grid makeWtTabFromIndex:start length:length];
}

@end



