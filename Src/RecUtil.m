//
//  RecUtil.m
//  utility functions
//

#import "RecUtil.h"
#import <NumKit/NumKit.h>

#import <sys/time.h>
#import "timer_macros.h"


//#import "RecUtil.h"

// ============= util functions =================
// error est util
float
Rec_dotprod(float *p1, float *p2, int len)
{
	int		i;
	float	sum;

	sum = 0;
	for (i = 0; i < len; i++) {
		sum += p1[i] * p2[i];
	}
	return sum;
}

float	Rec_L2_norm(float *p, int len)
{
	int		i;
	float	sum;

	sum = 0;
	for (i = 0; i < len; i++) {
		sum += p[i] * p[i];
	}
	return sum;
}

float	Rec_L2_dist(float *p1, float *p2, int len)
{
	int		i;
	float	sum, dif;

	sum = 0;
	for (i = 0; i < len; i++) {
		dif = p1[i] - p2[i];
		sum += dif * dif;
	}
	return sum;
}

void
Rec_normalize(float *p, int len)
{
	int		i;
	float	nm = Rec_L2_norm(p, len);

	for (i = 0; i < len; i++) {
		p[i] /= nm;
	}
}

// power-of-two
int
Rec_po2(int n)
{
    return Rec_up2Po2(n);
}

int
Rec_up2Po2(int n)
{
	int		i;

    for (i = 1; i < n; i *= 2) {
    }
    return i;
}

int
Rec_down2Po2(int n)
{
    int     i;

    for (i = 1; i < n; i *= 2) {
    }
	if (i != n) i /= 2;
    return i;
}

// complex mult (cpx1 *= cpx2)
void
Rec_cpx_mul(float *dst_re, float *dst_im, int dst_skip, float *src_re, float *src_im, int src_skip, int len)
{
	int		i, ix_d, ix_s;
	float	sre, sim, dre, dim;

	for (i = ix_d = ix_s = 0; i < len; i++) {
		dre = dst_re[ix_d]; dim = dst_im[ix_d];
		sre = src_re[ix_s]; sim = src_im[ix_s];
		dst_re[ix_d] = dre * sre - dim * sim;
		dst_im[ix_d] = dre * sim + dim * sre;
		ix_d += dst_skip;
		ix_s += src_skip;
	}
}

void
Rec_cpx_cmul(float *dst_re, float *dst_im, int dst_skip, float *src_re, float *src_im, int src_skip, int len)
{
	int		i, ix_d, ix_s;
	float	sre, sim, dre, dim;

	for (i = ix_d = ix_s = 0; i < len; i++) {
		dre = dst_re[ix_d]; dim = dst_im[ix_d];
		sre = src_re[ix_s]; sim = -src_im[ix_s];
		dst_re[ix_d] = dre * sre - dim * sim;
		dst_im[ix_d] = dre * sim + dim * sre;
		ix_d += dst_skip;
		ix_s += src_skip;
	}
}

// 0 th phase (phase of avg) estimate unit:(rad)
float
Rec_est_0th(float *re, float *im, int skip, int len)
{
	float	sumr, sumi, p0;

    vDSP_sve(re, skip, &sumr, len);
    vDSP_sve(im, skip, &sumi, len);

    p0 = atan2(sumi, sumr);

	return p0;
}

void
Rec_est_correl(float *re, float *im, int skip, int len, float *sumr, float *sumi)
{
	int		i, ix;

	for (i = ix = 0; i < len - 1; i++, ix += skip) {
		*sumr += re[ix + skip] * re[ix] + im[ix + skip] * im[ix];
		*sumi += im[ix + skip] * re[ix] - re[ix + skip] * im[ix];
	}
}

// 1st phs (linear phase over FOV) estimate, unit:rad / FOV
// result can be more than 2PI (which is OK)
float
Rec_est_1st(float *re, float *im, int skip, int len)
{
	float	sumr, sumi;
	float	p1;
//	int		i, ix;

	sumr = sumi = 0;
//	for (i = ix = 0; i < len - 1; i++, ix += skip) {
//		sumr += re[ix + skip] * re[ix] + im[ix + skip] * im[ix];
//		sumi += im[ix + skip] * re[ix] - re[ix + skip] * im[ix];
//	}
    Rec_est_correl(re, im, skip, len, &sumr, &sumi);
    p1 = atan2(sumi, sumr);

	return p1 * len;
}

void
Rec_pcorr(float *re, float *im, int skip, int len, float *phs)
{
	float	th, cs, sn;
	float	tmpr, tmpi;
	int		i, ix;

	for (i = ix = 0; i < len; i++, ix += skip) {
		th = phs[i];
		cs = cos(-th);
		sn = sin(-th);
		tmpr = re[ix];
		tmpi = im[ix];
		re[ix] = tmpr * cs - tmpi * sn;
		im[ix] = tmpr * sn + tmpi * cs;
	}
}

// 0th order phase correction
// phs unit: radian
void
Rec_corr0th(float *re, float *im, int skip, int len, float p0)
{
	float	th, cs, sn;
	float	tmpr, tmpi;
	int		i, ix;

	for (i = ix = 0; i < len; i++, ix += skip) {
		th = p0;
		cs = cos(-th);
		sn = sin(-th);
		tmpr = re[ix];
		tmpi = im[ix];
		re[ix] = tmpr * cs - tmpi * sn;
		im[ix] = tmpr * sn + tmpi * cs;
	}
}

// 1st order phase correction (do this before 0th)
// center   : (N-1)/2
// phs unit : radian / FOV
void
Rec_corr1st(float *re, float *im, int skip, int len, float p1)
{
	float	x, th, cs, sn;
	float	tmpr, tmpi;
	int		i, ix;

	for (i = ix = 0; i < len; i++, ix += skip) {
		x = (i - ((float)len - 1)/2) / len;
		th = x * p1;
		cs = cos(-th);
		sn = sin(-th);
		tmpr = re[ix];
		tmpi = im[ix];
		re[ix] = tmpr * cs - tmpi * sn;
		im[ix] = tmpr * sn + tmpi * cs;
	}
}

// phase correction 2D
float
Rec_est1_x(float *re, float *im, int xDim, int yDim)
{
	float	sumr, sumi;
    float   *p, *q;
	float	p1;
	int		i, j;

	sumr = sumi = 0;
    p = re;
    q = im;
	for (i = 0; i < yDim; i++) {
        for (j = 0; j < xDim - 1; j++) {
            sumr += p[j + 1] * p[j] + q[j + 1] * q[j];
            sumi += q[j + 1] * p[j] - p[j + 1] * q[j];
        }
        p += xDim;
        q += xDim;
	}
    p1 = atan2(sumi, sumr);

	return p1 * xDim;	// for FOV. can be more than 2PI (which is OK)
}

// 2D corr using one phase value
void
Rec_corr1_x(float *re, float *im, int xDim, int yDim, float p1)
{
	float	x, th, cs, sn;
	float	tmpr, tmpi;
    float   *p, *q;
	int		i, j;

    p = re;
    q = im;
	for (i = 0; i < yDim; i++) {
        for (j = 0; j < xDim; j++) {
            x = (i - ((float)xDim - 1)/2) / xDim;
            th = x * p1;
            cs = cos(-th);
            sn = sin(-th);
            tmpr = p[j];
            tmpi = q[j];
            p[j] = tmpr * cs - tmpi * sn;
            q[j] = tmpr * sn + tmpi * cs;
        }
        p += xDim;
        q += xDim;
	}
}

float
Rec_est1_y(float *re, float *im, int xDim, int yDim)
{
	float	sumr, sumi;
    float   *p, *q;
	float	p1;
	int		i, j, ix;

	sumr = sumi = 0;
    p = re;
    q = im;
	for (i = 0; i < xDim; i++) {
        for (j = ix = 0; j < yDim - 1; j++, ix += xDim) {
            sumr += p[ix + xDim] * p[ix] + q[ix + xDim] * q[ix];
            sumi += q[ix + xDim] * p[ix] - p[ix + xDim] * q[ix];
        }
        p += 1;
        q += 1;
	}
    p1 = atan2(sumi, sumr);

	return p1 * yDim;	// for FOV. can be more than 2PI (which is OK)
}

void
Rec_corr1_y(float *re, float *im, int xDim, int yDim, float p1)
{
	float	y, th, cs, sn;
	float	tmpr, tmpi;
    float   *p, *q;
	int		i, j, ix;

    p = re;
    q = im;
	for (i = 0; i < xDim; i++) {
        for (j = ix = 0; j < yDim; j++, ix += xDim) {
            y = (j - ((float)yDim - 1)/2) / yDim;
            th = y * p1;
            cs = cos(-th);
            sn = sin(-th);
            tmpr = p[ix];
            tmpi = q[ix];
            p[ix] = tmpr * cs - tmpi * sn;
            q[ix] = tmpr * sn + tmpi * cs;
        }
        p += 1;
        q += 1;
	}
}

