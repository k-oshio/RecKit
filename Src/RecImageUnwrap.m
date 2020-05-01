//
//	RecImageUnwrap
//
//	--- plan ---
//

#import "RecImage.h"
#import "Rec2DRef.h"
#import "RecLoop.h"
#import "RecLoopControl.h"
#import "RecResampler.h"
#import "RecUtil.h"

// lists
typedef struct blk_ent {
	int		x0;			// UL corner
	int		y0;			// UL corner
	int		siz;		// square blk
	int		area;		// number of non-zero pixels
	float	phs_sd;		// reliability
	int		flg;		// merge flag
} blk_ent;
blk_ent		*blklist;
int			len_blklist_buf;
int			len_blklist;

typedef struct bnd_ent {
	int		t1;		// index into blk list (t1 < t2)
	int		t2;		// index into blk list (t1 < t2)
	BOOL	hor;	// r or d
	int		st1;	// u-l index of boundary position within blk
	int		st2;	// u-l index of boundary position within blk
	int		siz;	// length of boundary
	int		area;	// area of non-zero pixels
	float	rel;	// reliability of boundary
} bnd_ent;
bnd_ent		*bndlist;
int			len_bndlist_buf;
int			len_bndlist;

void
add_blk(blk_ent ent)
{
	if (len_blklist >= len_blklist_buf) {
		len_blklist_buf *= 2;
		blklist = (blk_ent *)realloc(blklist, sizeof(blk_ent) * len_blklist_buf);
	}
	blklist[len_blklist++] = ent;	// copy
}

void
add_bnd(bnd_ent ent)
{
	if (len_bndlist >= len_bndlist_buf) {
		len_bndlist_buf *= 2;
		bndlist = (bnd_ent *)realloc(bndlist, sizeof(bnd_ent) * len_bndlist_buf);
	}
	bndlist[len_bndlist++] = ent;	// copy
}

void
init_lists(int initial_len)
{
	blklist = (blk_ent *)malloc(sizeof(blk_ent) * initial_len);
	bndlist = (bnd_ent *)malloc(sizeof(bnd_ent) * initial_len);
	len_blklist_buf = len_bndlist_buf = initial_len;
	len_blklist = len_bndlist = 0;
}

@implementation RecImage (Unwrap)


- (void)modPI
{
	int		i, n = [self dataLength];
	float	*p = [self data];

	for (i = 0; i < n; i++) {
		p[i] = M_PI * round(p[i] / M_PI);
	}
}

- (void)mod2PI
{
	int		i, n = [self dataLength];
	float	*p = [self data];

	for (i = 0; i < n; i++) {
		p[i] = M_PI * 2 * round(p[i] / (M_PI * 2));
	}
}

- (void)mod2PI:(float)ofs
{
	int		i, n = [self dataLength];
	float	*p = [self data];

	for (i = 0; i < n; i++) {
		if (p[i] > ofs) {
			p[i] = M_PI * 2;
		} else
		if (p[i] < -ofs) {
			p[i] = -M_PI * 2;
		} else {
			p[i] = 0;
		}
	//	p[i] = M_PI * 2 * round(p[i] / (M_PI * 2));
	}
}

- (void)unwrap0d
{
	int		i, n = [self dataLength];
	float	*p = [self data];

	for (i = 0; i < n; i++) {
		p[i] -= M_PI * 2 * round(p[i] / (M_PI * 2));
	}
}

- (void)unwrap1dForLoop:(RecLoop *)lp	// 1D phase unwrap (uses Rec_unwrap_1d)
{
    void    (^proc)(float *p, int skip, int len);
 
    proc = ^void(float *p, int len, int skip) {
        Rec_unwrap_1d(p, len, skip);
    };

    [self apply1dProc:proc forLoop:lp];
}

// input/output is phase image (real)
// assumes Po2 dim for laplace2d
// Schofield paper
- (RecImage *)unwrapEst2d	// initial est using Laplacian
{
	RecImage	*est;
	RecImage	*cs, *sn, *ph1, *ph2;

	sn = [self copy];
	[sn thToSin];
	cs = [self copy];
	[cs thToCos];

	ph1 = [sn copy];
	[ph1 laplace2d:REC_FORWARD];
	[ph1 multByImage:cs];

	ph2 = [cs copy];
	[ph2 laplace2d:REC_FORWARD];
	[ph2 multByImage:sn];

	est = [ph1 copy];
	[est subImage:ph2];
	[est laplace2d:REC_INVERSE];

	return est;
}

- (RecImage *)difMod:(RecImage *)ref
{
	RecImage	*dif;
	int			i, n;
	float		*p;

	dif = [self copy];
	[dif subImage:ref];
	p = [dif data];
	n = [dif dataLength];
	for (i = 0; i < n; i++) {
		p[i] = fmod(p[i], 2*M_PI);
	}
	return dif;
}

// input: complex, output: mg/unwrapped phase
// Laplacian based (Shofield)
// (discrete version is better)
- (RecImage *)unwrap2d_lap
{
	RecImage	*img, *iofs, *phs0, *phs1, *phs2, *est0, *est1, *est2, *est3;
	RecImage	*pdif;
	RecImage	*ph1, *ph3, *pnp;
	RecLoop		*xLp, *yLp;
	NSString	*path;
	int			i, n;
	float		mx, sd;
	float		*p, ofs;

//	mask = [self copy];
//	[mask magnitude];
//	[mask thresAt:0.1];

	img = [self copy];

//	[img zeroFill:[img xLoop] to:256];
//	[img zeroFill:[img yLoop] to:256];

img = [img sliceAtIndex:32];
	mx = [img maxVal];
	sd = [img noiseSigma];
printf("mx = %f, sd = %f\n", mx, sd);

	phs0 = [img copy];
	[phs0 phase];
//	est0 = [phs0 unwrapEst2d_disc];
	est0 = [phs0 unwrapEst2d];
[est0 saveAsKOImage:@"IMG_34_est0.img"];
	pdif = [est0 difMod:phs0];
[pdif saveAsKOImage:@"IMG_34_pdif0.img"];

	iofs = [img copy];
	ofs = sd * mx * 3.0; //3.0;
//	[iofs addReal:ofs];
	[iofs addImag:ofs];

[iofs saveAsKOImage:@"IMG_34_ofs.img"];
	phs1 = [iofs copy];

	[phs1 phase];
	
mx = [phs1 meanVal];
printf("mean phase = %f\n", mx);
[phs1 addConst:-mx + 0.5];
[phs1 fMod:M_PI * 2];
[phs1 saveAsKOImage:@"IMG_34_phs1_0.img"];

//exit(0);

//	est1 = [phs1 unwrapEst2d_disc];
	est1 = [phs1 unwrapEst2d];
[est1 saveAsKOImage:@"IMG_34_est1.img"];
	pdif = [est1 difMod:phs0];
[pdif saveAsKOImage:@"IMG_34_pdif1.img"];

	pdif = [phs1 copy];
	[pdif subImage:phs0];
	// mod
	p = [pdif data];
	n = [pdif dataLength];
	for (i = 0; i < n; i++) {
		if (p[i] > M_PI) {
			p[i] -= 2 * M_PI;
		} else
		if (p[i] < -M_PI) {
			p[i] += 2 * M_PI;
		}
	}
[pdif saveAsKOImage:@"IMG_34_pdif.img"];

	est2 = [est1 copy];
	[est2 addImage:pdif];	
[est2 saveAsKOImage:@"IMG_34_est2.img"];
	est3 = [phs0 copy];
	[est3 subImage:est1];
[est3 saveAsKOImage:@"IMG_34_dif1.img"];

	est3 = [phs0 copy];
	[est3 subImage:est2];
[est3 saveAsKOImage:@"IMG_34_dif0.img"];

	








exit(0);

	return ph1;
}

// private (FUDGE, ISMRM 2016, p27)
- (RecImage *)dif2ForLoop:(RecLoop *)lp
{
	RecImage	*dxp, *dxm;
	RecImage	*sn, *cs;

// f[t+1]
	dxp = [self copy];
	[dxp shift1d:lp by:1];
	[dxp subImage:self];
	sn = [dxp copy];
	[sn thToSin];
	cs = [dxp copy];
	[cs thToCos];
	[cs atan2:sn];
	dxp = [cs copy];
	
// f[t-1]
	dxm = [self copy];
	[dxm shift1d:lp by:-1];
	[dxm subImage:self];
	sn = [dxm copy];
	[sn thToSin];
	cs = [dxm copy];
	[cs thToCos];
	[cs atan2:sn];
	dxm = [cs copy];
	
	[dxp addImage:dxm];

	return dxp;
}

