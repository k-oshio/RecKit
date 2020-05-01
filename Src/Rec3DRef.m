//
//	RecImageRef.m
//  pointer to part of image
//      mainly for correlation calc
//      real only
// === plans ===
//  ### add range check
//  rec3d -> RecImageRef (merge)

#import "Rec3DRef.h"
#import "RecImage.h"
#import "RecLoopControl.h"
#import "RecLoop.h"

@implementation Rec3DRef

+ (Rec3DRef *)refForImage:(RecImage *)img
{
    return [self refForImage:img control:[img control]];
}

+ (Rec3DRef *)refForImage:(RecImage *)img control:(RecLoopControl *)lc
{
    Rec3DRef    *ref = [[Rec3DRef alloc] init];
    [ref initForImage:img control:lc];
    return ref;
}


- (id)copyWithZone:(NSZone *)zone
{
	id	ref = [Rec3DRef refForImage:image];
    [ref setOrigin:origin];
    [ref setNx:nX];
    [ref setNy:nY];
    [ref setNz:nZ];
    
    return ref;
}

- (void)initForImage:(RecImage *)img control:(RecLoopControl *)ctl
{   
    image = img;
    origin = 0;
    lc = ctl;
    nX = [image xDim];
    nY = [image yDim];
    nZ = [image zDim];
}

// range is not checked here
- (void)setX:(int)x y:(int)y z:(int)z nX:(int)nx nY:(int)ny nZ:(int)nz
{
    [self setX:x y:y z:z];
    [self setNx:nx];
    [self setNy:ny];
    [self setNz:nz];
}

- (void)setX:(int)x y:(int)y z:(int)z
{
    int     xDim = [image xDim];
    int     yDim = [image yDim];

    origin = z * xDim * yDim + y * xDim + x;
}

- (void)setOrigin:(int)org
{
    origin = org;
}

- (void)updateOrigin:(int)old withDx:(int)dx dY:(int)dy dZ:(int)dz
{
    int     xDim = [image xDim];
    int     yDim = [image yDim];
    origin = old + dz * xDim * yDim + dy * xDim + dx;
    if (origin < 0) {
        printf("negative offset\n");
        exit(-1);
    }
}

- (RecImage *)image
{
    return image;
}

- (int)origin
{
    return origin;
}

- (void)setNx:(int)xSize
{
    nX = xSize;
}

- (void)setNy:(int)ySize
{
    nY = ySize;
}

- (void)setNz:(int)zSize
{
    nZ = zSize;
}

- (int)nX
{
    return nX;
}

- (int)nY
{
    return nY;
}

- (int)nZ
{
    return nZ;
}

- (int)ySkip
{
    return [image xDim];
}

- (int)zSkip
{
    return [image yDim] * [image xDim];
}

// real only
// add range check ###
- (RecImage *)makeImage
{
    RecImage    *img;
    RecLoop     *xLoop, *yLoop, *zLoop;
    int         i, j, sl;
    int         ySkip = [self ySkip];
    int         zSkip = [self zSkip];
    float       *p, *q;
    float       *top = [image currentDataWithControl:lc] + origin;

    xLoop = [RecLoop loopWithDataLength:nX];
    yLoop = [RecLoop loopWithDataLength:nY];
    zLoop = [RecLoop loopWithDataLength:nZ];
    img = [RecImage imageOfType:RECIMAGE_REAL withLoops:zLoop, yLoop, xLoop, nil];
    // copy data
    q = [img data];
    for (sl = 0; sl < nZ; sl++) {
        p = top + sl * zSkip;
        for (i = 0; i < nY; i++) {
            for (j = 0; j < nX; j++) {
                *q++ = p[j];
            }
            p += ySkip;
        }
    }
    
    return img;
}

// real only    ### test
- (float)mean
{
    __block float sum;
    void    (^proc)(float *p, int n) = ^void(float *p, int n) {
        int     j;
         for (j = 0; j < n; j++) {
            sum += p[j];
        }
    };

    sum = 0;
    [self apply1refProc:proc];

    return sum / (nX * nY * nZ);
}