// moving average
void
Rec_smooth(float *p, int n, int ks)
{
    int     i, j, k;
    int     ks2 = ks/2;
    float   *buf, w;

    buf = (float *)malloc(n * sizeof(float));
    for (i = 0; i < n; i++) {
        w = 0;
        for (j = 0; j < ks; j++) {
            k = i + j - ks2;
            if (k >= 0 && k < n) {
                w += p[k];
            }
        }
        buf[i] = w / ks;
    }
    for (i = 0; i < n; i++) {
        p[i] = buf[i];
    }
    free(buf);
}

// EPIpcorr (by K. Oshio)
void
Rec_epi_pcorr(float *p, float *q, int xDim, int yDim, BOOL se)
{
    static float    *wc, *wp;
    float           *pp, *qq;
    float           *cr, *ci, *pr, *pi;
    int             i, j, size;
    int             ix1, ix2, tmp;
    int             width = 7; //9;
    float           re, im, er, ei, th;
    float           mg1, mg2;
	int				w = yDim * 0.25;	// yDim * 0.25

// make cos tab
    if (p == NULL) {
        size = sizeof(float) * yDim;
        wc = (float *)malloc(size); // central
        wp = (float *)malloc(size); // peripheral
        for (i = 0; i < yDim; i++) {
            wc[i] = wp[i] = 0;
        }
        for (i = 0; i < w; i++) {
            th = i * M_PI / w;
			th = 0.5 + 0.5 * cos(th);
			wp[i] = th;
			wp[yDim - i - 1] = th;
			wc[yDim/2 + i] = th;
			wc[yDim/2 - i] = th;
		}
	//	for (i = 0; i < yDim; i++) {
	//		printf("%d %f %f\n", i, wp[i], wc[i]);
	//	}
        return;
    }
// dealloc
    if (xDim == 0) {
        free(wc);
        free(wp);
        return;
    }

// else (normal case)
    size = xDim * sizeof(float);
    cr = (float *)malloc(size); // central (re)
    ci = (float *)malloc(size); // central (im)
    pr = (float *)malloc(size); // peripheral (re)
    pi = (float *)malloc(size); // peripheral (im)

// tmp image
    size = xDim * yDim * sizeof(float);
    pp = (float *)malloc(size);
    qq = (float *)malloc(size);
    for (i = 0; i < xDim * yDim; i++) {
        pp[i] = p[i];
        qq[i] = q[i];
    }

    if (!se) {  // GE EPI
        for (j = 0; j < xDim; j++) {
        // for every vertical line
            for (i = 0; i < yDim/2; i++) {
                ix1 = i * xDim + j;                 // upper half
                ix2 = (i + (yDim / 2)) * xDim + j;  // lower half
                mg1 = pp[ix1]*pp[ix1] + qq[ix1]*qq[ix1];
                mg1 = sqrt(mg1);
                mg2 = pp[ix2]*pp[ix2] + qq[ix2]*qq[ix2];
                mg2 = sqrt(mg2);
                if (mg1 < mg2) {    // if lower is stronger, swap
                    tmp = ix1;      // -> ix1 is stronger of upper/lower
                    ix1 = ix2;
                    ix2 = tmp;
                    re = mg1;
                    mg1 = mg2;
                    mg2 = re;
                }
                re = pp[ix1]; im = qq[ix1];
                er = pp[ix2]; ei = qq[ix2];
                th = atan2(-re*ei + im*er, re*er + im*ei);
                pp[ix1] = mg1;
                qq[ix1] = 0;
                pp[ix2] = mg2 * cos(-th);
                qq[ix2] = mg2 * sin(-th);
            }
        }
    }
    // centrer / periphery -> function 2 ###
    for (j = 0; j < xDim; j++) {
        cr[j] = ci[j] = pr[j] = pi[j] = 0;
    }
    for (j = 0; j < xDim; j++) {
        for (i = 0; i < yDim; i++) {
            ix1 = i * xDim + j;
            cr[j] += pp[ix1] * wc[i];
            ci[j] += qq[ix1] * wc[i];
            pr[j] += pp[ix1] * wp[i];
            pi[j] += qq[ix1] * wp[i];
        }
    }

    // 1-D filter
    Rec_smooth(cr, xDim, width);
    Rec_smooth(ci, xDim, width);
    Rec_smooth(pr, xDim, width);
    Rec_smooth(pi, xDim, width);

    // center/periphery -> even/odd -> function 3 ###
    for (j = 0; j < xDim; j++) {
        re = cr[j]; im = ci[j];
        er = pr[j]; ei = pi[j];
        th = -atan2(im + ei, re + er);
        cr[j] = cos(th);
        ci[j] = sin(th);
        th = -atan2(im - ei, re - er);
        pr[j] = cos(th);
        pi[j] = sin(th);
    }

    // corr
    Rec_fft_y(p, q, xDim, yDim, REC_INVERSE);
    for (i = 0; i < yDim; i++) {
        if (i % 2 == 0) {
            for (j = 0; j < xDim; j++) {
                ix1 = i * xDim + j;
                re = p[ix1];
                im = q[ix1];
                er = cr[j];
                ei = ci[j];
                p[ix1] = re * er - im * ei;
                q[ix1] = re * ei + im * er;
            }
        } else {
            for (j = 0; j < xDim; j++) {
                ix1 = i * xDim + j;
                re = p[ix1];
                im = q[ix1];
                er = pr[j];
                ei = pi[j];
                p[ix1] = re * er - im * ei;
                q[ix1] = re * ei + im * er;
            }
        }
    }
    Rec_fft_y(p, q, xDim, yDim, REC_FORWARD);

    // free mem
    free(cr); free(ci);
    free(pr); free(pi);
    free(pp); free(qq);
}

// 1D phase est
// uses Rec_cheb and Num_powel
void
Rec_est_poly_1d(float *coef, int order, float *re, float *im, int skip, int len)
{
	RecChebSetup	*setup;
	Num_param		*param;
	float			*mg, *ph, *est, mx;
	int				i, ix;
	float			(^cost)(float *);
	int				iter;
	float			err;

	setup = Rec_cheb_setup(len, order);
	mg = (float *)malloc(sizeof(float) * len);
	ph = (float *)malloc(sizeof(float) * len);
	est = (float *)malloc(sizeof(float) * len);

    cost = ^float(float *prm) {
        float   cst = 0;
		int		i;
		Rec_cheb_1d(est, 1, prm, 1, setup, REC_FORWARD);
		for (i = 0; i < len; i++) {
			if (mg[i] == 0) {
				ph[i] = est[i] = 0;
			}
		}
		cst = Rec_L2_dist(ph, est, len);
        return cst;    
    };

	// calc mg and phs
	mx = 0;
	for (i = ix = 0; i < len; i++, ix += skip) {
		mg[i] = sqrt(re[ix] * re[ix] + im[ix] * im[ix]);
		if (mx < mg[i]) mx = mg[i];
		ph[i] = atan2(im[ix], re[ix]);
	}
	// unwrap phs
	Rec_unwrap_1d(ph, len, 1);
	// make mask
	mx *= 0.1;
	for (i = 0; i < len; i++) {
		if (mg[i] < mx) mg[i] = 0;
	}
	// powell
	param = Num_alloc_param(order);
	for (i = 0; i < order; i++) {
		param->data[i] = 0;
	}
	iter = Num_powell(param, cost, &err);
//printf("iter = %d, err = %f\n", iter, err);
	// result
	for (i = 0; i < order; i++) {
		coef[i] = param->data[i];
	}
	// cleanup
	Rec_free_cheb_setup(setup);
	Num_free_param(param);
	free(mg);
	free(ph);
	free(est);
}

void
Rec_corr_poly_1d(float *coef, int order, float *re, float *im, int skip, int len)
{
	RecChebSetup	*setup;
	float			*phs;

	setup = Rec_cheb_setup(len, order);
	phs = (float *)malloc(sizeof(float) * len);

	Rec_cheb_1d(phs, 1, coef, 1, setup, REC_FORWARD);

	Rec_pcorr(re, im, skip, len, phs);

	// cleanup
	Rec_free_cheb_setup(setup);
	free(phs);
}