// input: phase, Po2 dim
- (RecImage *)unwrapEst2d_disc	// discrete laplacian (FUDGE, ISMRM 2016, p27)
{
	RecImage	*est;
	RecImage	*dx, *dy;
	int			nx, ny, nz;
	int			i, j, k;
	float		kk, *p;

//	[est laplace2d_disc];
	dx = [self dif2ForLoop:[self xLoop]];
	dy = [self dif2ForLoop:[self yLoop]];
	[dy addImage:dx];
	est = [dy copy];

// inverse DLT
	nx = [est xDim];
	ny = [est yDim];
	nz = [est zDim];

	[est dct2d];
	p = [est data];
	for (k = 0; k < nz; k++) {
		for (i = 0; i < ny; i++) {
			for (j = 0; j < nx; j++) {
				kk = (sqrt(i*i + j*j) + 1.0) / nx;
				p[((k * ny) + i) * nx + j] /= (2 * cos(M_PI * kk) - 2);
			}
		}
	}
	[est dct2d];

	[est multByConst:1.0];	// scale is OK (1.0)
//	[est multByConst:M_PI/2];

	return est;
}

// current version (not perfect, but works)
// input is complex
// returns phase image (real)
// multi-slice
- (RecImage *)unwrap2d
{
	RecImage	*cpx, *phs;		// single slice
	RecImage	*res;			// result, real, multi-slice
	int			i, nSlice = [self zDim];

	res = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
	for (i = 0; i < nSlice; i++) {
		cpx = [self sliceAtIndex:i];
	//	phs = [cpx unwrap2d_block];			// 2 (try LPF)
	//	phs = [cpx unwrap2d_block_2];		// 3
		phs = [cpx unwrap2d_block_rec];		// currently best, but with LPF. update rel etc according to block1
		[res copySlice:phs atIndex:i];
	}
	return res;
}

- (RecImage *)unwrap2d_fudge
{
	RecLoop		*xLp, *yLp;
	RecImage	*phs, *pnp;
	RecImage	*est;
	RecImage	*dif;	// dbg
	
	phs = [self copy];
	[phs phase];

	xLp = [phs xLoop];
	yLp = [phs yLoop];
	[phs zeroFillToPo2];	// for DCT & boundary condition for inv laplacian

	est = [phs unwrapEst2d_disc];

	pnp = [est copy];
	[pnp subImage:phs];
	dif = [pnp copy];
	[pnp mod2PI:M_PI];
	[dif laplace2dc:REC_FORWARD];
	[phs addImage:pnp];
	[phs replaceLoop:[phs xLoop] withLoop:xLp];
	[phs replaceLoop:[phs yLoop] withLoop:yLp];

	return phs;
}

// phase correction for phase-only image
- (void)apply2dx:(float)a1x y:(float)a1y phs:(float)a0
{
    void    (^proc)(float *p, int xDim, int yDim);

    proc = ^void(float *p, int xDim, int yDim) {
		int		i, j, ix;
		float	th;
		
		for (i = 0; i < yDim; i++) {
			for (j = 0; j < xDim; j++) {
				ix = i * xDim + j;
				th = ((float)i - yDim/2) / yDim * a1y + ((float)j - xDim/2) / xDim * a1x + a0;
				p[ix] += th;
			}
		}
    };
    [self apply2dProc:proc];
}

// unwrap block
RecImage *
unwrap_block(RecImage *blk, int ix)
{
	RecImage	*phs;
	float		a0, a1x, a1y;
	int			xDim, yDim;

	xDim = [blk xDim];
	yDim = [blk yDim];

	// linear phase correction
	a1x = [blk est1dForLoop:[blk xLoop]];
	a1y = [blk est1dForLoop:[blk yLoop]];
	a0  = [blk est0];
	[blk pcorr2dx:a1x y:a1y phs:a0];

	// chk range < +- M_PI/2
	// this is not good index ... consider mag / phase combination
	phs = [blk copy];
	[phs phase];

	// re-apply linear phase without wrap-around
	[phs apply2dx:a1x y:a1y phs:a0];
	
	return phs;
}

// unwrap block (recursive)
RecImage *
unwrap_block_rec(RecImage *blk, int x0, int y0)
{
	RecImage	*img = [blk copy];
	RecImage	*ctmp, *ptmp;
	RecImage	*subp;
	RecImage	*phs;
	int			siz = [blk xDim];
	int			siz2 = siz/2;
	float		a1x, a1y, a0;
	float		mn, mx, range;
	Rec2DRef	*ref, *pref;
	blk_ent		blk_ent;
	int			i, area;
	float		*p;
	float		sd;
	
	// ===== params  
	int			min_siz = 2;		// 2
	float		range_thres = 0.90; //; //0.95;

	blk_ent.x0 = x0;
	blk_ent.y0 = y0;
	blk_ent.siz = siz;

	// === (1)(OK) linear phase correction
	a1x = [img est1dForLoop:[img xLoop]];
	a1y = [img est1dForLoop:[img yLoop]];
	a0  = [img est0];
	[img pcorr2dx:a1x y:a1y phs:a0];

	phs = [img copy];
	[phs phase];

	mn = [phs minVal];
	mx = [phs maxVal];
	range = (mx - mn) / (2 * M_PI);

	// === (2) termination condition
	if (range < range_thres || siz <= min_siz) {
		// non-zero area
		area = 0;
		ctmp = [blk copy];
		[ctmp magnitude];
		p = [ctmp data];
		
		for (i = 0; i < siz * siz; i++) {
			if (p[i] != 0) {
				area++;
			}
		}
		blk_ent.area = area;
		
		// phase sd
		sd = 0;		
		for (i = 0; i < siz * siz; i++) {
			sd += p[i] * p[i];
		}
		sd /= (siz * siz);
		sd = sqrt(sd);
		blk_ent.phs_sd = sd;
		add_blk(blk_ent);

		[phs apply2dx:a1x y:a1y phs:a0];
		return phs;
	}

	// === (3)(OK) make 4 sub-images, and apply self for each
	img = [blk copy];
	subp = [RecImage imageOfType:RECIMAGE_REAL xDim:siz2 yDim:siz2 zDim:4];
	ref = [Rec2DRef refForImage:img];
	[ref setNx:siz2];
	[ref setNy:siz2];
	// TL
	[ref setX:0 y:0];
	ctmp = [ref makeImage];
	ptmp = unwrap_block_rec(ctmp, x0, y0);
	[subp copyXYLoopsOf:ptmp];
	[subp copySlice:ptmp atIndex:0];
	// TR
	[ref setX:siz2 y:0];
	ctmp = [ref makeImage];
	ptmp = unwrap_block_rec(ctmp, x0 + siz2, y0);
	[subp copyXYLoopsOf:ptmp];
	[subp copySlice:ptmp atIndex:1];
	// BR
	[ref setX:siz2 y:siz2];
	ctmp = [ref makeImage];
	ptmp = unwrap_block_rec(ctmp, x0 + siz2, y0 + siz2);
	[subp copyXYLoopsOf:ptmp];
	[subp copySlice:ptmp atIndex:2];
	// BL
	[ref setX:0 y:siz2];
	ctmp = [ref makeImage];
	ptmp = unwrap_block_rec(ctmp, x0, y0 + siz2);
	[subp copyXYLoopsOf:ptmp];
	[subp copySlice:ptmp atIndex:3];

	// === (5)(OK) copy back to phs
	pref = [Rec2DRef refForImage:phs];
	[pref setNx:siz2];
	[pref setNy:siz2];

	// TL
	[pref setX:0 y:0];
	ptmp = [subp sliceAtIndex:0];
	[pref copyImage:ptmp];
	// TR
	[pref setX:siz2 y:0];
	ptmp = [subp sliceAtIndex:1];
	[pref copyImage:ptmp];
	// BR
	[pref setX:siz2 y:siz2];
	ptmp = [subp sliceAtIndex:2];
	[pref copyImage:ptmp];
	// BL
	[pref setX:0 y:siz2];
	ptmp = [subp sliceAtIndex:3];
	[pref copyImage:ptmp];

	return phs;
}

