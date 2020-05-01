//
//  part of image (reference to image data)
//	real / complex
//
//	2nd version ... (based on 3D version) -> probably OK now...
//		-> update 3D (replace origin with x/y/zPos
//

#import <Foundation/Foundation.h>

@class RecImage, RecLoopControl;

@interface Rec2DRef : NSObject
{
    RecImage        *image;
	int				xPos, yPos, zPos;	// ul corner (can be outside of image)
    int             nX;
    int             nY;
}

+ (Rec2DRef *)refForImage:(RecImage *)img;
- (void)initForImage:(RecImage *)img;
- (id)copyWithZone:(NSZone *)zone;

- (void)setX:(int)x y:(int)y nX:(int)nx nY:(int)ny;
- (void)setX:(int)x y:(int)y;
- (void)setNx:(int)nx;
- (void)setNy:(int)ny;
- (void)setZ:(int)z;

- (RecImage *)image;
- (int)xPos;
- (int)yPos;
- (int)zPos;
- (int)nX;
- (int)nY;

- (int)ySkip;
- (int)zSkip;

- (float)avg;
- (void)multBy:(float)a;

- (RecImage *)makeImage;
- (void)copyImage:(RecImage *)img;	// reverse of above

@end