// ver2 ... grad based
void
Rec_unwrap_1d(float *p, int n, int skip)
{
	float	*grd = (float *)malloc(sizeof(float) * n);
	int		i;
	float	ph;

	// unwrap grad
	for (i = 0; i < n-1; i++) {
		grd[i] = p[(i + 1) * skip] - p[i * skip];
		if (grd[i] > M_PI) {
			grd[i] -= 2 * M_PI;
		} else
		if (grd[i] < -M_PI) {
			grd[i] += 2 * M_PI;
		}
	}
	// integ
	for (i = 1; i < n; i++) {
		p[i * skip] = p[(i - 1) * skip] + grd[i];
	}
	// center
	ph = p[n/2 * skip];
//	i = rint(ph / (M_PI));
//	ph = i * M_PI;
	for (i = 0; i < n; i++) {
		p[i * skip] -= ph;
	}

	free(grd);
}

// ### currently can't handle more than 2 PI
void
Rec_unwrap_1dx(float *p, int n, int skip)
{
	int		i, ix, npi;
	float	th0, th, dif;

	th0 = p[n/2 * skip];
	npi = 0;
	for (i = 1; i < n/2; i++) {
		ix = (n/2 + i) * skip;
		th = p[ix];
		dif = th - th0;
		if (dif > M_PI) {
			npi++;
		} else
		if (dif < -M_PI) {
			npi--;
		}
		th -= M_PI * 2 * npi;
		th0 = p[ix];
		p[ix] = th;
	}
	th0 = p[n/2 * skip];
	npi = 0;
	for (i = 1; i <= n/2; i++) {
		ix = (n/2 - i) * skip;
		th = p[ix];
		dif = th - th0;
		if (dif > M_PI) {
			npi++;
		} else
		if (dif < -M_PI) {
			npi--;
		}
		th -= M_PI * 2 * npi;
		th0 = p[ix];
		p[ix] = th;
	}
//	for (i = 0; i < n; i++) {
//		printf("%d %f\n", i, p[i]);
//	}
}

// 2D phase est
/*
void
Rec_est_poly_2d(float *coef, int ordx, int ordy, float *re, float *im, int xDim, int yDim)
{
//	RecChebSetup	*setup;
	RecImage		*kern;
	Num_param		*param;
	float			*mg, *ph, *est;
	int				i, len, pdim;
	float			(^cost)(float *);
	int				iter;
	float			err;

	kern = Rec_cheb_mk_2d_kern(xDim, yDim, ordx, ordy);

	len = xDim * yDim;
	pdim = ordx * ordy;

	mg = (float *)malloc(sizeof(float) * len);	// magnitude & mask
	ph = (float *)malloc(sizeof(float) * len);
	est = (float *)malloc(sizeof(float) * len);

    cost = ^float(float *prm) {
		float	cst;
		int		ii;
		// calc ms error over image (within mask)
		Rec_cheb_2d_expansion(est, prm, kern);
		for (ii = 0; ii < len; ii++) {
			if (mg[ii] == 0) {
				est[ii] = 0;
			}
		}
		cst = Rec_L2_dist(ph, est, len);
        return cst;    
    };

	// calc mg and phs
	for (i = 0; i < len; i++) {
		mg[i] = sqrt(re[i] * re[i] + im[i] * im[i]);
		if (re[i] == 0) {
			mg[i] = ph[i] = 0;
		} else {
			ph[i] = atan2(im[i], re[i]);
			if (0) {	// moved after unwrap
				if (ph[i] < -M_PI/4 || ph[i] > M_PI/4) {
					ph[i] = mg[i] = 0;
				}
			}
		}
	}
	// 1d unwrap
	if (1) {
		for (i = 0; i < yDim; i++) {
			Rec_unwrap_1d(ph + (i * xDim), xDim, 1);
		}
		for (i = 0; i < xDim; i++) {
			Rec_unwrap_1d(ph + i, xDim, xDim);
		}
	}
	if (1) {	// this is necessary
		for (i = 0; i < len; i++) {
			if (ph[i] < -M_PI/4 || ph[i] > M_PI/4) {
				ph[i] = mg[i] = 0;
			}
		}
	}

	// powell
	param = Num_alloc_param(pdim);
	for (i = 0; i < pdim; i++) {
		param->data[i] = 0;
	}

//TIMER_ST
	iter = Num_powell(param, cost, &err);
//TIMER_END("powel")
printf("2d pest: iter = %d, err = %f\n", iter, err);
	// result
	for (i = 0; i < pdim; i++) {
		coef[i] = param->data[i];
	}

	// cleanup
	Num_free_param(param);
	free(mg);
	free(ph);
	free(est);
}
*/

void
Rec_corr_poly_2d(float *coef, int ordx, int ordy, float *re, float *im, int xDim, int yDim)
{
	RecImage		*kern;
	float			*phs;
	int				len = xDim * yDim;

	phs = (float *)malloc(sizeof(float) * len);
	kern = Rec_cheb_mk_2d_kern(xDim, yDim, ordx, ordy);

	Rec_cheb_2d_expansion(phs, coef, kern);
	Rec_pcorr(re, im, 1, len, phs);

	free(phs);
}

// for 2D, just check phase > M_PI or < -M_PI, and set mask to 0
void
Rec_chk_phase(float *ph, float *mg, int xDim, int yDim, float mx)
{
	int		i, len = xDim * yDim;
	for (i = 0; i < len; i++) {
		if (ph[i] < -mx || ph[i] > mx) {
			mg[i] = ph[i] = 0;
		}
	}
}

// mask for pure-even part
RecImage *
Rec_nyquist_seg(RecImage *sm, RecImage *df)
{
	RecImage	*mask;
	float		*ps, *pd, *pm;
	int			i, dataLength;
	float		th = 0.025;

	mask = [RecImage imageOfType:RECIMAGE_REAL withImage:sm];
	pm = [mask data];
	dataLength = [mask dataLength];

	[sm magnitude];
	[sm thresAt:th];
	ps = [sm data];

	[df magnitude];
	[df thresAt:th];
	pd = [df data];

	for (i = 0; i < dataLength; i++) {
		if (ps[i] > 0 && pd[i] == 0) {
			pm[i] = 1;
		} else {
			pm[i] = 0;
		}
	}
	return mask;
}

void sort_mg(float *p, int n)
{
	int		(^compar)(const void *, const void *);

	compar = ^int(const void *p1, const void *p2) {
		float pp = *((float *)p1);
		float qq = *((float *)p2);
		if (pp > qq) {
			return 1;
		} else 
		if (pp == qq) {
			return 0;
		} else {
			return -1;
		}
	};
	qsort_b(p, n, sizeof(float), compar);
}

void pcorr_line(float *p, float *q, int xDim, int yDim, int x)
{
	int		i, ix;
	float	*mg, m;
	float	*wn, w;

// calc mag
	mg = (float *)malloc(sizeof(float) * yDim);
	for (i = 0; i < yDim; i++) {
		ix = i * xDim + x;
		m = p[ix] * p[ix] + q[ix] * q[ix];
		mg[i] = sqrt(m);
	}
// make sigmoid window
	wn = (float *)malloc(sizeof(float) * yDim);
	for (i = 0; i < yDim; i++) {
		w = (float)i / yDim;
		if (w < 0.10) {
			wn[i] = 1.0;
		} else
		if (w < 0.15) {
			wn[i] = cos((w - 0.1) / 0.05 * M_PI) * 0.5 + 0.5;
		} else {
			wn[i] = 0;
		}
	}
// sort mg
	sort_mg(mg, yDim);
// win
	for (i = 0; i < yDim; i++) {
		mg[i] *= wn[i];
		printf("%d %f\n", i, mg[i]);
	}
}

// DCT base... replace with poly 2d
void
Rec_pcorr_fine(float *p, float *q, int xDim, int yDim)
{
    // minimize imag part energy after correction
    // param: 0, 1x, 1y, 2x, 2y (chebyshev)
    int             ii, iter;   // [0..yDim, xDim]
    int             len;
    int             order = 3;  // 0, 1, 2
    Num_param       *param;   // 2D cos expantion
    float           minval;
    float           (^cost)(float *param);
    __block float   *th, *im;
    RecDctSetup     *setup;

    // alloc work area
    len = xDim * yDim;
    th = (float *)malloc(sizeof(float) * len);
    im = (float *)malloc(sizeof(float) * len);

    setup = Rec_dct_setup(xDim, order);

    cost = ^float(float *pr) {
        float   err = 0;    // imag part power
        float   cs, sn;
        int     i;

        // param -> coef
        Rec_dct_2d(th, pr, setup, REC_FORWARD); // coef -> th

        if (0) {    // time: 11.761829 (sec) pcorrFine
            err = 0;
            for (i = 0; i < len; i++) {
                cs = cos(th[i]);
                sn = sin(th[i]);
            //    im[i] = -p[i] * sn + q[i] * cs;
                im[i] = -p[i] * th[i] + q[i];  // small th approximation (17 s -> 6 s)
                err += im[i] * im[i];
            }
        } else {    // 0.970223 (sec) pcorrFin
            vDSP_vneg(th, 1, th, 1, len);
            vDSP_vma(p, 1, th, 1, q, 1, im, 1, len);
            vDSP_dotpr(im, 1, im, 1, &err, len);
        }

        return err;
    };

    param = Num_alloc_param(order * order);

    // init param
    for (ii = 0; ii < order * order; ii++) {
        param->data[ii] = 0;
    }
printf("Powell ...\n");
TIMER_ST
    iter = Num_powell(param, cost, &minval);
TIMER_END("pcorrFine");
printf("iter = %d\n", iter);
for (ii = 0; ii < order * order; ii++) {
    printf("%f ", param->data[ii]);
}
    // do final correction to p, q
    Rec_dct_2d_corr(p, q, param->data, setup);

    // free up memory
    Rec_free_dct_setup(setup);
    Num_free_param(param);
    free(th);
    free(im);
}