void
merge_blocks(RecImage *phs, RecImage *mg)
{
	int			i, j, ix;
	int			xDim = [phs xDim];
	bnd_ent		bnd;
	float		*ph0, *mg0;
	int			(^compar)(const void *, const void *);
	int			*grp;
	int			curr_grp;

// === make boundary list
	for (i = 0; i < len_blklist; i++) {			// t1
		for (j = i + 1; j < len_blklist; j++) {	// t2
		
			// skip 0 blk
			if (blklist[i].area == 0 && blklist[j].area == 0) continue;

			// common to L-R and T-B
			bnd.t1 = i;
			bnd.t2 = j;
			bnd.siz = Rec_min(blklist[i].siz, blklist[j].siz);
			bnd.area = Rec_min(blklist[i].area, blklist[j].area);
			bnd.rel = 0; // * Rec_max(blklist[i].phs_sd, blklist[j].phs_sd);

			// L-R
			if (blklist[i].x0 + blklist[i].siz == blklist[j].x0) {
				if ((blklist[j].y0 >= blklist[i].y0) && (blklist[j].y0 < blklist[i].y0 + blklist[i].siz)) {
					bnd.hor = YES;
					if (blklist[i].siz < blklist[j].siz) {
						bnd.st1 = 0;
						bnd.st2 = blklist[i].y0 - blklist[j].y0;
					} else {
						bnd.st2 = 0;
						bnd.st1 = blklist[j].y0 - blklist[i].y0;
					}
					ix = blklist[j].y0 * xDim + blklist[j].x0 - 1;
					ph0 = [phs data] + ix;
					mg0 = [mg data] + ix;
					bnd.rel = rel_block_rec(ph0, xDim, bnd.siz, bnd.hor);
				//	bnd.rel = rel_block_rec_2(mg0, xDim, bnd.siz, bnd.hor);
	
					add_bnd(bnd);
				}
			}

			// T-B
			if (blklist[i].y0 + blklist[i].siz == blklist[j].y0) {
				if ((blklist[j].x0 >= blklist[i].x0) && (blklist[j].x0 < blklist[i].x0 + blklist[i].siz)) {
					bnd.hor = NO;
					if (blklist[i].siz < blklist[j].siz) {
						bnd.st1 = 0;
						bnd.st2 = blklist[i].x0 - blklist[j].x0;
					} else {
						bnd.st2 = 0;
						bnd.st1 = blklist[j].x0 - blklist[i].x0;
					}
					ix = (blklist[j].y0 - 1) * xDim + blklist[j].x0;
					ph0 = [phs data] + ix;
					mg0 = [mg data] + ix;
					bnd.rel = rel_block_rec(ph0, xDim, bnd.siz, bnd.hor);
				//	bnd.rel = rel_block_rec_2(mg0, xDim, bnd.siz, bnd.hor);

					add_bnd(bnd);
				}
			}
		}
	}

// === sort by reliability (and size)
	compar = ^int(const void *p1, const void *p2) {
		float rel1 = ((bnd_ent *)p1)->rel;
		float rel2 = ((bnd_ent *)p2)->rel;
	//	float sz1 = ((bnd_ent *)p1)->siz;
	//	float sz2 = ((bnd_ent *)p2)->siz;
		float sz1 = ((bnd_ent *)p1)->area;
		float sz2 = ((bnd_ent *)p2)->area;
		// ascending
		if (sz1 > sz2) {
			return -1;
		} else
		if (sz1 < sz2) {
			return 1;
		} else {
			if (rel1 < rel2) {
				return -1;
			} else 
			if (rel1 == rel2) {
				return 0;
			} else {
				return 1;
			}
		}
	};
	qsort_b(bndlist, len_bndlist, sizeof(bnd_ent), compar);

//	dump_blklist();
//	dump_bndlist();

// === reliability-based merge

	// init block flag
	for (i = 0; i < len_blklist; i++) {
		blklist[i].flg = 0;
	}
	for (i = 0; i < len_bndlist; i++) {
		blklist[bndlist[i].t1].flg = 1;
		blklist[bndlist[i].t2].flg = 1;
	}
	// init group flag
	grp = (int *)malloc(sizeof(int) * len_blklist / 2);
	for (i = 0; i < len_blklist/2; i++) {
		grp[i] = 0;
	}
	curr_grp = 2;	// groups: starts from 2

	// 
	for (i = 0; i < len_bndlist; i++) {
		float	*p = [phs data];
		float	*m = [mg data];
		int		xDim = [phs xDim];
		int		t1, t2;
		int		gr1, gr2;
		int		mode;
		int		r;
		float	rel_lim = 1.0;
		int		use_mag = 0;

		t1 = bndlist[i].t1;
		t2 = bndlist[i].t2;

		if (blklist[t1].flg == 0 || blklist[t2].flg == 0) continue;	// skip 0 tile

		if (blklist[t1].flg == 1 && blklist[t2].flg == 1) {			// neither belong to grp
			mode = 1;
			blklist[t1].flg = blklist[t2].flg = curr_grp;
			grp[curr_grp] += blklist[t1].siz * blklist[t1].siz;
			grp[curr_grp] += blklist[t2].siz * blklist[t2].siz;
			curr_grp++;
			// calc r (t1, t2)
			if (use_mag) {
				r = calc_r_rec_m(bndlist + i, p, m, xDim);	// not better
			} else {
				r = calc_r_rec(bndlist + i, p, xDim);
			}
			// add 2PI * r to t2
			if (bndlist[i].rel < rel_lim) {
				add_rpi_rec(p, xDim, t1, r);
			}
		} else
		if (blklist[t1].flg == 1 && blklist[t2].flg > 1) {		// only t2 belong to grp -> add t1 to t2 grp
			mode = 2;
			blklist[t1].flg = blklist[t2].flg;
			grp[blklist[t2].flg] += blklist[t1].siz * blklist[t1].siz;
			if (use_mag) {
				r = calc_r_rec_m(bndlist + i, p, m, xDim);	// not better
			} else {
				r = calc_r_rec(bndlist + i, p, xDim);
			}
			if (bndlist[i].rel < rel_lim) {
				add_rpi_rec(p, xDim, t1, r);
			}
		} else
		if (blklist[t1].flg > 1 && blklist[t2].flg == 1) {		// only t1 belong to grp -> add t2 to t1 grp
			mode = 3;
			blklist[t2].flg = blklist[t1].flg;
			grp[blklist[t1].flg] += blklist[t2].siz * blklist[t2].siz;
			if (use_mag) {
				r = calc_r_rec_m(bndlist + i, p, m, xDim);	// not better
			} else {
				r = calc_r_rec(bndlist + i, p, xDim);
			}
			if (bndlist[i].rel < rel_lim) {
				add_rpi_rec(p, xDim, t2, -r);
			}
		} else {										// both belong to grp
			mode = 4;
			if (use_mag) {
				r = calc_r_rec_m(bndlist + i, p, m, xDim);	// not better
			} else {
				r = calc_r_rec(bndlist + i, p, xDim);
			}
			gr1 = blklist[t1].flg;
			gr2 = blklist[t2].flg;
			if (grp[gr1] == grp[gr2]) {
				continue;		// to avoid loop
			} else
			if (grp[gr1] > grp[gr2]) {
				// merge t2 group to t1 group
				for (j = 0; j < len_blklist; j++) {
					if (blklist[j].flg == gr2) {
						blklist[j].flg = gr1;
						grp[gr1] += blklist[j].siz * blklist[j].siz;
						grp[gr2] -= blklist[j].siz * blklist[j].siz;
						if (bndlist[i].rel < rel_lim) {
							add_rpi_rec(p, xDim, j, -r);
						}
					}
				}
			} else {
				// merge t1 group to t2 group
				for (j = 0; j < len_blklist; j++) {
					if (blklist[j].flg == gr1) {
						blklist[j].flg = gr2;
						grp[gr1] -= blklist[j].siz * blklist[j].siz;
						grp[gr2] += blklist[j].siz * blklist[j].siz;
						if (bndlist[i].rel < rel_lim) {
							add_rpi_rec(p, xDim, j, r);
						}
					}
				}
			}
		}
	}

//for (i = 0; i < curr_grp; i++) { printf("%d %d\n", i, grp[i]); }

	free(grp);
}

