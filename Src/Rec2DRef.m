//
//	RecImageRef.m
//  pointer to part of image
//      mainly for correlation calc
//

#import "Rec2DRef.h"
#import "RecImage.h"
#import "RecLoop.h"
#import "RecLoopControl.h"
#import "RecUtil.h"

@implementation Rec2DRef

+ (Rec2DRef *)refForImage:(RecImage *)img
{
    Rec2DRef    *ref = [[Rec2DRef alloc] init];
    [ref initForImage:img];
    return ref;
}


- (id)copyWithZone:(NSZone *)zone
{
	id	ref = [Rec2DRef refForImage:image];
//    [ref setOrigin:origin];
	[ref setX:xPos y:yPos];
    [ref setNx:nX];
    [ref setNy:nY];
    
    return ref;
}

- (void)initForImage:(RecImage *)img
{   
    image = img;
//    origin = 0;
    nX = [image xDim];
    nY = [image yDim];
	xPos = yPos = zPos = 0;
}

// range is not checked here
- (void)setX:(int)x y:(int)y nX:(int)nx nY:(int)ny
{
    [self setX:x y:y];
    [self setNx:nx];
    [self setNy:ny];
}

- (void)setX:(int)x y:(int)y
{
//    int     xDim = [image xDim];

	xPos = x;
	yPos = y;
}

- (void)setZ:(int)z
{
	zPos = z;
}


- (RecImage *)image
{
    return image;
}

//- (int)origin
//{
//    return origin;
//}

- (void)setNx:(int)xSize
{
    nX = xSize;
}

- (void)setNy:(int)ySize
{
    nY = ySize;
}

- (int)xPos
{
	return xPos;
}

- (int)yPos
{
	return yPos;
}

- (int)zPos
{
	return zPos;
}

- (int)nX
{
    return nX;
}

- (int)nY
{
    return nY;
}

- (int)ySkip
{
    return [image xDim];
}

- (int)zSkip
{
    return [image yDim] * [image xDim];
}

- (float)avg
{
    int			i, j;
	int			x, y;
	int			imgSize, refSize;
	int			xDim, yDim;
    float		*p, sum;
	int			ix;

 	p = [image data];

	xDim = [image xDim];
	yDim = [image yDim];
	imgSize = xDim * yDim;
	refSize = nX * nY;
	sum = 0;
	for (i = 0; i < nY; i++) {
		y = yPos + i;
		if (y < 0 || y >= yDim) continue;
		for (j = 0; j < nX; j++) {
			x = xPos + j;
			if (x < 0 || x >= xDim) continue;
			ix = zPos * imgSize + y * xDim + x;
			sum += p[ix];
		}
	}
    return sum / refSize;
}

- (void)multBy:(float)a
{
    int			i, j;
	int			x, y;
	int			imgSize;
	int			xDim, yDim;
    float		*p;
	int			ix;

 	p = [image data];

	xDim = [image xDim];
	yDim = [image yDim];
	imgSize = xDim * yDim;
	for (i = 0; i < nY; i++) {
		y = yPos + i;
		if (y < 0 || y >= yDim) continue;
		for (j = 0; j < nX; j++) {
			x = xPos + j;
			if (x < 0 || x >= xDim) continue;
			ix = zPos * imgSize + y * xDim + x;
			p[ix] *= a;
		}
	}
}

- (RecImage *)makeImage
{
    RecImage	*img;
    int			i, j, pl;
	int			x, y;
	int			imgSize;
	int			xDim, yDim;
    float		*p1, *p2;
	int			ix1, ix2;

    img = [RecImage imageOfType:[image type] xDim:nX yDim:nY];
	p1 = [image data];		// src
	p2 = [img data];		// dst

	xDim = [image xDim];
	yDim = [image yDim];
	imgSize = xDim * yDim;
	for (pl = 0; pl < [image pixSize]; pl++) {
		for (i = 0; i < nY; i++) {
			y = yPos + i;
			if (y < 0 || y >= yDim) continue;
			for (j = 0; j < nX; j++) {
				x = xPos + j;
				if (x < 0 || x >= xDim) continue;
				ix1 = pl * [image dataLength] + zPos * imgSize + y * xDim + x;	// src
				ix2 = pl * [img dataLength] + i * nX + j;		// dst
				p2[ix2] = p1[ix1];
			}
		}
	}
    return img;
}

- (void)copyImage:(RecImage *)img	// reverse of above
{
	int		i, j, pl;
	int		x, y;
	int		xDim, yDim, imgSize;
    float	*p1, *p2;
	int		ix1, ix2;

	// chk size
	if ([img xDim] != nX || [img yDim] != nY) {
		printf("ref/image size mismatch\n");
		exit(0);
	}
	xDim = [image xDim];
	yDim = [image yDim];
	imgSize = xDim * yDim;
	p1 = [image data];		// dst
	p2 = [img data];		// src
	for (pl = 0; pl < [image pixSize]; pl++) {
		for (i = 0; i < nY; i++) {
			y = yPos + i;
			if (y < 0 || y >= yDim) continue;
			for (j = 0; j < nX; j++) {
				x = xPos + j;
				if (x < 0 || x >= xDim) continue;
				ix1 = pl * [image dataLength] + zPos * imgSize + y * xDim + x;	// image
				ix2 = pl * [img dataLength] + i * nX + j;		// blk
				p1[ix1] = p2[ix2];
			}
		}
	}
}

@end