// new func, also returns mx value
float
Rec_find_peak(float *p, int skip, int n)
{
	float		mx, pos;

	pos = Rec_find_peak_mx(p, skip, n, &mx);
	return pos;
}

float
Rec_find_peak_mx(float *p, int skip, int n, float *mx)
{
    float       frac;
    vDSP_Length ix;

    vDSP_maxvi(p, skip, mx, &ix, n);   // find max val with index
	if (ix <= 0 || ix >= n * skip) {
		frac = 0;
	} else {
		frac = Rec_find_peak_frac(p + ix, skip, n);
	}
    return ix + frac;
}

// 2D
NSPoint
Rec_find_peak2(float *p, int xDim, int yDim)
{
    NSPoint         pt;
    float           mx; // val is not used

	pt = Rec_find_peak2_mx(p, xDim, yDim, &mx);

    return pt;
}

// unit: pixels
NSPoint
Rec_find_peak2_mx(float *p, int xDim, int yDim, float *mx)
{
    NSPoint         pt;
    unsigned long   ix, n = xDim * yDim;

    vDSP_maxvi(p, 1, mx, &ix, n);   // find max val with index
    // frac
    pt.x = Rec_find_peak_frac(p + ix,   1,      xDim);
    pt.y = Rec_find_peak_frac(p + ix,   xDim,   yDim);
    // calc integer part from ix
    pt.x += (ix % xDim) - xDim / 2.0;
    pt.y += (ix / xDim) - yDim / 2.0;

    return pt;
}

NSPoint
Rec_find_peak2_phs(float *p, float *q, int xDim, int yDim, float *phs)
{
    NSPoint         pt;
	float			mx, re, im;
    unsigned long   ix, n = xDim * yDim;

    vDSP_maxvi(p, 1, &mx, &ix, n);   // find max val with index
    // frac
    pt.x = Rec_find_peak_frac(p + ix,   1,      xDim);
    pt.y = Rec_find_peak_frac(p + ix,   xDim,   yDim);
    // calc integer part from ix
    pt.x += (ix % xDim) - xDim / 2.0;
    pt.y += (ix / xDim) - yDim / 2.0;
	// peak phase
	re = p[ix] + p[ix+1] + p[ix-1];
	im = q[ix] + q[ix+1] + q[ix-1];
	*phs = atan2(im, re);

    return pt;
}

// 3D
RecVector
Rec_find_peak3(float *p, int xDim, int yDim, int zDim)
{
    RecVector       v = {0, 0, 0};
    float           mx; // val is not used

	v = Rec_find_peak3_mx(p, xDim, yDim, zDim, &mx);

    return v;
}

RecVector
Rec_find_peak3_mx(float *p, int xDim, int yDim, int zDim, float *mx)
{
    RecVector       v = {0, 0, 0};
    unsigned long   ix, n = xDim * yDim * zDim;

    vDSP_maxvi(p, 1, mx, &ix, n);   // find max val with index
	if (ix < xDim * yDim || ix > n - xDim * yDim - 1) {
		return v;
	}
    // frac first
    v.x = Rec_find_peak_frac(p + ix, 1,              xDim);
    v.y = Rec_find_peak_frac(p + ix, xDim,           yDim);
    v.z = Rec_find_peak_frac(p + ix, xDim * yDim,    zDim);
    // calc integer part from ix
    v.x += (ix % xDim)          - xDim / 2.0;
    v.y += (ix / xDim) % yDim   - yDim / 2.0;
    v.z += (ix / xDim / yDim)   - zDim / 2.0;

    return v;
}

// 3 pt quad / gaussian
float
Rec_find_peak_frac(float *p, int skip, int n)
{
    float       mx;
    float       r1, r2;
    BOOL        quad = NO;  // quad or gauss

    r1 = p[-skip];
    r2 = p[ skip];
    mx = p[ 0];

// error condition
	if (mx == 0 || r1 <= 1e-8 || r2 <= 1e-8) {
		return 0.0;
	}

    if (quad) {    // quad
        r1 = mx - r1;
        r2 = mx - r2;
    } else {    // gauss
        r1 = log(mx / r1);
        r2 = log(mx / r2);
    }
    return 0.5 * (r1 - r2) / (r1 + r2);
}

void
Rec_fft_x(float *re, float *im, int xDim, int yDim, int dir)
{
	FFTSetup			setup;
	DSPSplitComplex		src;
	float				scale;
	int					i, len, len2, direction;
	unsigned int		lg2;

	len = xDim;
	lg2 = log2(len);
	setup = vDSP_create_fftsetup(lg2, kFFTRadix2);
	if (dir == REC_FORWARD) {
		direction = kFFTDirection_Forward;
	} else {
		direction = kFFTDirection_Inverse;
	}

    // x-ft
    for (i = 0; i < yDim; i++) {
        src.realp = re + i * xDim;
        src.imagp = im + i * xDim;
        len2 = xDim/2;
        vDSP_vswap(src.realp, 1, src.realp + len2, 1, len2);
        vDSP_vswap(src.imagp, 1, src.imagp + len2, 1, len2);
        vDSP_fft_zip(setup, &src, 1, lg2, direction); 
        vDSP_vswap(src.realp, 1, src.realp + len2, 1, len2);
        vDSP_vswap(src.imagp, 1, src.imagp + len2, 1, len2);
        if (direction == kFFTDirection_Inverse) {
            scale = 1.0 / xDim;
            vDSP_vsmul(src.realp, 1, &scale, src.realp, 1, xDim);
            vDSP_vsmul(src.imagp, 1, &scale, src.imagp, 1, xDim);
        }
    }
	vDSP_destroy_fftsetup(setup);
}

void
Rec_fft_y(float *re, float *im, int xDim, int yDim, int dir)
{
	FFTSetup			setup;
	DSPSplitComplex		src;
	float				scale;
	int					i, len, len2, direction;
	unsigned int		lg2;

	len = yDim;
	lg2 = log2(len);
	setup = vDSP_create_fftsetup(lg2, kFFTRadix2);
	if (dir == REC_FORWARD) {
		direction = kFFTDirection_Forward;
	} else {
		direction = kFFTDirection_Inverse;
	}

    // y-ft
    for (i = 0; i < xDim; i++) {
        src.realp = re + i;
        src.imagp = im + i;
        len2  = yDim/2;
        vDSP_vswap(src.realp, xDim, src.realp + len2*xDim, xDim, len2);
        vDSP_vswap(src.imagp, xDim, src.imagp + len2*xDim, xDim, len2);
        vDSP_fft_zip(setup, &src, xDim, lg2, direction); 
        vDSP_vswap(src.realp, xDim, src.realp + len2*xDim, xDim, len2);
        vDSP_vswap(src.imagp, xDim, src.imagp + len2*xDim, xDim, len2);
        if (direction == kFFTDirection_Inverse) {
            scale = 1.0 / yDim;
            vDSP_vsmul(src.realp, xDim, &scale, src.realp, xDim, yDim);
            vDSP_vsmul(src.imagp, xDim, &scale, src.imagp, xDim, yDim);
        }
    }
	vDSP_destroy_fftsetup(setup);
}

// func version FFT
FFTSetup
Rec_fft_setup(int dim)
{
	FFTSetup			setup;
	unsigned int		lg2;

	lg2 = log2(dim);
	setup = vDSP_create_fftsetup(lg2, kFFTRadix2);
	return setup;
}

void
Rec_free_fft_setup(FFTSetup setup)
{
	vDSP_destroy_fftsetup(setup);
}