// chk phase difference between blocks
// direct merge
void
shift_block(float *p, float *flg, int xDim, int yDim, int x, int y, int siz)
{
	int		i, j, ii, jj, n;
	int		ix;
	int		r;
	float	phs1, phs2, dif;

	// left
	dif = 0;
	n = 0;
	ix = y * siz + x;	// index into flg
	if (flg[ix] == 0) return;	// do nothing

//	flg[ix] = 2;
	if (x > 0 && flg[ix - 1] > 0) {
		n += siz;
		jj = x * siz;
		for (i = 0; i < siz; i++) {
			ii = y * siz + i;
			phs1 = p[ii * xDim + jj];
			phs2 = p[ii * xDim + jj - 1];
			dif += phs1 - phs2;
		}
	}
	// up
	if (y > 0 && flg[ix - siz] > 0) {
		n += siz;
		ii = y * siz;
		for (j = 0; j < siz; j++) {
			jj = x * siz + j;
			phs1 = p[ii * xDim + jj];
			phs2 = p[(ii - 1) * xDim + jj];
			dif += phs1 - phs2;
		}
	}
	
	if (n == 0) return;

	dif /= n;
	r = round(dif / 2.0 / M_PI);

	// add / sub 2PI * r for entire block
	if (r != 0) {
		dif = r * 2 * M_PI;
		for (i = 0; i < siz; i++) {
			ii = y * siz + i;
			for (j = 0; j < siz; j++) {
				jj = x * siz + j;
				p[ii * xDim + jj] -= dif;
			}
		}
	}
}

typedef struct {
	int		t1;
	int		t2;
	float	rel;
} rel_ent;

float
rel_block_r(float *p, int xDim, int yDim, int x, int y, int siz)
{
	float	rel, mn, var, phs1, phs2;
	int		ii, jj, i;

	mn = var = 0;
	for (i = 0; i < siz; i++) {
		ii = y * siz + i;
		jj = (x + 1) * siz;
		phs1 = p[ii * xDim + jj];
		phs2 = p[ii * xDim + jj - 1];
		var += (phs1 - phs2) * (phs1 - phs2);
		mn += (phs1 - phs2);
	}
	mn /= siz;
	var /= siz;
	var -= mn*mn;
	rel = sqrt(var) / (2 * M_PI);

	return rel;
}

float
rel_block_d(float *p, int xDim, int yDim, int x, int y, int siz)
{
	float	rel, mn, var, phs1, phs2;
	int		ii, jj, j;

	mn = var = 0;
	for (j = 0; j < siz; j++) {
		ii = (y + 1) * siz;
		jj = x * siz + j;
		phs1 = p[ii * xDim + jj];
		phs2 = p[(ii - 1) * xDim + jj];
		var += (phs1 - phs2) * (phs1 - phs2);
		mn += (phs1 - phs2);
	}
	mn /= siz;
	var /= siz;
	var -= mn*mn;
	rel = sqrt(var) / (2 * M_PI);

	return rel;
}

// phase diff
float
rel_block_r_2(RecImage *tile, int t1, int t2)
{
	float	rel, mn, var, phs1, phs2;
	float	*p1, *p2;
	int		siz = [tile xDim];
	int		i;

	p1 = [tile data] + siz * siz * t1;
	p2 = [tile data] + siz * siz * t2;
	mn = var = 0;
	for (i = 0; i < siz; i++) {
		phs1 = p1[i * siz + siz - 1];
		phs2 = p2[i * siz];
		var += (phs1 - phs2) * (phs1 - phs2);
		mn += (phs1 - phs2);
	}
	mn /= siz;
	var /= siz;
	var -= mn*mn;
	rel = sqrt(var) / (2 * M_PI);

	return rel;
}

// phase diff
float
rel_block_d_2(RecImage *tile, int t1, int t2)
{
	float	rel, mn, var, phs1, phs2;
	float	*p1, *p2;
	int		siz = [tile xDim];
	int		j;

	p1 = [tile data] + siz * siz * t1;
	p2 = [tile data] + siz * siz * t2;
	mn = var = 0;
	for (j = 0; j < siz; j++) {
		phs1 = p1[(siz - 1) * siz + j];
		phs2 = p2[j];
		var += (phs1 - phs2) * (phs1 - phs2);
		mn += (phs1 - phs2);
	}
	mn /= siz;
	var /= siz;
	var -= mn*mn;
	rel = sqrt(var) / (2 * M_PI);

	return rel;
}

// ##### mag based
float
rel_block_r_3(RecImage *tile, int t1)
{
	float	rel, mg1, mg2;
	float	*p, *q, mg;
	int		siz = [tile xDim];
	int		i, ix1, ix2;

	p = [tile data] + siz * siz * t1;
	q = p + [tile dataLength];
	mg = 0;
	for (i = 0; i < siz; i++) {
		ix1 = i * siz + siz - 1;
		ix2 = i * siz + siz - 2;
		mg1 = p[ix1]*p[ix1] + q[ix1]*q[ix1];
		mg2 = p[ix2]*p[ix2] + q[ix2]*q[ix2];
		mg += mg1 + mg2;
	}
	rel = 1.0 / sqrt(mg);

	return rel;
}

// ##### mag based
float
rel_block_d_3(RecImage *tile, int t1)
{
	float	rel, mg1, mg2;
	float	*p, *q, mg;
	int		siz = [tile xDim];
	int		i, ix1, ix2;

	p = [tile data] + siz * siz * t1;
	q = p + [tile dataLength];
	mg = 0;
	for (i = 0; i < siz; i++) {
		ix1 = (siz - 1) * siz + i;
		ix2 = (siz - 2) * siz + i;
		mg1 = p[ix1]*p[ix1] + q[ix1]*q[ix1];
		mg2 = p[ix2]*p[ix2] + q[ix2]*q[ix2];
		mg += mg1 + mg2;
	}
	rel = 1.0 / sqrt(mg);

	return rel;
}

// phs sd
float
rel_block_rec(float *p, int xDim, int siz, BOOL hor)
{
	float	rel, mn1, mn2, var, phs1, phs2, dif;
	int		i, st1, st2, skip;

	if (hor) {
		st1 = 0;
		st2 = 1;
		skip = xDim;
	} else {
		st1 = 0;
		st2 = xDim;
		skip = 1;
	}
	mn1 = mn2 = 0;
	for (i = 0; i < siz; i++) {
		mn1 += p[st1 + i * skip];
		mn2 += p[st2 + i * skip];
	}
	mn1 /= siz;
	mn2 /= siz;
	dif = round((mn1 - mn2) / (M_PI * 2));
	dif = fabs(dif);

	var = 0;
	for (i = 0; i < siz; i++) {
		phs1 = p[st1 + i * skip] - mn1;
		phs2 = p[st2 + i * skip] - mn2;
		var += (phs1 - phs2) * (phs1 - phs2);
	}
	var /= siz;
	var = sqrt(var) / (2 * M_PI);

	if (var <= 0) {
		rel = 1.0;
	} else {
		rel = var + dif * 0.0;	// 0.2
	}

	return rel;
}

// mg only
float
rel_block_rec_2(float *p, int xDim, int siz, BOOL hor)
{
	float	rel, mg1, mg2;
	int		i, st1, st2, skip;

	if (hor) {
		st1 = 0;
		st2 = 1;
		skip = xDim;
	} else {
		st1 = 0;
		st2 = xDim;
		skip = 1;
	}
	mg1 = mg2 = 0;
	for (i = 0; i < siz; i++) {
		mg1 += p[st1 + i * skip];
		mg2 += p[st2 + i * skip];
	}
	rel = Rec_min(mg1, mg2);

	return -rel;
}

// phase difference of t2 w.r.t. t1
int
calc_r(float *p, int xDim, int yDim, int t1, int t2, int siz)
{
	int		i, j, ii, jj, n;
	int		x, y;
	float	dif, phs1, phs2;
	int		r;

	n = xDim / siz;
	x = t1 % n;
	y = t1 / n;
	if ((t2 - t1) > 2) {	// vertical
		dif = 0;
		for (j = 0; j < siz; j++) {
			ii = (y + 1) * siz;
			jj = x * siz + j;
			phs1 = p[(ii - 1) * xDim + jj];
			phs2 = p[ii * xDim + jj];
			dif += phs2 - phs1;
		}
	} else {				// horizontal
		dif = 0;
		for (i = 0; i < siz; i++) {
			ii = y * siz + i;
			jj = (x + 1) * siz;
			phs1 = p[ii * xDim + jj - 1];
			phs2 = p[ii * xDim + jj];
			dif += phs2 - phs1;
		}
	}
	dif /= siz;
	r = round(dif / (2 * M_PI));

	return r;
}

