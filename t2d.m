//
//  t2d (T2 minus DWI)
//  K. Oshio
//
//  first version: 11-26-2014
//
//  *test on other machine (OK)
//

#import <RecKit/RecKit.h>

RecImage    *calc_adc(RecImage *b0, RecImage *b1000);
RecImage    *calc_t2d(RecImage *b0, RecImage *b1000);

float   bmax = 1.0, Dthres = 1.0;   // global, and commmon to all calc

int
main(int ac, char *av[])
{
    @autoreleasepool {
        RecImage	*b0, *b1000, *result;

        if (ac < 3) {
            printf("t2d <b0file><b1000file>[<bmax><Dthres>]\n");
            exit(0);
        }
        if (ac > 3) {
            sscanf(av[3], "%f", &bmax);
            bmax /= 1000.0;
        }
        if (ac > 4) {
            sscanf(av[4], "%f", &Dthres);
        }
        printf("file1:%s, file2:%s, bmax = %4.1f, Dthres = %5.1f\n", av[1], av[2], bmax, Dthres);

        b0    = [RecImage imageWithKOImage:[NSString stringWithUTF8String:av[1]]];
        b1000 = [RecImage imageWithKOImage:[NSString stringWithUTF8String:av[2]]];
        
 
        result = calc_adc(b0, b1000);
        [result saveAsKOImage:@"ADC.img"];

        result = calc_t2d(b0, b1000);
        [result saveAsKOImage:@"T2D.img"];

        return 0;
    }
}

RecImage *
calc_adc(RecImage *b0, RecImage *b1000)
{
    RecImage    *img;
    float       *p1, *p2;
    float       *pp;
    float       val;
    int         i, len;

    img = [RecImage imageWithImage:b0];
    p1 = [b0 data];
    p2 = [b1000 data];
    pp = [img data];
    len = [img dataLength];

    for (i = 0; i < len; i++) {
        if (p1[i] > 0) {
            val = p2[i] / p1[i];
            val = -log(val);
            pp[i] = val * 1000;
        } else {
            pp[i] = 0;
        }
    }

    return img;
}

RecImage *
calc_t2d(RecImage *b0, RecImage *b1000)
{
    RecImage    *img;
    float       *p1, *p2;
    float       *pp;
    float       val, frac;
    int         i, len;

    img = [RecImage imageWithImage:b0];
    p1 = [b0 data];
    p2 = [b1000 data];
    pp = [img data];
    len = [img dataLength];

    frac = exp(- Dthres * bmax);
    for (i = 0; i < len; i++) {
        val = p1[i] * frac - p2[i];
        pp[i] = val;
    }

    return img;
}
