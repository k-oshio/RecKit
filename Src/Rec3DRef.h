//
//  part of image (reference to image data)
//  2nd attempt ... replace Rec2DRef when done

#import <Foundation/Foundation.h>
#import "RecImage.h"
@class RecLoopControl;

@interface Rec3DRef : NSObject
{
    RecImage        *image;
    RecLoopControl  *lc;
    int             origin;    // location of origin W.R.T. current lc
    int             nX;
    int             nY;
    int             nZ;
}

+ (Rec3DRef *)refForImage:(RecImage *)img control:(RecLoopControl *)lc;
+ (Rec3DRef *)refForImage:(RecImage *)img;
- (void)initForImage:(RecImage *)img control:(RecLoopControl *)lc;
- (id)copyWithZone:(NSZone *)zone;

- (void)setX:(int)x y:(int)y z:(int)z nX:(int)nx nY:(int)ny nZ:(int)nz;
- (void)setX:(int)x y:(int)y z:(int)z;
- (void)setNx:(int)nx;
- (void)setNy:(int)ny;
- (void)setNz:(int)nz;
- (void)setOrigin:(int)origin;
- (void)updateOrigin:(int)old withDx:(int)dx dY:(int)dY dZ:(int)dZ;

- (RecImage *)image;
- (int)origin;
- (int)nX;
- (int)nY;
- (int)nZ;

- (int)ySkip;
- (int)zSkip;

- (RecImage *)makeImage;

- (float)mean;
- (float)sdWithMean:(float)m;
- (float)normalizedCorrelationWith:(Rec3DRef *)ref; // probably this is not necessary
- (void)normalizedCorrelationWith:(Rec3DRef *)ref result:(RecImage *)wk;
- (void)apply1refProc:(void (^)(float *p, int n))proc;
- (void)apply2refProc:(void (^)(float *p1, float *p2, int n))proc withRef:(Rec3DRef *)ref;

//=== debug
- (void)markWith:(float)mk;

@end