// phase difference of t2 w.r.t. t1
int
calc_r_rec(bnd_ent *bnd, float *p, int xDim)
{
	int		i, j, ii, jj;
	float	dif, phs1, phs2;
	int		r;
	int		siz = bnd->siz;
	int		t1 = bnd->t1;
	int		t2 = bnd->t2;
	int		x, y;

	if (bnd->hor) {				// horizontal
		// x / y : start position in phs image
		x = blklist[t2].x0 - 1;
		y = blklist[t1].y0 + bnd->st1;

		dif = 0;
		for (i = 0; i < siz; i++) {
			phs1 = p[(y + i) * xDim + x];
			phs2 = p[(y + i) * xDim + x + 1];
			dif += phs2 - phs1;
		}
	} else {	// vertical
		// x / y : start position in phs image
		x = blklist[t1].x0 + bnd->st1;
		y = blklist[t2].y0 - 1;

		dif = 0;
		for (j = 0; j < siz; j++) {
			ii = (y + 1);
			jj = x + j;
			phs1 = p[y       * xDim + x + j];
			phs2 = p[(y + 1) * xDim + x + j];
			dif += phs2 - phs1;
		}
	}
	dif /= siz;
	r = round(dif / (2 * M_PI));

	return r;
}

// phase difference of t2 w.r.t. t1
int
calc_r_rec_m(bnd_ent *bnd, float *p, float *mg, int xDim)
{
	int		i, j;
	float	dif, phs1, phs2;
	float	wt, mg1, mg2;
	int		r;
	int		siz = bnd->siz;
	int		t1 = bnd->t1;
	int		t2 = bnd->t2;
	int		x, y, ix1, ix2;

	dif = wt = 0;
	if (bnd->hor) {				// horizontal
		// x / y : start position in phs image
		x = blklist[t2].x0 - 1;
		y = blklist[t1].y0 + bnd->st1;

		for (i = 0; i < siz; i++) {
			ix1 = (y + i) * xDim + x;
			ix2 = (y + i) * xDim + x + 1;
			phs1 = p[ix1];
			phs2 = p[ix2];
			mg1 = mg[ix1];
			mg2 = mg[ix2];
			mg1 *= mg1;
			mg2 *= mg2;
			dif += phs2 * mg2 - phs1 * mg1;
			wt += (mg1 + mg2)/2;
		}
	} else {	// vertical
		// x / y : start position in phs image
		x = blklist[t1].x0 + bnd->st1;
		y = blklist[t2].y0 - 1;

		for (j = 0; j < siz; j++) {
			ix1 = y       * xDim + x + j;
			ix2 = (y + 1) * xDim + x + j;
			phs1 = p[ix1];
			phs2 = p[ix2];
			mg1 = mg[ix1];
			mg2 = mg[ix2];
			mg1 *= mg1;
			mg2 *= mg2;
			dif += phs2 * mg2 - phs1 * mg1;
			wt += (mg1 + mg2)/2;
		}
	}
if (wt <= 0) {
	printf("neg wt (%f) ####\n", wt);
}

	if (wt == 0) {
		r = 0;
	} else {
		dif /= wt;
		r = round(dif / (2 * M_PI));
	}

	return r;
}

void
add_rpi_rec(float *p, int xDim, int tile, int r)
{
	int		x, y, siz;
	int		i, j;
	float	ph;

	if (r == 0) return;
//	if (blklist[tile].phs_sd > 1.6) return;	// doesn't work ???

	x = blklist[tile].x0;
	y = blklist[tile].y0;
	siz = blklist[tile].siz;
	ph = 2 * M_PI * r;
	for (i = 0; i < siz; i++) {
		for (j = 0; j < siz; j++) {
			p[(y + i) * xDim + x + j] += ph;
		}
	}
}

void
add_rpi(float *p, int xDim, int t1, int siz, int r)
{
	int		x, y, n;
	int		i, j;
	float	ph;

	n = xDim / siz;
	x = t1 % n;
	y = t1 / n;
	ph = 2 * M_PI * r;
	for (i = 0; i < siz; i++) {
		for (j = 0; j < siz; j++) {
			p[(y * siz + i) * xDim + x * siz + j] += ph;
		}
	}
}

void
add_rpi_2(RecImage *tiles, int t1, int r)
{
	int		i, j;
	int		siz = [tiles xDim];
	float	ph;
	float	*p1;

	ph = 2 * M_PI * r;
	p1 = [tiles data] + siz*siz * t1;
	for (i = 0; i < siz; i++) {
		for (j = 0; j < siz; j++) {
			p1[i * siz + j] += ph;
		}
	}
}

int
calc_r_2(RecImage *tiles, int t1, int t2)
{
	int		i, j;
	int		siz = [tiles xDim];
	float	*p1, *p2;
	float	dif, phs1, phs2;
	int		r;

	p1 = [tiles data] + siz*siz * t1;
	p2 = [tiles data] + siz*siz * t2;
	if ((t2 - t1) > 2) {	// vertical
		dif = 0;
		for (j = 0; j < siz; j++) {
			phs1 = p1[siz * (siz - 1) + j];
			phs2 = p2[j];
			dif += phs2 - phs1;
		}
	} else {				// horizontal
		dif = 0;
		for (i = 0; i < siz; i++) {
			phs1 = p1[i * siz + siz - 1];
			phs2 = p2[i * siz];
			dif += phs2 - phs1;
		}
	}
	dif /= siz;
	r = round(dif / (2 * M_PI));

	return r;
}

int
calc_r_3(RecImage *tiles, RecImage *ptiles, int t1, int t2)
{
	int		i, j;
	int		siz = [tiles xDim];
	float	*p1, *p2;
	float	*m1, *m2;
	float	dif, phs1, phs2;
	float	mg1, mg2, wt;
	int		r;

	// unwrapped phase
	p1 = [ptiles data] + siz*siz * t1;
	p2 = [ptiles data] + siz*siz * t2;
	// magnitude
	m1 = [tiles data] + siz*siz * t1;
	m2 = [tiles data] + siz*siz * t2;

	if ((t2 - t1) > 2) {	// vertical
		dif = wt = 0;
		for (j = 0; j < siz; j++) {
			phs1 = p1[siz * (siz - 1) + j];
			phs2 = p2[j];
			mg1 = m1[siz * (siz - 1) + j];
			mg2 = m2[j];
			dif += phs2 * mg2 - phs1 * mg1;
			wt += (mg2 + mg1) / 2;
		}
	} else {				// horizontal
		dif = wt = 0;
		for (i = 0; i < siz; i++) {
			phs1 = p1[i * siz + siz - 1];
			phs2 = p2[i * siz];
			mg1 = m1[i * siz + siz - 1];
			mg2 = m2[i * siz];
			dif += phs2 * mg2 - phs1 * mg1;
			wt += (mg2 + mg1) / 2;
		}
	}
	dif /= wt;
	r = round(dif / (2 * M_PI));

	return r;
}

// clockwise #### not done yet
// t2 is target
int
calc_r_4(RecImage *tiles, int t2)
{
	int		t1;
	int		i, j;
	int		siz = [tiles xDim];
	float	*p1, *p2;
	float	dif, phs1, phs2;
	int		r;

	t1 = t2 - 1;
	if (t1 < 0) t1 = 3;

	p1 = [tiles data] + siz*siz * t1;
	p2 = [tiles data] + siz*siz * t2;

	dif = 0;
	switch (t2) {
	case 0 :	// 3 - 0 (U)
	default :
		for (j = 0; j < siz; j++) {
			phs1 = p1[j];
			phs2 = p2[siz * (siz - 1) + j];
			dif += phs2 - phs1;
		}
		break;
	case 1 :	// 0 - 1 (R)
		for (i = 0; i < siz; i++) {
			phs1 = p1[i * siz + siz - 1];
			phs2 = p2[i * siz];
			dif += phs2 - phs1;
		}
		break;
	case 2 :	// 1 - 2 (D)
		for (j = 0; j < siz; j++) {
			phs1 = p1[siz * (siz - 1) + j];
			phs2 = p2[j];
			dif += phs2 - phs1;
		}
		break;
	case 3 :	// 2 - 3 (L)
		for (i = 0; i < siz; i++) {
			phs1 = p1[i * siz];
			phs2 = p2[i * siz + siz - 1];
			dif += phs2 - phs1;
		}
		break;
	}
	dif /= siz;
	r = round(dif / (2.0 * M_PI));

	return -r;
}


