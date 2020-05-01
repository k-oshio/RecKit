//
//	RecCoilProfile.m
//	1-27-2010
//
//	x, y, z : [0 .. 1]
//

#import "RecCoilProfile.h"
#import "RecImage.h"
#import "RecLoop.h"

@implementation RecCoilProfile

+ (RecCoilProfile *)profileForCoil:(int)coilID
{
	RecCoilProfile	*cp;

	cp = [[RecCoilProfile alloc] init];
	[cp setCoilID:coilID];

	return cp;
}

- (void)setCoilID:(int)anID
{
	coilID = anID;
}

- (int)coilID
{
	return coilID;
}

- (void)initWithImage:(RecImage *)img
{
    int                 i, j, k, ch, ix;
    int                 xDim, yDim, zDim, nCh;
    float               *p;
    float               *wtx, *wty, *wtz;

// init weight table
    weight = [RecImage imageOfType:RECIMAGE_REAL withImage:img];
    xDim = [img xDim];
    yDim = [img yDim];
    zDim = [img zDim];
    nCh = [[img topLoop] dataLength];
    p = [weight data];

    for (ch = 0; ch < nCh; ch++) {
        wtx = [self xWeightForCh:ch dim:xDim];
        wty = [self yWeightForCh:ch dim:yDim];
        wtz = [self zWeightForCh:ch dim:zDim];
        for (k = 0; k < zDim; k++) {
            for (i = 0; i < yDim; i++) {
                ix = ch * xDim * yDim * zDim
                    + k * xDim * yDim
                    + i * xDim;
                for (j = 0; j < xDim; j++, ix++) {
                    p[ix] = wtx[j] * wty[i] * wtz[k];
                }
            }
        }
        free(wtx);
        free(wty);
        free(wtz);
   }
}

// z-only version
- (void)initWithPWImage:(RecImage *)img
{
    int                 i, j, k, ch, ix;
    int                 xDim, yDim, zDim, nCh;
    float               *p;
    float               *wtz;

// init weight table
    weight = [RecImage imageOfType:RECIMAGE_REAL withImage:img];
    xDim = [img xDim];
    yDim = [img yDim];  // physical Z
    zDim = [img zDim];  // projection
    nCh = [[img topLoop] dataLength];
    p = [weight data];

    for (ch = 0; ch < nCh; ch++) {
        wtz = [self zWeightForCh:ch dim:yDim];
        for (k = 0; k < zDim; k++) {
            for (i = 0; i < yDim; i++) {
                ix = ch * xDim * yDim * zDim
                    + k * xDim * yDim
                    + i * xDim;
                for (j = 0; j < xDim; j++, ix++) {
                     p[ix] = wtz[i];
                }
            }
        }
        free(wtz);
   }
}

// new
- (RecImage *)weight
{
    return weight;
}

- (float *)xWeightForCh:(int)ch dim:(int)xDim
{
    float   *p = (float *)malloc(sizeof(float) * xDim);
    int     i;
    float   x, w;

    switch (coilID) {
    case GE_Card_8_old :
        // not implemented
        break;
    case GE_Card_8_new :
    default :
        for (i = 0; i < xDim; i++) {
            x = (float)i / xDim;
            switch (ch) {
            case 0: case 2: case 5: case 7:
                w = (x - 0.25) * 2.0;
                w = exp(-w * w);
                break;
            default :	// 1, 3, 4, 6
                w = (x - 0.75) * 2.0;
                w = exp(-w * w);
                break;
            }
            p[i] = w*w;
        }
        break;
    case TOSHIBA_15 :
        for (i = 0; i < xDim; i++) {
			p[i] = 1.0;
		}
		break;
    }
    return p;
}

- (float *)yWeightForCh:(int)ch dim:(int)yDim
{
    float   *p = (float *)malloc(sizeof(float) * yDim);
    int     i;
    float   y, w;

    switch (coilID) {
    case GE_Card_8_old :
        // not implemented
        break;
    case GE_Card_8_new :
    default :
        for (i = 0; i < yDim; i++) {
            y = (float)i / yDim;
            switch (ch) {
            case 4: case 5: case 6: case 7:		// P
                w = (y - 0.75) * 2.0;
                w = exp(-w * w);
                break;
            default :	// 0, 1, 2, 3			// A
                w = (y - 0.25) * 2.0;
                w = exp(-w * w);
                break;
            }
            p[i] = w*w;
        }
        break;
    case TOSHIBA_15 :
        for (i = 0; i < yDim; i++) {
            y = (float)i / yDim;
			switch (ch) {
			case 0: case 1: case 3: case 4:		// A
                w = (y - 0.25) * 2.0;
                w = exp(-w * w);
				break;
			case 6: case 7: case 9: case 10:// case 12: case 13:		// P
                w = (y - 0.75) * 2.0;
                w = exp(-w * w);
				break;
			default:	// lower
				w = 0;
				break;
			}
			p[i] = w*w;
		}
		break;
    }
    return p;
}

- (float *)zWeightForCh:(int)ch dim:(int)zDim
{
    float   *p = (float *)malloc(sizeof(float) * zDim);
    int     i;
    float   z, w;
	float	width = 0.3;

    switch (coilID) {
    case GE_Card_8_old :
        // not implemented
        break;
    case GE_Card_8_new :
    default :
        for (i = 0; i < zDim; i++) {
            z = (float)i / zDim;
            switch (ch) {
            case 2: case 3: case 6: case 7:	// I
                if (z > 1.0 - width) {
                    w = (z + width - 1.0) / width * M_PI / 2;
                    w = cos(w);
                } else {					// S
                    w = 1.0;
                }
                break;
            default :	// 0, 1, 4, 5
                if (z < width) {
                    w = (width - z) / width * M_PI / 2;
                    w = cos(w);
                } else {
                    w = 1.0;
                }
                break;
            }
            p[i] = w * w;
        }
        break;
    case TOSHIBA_15 :
        for (i = 0; i < zDim; i++) {
            z = (float)i / zDim;
			switch (ch) {
			case 0: case 3: case 6: case 9:	case 12:	// S
                if (z < width) {
                    w = (width - z) / width * M_PI / 2;
                    w = cos(w);
                } else {
                    w = 1.0;
                }
				break;
			case 1: case 4: case 7: case 10: case 13:	// I
                if (z > 1.0 - width) {
                    w = (z + width - 1.0) / width * M_PI / 2;
                    w = cos(w);
                } else {					// S
                    w = 1.0;
                }
                break;
			default :
				w = 0;
				break;
			}
            p[i] = w * w;
		}
    }
    return p;
}

@end