- (float)sdWithMean:(float)m
{
    __block float   sum;        // read / write
    float           mn = 0;     // read only
    void    (^proc)(float *p, int n) = ^void(float *p, int n) {
        int     j;
        float   val;
        for (j = 0; j < n; j++) {
            val = p[j] - mn;
            sum += val * val;
        }
    };

    mn = [self mean];
    sum = 0;
    [self apply1refProc:proc];

    return sqrt(sum / (nX * nY * nZ));
}

// use block (2 ref proc)
- (float)normalizedCorrelationWith:(Rec3DRef *)ref
{
    __block float   sum;
    float   m1 = 0, m2 = 0, sd1, sd2;
    void    (^proc)(float *p1, float *p2, int n) = ^void(float *p1, float *p2, int n) {
        int     j;
        for (j = 0; j < n; j++) {
            sum += (p1[j] - m1) * (p2[j] - m2);
        }
    };

    m1 = [self mean];
    sd1 = [self sdWithMean:m1];
    m2 = [ref mean];
    sd2 = [ref sdWithMean:m2];

    sum = 0;
    [self apply2refProc:proc withRef:ref];
    return sum / (sd1 * sd2 * nX * nY * nZ);
}

//
- (void)normalizedCorrelationWith:(Rec3DRef *)ref result:(RecImage *)wk
{
    int         xDim, yDim, zDim;
    float       *p;
    int         old = [ref origin];
    int         i, j, k;
    __block float   sum;
    float   m1 = 0, m2 = 0, sd1, sd2;
    void    (^proc)(float *p1, float *p2, int n) = ^void(float *p1, float *p2, int n) {
        int     j;
        for (j = 0; j < n; j++) {
            sum += (p1[j] - m1) * (p2[j] - m2);
        }
    };

    xDim = [wk xDim];
    yDim = [wk yDim];
    zDim = [wk zDim];
    p = [wk data];
    m1 = [self mean];
    sd1 = [self sdWithMean:m1];
    for (k = 0; k < zDim; k++) {
        for (i = 0; i < yDim; i++) {
            for (j = 0; j < xDim; j++) {
                [ref updateOrigin:old withDx:j - xDim/2 dY:i - yDim/2 dZ:k - zDim/2];
                m2 = [ref mean];
                sd2 = [ref sdWithMean:m2];
                sum = 0;
                [self apply2refProc:proc withRef:ref];
                *p++ = sum / (sd1 * sd2 * nX * nY * nZ);
            }
        }
    }
}

//============= blocks ============
- (void)apply1refProc:(void (^)(float *p, int n))proc
{
    float   *top = [image currentDataWithControl:lc] + origin;
    float   *p;
    int     i, k;
    int     ySkip = [self ySkip];
    int     zSkip = [self zSkip];

    for (k = 0; k < nZ; k++) {
        p = top + k * zSkip;
        for (i = 0; i < nY; i++) {
            proc(p, nX);
            p += ySkip;
        }
    }
}

- (void)apply2refProc:(void (^)(float *p1, float *p2, int n))proc withRef:(Rec3DRef *)ref
{
    float   *p1, *p2;
    int     i, k;
    float   *top1 = [image currentDataWithControl:lc] + origin;
    int     ySkip1 = [self ySkip];
    int     zSkip1 = [self zSkip];
    float   *top2 = [[ref image] currentDataWithControl:lc] + [ref origin];
    int     ySkip2 = [ref ySkip];
    int     zSkip2 = [ref zSkip];

    for (k = 0; k < nZ; k++) {
        p1 = top1 + k * zSkip1;
        p2 = top2 + k * zSkip2;
        for (i = 0; i < nY; i++) {
            proc(p1, p2, nX);
            p1 += ySkip1;
            p2 += ySkip2;
        }
    }
}

//=== debug
- (void)markWith:(float)mk
{
    void    (^proc)(float *p, int n) = ^void(float *p, int n) {
        int     j;
        float   fr = 1.0 + mk;
        for (j = 0; j < n; j++) {
            p[j] *= fr;
        }
    };
    [self apply1refProc:proc];
}

@end