// based on Strand, IEEE Trans Image Proc 1999:8;375.
//			Antonopulos, PLOS One 2015
// input is complex
// output is real (unwrapped phase)
- (RecImage *)unwrap2d_block		// block-wise linear
{
	RecImage	*blk, *pblk;
	RecImage	*mask;
	RecImage	*flg;
	float		*flag;	// n x n
	int			ngrp;
	int			*grp;	// n x n / 2
	int			curr_grp;
	int			nrel;
	rel_ent		*rel;
	int			(^compar)(const void *, const void *);
	RecImage	*phs = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
	Rec2DRef	*ref = [Rec2DRef refForImage:self];
	Rec2DRef	*pref = [Rec2DRef refForImage:phs];
	int			i, j, n;
	int			ii, jj;
	int			ix;
	int			siz = 2;	// 4
	int			xDim = [self xDim];
	int			yDim = [self yDim];
	float		*p, val;
	int			r;

	mask = [self copy];
	[mask thresAt:1.0e-8];
//	[mask thresAt:0.1];

	n = [self xDim] / siz;
	[ref setNx:siz];
	[ref setNy:siz];
	[pref setNx:siz];
	[pref setNy:siz];

	// init flag
	flg = [RecImage imageOfType:RECIMAGE_REAL xDim:n yDim:n];
	flag = [flg data];
	p = [mask data];
	for (i = 0; i < n; i++) {
		for (j = 0; j < n; j++) {
			val = 0;
			for (ii = 0; ii < siz; ii++) {
				for (jj = 0; jj < siz; jj++) {
					val += p[(i * siz + ii) * xDim + (j * siz + jj)];
				}
			}
			if (val > 0) {
				flag[i * n + j] = 1;	// non-zero data, belong to no group
			} else {
				flag[i * n + j] = 0;	// zero data
			}
		//	printf("%d ", flag[i * siz + j]);
		}
	//	printf("\n");
	}

	// unwrap block
	for (i = 0; i < n; i++) {
		for (j = 0; j < n; j++) {
		//	if (flag[i * n + j] == 0) continue;
			// make sub-image
			[ref setX:j * siz y:i * siz];
			blk = [ref makeImage];
			
			// call unrap
			pblk = unwrap_block(blk, i * n + j);
			
			// copy back to phs
			[pref setX:j * siz y:i * siz];
			[pref copyImage:pblk];
			
		}
	}

	[phs multByImage:mask];
//	[phs saveAsKOImage:@"IMG_unwrap.img"];

// tile merge
	if (0) {	// sequential
		p = [phs data];
		for (i = 0; i < n; i++) {
			for (j = 0; j < n; j++) {
				shift_block(p, flag, xDim, yDim, j, i, siz);
			}
		}
	} else {	// sorted
		int			mode = 0;

		rel = (rel_ent *)malloc(sizeof(rel_ent) * n * (n - 1) * 2);	// # of junctions
		p = [phs data];
		
		// calc reliability for all junctions
		for (i = ix = 0; i < n; i++) {			// y
			for (j = 0; j < n - 1; j++, ix++) {	// x
				// rel for t(i, j) - t(i, j + 1)
				rel[ix].rel = rel_block_r(p, xDim, yDim, j, i, siz);
				rel[ix].t1 = i * n + j;
				rel[ix].t2 = i * n + j + 1;
			}
		}
		for (i = 0; i < n - 1; i++) {			// y
			for (j = 0; j < n; j++, ix++) {		// x
				// rel for t(i, j) - t(i + 1, j)
				rel[ix].rel = rel_block_d(p, xDim, yDim, j, i, siz);
				rel[ix].t1 = i * n + j;
				rel[ix].t2 = (i + 1) * n + j;
			}
		}
		nrel = ix;
//printf("nrel = %d / %d\n", nrel, n * (n - 1) * 2);

		// sort by reliability
		compar = ^int(const void *p1, const void *p2) {
			float pp = ((rel_ent *)p1)->rel;
			float qq = ((rel_ent *)p2)->rel;
			// descending
			if (pp < qq) {
				return -1;
			} else 
			if (pp == qq) {
				return 0;
			} else {
				return 1;
			}
		};
		qsort_b(rel, nrel, sizeof(rel_ent), compar);

		// connect tiles according to reliability (tSRNCP)
		grp = (int *)malloc(sizeof(int) * n * n / 2);	// groups: starts from 2
		ngrp = 0;
		for (i = 0; i < n*n/2; i++) {
			grp[i] = 0;
		}
		curr_grp = 2;

		for (ix = 0; ix < nrel; ix++) {
			int t1, t2;
			int	gr1, gr2;
			t1 = rel[ix].t1;
			t2 = rel[ix].t2;

			if (flag[t1] == 0 || flag[t2] == 0) continue;	// skip 0 tile

			if (flag[t1] == 1 && flag[t2] == 1) {			// neither belong to grp
				mode = 1;
				flag[t1] = flag[t2] = curr_grp;
				grp[curr_grp] += 2;
				curr_grp++;
				// calc r (t1, t2)
				r = calc_r(p, xDim, yDim, t1, t2, siz);
				// add 2PI * r to t2
				if (r != 0) {
					add_rpi(p, xDim, t1, siz, r);
				}
			} else
			if (flag[t1] == 1 && flag[t2] > 1) {			// only t2 belong to grp
				mode = 2;
				flag[t1] = flag[t2];
				grp[(int)flag[t2]] += 1;
				r = calc_r(p, xDim, yDim, t1, t2, siz);
				if (r != 0) {
					add_rpi(p, xDim, t1, siz, r);
				}
			} else
			if (flag[t1] > 1 && flag[t2] == 1) {				// only t1 belong to grp
				mode = 3;
				flag[t2] = flag[t1];
				grp[(int)flag[t1]] += 1;
				r = calc_r(p, xDim, yDim, t1, t2, siz);
				if (r != 0) {
					add_rpi(p, xDim, t2, siz, -r);
				}
			} else {										// both belong to grp
				mode = 4;
				r = calc_r(p, xDim, yDim, t1, t2, siz);
				gr1 = flag[t1];
				gr2 = flag[t2];
				if (grp[gr1] == grp[gr2]) {
				//	printf("### %d\n", ix);
					continue;		// to avoid loop
				} else
				if (grp[gr1] > grp[gr2]) {
					// merge t2 group to t1 group
					for (j = 0; j < n*n; j++) {
						if (flag[j] == gr2) {
							flag[j] = gr1;
							grp[gr1]++;
							grp[gr2]--;
							add_rpi(p, xDim, j, siz, -r);
						}
					}
				} else {
					// merge t1 group to t2 group
					for (j = 0; j < n*n; j++) {
						if (flag[j] == gr1) {
							flag[j] = gr2;
							grp[gr1]--;
							grp[gr2]++;
							add_rpi(p, xDim, j, siz, r);
						}
					}
				}
			}
		//	printf("%5d (%3d/%3d) (%3d/%3d) %5d grp = %d, mode = %d\n", ix, t1%n*siz, t1/n*siz, t2%n*siz, t2/n*siz, r, curr_grp, mode);
		}

		free(rel);
		free(grp);
	}
//	free(flag);

[phs multByImage:mask];
//[phs saveAsKOImage:@"IMG_unwrap_2.img"];

	return phs;
}