void
Rec_fft_1d(float *re, float *im, int len, int dir, FFTSetup setup)
{
	DSPSplitComplex		src;
	float				scale;
	int					len2, direction;
	unsigned int		lg2;

	if (dir == REC_FORWARD) {
		direction = kFFTDirection_Forward;
	} else {
		direction = kFFTDirection_Inverse;
	}

	src.realp = re;
	src.imagp = im;
	len2  = len/2;
	lg2 = log2(len); 
	vDSP_vswap(src.realp, len, src.realp + len2*len, len, len2);
	vDSP_vswap(src.imagp, len, src.imagp + len2*len, len, len2);
	vDSP_fft_zip(setup, &src, len, lg2, direction); 
	vDSP_vswap(src.realp, len, src.realp + len2*len, len, len2);
	vDSP_vswap(src.imagp, len, src.imagp + len2*len, len, len2);
	if (direction == kFFTDirection_Inverse) {
		scale = 1.0 / len;
		vDSP_vsmul(src.realp, len, &scale, src.realp, len, len);
		vDSP_vsmul(src.imagp, len, &scale, src.imagp, len, len);
	}
}

void
Rec_fft_2d(float *re, float *im, int xDim, int yDim, int dir)
{
    Rec_fft_x(re, im, xDim, yDim, dir);
    Rec_fft_y(re, im, xDim, yDim, dir);
}

RecDctSetup *
Rec_dct_setup(int dim, int order)
{
    RecDctSetup     *setup;
    int             i, k;
    float           th;

    setup = (RecDctSetup *)malloc(sizeof(RecDctSetup));
    setup->dim = dim;
    setup->order = order;
    setup->cs = (float *)malloc(sizeof(float) * dim * order);

	// DCT
    for (k = 0; k < order; k++) {
        for (i = 0; i < dim; i++) {
            th = k * (i + 0.5) * M_PI / dim;
            setup->cs[k * dim + i] = cos(th);
        }
    }

    return setup;
}

void
Rec_free_dct_setup(RecDctSetup *setup)
{
    if (setup) {
        if (setup->cs) {
            free(setup->cs);
        }
        free(setup);
    }
}

// new version
void
Rec_dct_1d(float *img, int i_skip, float *coef, int c_skip, RecDctSetup *setup, int direction)
{
	int		i, j;
	int		i_ix, c_ix;
	int		dim = setup->dim;
	int		order = setup->order;
	float	*cs = setup->cs;
	float	sum;

	if (direction == REC_FORWARD) {
		i_ix = 0;
		for (j = i_ix = 0; j < dim; j++, i_ix += i_skip) {
			sum = 0;
			for (i = c_ix = 0; i < order; i++, c_ix += c_skip) {
				sum += coef[c_ix] * cs[i * dim + j];
			}
			img[i_ix] = sum;
		}
	} else {	// REC_INVERSE
		for (i = c_ix = 0; i < order; i++, c_ix += c_skip) {
			sum = 0;
			for (j = i_ix = 0; j < dim; j++, i_ix += i_skip) {
				sum += img[i_ix] * cs[i * dim + j];
			}
			if (i == 0) {
				coef[c_ix] = sum / dim;
			} else {
				coef[c_ix] = sum / dim * 2;
			}
		}
	}
}

void
Rec_dct_2d(float *img, float *coef, RecDctSetup *setup, int direction)
{
    int			dim   = setup->dim;
    int			order = setup->order;
    int			i;
    float		*src, *dst;     // in, out
    float		*wk;        // work area



    wk = (float *)malloc(sizeof(float) * dim * order);
    if (direction == REC_FORWARD) { // coef -> img
        for (i = 0; i < order; i++) {
            src = coef + i * order;
            dst = wk + i * dim;
            Rec_dct_1d(dst, 1, src, 1, setup, REC_FORWARD);
        }
        for (i = 0; i < dim; i++) {
            src = wk + i;
            dst = img + i;
            Rec_dct_1d(dst, dim, src, dim, setup, REC_FORWARD);
        }
    } else {    // REC_INVERSE // img -> coef
        for (i = 0; i < dim; i++) {
            src = wk + i * order;
            dst = img + i * dim;
            Rec_dct_1d(dst, 1, src, 1, setup, REC_INVERSE);
        }
        for (i = 0; i < order; i++) {
            src = coef + i;
            dst = wk + i;
            Rec_dct_1d(dst, order, src, order, setup, REC_INVERSE);
        }
    }
    free(wk);
}

void
Rec_dct_2d_corr(float *p, float *q, float *coef, RecDctSetup *setup)
{
    int     i, len = setup->dim * setup->dim;
    float   *th, re, im, cs, sn;

    th = (float *)malloc(sizeof(float) * len);
    Rec_dct_2d(th, coef, setup, REC_FORWARD);
    for (i = 0; i < len; i++) {
        re = p[i]; im = q[i];
        cs = cos(th[i]); sn = sin(th[i]);
        p[i] =   re * cs + im * sn;
        q[i] = - im * cs + re * sn;
    }

    free(th);
}

RecChebSetup *
Rec_cheb_setup(int dim, int order)
{
    RecChebSetup     *setup;
    int             i, k;
    float           x, *Tk, *w, *nm;
	float			len;

    setup = (RecChebSetup *)malloc(sizeof(RecChebSetup));
    setup->dim = dim;
    setup->order = order;
    Tk = (float *)malloc(sizeof(float) * dim * order);
	setup->Tk = Tk;
	w = (float *)malloc(sizeof(float) * dim);
	setup->w = w;
	nm = (float *)malloc(sizeof(float) * dim);
	setup->nm = nm;

    for (k = 0; k < order; k++) {
		if (k == 0) {
			for (i = 0; i < dim; i++) {
				Tk[i] = 1.0;
			}
		} else
		if (k == 1) {
			for (i = 0; i < dim; i++) {
				x = ((float)i - dim/2) * 2 / dim;	// [-1 .. 1]
				Tk[k * dim + i] = x;
			}
		} else {
			for (i = 0; i < dim; i++) {
				x = ((float)i - dim/2) * 2 / dim;
				Tk[k * dim + i] = 2 * x * Tk[(k - 1) * dim + i]
										- Tk[(k - 2) * dim + i];
			}
		}
    }
	// weight
	for (i = 0; i < dim; i++) {
		x = ((float)i - dim/2) * 2 / dim;	// [-1 .. 1]
		if (i == 0) {
			w[i] = 0;
		} else {
			w[i] = 1.0 / sqrt(1.0 - x*x);
		//	if (w[i] > 3.0) w[i] = 0;
		}
	}
	// norm
    for (k = 0; k < order; k++) {
		len = 0;
		for (i = 0; i < dim; i++) {
			len += Tk[k * dim + i] * Tk[k * dim + i];
		}
		len = sqrt(len);
		nm[k] = len;
		for (i = 0; i < dim; i++) {
			Tk[k * dim + i] /= len;
		}
	}

	// dbg
	if (0) {
		for (i = 0; i < dim; i++) {
			printf("%d ", i);
			for (k = 0; k < order; k++) {
				printf("%f ", Tk[k * dim + i]);
			}
		//	printf("%f \n", w[i]);
			printf("\n");
		}
		exit(0);
	}

    return setup;
}

void
Rec_free_cheb_setup(RecChebSetup *setup)
{
    if (setup) {
        if (setup->Tk) {
            free(setup->Tk);
        }
        if (setup->w) {
            free(setup->w);
        }
        free(setup);
    }
}

void
Rec_cheb_1d(float *img, int i_skip, float *coef, int c_skip, RecChebSetup *setup, int direction)
{
	int		i, j;
	int		i_ix, c_ix;
	int		dim = setup->dim;
	int		order = setup->order;
	float	*Tk = setup->Tk;
	float	sum, *w = setup->w;

	if (direction == REC_FORWARD) {
		i_ix = 0;
		for (j = i_ix = 0; j < dim; j++, i_ix += i_skip) {
			sum = 0;
			for (i = c_ix = 0; i < order; i++, c_ix += c_skip) {
				sum += coef[c_ix] * Tk[i * dim + j];
			}
			img[i_ix] = sum;
		}
	} else {	// REC_INVERSE
		for (i = c_ix = 0; i < order; i++, c_ix += c_skip) {
			sum = 0;
			for (j = i_ix = 0; j < dim; j++, i_ix += i_skip) {
				sum += img[i_ix] * w[j] * Tk[i * dim + j];
			}
			coef[c_ix] = sum / dim;
		}
	}
}

