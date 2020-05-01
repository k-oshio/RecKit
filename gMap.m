//
//  gMap (gamma map)
//  K. Oshio
//
//  first version: 12-10-2014
//
// --- plans ---
//  hard code path & b-values (prostate & uterus)
//

#import <RecKit/RecKit.h>
#import <NumKit/NumKit.h>

#define MAX_N_B 10

float   d1 = 1.0;
float   d3 = 3.0;
float   thres = 0.01;

float   b_value[MAX_N_B];   // b_value array
int     n_b;

// =====================
float
model(float x, float *p, float *dydp)
{
	float	pd = p[0];
	float	k  = p[1];
    float   th = p[2];
	float	y, denom;

// model
    denom = pow(1.0 + th * x, k);
    y = pd / denom;
    if (dydp) {
        dydp[0] = 1.0 / denom;
        dydp[1] = - pd * log(x * th + 1) / denom;
        dydp[2] = - x * k * pd * pow(x * th + 1, -k - 1);
    }
    return y;
}

float
fracLessThan(float Dthres, float k, float th)
{
    int     i;
    float   D, Dmax = 100.0, dD = 0.1;
    float   val, acc;

    acc = 0;
    D = Dthres;
    for (i = 0; D < Dmax; i++) {
        D = Dthres + i * dD;    // right side only
        val = pow(D, k - 1.0) * exp(- D / th) / (tgamma(k) * pow(th, k));
        acc += val * dD;
        if (val < 0.0001) break;
    }
    acc = 1.0 - acc;

    return acc;
}
// =====================

void
tmp()
{
    RecImage    *pdImg, *kImg, *thImg;
    RecImage    *imgL, *imgG;
    float       *p0, *p1, *p2, *q1, *q2;
    int         i, n;

    pdImg = [RecImage imageWithKOImage:@"b_pd.img"];
    kImg  = [RecImage imageWithKOImage:@"b_k.img"];
    thImg = [RecImage imageWithKOImage:@"b_th.img"];
    imgL  = [RecImage imageWithImage:thImg];
    imgG  = [RecImage imageWithImage:thImg];
    p0 = [pdImg data];
    p1 = [kImg data];
    p2 = [thImg data];
    q1 = [imgL data];
    q2 = [imgG data];

    n = [pdImg dataLength];
    for (i = 0; i < n; i++) {
        if (i % 65536 == 0) {
            printf("slc: %d\n", i / 65536);
        }
        if (p0[i] == 0) continue;
        q1[i] = p0[i] * fracLessThan(d1, p1[i], p2[i]);
        q2[i] = p0[i] * (1.0 - fracLessThan(d3, p1[i], p2[i]));
    }
    [imgL saveAsKOImage:@"b_lt.img"];
    [imgG saveAsKOImage:@"b_gt.img"];
}

int
main(int ac, char *av[])
{
    @autoreleasepool {
        RecImage        *bx[MAX_N_B], *img, *kImg, *thImg, *pdImg;
        RecLoop         *bLp;
        RecLoopControl  *sLc, *dLc;
        RecLoopIndex    *dLi;
        NSArray         *lpArray;
        int             i, j, n;
        int             iter;
        float           minval;
        int             ib;
        char            path[256];
        float           *p, *q0, *q1, *q2, mx;
        int             skip;
        float           *b_val;
        Num_data        *data;
        Num_param       *param;

tmp();
exit(0);
        if (ac < 3) {
            printf("gMap <b_value1><b_value2>...\n");
            exit(0);
        }
        n_b = ac - 1;
        data  = Num_alloc_data(n_b);
        param = Num_alloc_param(3);
        b_val = (float *)malloc(sizeof(float) * n_b);

        // read images
        for (i = 0; i < n_b; i++) {
            ib = atoi(av[i + 1]);
            printf("b = %d\n", ib);
            sprintf(path, "b%d.img", ib);
            b_val[i] = (float)ib;
            bx[i] = [RecImage imageWithKOImage:[NSString stringWithUTF8String:path]];
            if (i > 0) {
                [bx[i] copyDimensionsOf:bx[0]];
            }
        }

        // combine image
        bLp = [RecLoop loopWithDataLength:n_b];
        lpArray = [NSArray arrayWithObject:bLp];
        lpArray = [lpArray arrayByAddingObjectsFromArray:[bx[0] loops]];
        img = [RecImage imageOfType:RECIMAGE_REAL withLoopArray:lpArray];
        [img copyDimensionsOf:bx[0]];
        dLc = [img control];
    //    dLi = [dLc topLoopIndex];
        dLi = [dLc loopIndexForLoop:bLp];
        [dLi deactivate];
        for (i = 0; i < n_b; i++) {
            [dLi setCurrent:i];
            sLc = [bx[i] control];
            [img copyImage:bx[i] withControl:dLc];
        }
        mx = [img maxVal];

        [img saveAsKOImage:@"b_comb.img"];

    // do gamma fitting for bLp

        kImg  = [RecImage imageWithImage:bx[0]];
        thImg = [RecImage imageWithImage:bx[0]];
        pdImg = [RecImage imageWithImage:bx[0]];

        sLc = [img control];
        [sLc deactivateLoop:bLp];
        n = [sLc loopLength];
        dLc = [RecLoopControl controlWithControl:sLc forImage:pdImg];
        skip = [img skipSizeForLoop:bLp];
        for (i = 0; i < n; i++) {
            // copy data
            p = [img currentDataWithControl:sLc];
            q0 = [pdImg currentDataWithControl:dLc];
            q1 = [kImg  currentDataWithControl:dLc];
            q2 = [thImg currentDataWithControl:dLc];
            if (p[0] > mx * thres) {
                for (j = 0; j < n_b; j++) {
                    data->x[j] = b_val[j];
                    data->y[j] = p[j * skip];
                    // dbg
                }
                data->xscale = 1.0;
                data->yscale = 1.0;
                if (i % 65536 == 31104) {
                    for (j = 0; j < n_b; j++) {
                        printf("%f %f\n", data->x[j], data->y[j]);
                    }
                    for (j = 0; j < 3; j++) {
                        printf("%f\n", param->data[j]);
                    }
                }
                Num_normalize_data(data);
                // gamma fit (## error handling)
                param->data[0] = 1.0;   //1.0;    // PD
                param->data[1] = 1.0;   //1.0;    // k
                param->data[2] = 3.0;   //3.0;      // theta
                iter = Num_least_sq(data, param, model, &minval);
                if (param->data[0] == param->data[0]) { // not NaN
                    // convert k/th/pd to frac<1 etc
                    // probably should be scaled by PD
                    // ###
                    *q0 = param->data[0] * data->yscale;   // pd
                    *q1 = param->data[1];   // k
                    *q2 = param->data[2] / data->xscale * 1000;   // th
                }
            }
            [sLc increment];
        }
        [pdImg saveAsKOImage:@"b_pd.img"];
        [kImg  saveAsKOImage:@"b_k.img"];
        [thImg saveAsKOImage:@"b_th.img"];
        Num_free_param(param);
        Num_free_data(data);
        free(b_val);
    }

    return 0;
}
            