// ### version 2 (tiles are separate images) (ver 1 is better ?)
//		
// new calc_r() & add_rpi()
// new rel (currently phs image is used)(instead of tiles)
- (RecImage *)unwrap2d_block_2
{
	RecImage	*blk, *pblk;
	RecImage	*mask;
	RecImage	*flg;
	RecImage	*tiles, *ptiles;
	float		*flag;	// n x n
	int			*grp;	// n x n / 2
	int			curr_grp;
	int			nrel;
	rel_ent		*rel;
	int			(^compar)(const void *, const void *);
	RecImage	*phs = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
	Rec2DRef	*ref = [Rec2DRef refForImage:self];
	Rec2DRef	*pref = [Rec2DRef refForImage:phs];
	int			i, j, n;
	int			ii, jj;
	int			ix;
	int			siz = 4;
	int			xDim = [self xDim];
//	int			yDim = [self yDim];
	float		*p1, *p2, val;
	RecLoopControl	*lc;
	int			r;

	mask = [self copy];
//	[mask thresAt:1.0e-8];
	[mask thresAt:0.01];

	n = [self xDim] / siz;
	[ref setNx:siz];
	[ref setNy:siz];
	[pref setNx:siz];
	[pref setNy:siz];

	// init flag
	flg = [RecImage imageOfType:RECIMAGE_REAL xDim:n yDim:n];
	flag = [flg data];
	p1 = [mask data];
	for (i = 0; i < n; i++) {
		for (j = 0; j < n; j++) {
			val = 0;
			for (ii = 0; ii < siz; ii++) {
				for (jj = 0; jj < siz; jj++) {
					val += p1[(i * siz + ii) * xDim + (j * siz + jj)];
				}
			}
			if (val > 0) {
				flag[i * n + j] = 1;	// non-zero data, belong to no group
			} else {
				flag[i * n + j] = 0;	// zero data
			}
		//	printf("%d ", flag[i * siz + j]);
		}
	//	printf("\n");
	}

	tiles = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:siz yDim:siz zDim:n * n];
	ptiles = [RecImage imageOfType:RECIMAGE_REAL xDim:siz yDim:siz zDim:n * n];
	[ptiles copyLoopsOf:tiles];

	// copy to tiles
	for (i = ix = 0; i < n; i++) {
		for (j = 0; j < n; j++, ix++) {
			// make sub-image
			[ref setX:j * siz y:i * siz];
			blk = [ref makeImage];
			[blk copyXYLoopsOf:tiles];
			[tiles copySlice:blk atIndex:ix];
		}
	}
	[tiles saveAsKOImage:@"IMG_tiles.img"];


	// unwrap block
	for (i = ix = 0; i < n; i++) {
		for (j = 0; j < n; j++, ix++) {
		//	if (flag[i * n + j] == 0) continue;
			
			// call unrap
			blk = [tiles sliceAtIndex:ix];
			pblk = unwrap_block(blk, ix);
			
			// copy back to ptiles
			[ptiles copySlice:pblk atIndex:ix];
		}
	}

	[ptiles saveAsKOImage:@"IMG_ptiles.img"];

// for debugging... not necessary for result
if (0) {
	[phs clear];
// copy tiles back to image
	p1 = [phs data];
	lc = [ptiles control];
	[lc rewind];
	[lc deactivateXY];
	for (i = ix = 0; i < n; i++) {
		for (j = 0; j < n; j++, ix++) {
			p2 = [ptiles currentDataWithControl:lc];
			for (ii = 0; ii < siz; ii++) {
				for (jj = 0; jj < siz; jj++) {
					p1[(i * siz + ii) * xDim + j * siz + jj] = p2[ii * siz + jj];
				}
			}
			[lc increment];
		}
	}

[phs saveAsKOImage:@"IMG_unwrap.img"];

}

// tile merge
	int			mode = 0;

//	[tiles magnitude];	// cpx -> mag
	[tiles magnitudeSq];	// cpx -> mag^2
	rel = (rel_ent *)malloc(sizeof(rel_ent) * n * (n - 1) * 2);	// # of junctions
	p1 = [phs data];
	
	// calc reliability for all junctions
	ix = 0;
	for (i = 0; i < n; i++) {			// y
		for (j = 0; j < n - 1; j++) {	// x
			// rel for t(i, j) - t(i, j + 1)
			rel[ix].t1 = i * n + j;
			rel[ix].t2 = i * n + j + 1;
			rel[ix].rel = rel_block_r_2(ptiles, rel[ix].t1, rel[ix].t2);	// phs var
		//	rel[ix].rel = rel_block_r_3(tiles, ptiles, rel[ix].t1, rel[ix].t2);		// mag based
			ix++;
		}
	}
	for (i = 0; i < n - 1; i++) {			// y
		for (j = 0; j < n; j++) {		// x
			// rel for t(i, j) - t(i + 1, j)
			rel[ix].t1 = i * n + j;
			rel[ix].t2 = (i + 1) * n + j;
			rel[ix].rel = rel_block_d_2(ptiles, rel[ix].t1, rel[ix].t2);	// phs var
		//	rel[ix].rel = rel_block_d_3(tiles, ptiles, rel[ix].t1, rel[ix].t2);		// mag based
			ix++;
		}
	}
	nrel = ix;
printf("nrel = %d / %d\n", nrel, n * (n - 1) * 2);

	// sort by reliability
	compar = ^int(const void *p1, const void *p2) {
		float pp = ((rel_ent *)p1)->rel;
		float qq = ((rel_ent *)p2)->rel;
		// descending
		if (pp < qq) {
			return -1;
		} else 
		if (pp == qq) {
			return 0;
		} else {
			return 1;
		}
	};
	qsort_b(rel, nrel, sizeof(rel_ent), compar);

	// connect tiles according to reliability (tSRNCP)
	grp = (int *)malloc(sizeof(int) * n * n / 2);	// groups: starts from 2
	for (i = 0; i < n*n/2; i++) {
		grp[i] = 0;
	}
	curr_grp = 2;

	for (ix = 0; ix < nrel; ix++) {
		int t1, t2;
		int	gr1, gr2;
		t1 = rel[ix].t1;
		t2 = rel[ix].t2;

		if (flag[t1] == 0 || flag[t2] == 0) continue;	// skip 0 tile

		if (flag[t1] == 1 && flag[t2] == 1) {			// neither belong to grp
			mode = 1;
			flag[t1] = flag[t2] = curr_grp;
			grp[curr_grp] += 2;
			curr_grp++;
			// calc r (t1, t2)
		//	r = calc_r_2(ptiles, t1, t2);			// phase-based
			r = calc_r_3(tiles, ptiles, t1, t2);	// mag-based
			// add 2PI * r to t2
			if (r != 0) {
				add_rpi_2(ptiles, t1, r);
			}
		} else
		if (flag[t1] == 1 && flag[t2] > 1) {			// only t2 belong to grp
			mode = 2;
			flag[t1] = flag[t2];
			grp[(int)flag[t2]] += 1;
		//	r = calc_r_2(ptiles, t1, t2);
			r = calc_r_3(tiles, ptiles, t1, t2);
			if (r != 0) {
				add_rpi_2(ptiles, t1, r);
			}
		} else
		if (flag[t1] > 1 && flag[t2] == 1) {				// only t1 belong to grp
			mode = 3;
			flag[t2] = flag[t1];
			grp[(int)flag[t1]] += 1;
		//	r = calc_r_2(ptiles, t1, t2);
			r = calc_r_3(tiles, ptiles, t1, t2);
			if (r != 0) {
				add_rpi_2(ptiles, t2, -r);
			}
		} else {										// both belong to grp
			mode = 4;
		//	r = calc_r_2(ptiles, t1, t2);
			r = calc_r_3(tiles, ptiles, t1, t2);
			gr1 = flag[t1];
			gr2 = flag[t2];
			if (grp[gr1] == grp[gr2]) {
				continue;		// to avoid loop
			} else
			if (grp[gr1] > grp[gr2]) {
				// merge t2 group to t1 group
				for (j = 0; j < n*n; j++) {
					if (flag[j] == gr2) {
						flag[j] = gr1;
						grp[gr1]++;
						grp[gr2]--;
						add_rpi_2(ptiles, j, -r);
					}
				}
			} else {
				// merge t1 group to t2 group
				for (j = 0; j < n*n; j++) {
					if (flag[j] == gr1) {
						flag[j] = gr2;
						grp[gr1]--;
						grp[gr2]++;
						add_rpi_2(ptiles, j, r);
					}
				}
			}
		}
	//	printf("%5d (%3d/%3d) (%3d/%3d) %5d grp = %d, mode = %d\n", ix, t1%n*siz, t1/n*siz, t2%n*siz, t2/n*siz, r, curr_grp, mode);
	}

// copy tiles back to image

