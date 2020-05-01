//
// tmp programs... started as general purpose recon
//

#import <RecKit/RecKit.h>

RecImage	*f1, *f2;

int test1();
int test2();	// phase gradient
int test3();	// noise power spectrum
int	test4();	// gridding kernel experiments
int	test5();	// gridding density correction experiments
int	test6();	// kaiser window experiments
int	test7();	// iterative besseli0()

float bessel_test(float x);

int
main()
{
    @autoreleasepool {
//	test1();
//	test2();
//	test3();
//	test4();
	test5();
//	test6();
//	test7();

	return 0;
    }
}

int
test1()
{
	RecLoop		*ky, *kx;
	RecImage	*p, *m;

	kx = [f1 xLoop];
	ky = [f1 yLoop];
	f2 = [f1 copy];
//	[f2 flipForLoop:kx];
	[f2 flipForLoop:ky];
	[f2 conjugate];

	[f1 fft1d:kx direction:REC_INVERSE];
	[f1 fft1d:ky direction:REC_INVERSE];

	[f2 fft1d:kx direction:REC_INVERSE];
	[f2 fft1d:ky direction:REC_INVERSE];
//	[f2 flipForLoop:ky];
	[f2 flipForLoop:kx];

	[f1 saveAsKOImage:@"IMG1"];
	[f2 saveAsKOImage:@"IMG2"];

	[f1 magnitude];
	[f2 magnitude];

	p = [f1 copy];
	[p addImage:f2];
	m = [f1 copy];
	[m subImage:f2];
	[m divImage:p];

	[m saveAsKOImage:@"IMG_sub"];

	return 0;
}

// phase gradient
int
test2()
{
	RecImage		*pos, *neg;
	RecLoop			*kx, *ky, *dir;
	int				i, k;
	int				len, pixSize, dataLength;
	int				skip;
	float			*p;
	RecLoopControl	*lc;

	f2 = [f1 copy];
	kx = [f1 xLoop];
	ky = [f1 yLoop];
	dir = ky; //kx;
	lc = [f1 outerLoopControlForLoop:dir];

	len = [dir dataLength];
	skip = [f1 skipSizeForLoop:dir];
	pixSize = [f1 pixSize];
	dataLength = [f1 dataLength];

	[lc rewind];
	for (i = 0; i < [lc loopLength]; i++) {
		p = [f1 currentDataWithControl:lc];
		for (k = 0; k < pixSize; k++) {
			vDSP_vclr(p + skip*len/2, skip, len/2);
			p += dataLength;
		}
		[lc increment];
	}

	[lc rewind];
	for (i = 0; i < [lc loopLength]; i++) {
		p = [f2 currentDataWithControl:lc];
		for (k = 0; k < pixSize; k++) {
			vDSP_vclr(p, skip, len/2);
			p += dataLength;
		}
		[lc increment];
	}

	[f1 saveAsKOImage:@"../test_img/IMG1"];
	[f2 saveAsKOImage:@"../test_img/IMG2"];
	[f1 fft2d:REC_INVERSE];
	[f2 fft2d:REC_INVERSE];
	[f1 magnitude];
	[f2 magnitude];

	pos = [f1 copy];
	[pos addImage:f2];
	neg = [f1 copy];
	[neg subImage:f2];
	[neg divImage:pos];

	[neg saveAsKOImage:@"../test_img/IMG_sub"];

	return 0;
}

// noise power spectrum
int
test3()
{
    RecImage    *r1, *r2;
    RecImage    *f1, *f2;
    RecImage    *mask;
    RECCTL      ctl;
    RecLoop     *kx, *ky;

    r1 = [RecImage imageWithPfile:@"../test_img/P39936.7" RECCTL:&ctl];
    r2 = [RecImage imageWithPfile:@"../test_img/P41984.7" RECCTL:&ctl];
//    r1 = [RecImage imageWithKOImage:@"../test_img/I39936.raw"];
//    r2 = [RecImage imageWithKOImage:@"../test_img/I41984.raw"];

//    [r1 saveAsKOImage:@"../test_img/nps_raw1.img"];
//    [r2 saveAsKOImage:@"../test_img/nps_raw2.img"];
    kx = [RecLoop loopWithDataLength:512];
    ky = [RecLoop loopWithDataLength:512];

    [r1 replaceLoop:[r1 xLoop] withLoop:kx];
    [r1 replaceLoop:[r1 yLoop] withLoop:ky];
    [r1 fft2d:REC_FORWARD];
    [r1 pfSwap:ctl.trans rot:ctl.rot];
    [r1 saveAsKOImage:@"../test_img/nps_img1.img"];

    [r2 replaceLoop:[r2 xLoop] withLoop:kx];
    [r2 replaceLoop:[r2 yLoop] withLoop:ky];
    [r2 fft2d:REC_FORWARD];
    [r2 pfSwap:ctl.trans rot:ctl.rot];
    [r2 saveAsKOImage:@"../test_img/nps_img2.img"];

    mask = [r1 copy];
    [mask thresAt:0.2];

    [r1 scaleByImage:mask];
    [r2 scaleByImage:mask];

    [r1 magnitude];
    [r2 magnitude];
    

    [r1 subImage:r2];
    [r1 makeComplex];
    [r1 saveAsKOImage:@"../test_img/nps.img"];
    [r1 fft2d:REC_INVERSE];
    [r1 saveAsKOImage:@"../test_img/nps_k.img"];

    return 0;
}