// ### should be replaced by cheb_expansion
// ### INVERSE doens't work anyway
void
Rec_cheb_2d(float *img, float *coef, RecChebSetup *setup, int direction)
{
    int			dim   = setup->dim;
    int			order = setup->order;
    int			i;
    float		*src, *dst;     // in, out
    float		*wk;        // work area

    wk = (float *)malloc(sizeof(float) * dim * order);
    if (direction == REC_FORWARD) { // coef -> img
        for (i = 0; i < order; i++) {
            src = coef + i * order;
            dst = wk + i * dim;
            Rec_cheb_1d(dst, 1, src, 1, setup, REC_FORWARD);
        }
        for (i = 0; i < dim; i++) {
            src = wk + i;
            dst = img + i;
            Rec_cheb_1d(dst, dim, src, dim, setup, REC_FORWARD);
        }
    } else {    // REC_INVERSE // img -> coef
        for (i = 0; i < dim; i++) {
            src = wk + i * order;
            dst = img + i * dim;
            Rec_cheb_1d(dst, 1, src, 1, setup, REC_INVERSE);
        }
        for (i = 0; i < order; i++) {
            src = coef + i;
            dst = wk + i;
            Rec_cheb_1d(dst, order, src, order, setup, REC_INVERSE);
        }
    }
    free(wk);
}

RecImage *
Rec_cheb_mk_2d_kern(int xDim, int yDim, int ordx, int ordy)
{
	RecChebSetup	*set_x, *set_y;
	RecImage		*img;
	float			*p, wx, wy, *kx, *ky;
	int				i, j, ii, jj, ix;

	set_x = Rec_cheb_setup(xDim, ordx);
	set_y = Rec_cheb_setup(yDim, ordy);

	img = [RecImage imageOfType:RECIMAGE_REAL xDim:xDim yDim:xDim zDim:ordx * ordy];
	for (ii = ix = 0; ii < ordy; ii++) {
		ky = set_y->Tk + ii * yDim;
		for (jj = 0; jj < ordx; jj++, ix++) {
			p = [img data] + ix * xDim * yDim;
			kx = set_x->Tk + jj * xDim;
			for (i = 0; i < yDim; i++) {
				wy = ky[i];
				for (j = 0; j < xDim; j++) {
					wx = kx[j];
					p[i * xDim + j] = wx * wy;
				}
			}
		}
	}
	Rec_free_cheb_setup(set_x);
	Rec_free_cheb_setup(set_y);

	return img;
}

void
Rec_cheb_2d_expansion(float *p, float *coef, RecImage *kern)
{
	int			i, j, len, dim2;
	float		*kn;

	len = [kern xDim] * [kern yDim];
	dim2 = [kern zDim];
	for (j = 0; j < len; j++) {
		p[j] = 0;
	}
	for (i = 0; i < dim2; i++) {
		kn = [kern data] + i * len;
		for (j = 0; j < len; j++) {
			p[j] += kn[j] * coef[i];
		}
	}
}

void
Rec_cheb_2d_corr(float *p, float *q, float *coef, RecChebSetup *setup)
{
    int     i, len = setup->dim * setup->dim;
    float   *th, re, im, cs, sn;

    th = (float *)malloc(sizeof(float) * len);
    Rec_cheb_2d(th, coef, setup, REC_FORWARD);
    for (i = 0; i < len; i++) {
        re = p[i]; im = q[i];
        cs = cos(th[i]); sn = sin(th[i]);
        p[i] =   re * cs + im * sn;
        q[i] = - im * cs + re * sn;
    }

    free(th);
}

// Wavelet (Haar wavelet for the moment)
// kernel is not actually used
RecWaveSetup *
Rec_wave_setup(int dim)
{
	RecWaveSetup	*setup = (RecWaveSetup *)malloc(sizeof(RecWaveSetup));
	int				ks = 2;	// Haar
	setup->dim = dim;
	setup->kern_size = ks;
	setup->wk = (float *)malloc(sizeof(float) * dim);
	setup->sc = (float *)malloc(sizeof(float) * ks);
	setup->wv = (float *)malloc(sizeof(float) * ks);
	setup->sc[0] =  0.5;	//
	setup->sc[1] =  0.5;	// Haar
	setup->wv[0] =  0.5;	//
	setup->wv[1] = -0.5;	//

	return setup;
}

void
Rec_free_wave_setup(RecWaveSetup *setup)
{
	if (setup) {
		if (setup->wk) free(setup->wk);
		if (setup->sc) free(setup->sc);
		if (setup->wv) free(setup->wv);
		free(setup);
	}
}

// 
void
Rec_wvt(float *x, int lev, RecWaveSetup *setup)
{
	int		i, j, n;
	float	*wk = setup->wk;

	n = setup->dim;
	for (i = 0; i < lev; i++) {		// level
		for (j = 0; j < n; j++) {
			wk[j] = x[j];
		}
		n /= 2;
		for (j = 0; j < n; j++) {	// position
			x[j]   = (wk[j*2] + wk[j*2+1]) / 2.0;
			x[j+n] = (wk[j*2] - wk[j*2+1]) / 2.0;
		}
	}
}

// 
void
Rec_iwvt(float *x, int lev, RecWaveSetup *setup)
{
	int		i, j, n;
	float	*wk = setup->wk;

	n = setup->dim;
	for (i = 0; i < lev; i++) {
		n /= 2;
	}

	for (i = 0; i < lev; i++) {		// level - i
		for (j = 0; j < n*2; j++) {
			wk[j] = x[j];
		}
		for (j = 0; j < n; j++) {	// position
			x[j*2]   = wk[j] + wk[j+n];
			x[j*2+1] = wk[j] - wk[j+n];
		}
		n *= 2;
	}
}

float
bnc(int n, int k) {	// (n/k)
	int		i;
	float	a, b, c;

	// a
	a = 1;
	for (i = 0; i < n; i++) {
		a *= i + 1;
	}
	// b
	b = 1;
	for (i = 0; i < k; i++) {
		b *= i + 1;
	}
	// c
	c = 1;
	for (i = 0; i < n - k; i++) {
		c *= i + 1;
	}
	
	return a / b / c;
	
}

// Pinwheel
void
Rec_pinwheel(int k, int l, int n, RecImage *img)
{
	int			len = [img xDim];
	int			cm = 2;
	int			i, j, ix, rn, kp, kl;
	float		x, y, sx, cx, sy, cy;
	float		a;
	float		ak, al, bk, bl;
	int			sgn, rea;
	float		*p, *q;

	// make these loop later
	if (k < 0) {
		k = -k;
		kp = -1;
	} else {
		kp = 1;
	}

	if (n % 2 == 0) {
		rn = 0;
	} else {
		rn = 1;
	}

	ak = bnc(n, k);
	al = bnc(n, l);
	bk = bnc(n - 2, k - 1);
	bl = bnc(n - 2, l - 1);
	cm = 2;

	p = [img real];
	q = [img imag];
	
	for (i = 0; i < len; i++) {
		y = (float)i / len - 0.5;
		cy = cos(y * M_PI); sy = sin(y * M_PI);
		for (j = 0; j < len; j++) {
			ix = i * len + j;
			x = (float)j / len - 0.5;
			cx = cos(x * M_PI); sx = sin(x * M_PI);

			// F
			if ((k == 0 && l == 0) || (k == 0 && l == n) || (k == n && l == 0) || (k == n && l == n)) {
				kl = k + l;
				a = 1 *   cm * pow(cx, n-k) * pow(sx, k) * pow(cy, n-l) * pow(sy, l);
			} else
			// G
			if (k == 0 || l == 0 || k == n || l == n) {
				kl = k + l;
				a = 1 *   1.0/sqrt(2.0) * cm * sqrt(ak * al) * pow(cx, n-k) * pow(sx, k) * pow(cy, n-l) * pow(sy, l);
			// A
			} else {
				kl = k + l + 1;
				a = 1 *   0.5 * cm * pow(cx, n-k-1) * pow(sx, k-1) * pow(cy, n-l-1) * pow(sy, l-1)
					* (kp * sqrt(ak * bl) * cx * sx + sqrt(al * bk) * cy * sy);
			}
			// i^(k+l)
			switch (kl % 4) {
			case 0:
				rea = 1;
				sgn = 1;
				break;
			case 1:
				rea = 0;
				sgn = 1;
				break;
			case 2:
				rea = 1;
				sgn = -1;
				break;
			case 3:
				rea = 0;
				sgn = -1;
				break;
			}
			if (rea) {
				p[ix] = a * sgn;
				q[ix] = 0;
			} else {
				p[ix] = 0;
				q[ix] = a * sgn;
			}
		}
	}
}

