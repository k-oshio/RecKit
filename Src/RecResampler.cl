//
// RecResampler.cl
// OpenCL resampler
//

// === plans ===
// 1. use warp_tab unmodified
// 2. use cornerIx + posTab + kernel
//

#define KERN_TAB_LEN        (300)

#define LANCZ_ORDER         (3)
#define LANCZ_KERNSIZE      (36)
#define LANCZ_KERNSIZE_1D   (6)

#define M_PI                (3.14159265)

typedef struct WarpTab {
	int			cornerIx;
	float		wt[LANCZ_KERNSIZE];		// order * 2 ^ 2
} WarpTabSt;

typedef struct WarpTab1d {
	int			leftIx;
	float		wt[LANCZ_KERNSIZE_1D];		// order * 2 ^ 2
} WarpTab1dSt;


// ====== 2D resampler ====

// works OK, difficult to speed up
kernel void
resample1(global float *src, int six, global float *dst, int dix, global WarpTabSt *tab, int srcXdim, int dstXdim)
{
	int                 g_id, l_id;
    int                 i, j, ix, dim = LANCZ_ORDER * 2;
    float               sum;
    global float        *srcp;
    local int           pos_ofs[LANCZ_KERNSIZE];
    global WarpTabSt   *tab_entry;

	g_id   = get_global_id(0) * dstXdim + get_global_id(1);
	l_id   = get_local_id(0) * get_local_id(0);

    if (l_id == 0) {    // one for each work group
        for (i = ix = 0; i < dim; i++) {
            for (j = 0; j < dim; j++, ix++) {
                pos_ofs[ix] = i * srcXdim + j;
            }
        }
    }
	barrier(CLK_LOCAL_MEM_FENCE);   // wait for  pos_ofs init

    tab_entry = tab + g_id;
    srcp = src + six + tab_entry->cornerIx;
    sum = 0;

    for (i = 0; i < LANCZ_KERNSIZE; i++) {	// kern_size = 36
        if (tab_entry->wt[i] != 0) {
            sum += srcp[pos_ofs[i]] * tab_entry->wt[i];
        }
    }
    dst[g_id + dix] = sum;
}

int
warp_kernel_index(float dist, int step, int len)
{
	int		ix;

    ix = floor(dist * step);    // two-sided (signed)
    ix = abs(ix);

	if (ix < 0) ix = 0;
	if (ix > len)  ix = len;

	return ix;
}

void
make_lancz_kern(local float *kern, int len)
{
    float   w, x;
    int     i, k, n;

// Lanczos kernel (without DC correction)
	for (i = 0; i <= len; i++) {
		if (i == 0) {
			kern[i] = 1.0;
		} else {
			x = (float)i * (float)LANCZ_ORDER * M_PI / len;
			w = (sin(x) / x) * (sin(x/(float)LANCZ_ORDER) / (x/(float)LANCZ_ORDER));
			kern[i] = w;
        }
	}
}

// kernel only version. not correct yet ###???
// try local cache later (make separate kernel for comparison)
    // not correct, and slower ???
kernel void
resample2(global float *src, int six, global float *dst, int dix, global float *mapx, global float *mapy, int srcDim, int dstDim)
{
	int             g_id, l_id, l_x, l_y;
    int             i, j, kern_ix, kern_step, dim = LANCZ_ORDER * 2;
    float           x, y, dist, sum;
    float           tmp;
    float           w, wx, wy;
    int             xi, yi, xpos, ypos;
    global float    *srcp;
    local float     lancz_kern[KERN_TAB_LEN + 1];
    local float     buf[484];    // (16 + 6) ^2
    local int       x0, y0, x1, y1;     // offset of upper left / lower righght corners
    int             xx, yy; // offset into local buf
    int             lbs = 16;   // local group size
    int             bufdim = lbs + dim;

	g_id = get_global_id(0) * dstDim + get_global_id(1);
    l_y  = get_local_id(0);
    l_x  = get_local_id(1);
	l_id = l_y * lbs + l_x;

    if (l_id == 1) {
        make_lancz_kern(lancz_kern, KERN_TAB_LEN);
    }
//	barrier(CLK_LOCAL_MEM_FENCE);   // wait for  kern tab init

	kern_step = KERN_TAB_LEN / LANCZ_ORDER;
    x = mapx[g_id] * (float)srcDim + srcDim/2;
    xi = (int)ceil(x) - LANCZ_ORDER;
    x = (float)xi - x;
    y = mapy[g_id] * (float)srcDim + srcDim/2;
    yi = (int)ceil(y) - LANCZ_ORDER;
    y = (float)yi - y;
    srcp = src + six + yi * srcDim + xi;   // upper left corner

    // upper left corner
    if (l_id == 0) {
        x0 = xi;
        y0 = yi;
    }
    if (l_id == lbs*lbs - 1) {  // lower right corner
        x1 = xi;
        y1 = yi;
    }
	barrier(CLK_LOCAL_MEM_FENCE);   // wait for  kern tab init

    if (l_id == 0) {
        for (i = 0; i < y1 - y0 + dim; i++) {
            for (j = 0; j < x1 - x0 + dim; j++) {
                buf[i * bufdim + j] = srcp[i * srcDim + j];
            }
        }
    }
	barrier(CLK_LOCAL_MEM_FENCE);   // wait for  kern tab init

    sum = 0;
    xx = xi - x0;
    yy = yi - y0;
    for (i = 0; i < dim; i++) {
        ypos = yi + i;
        if (ypos < 0 || ypos >= srcDim) {
            wy = 0;
        //    continue;
        } else {
            dist = y + i;
            kern_ix = warp_kernel_index(dist, kern_step, KERN_TAB_LEN);
            wy = lancz_kern[kern_ix];
        }
        for (j = 0; j < dim; j++) {
            xpos = xi + j;
            if (xpos < 0 || xpos >= srcDim) {
                wx = 0;
            //    continue;
            } else {
                dist = x + j;
                kern_ix = warp_kernel_index(dist, kern_step, KERN_TAB_LEN);
                wx = lancz_kern[kern_ix];
            }
            w = wx * wy;
            if (w != 0) {
            //    sum += srcp[i * srcDim + j] * w;
                sum += buf[(i + yy) * bufdim + j + xx] * w;
            }
        }
    }
    dst[g_id + dix] = sum;
}

// ====== 1D resampler ====
kernel void
resample1d(global float *src, int six, global float *dst, int dix, int lpSkip, int srcSkip, int dstSkip, int xDim, global WarpTab1dSt *tab)
{
	int                 g_id0, g_id1;
    int                 i, j, ix, dim = LANCZ_ORDER * 2;
    float               sum;
    global float        *srcp;
    global WarpTab1dSt  *tab_entry;

	g_id0 = get_global_id(0);   // lp
    g_id1 = get_global_id(1);   // x (or y)
    tab_entry = tab + g_id0;
//    srcp = src + six + tab_entry->leftIx * lpSkip;
    srcp = src + six + tab_entry->leftIx * lpSkip + g_id1 * srcSkip;
    sum = 0;

    for (i = 0; i < LANCZ_KERNSIZE_1D; i++) {	// kern_size = 6
        if (tab_entry->wt[i] != 0) {
        //    sum += srcp[i * lpSkip] * tab_entry->wt[i];
            sum += srcp[i * lpSkip] * tab_entry->wt[i];
        }
    }
//    dst[dix + g_id0 * lpSkip] = sum;
    dst[dix + g_id0 * lpSkip + g_id1 * dstSkip] = sum;
}