void
normalize_kern(float *p, int len)
{
	int		i;
	float	mx = 0;

	for (i = 0; i < len; i++) {
		if (mx < p[i]) {
			mx = p[i];
		}
	}
	mx = 1.0 / mx;
	for (i = 0; i < len; i++) {
		p[i] *= mx;
	}
}
	
void
dump_kern(float *p, int kern_len, int ft_len)
{
	int	i, ix;

	for (i = 0; i < kern_len; i++) {
		ix = ft_len/2 - kern_len/2 + i;
		printf("%d %16.12f\n", i, p[ix]);
	}
}

void
limit_kern(float *p, int len, int w)
{
	int	i;

	for (i = 0; i < len; i++) {
		if (abs(i - len/2) > w) p[i] = 0;
		p[i + len] = 0;	// clear imag
	}
}

// gridding kernel
int
test4()
{
	int			i, ix;
	int			iter;
	int			kern_len = 256;	// 2-sided
	int			rec_len = 256;
	int			op = 2;
	int			ft_len = kern_len * rec_len * op / 8;
	int			wx = kern_len/2;
	int			wk = wx * 0.5;
	float		x, xx, a0;
	// gaussian
	float		sd = 0.60;
	// Kaiser Bessel
	float		a = 4.0;	//5.0;

	RecImage	*kern;

	int			kn = 4;	// 0:rect, 1:sinc, 2:Lanczos, 3:gauss, 4:KB, 5: KB inv
	int			niter = 0; //5000;
	float		*p, *pi, *q;

	kern  = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:ft_len yDim:1 zDim:1];
	p = [kern data];

	switch (kn) {
	case 0 :	// rect
		q = (float *)malloc(sizeof(float) * kern_len/4);
		for (i = 0; i < kern_len/4; i++) {
			q[i] = 1.0;
			p[ft_len/2 + i] = q[i];
			p[ft_len/2 - i] = q[i];
		}
		free(q);
		break;
	case 1 :	// truncated sinc
		q = (float *)malloc(sizeof(float) * kern_len/2);
		for (i = 0; i < kern_len/2; i++) {
			x = (float)i * 2 * M_PI / (kern_len/2 - 1);		// x = [0 .. 2pi]
			if (i == 0) {
				q[i] = 1.0;
			} else {
				q[i] = sin(x) / x;
			}
			p[ft_len/2 + i] = q[i];
			p[ft_len/2 - i] = q[i];
		}
		free(q);
		break;
	case 2 :	// Lanczos
		q = Rec_lanczos_kern(kern_len/2, 2);
		for (i = 0; i <= kern_len/2; i++) {
			p[ft_len/2 + i] = q[i];
			p[ft_len/2 - i] = q[i];
		}
		free(q);
		break;
	case 3 :	// truncated gaussian
		q = (float *)malloc(sizeof(float) * kern_len/2);
		for (i = 0; i < kern_len/2; i++) {	// half tab
			x = (float)i * 2 / (kern_len/2 - 1);		// x = [0 .. 2]
			q[i] = exp(-0.5 * x * x / (sd * sd));
			p[ft_len/2 + i] = q[i];
			p[ft_len/2 - i] = q[i];
		}
		free(q);
		break;
	case 4 :	// Kaiser Bessel
		q = (float *)malloc(sizeof(float) * kern_len/2);
		q[0] = besseli0(a * M_PI);
		for (i = 0; i < kern_len/2; i++) {
			x = (float)i / (kern_len/2 - 1);		// x = [0 .. 1]
			q[i] = besseli0(a * M_PI * sqrt(1.0 - x * x));
		//	q[i] = bessel_test(a * M_PI * sqrt(1.0 - x * x));
			p[ft_len/2 + i] = q[i];
			p[ft_len/2 - i] = q[i];
		}
		free(q);
		break;
	case 5 :	// Kaiser ft
		q = (float *)malloc(sizeof(float) * kern_len);
		a0 = sinh(a * M_PI) / (a * M_PI);
		for (i = 0; i < kern_len * 2; i++) {
			x = (float)i * 2 / (kern_len/2 - 1);		// x = [0 .. 2]
			xx = a*a - x*x;
			if (xx > 0) {
				xx = M_PI * sqrt(xx);
				q[i] = sinh(xx) / xx / a0; // ;
			} else {
				xx = M_PI * sqrt(-xx);
				q[i] = sin(xx) / xx / a0;
			}
			p[ft_len/2 + i] = q[i];
			p[ft_len/2 - i] = q[i];
		}
		free(q);
		break;
	}

	normalize_kern(p, ft_len);

	if (kn == 5) {
		dump_kern(p, rec_len * op * 2, ft_len);
		exit(0);
	}

	for (iter = 0; iter < niter; iter++) {
		if (niter == 0) break;
		limit_kern(p, ft_len, wx);
		[kern fft1d:[kern xLoop] direction:REC_INVERSE];
		normalize_kern(p, ft_len);
		limit_kern(p, ft_len, wk);
		[kern fft1d:[kern xLoop] direction:REC_FORWARD];
		normalize_kern(p, ft_len);
	}
	limit_kern(p, ft_len, wx);
	dump_kern(p, kern_len, ft_len);	// k
	[kern fft1d:[kern xLoop] direction:REC_INVERSE];	// x
	normalize_kern(p, ft_len);
	dump_kern(p, rec_len * op * 2, ft_len);	// x

	return 0;
}