RecImage *
Rec_pinwheel_param(int n)
{
	RecImage	*param;
	int			k, l, ix, nn;
	int			len;
	float		*p, *q;

	// qsort
	typedef	struct cpx {
		float	re;
		float	im;
	} cpx;
	cpx			*buf;
	int			(^compar)(const void *, const void *);

	nn = (n+1)*(n+1) + (n-1)*(n-1);	printf("nn = %d\n", nn);
	param = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:nn];
	len = [param dataLength];
	p = [param real];
	q = [param imag];

	// adjust k-l order ### not correct yet
	ix = 0;
	for (l = 0; l <= n; l++) {
		for (k = -n; k <= 0; k++, ix++) {
			p[ix] = k;
			q[ix] = l;
		}
	}
	for (l = 1; l < n; l++) {
		for (k = 1; k < n; k++, ix++) {
			p[ix] = k;
			q[ix] = l;
		}
	}

// sort
	buf = (cpx *)malloc(sizeof(float) * len * 2); 
	// copy back to RecImage
	for (ix = 0; ix < len; ix++) {
		buf[ix].re = p[ix];
		buf[ix].im = q[ix];
	}
	compar = ^int(const void *p1, const void *p2) {
		float	k1 = ((cpx *)p1)->re;
		float	l1 = ((cpx *)p1)->im;
		float	k2 = ((cpx *)p2)->re;
		float	l2 = ((cpx *)p2)->im;
		float	r1, r2, th1, th2;

		r1 = sqrt(k1 * k1 + l1 * l1);
		r2 = sqrt(k2 * k2 + l2 * l2);
		th1 = atan2(l1, k1);
		th2 = atan2(l2, k2);

		// ascending
		if (r1 > r2) {
			return 1;
		} else
		if (r1 < r2) {
			return -1;
		} else {	// r1 == r2
			if (th1 < th2) {
				return 1;
			} else 
			if (th1 == th2) {
				return 0;
			} else {
				return -1;
			}
		}
	};
	qsort_b(buf, len, sizeof(cpx), compar);

	// copy back to RecImage
	for (ix = 0; ix < len; ix++) {
		p[ix] = buf[ix].re;
		q[ix] = buf[ix].im;
	}
	free(buf);
		
	return param;
}

RecImage *
//Rec_pinwheel_kernel(RecImage *param, int len)
Rec_pinwheel_kernel(RecImage *img, RecImage *param)
{
	RecImage	*knl, *tmp;
	int			k, l;
	int			i, n, nn;
	float		*pp, *qq;

	nn = [param xDim];
	n = sqrt((nn - 2) / 2);

	knl = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:[param xLoop], [img yLoop], [img xLoop], nil];
	tmp = [knl sliceAtIndex:0];
	pp = [param real];
	qq = [param imag];
	

	for (i = 0; i < nn; i++) {
		k = pp[i];
		l = qq[i];
		Rec_pinwheel(k, l, n, tmp);
		[knl copySlice:tmp atIndex:i];
	}
	[knl setUnit:REC_FREQ];

	return knl;
}

int
place_tile(RecImage *img, RecImage *tile, int x, int y)
{
	int		i, j;
	float	*p, *q;
	int		ii, jj;
	int		tile_sz = [tile xDim];
	int		xDim = [img xDim];

	p = [tile data];
	q = [img data];
	for (i = 0; i < tile_sz; i++) {
		ii = y * tile_sz + i;
		for (j = 0; j < tile_sz; j++) {
			jj = x * tile_sz + j;
			q[ii * xDim + jj] = p[i * tile_sz + j];
		}
	}
	return 0;
}

RecImage *
Rec_pinwheel_dump_kernel(int n)
{

	RecImage	*param = Rec_pinwheel_param(n);
	float		*param_k = [param real];
	float		*param_l = [param imag];
	int			dim = Rec_po2(n * 32);
	RecImage	*img = [RecImage imageOfType:RECIMAGE_REAL xDim:dim yDim:dim];
	RecImage	*kern  = Rec_pinwheel_kernel(img, param);
	int			tile = n*2;
	int			i, k, l;
	int			x, y;

	[kern fft2d:REC_FORWARD];
	[kern crop:[kern xLoop] to:tile];
	[kern crop:[kern yLoop] to:tile];

	for (i = 0; i < [param dataLength]; i++) {
		k = param_k[i];
		l = param_l[i];
		x = [img xDim] / tile / 2 + k;
		y = [img yDim] / tile / 2 + l;
		place_tile(img, [kern sliceAtIndex:i], x, y);
	}
	[img saveAsKOImage:@"img_tile"];

	return img;
}

RecImage *
Rec_pinwheel_decomp(RecImage *img, RecImage *knl)
{
	RecImage	*tmp;
	RecImage	*imgm;
	int			i, nn = [knl zDim];

	tmp = [img copy];	// orig is not modified
	[tmp fft2d:REC_INVERSE];
	imgm = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:[knl zLoop], [img yLoop], [img xLoop], nil];
	for (i = 0; i < nn; i++) {
		[imgm copySlice:tmp atIndex:i];
	}
	[imgm multByImage:knl];
	[imgm fft2d:REC_FORWARD];
	[imgm takeRealPart];

	return imgm;
}

RecImage *
Rec_pinwheel_synth(RecImage *imgm, RecImage *knl)
{
	RecImage	*tmp, *iknl;

	tmp = [imgm copy];	// orig is not modified
	iknl = [knl copy];
	[iknl conjugate];
	[tmp fft2d:REC_INVERSE];
	[tmp multByImage:iknl];
	[tmp fft2d:REC_FORWARD];
	[tmp takeRealPart];
	tmp = [tmp sumForLoop:[tmp zLoop]];
	[tmp multByConst:0.25];	// scaling

	return tmp;
}


// IEEE Trans Med Imaging 26(1), 68 (2007).
// 111.246 deg
float
Rec_golden_angle(int i)
{
	float	th;		// rad
	int		ith;

	th = i * M_PI * (sqrt(5) - 1) / 2;
	ith = (int)(th / (M_PI * 2));
	th -= ith * 2 * M_PI;
	return th;
}

float
Rec_golden_angle_t(int i)
{
	float	gaStep;
	float	angle;
	int		len = 128;

	gaStep = acos(-1.0) / ((1.0 + sqrt(5.0)) / 2.0);

	if (i >= len - 8) {
		gaStep = acos(-1.0) * (45.0 / 180.0);
		angle = (i - len + 8) * gaStep;
	} else {
		angle = i * gaStep;
	}
	return angle;
}

//
RecImage *
dispToMap(RecImage *disp)
{
    RecImage    *map;
    int         i, j, k, ix;
    float       x, y, z;
    int         len = [disp dataLength];
    int         xDim = [disp xDim];
    int         yDim = [disp yDim];
    int         zDim = [disp zDim];
    float       *dx, *dy, *dz;
    float       *mx, *my, *mz;

    dx = [disp data];
    dy = dx + len;
    dz = dy + len;
    map = [RecImage imageWithImage:disp];
    mx = [map data];
    my = mx + len;
    mz = my + len;
    ix = 0;
    for (k = 0; k < zDim; k++) {
        z = ((float)k - zDim/2) / zDim;
        for (i = 0; i < yDim; i++) {
            y = ((float)i - yDim/2) / yDim;
            for (j = 0; j < xDim; j++, ix++) {
                x = ((float)j - xDim/2) / xDim;
                mx[ix] = -dx[ix] / xDim + x;
                my[ix] = -dy[ix] / yDim + y;
                mz[ix] = -dz[ix] / zDim + z;
            }
        }
    }
    return map;
}

// 3D version... add 2D later
void
Rec_take_ROI(RecImage *src, RecImage *dst, int xc, int yc, int zc)
{
//    float   *srcp = [src data];
//    float   *dstp = [dst data];
    float   *srcp;
    float   *dstp;
    int     srcDim = [src xDim];
    int     dstDim = [dst xDim];
    int     i, j, k;
    int     ii, jj, kk;
	BOOL	twoD;

	twoD = ([dst zDim] == 1);

	if (twoD) {
		[dst clear];
		srcp = [src data] + zc * srcDim * srcDim;
		dstp = [dst data] + zc * dstDim * dstDim;
		for (ii = 0; ii < dstDim; ii++) {
			i = yc + ii - dstDim/2;
			if (i < 0 || i >= srcDim) continue;
			for (jj = 0; jj < dstDim; jj++) {
				j = xc + jj - dstDim/2;
				if (j < 0 || j >= srcDim) continue;
				dstp[ii * dstDim + jj] = srcp[i * srcDim + j];
			}
		}
	} else {
		// else (3D)
		[dst clear];
		srcp = [src data];
		dstp = [dst data];
		for (kk = 0; kk < dstDim; kk++) {
			k = zc + kk - dstDim/2;
			if (k < 0 || k >= srcDim) continue;
			for (ii = 0; ii < dstDim; ii++) {
				i = yc + ii - dstDim/2;
				if (i < 0 || i >= srcDim) continue;
				for (jj = 0; jj < dstDim; jj++) {
					j = xc + jj - dstDim/2;
					if (j < 0 || j >= srcDim) continue;
					dstp[(kk * dstDim + ii) * dstDim + jj] = srcp[(k * srcDim + i) * srcDim + j];
				}
			}
		}
	}
}