[phs clear];
	p1 = [phs data];
	lc = [ptiles control];
	[lc rewind];
	[lc deactivateXY];
	for (i = ix = 0; i < n; i++) {
		for (j = 0; j < n; j++, ix++) {
			p2 = [ptiles currentDataWithControl:lc];
			for (ii = 0; ii < siz; ii++) {
				for (jj = 0; jj < siz; jj++) {
					p1[(i * siz + ii) * xDim + j * siz + jj] = p2[ii * siz + jj];
				}
			}
			[lc increment];
		}
	}

[phs saveAsKOImage:@"IMG_merge.img"];

	free(rel);
	free(grp);

[phs multByImage:mask];
//[phs saveAsKOImage:@"IMG_final.img"];

	return phs;
}

void
dump_blklist()
{
	int		i;

	printf("==== len:%d ====\n", len_blklist);
	for (i = 0; i < len_blklist; i++) {
		printf("%3d %3d (%3d,%3d) %5d\n", i, blklist[i].siz, blklist[i].x0, blklist[i].y0, blklist[i].area);
	}
	printf("\n");
}

void
draw_blk(RecImage *phs)
{
	int		k, i, j, ix0;
	float	*p = [phs data];
	int		xDim = [phs xDim];

	for (k = 0; k < len_blklist; k++) {
		for (i = 0; i < blklist[k].siz; i++) {
			ix0 = blklist[k].y0 * xDim + blklist[k].x0;
			for (j = 0; j < blklist[k].siz; j++) {
				p[ix0 + j] = -1;
				p[ix0 + j * xDim] = -1;
			}
		}		
	}
}

void
dump_bndlist()
{
	int		i;
//	int		t1, t2;
// === dbg
//for (i = 0; i < len_blklist; i++) {
//	blklist[i].flg = 0;
//}

	printf("==== len:%d ====\n", len_bndlist);
	for (i = 0; i < len_bndlist; i++) {
		printf("%3d (%4d,%4d) %3d (%3d,%3d) %8.4f\n", bndlist[i].hor, bndlist[i].t1, bndlist[i].t2, 
				bndlist[i].siz, bndlist[i].st1, bndlist[i].st2, bndlist[i].rel);
		if (bndlist[i].st1 < 0 || bndlist[i].st2 < 0)  printf("########\n");
		
//		t1 = bndlist[i].t1;
//		t2 = bndlist[i].t2;
//		blklist[t1].flg++;
//		blklist[t2].flg++;
	}
	printf("\n");

//	for (i = 0; i < len_blklist; i++) {
//		printf("%d %d\n", i, blklist[i].flg);
//	}
}

RecImage *
unwrap_fine(RecImage *phs, RecImage *self)
{
	RecImage	*r, *hi;

	r = [self copy];
	[r phase];
	[r subImage:phs];
	[r mod2PI];
	hi = [self copy];
	[hi phase];
	[hi subImage:r];
	
	return hi;
}

extern BOOL fft_dbg;

BOOL unwrap_dbg = NO;

// top level (final version would be single call of unwrap_block_rec()
- (RecImage *)unwrap2d_block_rec
{
	RecImage	*cpx, *phs;
	RecImage	*mg;
	RecImage	*mask;
	RecImage	*tmp;

	fft_dbg = NO;

	mg = [self copy];
	[mg magnitude];

	mask = [mg copy];
//	[mask thresAt:0.01];
	[mask thresAt:1.0e-8];
	
	init_lists(100);

	cpx = [self copy];
	[cpx phsNoiseFilt:3.0];	// 3.0
//	[cpx gauss2DLP:0.7];
//	[cpx lanczWin2D];
if (unwrap_dbg) [cpx saveAsKOImage:@"IMG_noiseFilt"];

	[cpx multByImage:mask];

	phs = unwrap_block_rec(cpx, 0, 0);		// unwrap stage
	[phs multByImage:mask];
if (unwrap_dbg) {
	tmp = [phs copy];
	draw_blk(tmp);
	[tmp saveAsKOImage:@"IMG_unwrap"];
}

	merge_blocks(phs, mg);

if (unwrap_dbg) {
	tmp = [phs copy];
	draw_blk(tmp);
	[tmp saveAsKOImage:@"IMG_merge"];
}

	free(blklist);
	free(bndlist);


//	phs = unwrap_fine(phs, self);
//[phs saveAsKOImage:@"IMG_fine"];

	mask = [self phsNoiseMask:10.0];
	[phs multByImage:mask];
	
	return phs;
}

// input is complex
// returns phase image (real)
- (RecImage *)unwrap2d_work	// grad, fudge etc
{
	RecLoop		*xLp, *yLp;
	RecImage	*phs, *pnp;
	RecImage	*est;
	RecImage	*dif;	// dbg
	RecImage	*gx, *gy, *div, *divm, *p, *p0;
	
	phs = [self copy];
	[phs phase];
	phs = [phs sliceAtIndex:5];
//	[phs dumpLoops];


//	[phs fermiWithRx:0.6 ry:0.6 d:0.2 x:0 y:0 invert:NO half:NO];
[phs saveAsKOImage:@"IMG_in.img"];

	if (1) {	// grad based
		float	gm = 2.0, tau = 0.25;
		int		i;
		// grad (shift) not correct yet ###
		gx = [phs pGrad1dForLoop:[phs xLoop]];
		[gx saveAsKOImage:@"IMG_gx.img"];
		gy = [phs pGrad1dForLoop:[phs yLoop]];
		[gy saveAsKOImage:@"IMG_gy.img"];
		
		[gx multByConst:1.0/gm];
		p0 = [RecImage imageWithImage:phs];
		for (i = 0; i < 50; i++) {
			div = [p0 copy];
			[div subImage:gx];
			div = [div div2d];
			div = [div pGrad2d];
			[div saveAsKOImage:@"IMG_div.img"];
			divm = [div copy];
			[divm magnitude];
			[div multByConst:tau];
			[divm multByConst:tau];
			p = [p0 copy];
			[p addImage:div];
			[divm addConst:1.0];
			[p divImage:divm];
			p0 = [p copy];
		}
		[p saveAsKOImage:@"IMG_p.img"];
		p = [p div2d];
		[p multByConst:gm];
		[p saveAsKOImage:@"IMG_pdiv.img"];
		[p subImage:gx];
		[p saveAsKOImage:@"IMG_pd_gx.img"];
		

		exit(0);
	}

	xLp = [phs xLoop];
	yLp = [phs yLoop];
	[phs zeroFillToPo2];	// for DCT & boundary condition for inv laplacian

	est = [phs unwrapEst2d_disc];
[est saveAsKOImage:@"IMG_est.img"];

	pnp = [est copy];
	[pnp subImage:phs];
	dif = [pnp copy];
	[dif saveAsKOImage:@"IMG_dif.img"];

	[pnp mod2PI:M_PI * 0.9];
[pnp saveAsKOImage:@"IMG_pnp.img"];


//	[dif wave2d:REC_FORWARD level:1];
	[dif laplace2dc:REC_FORWARD];
[dif saveAsKOImage:@"IMG_dif_ft.img"];

	[phs addImage:pnp];
[phs saveAsKOImage:@"IMG_1st.img"];

	[phs subImage:est];
[phs saveAsKOImage:@"IMG_dif2.img"];
	[phs multByConst:1.5];
	[phs mod2PI];
[phs saveAsKOImage:@"IMG_pnp2.img"];
	
//[phs addImage:dif];
//[phs saveAsKOImage:@"IMG_1st_sub.img"];

	[phs replaceLoop:[phs xLoop] withLoop:xLp];
	[phs replaceLoop:[phs yLoop] withLoop:yLp];


	return phs;
}

- (RecImage *)phsNoiseMask:(float)sg	// input is complex, output is (soft) mask
{
	RecImage	*mask;
	float		thres, *p;
	int			i, n;

	mask = [self copy];
	[mask magnitude];
	thres = [mask noiseSigma] * [mask maxVal];
	thres *= sg;

	n = [mask dataLength];
	p = [mask data];
	for (i = 0; i < n; i++) {
		if (p[i] < thres) {
			p[i] /= thres;
		} else {
			p[i] = 1.0;
		}
	//	p[i] *= p[i];
	}
	return mask;
}

- (void)phsNoiseFilt:(float)sg
{
	RecImage	*mask, *phs;

	phs = [self copy];
	[phs phase];
	mask = [self phsNoiseMask:sg];
	[phs multByImage:mask];
	[self magnitude];
	[self makeComplexWithPhs:phs];
}

@end