//=== density correction ===
typedef struct {
	int		ix;
	float	w;
} wt_entry;

typedef struct {
	int			tab_len;
	wt_entry	*buf;
	wt_entry	**p;
	int			*nent;
} wt_tab;

int		kernLen;
float	*kern;

RecImage *
mk_dist_img(RecImage *traj)
{
	RecImage	*dist;
	float		*dp;
	int			xDim = [traj xDim];
	int			yDim = [traj yDim];
	int			zDim = [traj xDim];	// circularly symmetric. if not, this becomes xDim * yDim
	float		*kx, *ky;
	float		x0, y0, x1, y1, d;
	int			i, ii, jj;

	dist = [RecImage imageOfType:RECIMAGE_REAL xDim:xDim yDim:yDim zDim:xDim];
	dp = [dist data];

	// calc distance and make table (1D first)
	kx = [traj data];
	ky = kx + [traj dataLength];
	for (i = 0; i < xDim; i++) {	// first line only
		x0 = kx[i];
		y0 = ky[i];
		for (ii = 0; ii < yDim; ii++) {
			for (jj = 0; jj < xDim; jj++) {
				x1 = kx[ii * xDim + jj];
				y1 = ky[ii * xDim + jj];
				d = (x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0);
				d = sqrt(d) * xDim;
				if (d < 2.0) {
					d = kern[(int)(d * kernLen / 2.0)];
				//	printf("%d %d %f\n", ii, jj, d);
				} else {
					d = 0;
				}
				dp[(i * yDim + ii) * xDim + jj] = d;
			}
		}
	}
	return dist;
}

wt_tab *
mk_wt_tab(RecImage	*wt)
{
	wt_tab		*tab;
	int			i, ix, n = [wt zDim];
	int			ii, jj;
	int			ent, nent, bufix;
	float		*wp = [wt data];
	int			xDim = [wt xDim];
	int			yDim = [wt yDim];

// pass 1, count nentry
	bufix = 0;
	for (i = 0; i < n; i++) {
		for (ii = 0; ii < yDim; ii++) {
			for (jj = 0; jj < xDim; jj++) {
				ix = (i * yDim + ii) * xDim + jj;
				if (wp[ix] != 0) {
					bufix++;
				}
			}
		}
	}

// pass 2
	tab = (wt_tab *)malloc(sizeof(wt_tab));
	tab->buf = (wt_entry *)malloc(sizeof(wt_entry) * bufix);
	tab->tab_len = n;

	tab->p		= (wt_entry **)malloc(sizeof(wt_entry *) * n);
	tab->nent	= (int *)malloc(sizeof(int *) * n);

	bufix = 0;
	for (i = 0; i < n; i++) {
		ent = 0;
		tab->p[i] = tab->buf + bufix;
		for (ii = 0; ii < yDim; ii++) {
			for (jj = 0; jj < xDim; jj++) {
				ix = (i * yDim + ii) * xDim + jj;
				if (wp[ix] != 0) {
					tab->buf[bufix].ix = jj;
					tab->buf[bufix].w = wp[ix];
					ent++;
					bufix++;
				}
			}
		}
		tab->nent[i] = ent;
	}
	return tab;
}