// DFT
RecDftSetup	*
Rec_dftsetup(int len)
{
	RecDftSetup	*setup;
	int			i;
	float		th;

	setup = (RecDftSetup *)malloc(sizeof(RecDftSetup));
	setup->cs.realp = (float *)malloc(sizeof(float) * len);
	setup->cs.imagp = (float *)malloc(sizeof(float) * len);
	setup->wkcs.realp = (float *)malloc(sizeof(float) * len);
	setup->wkcs.imagp = (float *)malloc(sizeof(float) * len);
	setup->wk.realp = (float *)malloc(sizeof(float) * len);
	setup->wk.imagp = (float *)malloc(sizeof(float) * len);
	setup->dim = len;
	for (i = 0; i < len; i++) {
		for (i = 0; i < len; i++) {
			th = (float)i * M_PI * 2 / len;
			setup->cs.realp[i] = cos(th);
			setup->cs.imagp[i] = sin(th);
		}
	}
	return setup;
}

void
Rec_destroy_dftsetup(RecDftSetup *setup)
{
	if (setup) {
		if (setup->cs.realp) free(setup->cs.realp);
		if (setup->cs.imagp) free(setup->cs.imagp);
		if (setup->wkcs.realp) free(setup->wkcs.realp);
		if (setup->wkcs.imagp) free(setup->wkcs.imagp);
		if (setup->wk.realp) free(setup->wk.realp);
		if (setup->wk.imagp) free(setup->wk.imagp);
		free(setup);
	}
}

void
Rec_dft(RecDftSetup *setup, DSPSplitComplex *src, int src_skip, int direction)
{
	int		i, j, n = setup->dim;
	int		ix;
	float	re, im;
	DSPSplitComplex	sum;

	sum.realp = &re;
	sum.imagp = &im;
	vDSP_zvmov(src, src_skip, &(setup->wk), 1, n);

	// ### vDSP version not faster
	for (i = 0; i < n; i++) {
		src->realp[i * src_skip] = 0;
		src->imagp[i * src_skip] = 0;
		if (direction == REC_FORWARD) {
			for (j = 0; j < n; j++) {
				ix = (i * j) % n;
				src->realp[i * src_skip] += setup->wk.realp[j] * setup->cs.realp[ix] + setup->wk.imagp[j] * setup->cs.imagp[ix];
				src->imagp[i * src_skip] += setup->wk.imagp[j] * setup->cs.realp[ix] - setup->wk.realp[j] * setup->cs.imagp[ix];
			}
			
		} else {
			for (j = 0; j < n; j++) {
				ix = (i * j) % n;
				src->realp[i * src_skip] += setup->wk.realp[j] * setup->cs.realp[ix] - setup->wk.imagp[j] * setup->cs.imagp[ix];
				src->imagp[i * src_skip] += setup->wk.imagp[j] * setup->cs.realp[ix] + setup->wk.realp[j] * setup->cs.imagp[ix];
			}
		}
	}
}

// ### debug
void
dump_array(DSPSplitComplex ptr, int len)
{
	int		i;
	for (i = 0; i < len; i++) {
		printf("%d %f %f\n", i, ptr.realp[i], ptr.imagp[i]);
	}
}

// Chirp-Z
RecCftSetup	*
Rec_cftsetup(int len)
{
	RecCftSetup	*setup;
	int			dim, dim2, lg2;
	int			i, i2;
	float		th;

	setup = (RecCftSetup *)malloc(sizeof(RecCftSetup));

	// FFT setup
	setup->dim = dim = len;
	setup->dim2 = dim2 = Rec_po2(len * 2 - 1);
	lg2 = log2(dim2);
	setup->fft_setup = vDSP_create_fftsetup(lg2, kFFTRadix2);

	// Chirp-Z setup
	setup->cp.realp  = (float *)malloc(sizeof(float) * dim);
	setup->cp.imagp  = (float *)malloc(sizeof(float) * dim);
	setup->cpf.realp = (float *)malloc(sizeof(float) * dim2);
	setup->cpf.imagp = (float *)malloc(sizeof(float) * dim2);
	setup->wk.realp  = (float *)malloc(sizeof(float) * dim2);
	setup->wk.imagp  = (float *)malloc(sizeof(float) * dim2);

	//-> W i^2/2 tab (dim)
	for (i = i2 = 0; i < dim; i++) {
			th = -(float)i*i * M_PI / dim;
			setup->cp.realp[i] = cos(th);
			setup->cp.imagp[i] = sin(th);
	}
//dump_array(setup->cp, dim); exit(0);

	// zero-fill & FT (dim2)
	for (i = 0; i < dim; i++) {
		setup->cpf.realp[i] =  setup->cp.realp[i];
		setup->cpf.imagp[i] = -setup->cp.imagp[i];
	}
	for (; i < dim2 - dim; i++) {
		setup->cpf.realp[i] = 0;
		setup->cpf.imagp[i] = 0;
	}
	for (; i < dim2; i++) {
		setup->cpf.realp[i] =  setup->cp.realp[dim2 - i];
		setup->cpf.imagp[i] = -setup->cp.imagp[dim2 - i];
	}
//dump_array(setup->cpf, dim2); exit(0);

	vDSP_fft_zip(setup->fft_setup, &setup->cpf, 1, lg2, kFFTDirection_Forward); 
//dump_array(setup->cpf, dim2); exit(0);

	return setup;
}

void
Rec_destroy_cftsetup(RecCftSetup *setup)
{
	if (setup) {
		if (setup->cp.realp) free(setup->cp.realp);
		if (setup->cp.imagp) free(setup->cp.imagp);
		if (setup->cpf.realp) free(setup->cpf.realp);
		if (setup->cpf.imagp) free(setup->cpf.imagp);
		if (setup->wk.realp) free(setup->wk.realp);
		if (setup->wk.imagp) free(setup->wk.imagp);
		vDSP_destroy_fftsetup(setup->fft_setup);
		free(setup);
	}
}

void
Rec_cft(RecCftSetup *setup, DSPSplitComplex *src, int src_skip, int direction)
{
	int		i;
	int		dim  = setup->dim;
	int		dim2 = setup->dim2;
	int		lg2 = log2(dim2);

	// input
	vDSP_zvmov(src, src_skip, &(setup->wk), 1, dim);
	if (dim2 > dim) {
		for (i = dim; i < dim2; i++) {
			setup->wk.realp[i] = setup->wk.imagp[i] = 0;
		}
	}

	// input * chirp
	if (direction == REC_FORWARD) {
		Rec_cpx_mul(setup->wk.realp, setup->wk.imagp, 1, setup->cp.realp, setup->cp.imagp, 1, dim);
	} else {
		Rec_cpx_cmul(setup->wk.realp, setup->wk.imagp, 1, setup->cp.realp, setup->cp.imagp, 1, dim);
	}
//dump_array(setup->wk, dim); exit(0);
	vDSP_fft_zip(setup->fft_setup, &setup->wk, 1, lg2, kFFTDirection_Forward); 
//dump_array(setup->wk, dim2); exit(0);

	if (direction == REC_FORWARD) {
		Rec_cpx_mul(setup->wk.realp, setup->wk.imagp, 1, setup->cpf.realp, setup->cpf.imagp, 1, dim2);
	} else {
		Rec_cpx_cmul(setup->wk.realp, setup->wk.imagp, 1, setup->cpf.realp, setup->cpf.imagp, 1, dim2);
	}
//dump_array(setup->wk, dim2); exit(0);
	vDSP_fft_zip(setup->fft_setup, &setup->wk, 1, lg2, kFFTDirection_Inverse); 
	for (i = 0; i < dim; i++) {
		setup->wk.realp[i] /= dim2;
		setup->wk.imagp[i] /= dim2;
	}
//dump_array(setup->wk, dim2); exit(0);
	if (direction == REC_FORWARD) {
		Rec_cpx_mul(setup->wk.realp, setup->wk.imagp, 1, setup->cp.realp, setup->cp.imagp, 1, dim);
	} else {
		Rec_cpx_cmul(setup->wk.realp, setup->wk.imagp, 1, setup->cp.realp, setup->cp.imagp, 1, dim);
	}
//dump_array(setup->wk, dim2); exit(0);
	vDSP_zvmov(&(setup->wk), 1, src, src_skip, dim);
}