void
dump_wt_tab(wt_tab *tab)
{
	int			i, n = tab->tab_len;
	wt_entry	*et;

	for (i = 0; i < n; i++) {
		printf("nent[%d] = %d\n", i, tab->nent[i]);
	}
}

void
free_wt_tab(wt_tab *tab)
{
	int	i;

	if (tab == NULL) return;
	if (tab->buf)	free(tab->buf);
	if (tab->p)		free(tab->p);
	if (tab->nent)	free(tab->nent);
	free(tab);
}

void
grid_to_traj(wt_tab *tab, float *pout, float *pin)
{
	int			i, j, n = tab->tab_len;
	wt_entry	*en;

	for (i = 0; i < n; i++) {
		pout[i] = 0;
		en = tab->p[i];
		for (j = 0; j < tab->nent[i]; j++) {
			pout[i] += pin[en[j].ix] * en[j].w;
		}
	}
}

float
eval_error(float *wt, int n)
{
	float	mx, mn;
	int		i;

	mx = 0.0; mn = 2.0;
	for (i = 0; i < n; i++) {
		if (mx < wt[i]) mx = wt[i];
		if (mn > wt[i]) mn = wt[i];
	}
	return (mx - mn) / mx;
}

int
test5()
{
	int			i;
	int			xDim = 256;
	int			yDim = 128;
	int			tabLen = xDim;	// circularly symmetric
	float		x, a = 4.0;
	RecImage	*traj, *dist;
	float		tmp_i[256], tmp_o[256];
	int			iter;
	wt_tab		*tab;
	float		er;

	// make KB kernel (one sided)
	kernLen = 256;
	kern = (float *)malloc(sizeof(float) * kernLen);
	for (i = 0; i < kernLen; i++) {
		x = (float)i / (kernLen - 1);		// x = [0 .. 1]
		kern[i] = besseli0(a * M_PI * sqrt(1.0 - x * x));
	}
	normalize_kern(kern, kernLen);	// this is necessary

	// calc rad traj
	traj = [RecImage imageOfType:RECIMAGE_KTRAJ xDim:xDim yDim:yDim];
	[traj initRadialTraj];
//	[traj saveAsKOImage:@"../test_img/traj.img"];

	dist = mk_dist_img(traj);
	tab = mk_wt_tab(dist);

	for (i = 0; i < tabLen; i++) {
		tmp_i[i] = 1.0;
	}
	for (iter = 0; iter < 60; iter++) {
		grid_to_traj(tab, tmp_o, tmp_i);
		for (i = 0; i < tabLen; i++) {
			if (tmp_o[i] != 0) {
				tmp_i[i] /= tmp_o[i];
			}
		}
		er = eval_error(tmp_o, tabLen);
		printf("%d %16.12f\n", iter, er);
	}
	for (i = 0; i < tabLen; i++) {
		printf("%d %f %f\n", i, tmp_i[i], tmp_o[i]);
	}
	free_wt_tab(tab);

	return 0;
}

int
test6()
{
	int		i, N = 256;
	float	a = 5.9; //4.0;
	float	b = a * M_PI;
	float	A, x, xx;
	float	kern[N], ikern[N];

// Kaiser window
	A = besseli0(b);
	for (i = 0; i < N; i++) {
		x = (float)i / (N - 1);
		kern[i] = besseli0(b * sqrt(1.0 - x * x)) / A;
	//	printf("%d %16.12f %16.12f\n", i, x, kern[i]);
	}
	dump_kern(kern, N, N);	// x

// FT of Kaiser window
	A = sinh(b) / b;
	for (i = 0; i < N; i++) {
		x = (float)i * 8 / (N - 1);
		xx = a*a - x*x;
		if (xx == 0) {
			ikern[i] = 1.0 / A;
		} else
		if (xx > 0) {
			xx = M_PI * sqrt(xx);
			ikern[i] = sinh(xx) / xx / A;
		} else {
			xx = M_PI * sqrt(-xx);
			ikern[i] = sin(xx) / xx / A;
		}
	}
	dump_kern(ikern, N, N);

	return 0;
}

#define BIZ_EPS 1e-20 // Max error acceptable 

float bessel_test(float x)
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

int
test7()
{
	int		i;
	float	x, b;

	for (i = 0; i < 256; i++) {
		x = (float)i * 5 / 256;
		b = bessel_test(x) - besseli0(x);
	//	b = besseli0(x);
		printf("%d %10.8f\n", i, b);
	}
	return 0;
}

