//
//	RecImage
//

#import "RecImage.h"
#import "RecLoop.h"
#import "RecLoopIndex.h"
#import "RecLoopControl.h"
#import "RecNoise.h"
#import "RecUtil.h"
#import "RecCoilProfile.h"
#import <NumKit/NumKit.h>

// ===== RecAxis ====
@implementation RecAxis

+ (RecAxis *)axisWithLoop:(RecLoop *)lp
{
    RecAxis *ax = [[RecAxis alloc] initWithLoop:lp];
    return ax;
}

+ (RecAxis *)pointAx
{
	RecAxis *ax = [[RecAxis alloc] initWithLoop:[RecLoop pointLoop]];
	return ax;
}

// designated initializer
- (id)initWithLoop:(RecLoop *)lp
{
    self = [super init];
    if (self) {
        loop = lp;
        unit = REC_POS;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject: loop forKey:@"RecAxLp"];
	[coder encodeInt:    unit forKey:@"RecAxU"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];    // NSObject
    if (self) {
        loop = [coder decodeObjectForKey: @"RecAxLp"];
        unit = [coder decodeIntForKey:    @"RecAxU"];
    }
    return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	RecAxis		*ax;

    ax = [RecAxis axisWithLoop:[self loop]];
    if (!ax) return nil;
    [ax setUnit:unit];
	return ax;
}

- (void)setLoop:(RecLoop *)lp
{
    loop = lp;
}

- (RecLoop *)loop
{
    return loop;
}

- (int)unit
{
    return unit;
}

- (void)setUnit:(int)u
{
    unit = u;
}

- (void)changeUnit:(int)dir
{
    unit += dir;
// debug
    if (fft_dbg > 0 && (unit < 0 || unit > 1)) {
        printf("Loop: unit out of range\n");
    }

}

// loop
- (int)dataLength
{
    return [loop dataLength];
}

- (BOOL)isPointLoop
{
    return [loop isPointLoop];
}

@end

int		fft_mode = 0;	// 0:vDSP, 1:vDSP + NSOperation
BOOL	fft_dbg = NO;	// 0:unit check off, 1:unit check on

// ===== RecImage ====
@implementation RecImage

+ (void)setFFTmode:(int)mode
{
    fft_mode = mode;
}

// init with zero cleared data
// designated initializer
- (id)initWithDimensions:(NSArray *)dm type:(int)tp
{
    self = [super init];    // NSObject
    if (!self) return nil;

	type = tp;
	switch (type) {
	case	RECIMAGE_REAL :
		pixSize = 1;
		break;
	case	RECIMAGE_COMPLEX :
	case	RECIMAGE_MAP :
	default :
		pixSize = 2;
		break;
	case	RECIMAGE_KTRAJ :
		pixSize = 4;
		break;
	case	RECIMAGE_COLOR :
	case	RECIMAGE_VECTOR :
		pixSize = 3;
		break;
	case	RECIMAGE_AFFINE :
		pixSize = 6;
		break;
	case	RECIMAGE_HOMOG :
		pixSize = 8;
		break;
	case	RECIMAGE_QUAD :
		pixSize = 12;
		break;
	}

	dimensions = [NSArray arrayWithArray:dm];
	[self calcDataLength];
	data = [NSMutableData dataWithLength:sizeof(float) * pixSize * dataLength];
    name = @"NoName";

	return self;
}

// make deep copy of self
- (id)copyWithZone:(NSZone *)zone
{
	RecImage		*img;

//	img = [RecImage imageOfType:type withDimensions:dimensions]; // below is correct
    img = [RecImage imageOfType:type withDimensions:[self copyOfDimensions]];
	[img copyImage:self];

	return img;
}

+ (RecImage *)imageOfType:(int)tp withDimensions:(NSArray *)dims;
{
    RecImage    *im = [[RecImage alloc] initWithDimensions:dims type:tp];
    return im;
}

// loop array order: from higher to lower level (z, y, x etc)
+ (RecImage *)imageOfType:(int)tp withLoopArray:(NSArray *)lpArray;
{
    NSArray     *dm = [RecImage dimensionsFromLoops:lpArray];
    RecImage    *im = [[RecImage alloc] initWithDimensions:dm type:tp];
    return im;
}

// loop array order: from higher to lower level (z, y, x etc)
+ (RecImage *)imageOfType:(int)tp withLoops:(RecLoop *)lp, ...
{
	RecImage		*im = nil;
	NSMutableArray	*loops = [NSMutableArray array];
	va_list			varglist;

	if (lp) {
		[loops addObject:lp];
		va_start(varglist, lp);
		while ((lp = va_arg(varglist, RecLoop *))) {
			[loops addObject:lp];
			va_end(varglist);
		}
		im = [RecImage imageOfType:tp withLoopArray:loops];
	}

	return im;
}

// create image using active loops in lc (or make option to remove inactive loops)
+ (RecImage *)imageOfType:(int)tp withControl:(RecLoopControl *)lc
{
	NSMutableArray	*tmpArray = [NSMutableArray array];
	RecLoopIndex	*li;
	int				i, n;

	n = [lc dim];
	for (i = 0; i < n; i++) {
		li = [lc loopIndexAtIndex:i];
		if ([li active]) {
			[tmpArray addObject:[li loop]];
		}
	}
	return [RecImage imageOfType:tp withLoopArray:tmpArray];
}

// RecImage with one data value
+ (RecImage *)pointImageOfType:(int)tp
{
	RecLoop		*lp = [RecLoop pointLoop];
	return [RecImage imageOfType:tp withLoopArray:[NSArray arrayWithObject:lp]];
}

+ (RecImage *)pointImageWithReal:(float)val
{
	RecImage	*im = [RecImage pointImageOfType:RECIMAGE_REAL];
	float		*data = [im data];
	data[0] = val;

	return im;
}

+ (RecImage *)pointImageWithReal:(float)re imag:(float)im   // complex point
{
	RecImage	*img = [RecImage pointImageOfType:RECIMAGE_COMPLEX];
	float		*data = [img data];
	data[0] = re;
	data[1] = im;

	return img;
}

+ (RecImage *)pointPoint:(NSPoint)p            // NSPoint
{
	RecImage	*im = [RecImage pointImageOfType:RECIMAGE_MAP];
	float		*data = [im data];
	data[0] = p.x;
    data[1] = p.y;

	return im;
}

+ (RecImage *)pointVector:(RecVector)v         // RecVector
{
	RecImage	*im = [RecImage pointImageOfType:RECIMAGE_VECTOR];
	float		*data = [im data];
	data[0] = v.x;
    data[1] = v.y;
    data[2] = v.z;

	return im;
}

+ (RecImage *)imageOfType:(int)tp withImage:(RecImage *)img
{
//	RecImage *newImg = [RecImage imageOfType:tp withLoopArray:[img loops]];
//    [newImg copyDimensionsOf:img];	// #### copyDimensionsOf: is wrong !!!

	RecImage *newImg = [RecImage imageOfType:tp withDimensions:[img copyOfDimensions]];

	return newImg;
}

// copy structure (data is not copied)
+ (RecImage *)imageWithImage:(RecImage *)img
{
    RecImage    *newImg = [RecImage imageOfType:[img type] withImage:img];
    return newImg;
}

+ (RecImage *)sliceWithImage:(RecImage *)img
{
    RecImage    *newImg = [RecImage imageOfType:[img type] withLoops:[img yLoop], [img xLoop], nil];
    return newImg;
}

+ (RecImage *)imageOfType:(int)tp xDim:(int)xDim				// 1D
{
	RecImage    *newImg;
    RecLoop     *xLoop;
    xLoop = [RecLoop loopWithDataLength:xDim];
    newImg = [RecImage imageOfType:tp withLoops:xLoop, nil];
	return newImg;
}

+ (RecImage *)imageOfType:(int)tp xDim:(int)xDim yDim:(int)yDim
{
	RecImage    *newImg;
    RecLoop     *xLoop, *yLoop;
    xLoop = [RecLoop loopWithDataLength:xDim];
    yLoop = [RecLoop loopWithDataLength:yDim];
    newImg = [RecImage imageOfType:tp withLoops:yLoop, xLoop, nil];
	return newImg;
}

+ (RecImage *)imageOfType:(int)tp xDim:(int)xDim yDim:(int)yDim zDim:(int)zDim
{
	RecImage    *newImg;
    RecLoop     *xLoop, *yLoop, *zLoop;
    xLoop = [RecLoop loopWithDataLength:xDim];
    yLoop = [RecLoop loopWithDataLength:yDim];
    zLoop = [RecLoop loopWithDataLength:zDim];
    newImg = [RecImage imageOfType:tp withLoops:zLoop, yLoop, xLoop, nil];
	return newImg;
}

+ (RecImage *)imageOfType:(int)tp xDim:(int)xDim yDim:(int)yDim zDim:(int)zDim chDim:(int)chDim	// 4D
{
	RecImage    *newImg;
    RecLoop     *xLoop, *yLoop, *zLoop, *chLoop;
    xLoop = [RecLoop loopWithDataLength:xDim];
    yLoop = [RecLoop loopWithDataLength:yDim];
    zLoop = [RecLoop loopWithDataLength:zDim];
    chLoop = [RecLoop loopWithDataLength:chDim];
    newImg = [RecImage imageOfType:tp withLoops:chLoop, zLoop, yLoop, xLoop, nil];
	return newImg;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    // NSObject doesn't support NSCoding
	[coder encodeObject:	dimensions	forKey:@"RecImDim"];        // NSArray of RecAxis
	[coder encodeInt:		type		forKey:@"RecImType"];       // int
	[coder encodeInt:		pixSize		forKey:@"RecImPixSize"];    // int
	[coder encodeInt:		dataLength	forKey:@"RecImDtLen"];      // int
	[coder encodeObject:	data		forKey:@"RecImDtObj"];      // NSMutableData
	[coder encodeObject:	name		forKey:@"RecImName"];       // NSString
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];    // NSObject doesn't support NSCoding
    if (self) {
        dimensions	= [coder decodeObjectForKey:	@"RecImDim"];        // NSArray of RecAxis
        type		= [coder decodeIntForKey:		@"RecImType"];       // int
        pixSize		= [coder decodeIntForKey:		@"RecImPixSize"];    // int
        dataLength	= [coder decodeIntForKey:		@"RecImDtLen"];      // int
        data		= [coder decodeObjectForKey:	@"RecImDtObj"];      // NSMutableData
        name		= [coder decodeObjectForKey:	@"RecImName"];       // NSString
    }
	return self;
}

// test -> NSString *curDir = [[NSFileManager defaultManager] currentDirectoryPath];
- (void)saveToFile:(NSString *)path relativePath:(BOOL)flg
{
	char        cwd[256];
    BOOL        sts;

	if (flg && (getcwd(cwd, 256) != NULL)) {		// if path is relative to current dir
		path = [NSString stringWithFormat:@"%s/%@", cwd, path];
	}
	if (![[path pathExtension] isEqualToString:@"recimg"]) {	// force "recimg" extention
		path = [path stringByAppendingPathExtension:@"recimg"];
	}
	sts = [NSKeyedArchiver archiveRootObject:self toFile:path];
// debug code ###
    if (sts) {
        printf("Archiving to file succeeded\n");
        [self dumpLoops];
    } else {
        printf("Error in archiving\n");
        [self dumpLoops];
    }
}

+ (RecImage *)imageFromFile:(NSString *)path relativePath:(BOOL)flg
{
	RecImage	*img = nil;
	char		cwd[256];

	if (![[path pathExtension] isEqualToString:@"recimg"]) {	// check image type
		path = [path stringByAppendingPathExtension:@"recimg"];
	}
	if (flg && (getcwd(cwd, 256) != NULL)) {
		path = [NSString stringWithFormat:@"%s/%@", cwd, path];
	}
	img = [NSKeyedUnarchiver unarchiveObjectWithFile:path];

	return img;
}

- (void)calcDataLength
{
	int			i, len = 1;
	int			n = (int)[dimensions count];
	RecLoop		*lp;

	for (i = 0; i < n; i++) {
		lp = [[dimensions objectAtIndex:i] loop];
		len *= [lp dataLength];
	}
	dataLength = len;
}

+ (NSArray *)loopsFromDimensions:(NSArray *)dm
{
    int     i, n = (int)[dm count];
    NSMutableArray  *lp = [NSMutableArray array];

    for (i = 0; i < n; i++) {
        [lp addObject:[[dm objectAtIndex:i] loop]];
    }
    return [NSArray arrayWithArray:lp];
}

+ (NSArray *)dimensionsFromLoops:(NSArray *)lp
{
    int     i, n = (int)[lp count];
    NSMutableArray  *dm = [NSMutableArray array];

    for (i = 0; i < n; i++) {
        [dm addObject:[RecAxis axisWithLoop:[lp objectAtIndex:i]]];
    }
    return [NSArray arrayWithArray:dm];
}

- (int)dataLength
{
	return dataLength;
}

- (int)dim
{
	return (int)[dimensions count];
}

- (int)realDim
{
	int		i, n = (int)[dimensions count];
	int		dim = 0;

	for (i = 0; i < n; i++) {
		if (![[[dimensions objectAtIndex:i] loop] isPointLoop]) {
			dim++;
		}
	}
	return dim;
}

- (int)pixSize
{
	return pixSize;
}

- (NSData *)dataObj
{
    return data;
}

- (float *)data
{
	return (float *)[data mutableBytes];
}

- (float *)real
{
    return [self data];
}

- (float *)imag
{
    return [self data] + [self dataLength];
}

- (float *)r
{
	return [self data];
}

- (float *)g
{
	return [self data] + [self dataLength];
}

- (float *)b
{
	return [self data] + [self dataLength] * 2;
}

// for point image (float)
- (void)setVal:(float)val
{
	float	*p = [self data];
	*p = val;
}

// for point image (complex, map)
- (void)setVal1:(float)val1 val2:(float)val2
{
	float	*p = [self data];
	p[0] = val1;
	p[1] = val2;
}

- (int)type
{
	return type;
}

- (NSArray *)loops
{
    return [RecImage loopsFromDimensions:dimensions];
}

- (void)setLoops:(NSArray *)loopArray
{
    dimensions = [RecImage dimensionsFromLoops:loopArray];
}

- (void)setDimensions:(NSArray *)dim
{
    dimensions = dim;
}
    
- (NSArray *)dimensions
{
    return dimensions;
}

- (NSArray *)copyOfDimensions   // [dimensions copy] returns a shallow copy
{
    int     i, n = (int)[dimensions count];
    NSMutableArray  *dm = [NSMutableArray array];

    for (i = 0; i < n; i++) {
        [dm addObject:[[dimensions objectAtIndex:i] copy]];
    }
    return [NSArray arrayWithArray:dm];
}

// image dim comparison
- (BOOL)hasEqualDimWith:(RecImage *)img
{
    int     i, n = [self dim];

    if (type != [img type]) return NO;
    if (n != [img dim])     return NO;
    for (i = 0; i < n; i++) {
        if (![[self loopAtIndex:i] isEqualTo:[img loopAtIndex:i]]) {
            return NO;
        }
    }
    return YES;
}

- (void)dumpLoops
{
	RecLoop			*lp;
    RecAxis         *ax;
	int				i, n;

	printf("===== Loops (RecImage [%s]) =======\n", [name UTF8String]);
	n = (int)[dimensions count];
	for (i = 0; i < n; i++) {
        ax = [dimensions objectAtIndex:i];
		lp = [ax loop];
		printf("RecLoop:[%s](%d) %d lp:0x%0lx ax:0x%0lx\n",
            [[lp name] UTF8String],
            [ax unit],
            [lp dataLength],
            (unsigned long)lp,
            (unsigned long)ax);
	}
	printf("===================\n");
}

- (int)skipSizeForLoop:(RecLoop *)lp
{
	int			skip = 1;
	RecLoop		*loop;
	int			i, n = (int)[dimensions count];

	for (i = n - 1; i >= 0; i--) {
		loop = [[dimensions objectAtIndex:i] loop];
		if ([lp isEqual:loop]) break;
		skip *= [loop dataLength];
	}
	if (i < 0) {	// loop not found
		NSLog(@"Loop [%@] not found in image.", [lp name]);
		exit(0);
	}

	return skip;
}

// loops have to match between image and control
//  (can be obtained using controlWithControl: forImage:)
// this is critical step for speed
- (float *)currentDataWithControl:(RecLoopControl *)control
{
	return [self data] + [control current];
}

- (float *)currentDataWithControl:(RecLoopControl *)control line:(int)y
{
    return [self currentDataWithControl:control] + [self xDim] * y;
}

typedef struct {
	int				magic;	// KO_MAGIC3
	int				type;
	int				xdim;
	int				ydim;
	int				zdim;
	int				fill[3];
}	KO_HDR3;	// 32 bytes

- (void)saveAsKOImage:(NSString *)path		// save as KOImage block
{
	const char		*cPath = [path UTF8String];
	FILE			*fp;
	KO_HDR3			hdr3;
	int				totalSize;

	hdr3.magic = 0x494d3344;	// 	"IM3D"
	switch (type) {
	case RECIMAGE_REAL :
		hdr3.type = 2;  // KO_REAL
		break;
	default :
	case RECIMAGE_COMPLEX :
	case RECIMAGE_MAP :
	case RECIMAGE_KTRAJ :   // 4 planes (kx, ky, den, wt)
    case RECIMAGE_HOMOG :   // 8 planes
		hdr3.type = 4;  // KO_COMPLEX
		break;
	case RECIMAGE_COLOR :
	case RECIMAGE_VECTOR :
		hdr3.type = 8;  // KO_COLOR
		break;
	}

// calc dimensions
	hdr3.xdim = [self xDim];
	hdr3.ydim = [self yDim];
	hdr3.zdim = [self nImages];
	totalSize = [self dataLength] * pixSize;

// write image file
	fp = fopen(cPath, "w");
    if (fp == NULL) {
        printf("Couldn't open file [%s].\n", cPath);
        return;
    }
	fwrite(&hdr3, sizeof(KO_HDR3), 1, fp);
	fwrite([self data], sizeof(float), totalSize, fp);
	fclose(fp);
}

- (void)saveRawAsKOImage:(NSString *)path
{
	RecImage	*logImg = [self copy];
//	logImg = [logImg logP1];
	[logImg logP1];
	[logImg saveAsKOImage:path];
}

- (void)initWithKOImage:(NSString *)path
{
	const char		*cPath = [path UTF8String];
	FILE			*fp;
	KO_HDR3			hdr3;
	float			*p;
	
	if ((fp = fopen(cPath, "r")) == NULL) {
		NSLog(@"Couldn't open KOImage.");
		return;
	}
	fread(&hdr3, sizeof(KO_HDR3), 1, fp);
	p = [self data];
	fread(p, sizeof(float), dataLength, fp);
	if (pixSize == 2) {
		p += dataLength;
		fread(p, sizeof(float), dataLength, fp);
	}
	fclose(fp);
    if ([self checkNaN]) printf("RecImage:initWithKOImage NaN found\n");
}

+ (RecImage *)imageWithKOImage:(NSString *)path	// read from KOImage
{
	const char		*cPath = [path UTF8String];
	FILE			*fp;
	KO_HDR3			hdr3;
	int				dataLength;
    int             i, j, pixSize;
    int             ix, size = 0;
	int				type;
    BOOL            toFloat = NO;
	RecImage		*img;
	RecLoop			*kx, *ky, *kz;
	float			*p;
    short           *pi;
	
	if ((fp = fopen(cPath, "r")) == NULL) {
		NSLog(@"Couldn't open KOImage.");
		return nil;
	}
	fread(&hdr3, sizeof(KO_HDR3), 1, fp);
	if (hdr3.magic != 0x494d3344) {
		NSLog(@"Not a KOImage.");
		return nil;
	}
		
	switch (hdr3.type) {
	case 1 :    // integer
		type = RECIMAGE_REAL;
        toFloat = YES;
        break;
	case 2 :
	default :
		type = RECIMAGE_REAL;
		break;
	case 4 :
		type = RECIMAGE_COMPLEX;
		break;
    case 7 :
    case 8 :
        type = RECIMAGE_VECTOR;
        break;
	}
	kx = [RecLoop loopWithName:nil dataLength:hdr3.xdim];
	ky = [RecLoop loopWithName:nil dataLength:hdr3.ydim];
	kz = [RecLoop loopWithName:nil dataLength:hdr3.zdim];
	img = [RecImage imageOfType:type withLoops:kz, ky, kx, nil];
	p = [img data];
	dataLength = hdr3.xdim * hdr3.ydim * hdr3.zdim;
    pixSize = [img pixSize];

    if (toFloat) {
        size = hdr3.xdim * hdr3.ydim;
        pi = (short *)malloc(sizeof(short) * size);
        ix = 0;
        for (i = 0; i < hdr3.zdim; i++) {
            fread(pi, sizeof(short), size, fp);
            for (j = 0; j < size; j++, ix++) {
                p[ix] = (float)pi[j];
            }
        }
        free(pi);
    } else {
        for (i = 0; i < pixSize; i++) {
            fread(p, sizeof(float), dataLength, fp);
            p += dataLength;
        }
    }
	fclose(fp);

    if ([img checkNaN])  printf("RecImage:imageWithKOImage NaN found\n");

	return img;
}

// for Osirix etc (16bit real only, signed short)
- (void)initWithRawImage:(NSString *)path			// read from raw (real)
{
	const char *cPath = [path UTF8String];
	FILE	*fp;
	int		len;
	float	*p;

	if ((fp = fopen(cPath, "r")) == NULL) return;
	fseek(fp, 0, SEEK_END);
	len = (int)ftell(fp);
	len /= sizeof(float);	// number of short
	if (len > dataLength) {
		len = dataLength;
	}
	rewind(fp);
	p = [self data];
	fread(p, sizeof(float), len, fp);
	fclose(fp);
}

// for Osirix etc (16bit real only, signed short)
// I -> S
- (void)saveAsRawImage:(NSString *)path				// save as raw
{
	const char *cPath = [path UTF8String];
	FILE	*fp;
	int		i, j, nslice, slsize;
	short	*buf, *dst;
	float	*p, *src;

    [self scaleToVal:4000.0];
	buf = (short *)malloc(dataLength * sizeof(short));
	p = [self data];
// slice flip
    slsize = [self xDim] * [self yDim];
    nslice = dataLength / slsize;
    for (i = 0; i < nslice; i++) {
        src = p + slsize * i;
        dst = buf + (nslice - i - 1) * slsize;
        for (j = 0; j < slsize; j++) {
            dst[j] = src[j];
        }
    }
// save to file
	fp = fopen(cPath, "w");
	fwrite(buf, sizeof(short), dataLength, fp);
	fclose(fp);
	free(buf);
}

// remove all but one
- (void)removePointLoops
{
	int				i, n, nAdded;
    RecAxis         *ax;
	NSMutableArray	*tmpArray = [NSMutableArray array];

	n = (int)[dimensions count];
    nAdded = 0;
	for (i = 0; i < n; i++) {
		ax = [dimensions objectAtIndex:i];
		if ([ax dataLength] > 1) {
			[tmpArray addObject:ax];
            nAdded++;
		}
	}
    if (nAdded == 0) {
        [tmpArray addObject:ax];
    }
	dimensions = [NSArray arrayWithArray:tmpArray];
}

// change loop order, and update data
// swap axis (with unit intact) ####
- (void)swapLoop:(RecLoop *)lp1 withLoop:(RecLoop *)lp2
{
	int				i, n = (int)[dimensions count];
	RecAxis			*ax, *ax1, *ax2;
    RecLoop         *lp;
    int             ix1, ix2;
	NSMutableArray	*newDms = [NSMutableArray arrayWithArray:dimensions];
    RecImage        *img = [self copy];

    ax1 = ax2 = nil;
    for (i = 0; i < n; i++) {
		ax = [dimensions objectAtIndex:i];
        lp = [ax loop];
        if ([lp isEqual:lp1]) {
            ax1 = ax;
            ix1 = i;
        } else
        if ([lp isEqual:lp2]) {
            ax2 = ax;
            ix2 = i;
        }
    }
    if (ax1 != nil && ax2 != nil) {
        [newDms replaceObjectAtIndex:ix1 withObject:ax2];
        [newDms replaceObjectAtIndex:ix2 withObject:ax1];
        dimensions = [NSArray arrayWithArray:newDms];
        [self copyImage:img];
    }
}

// increase dimension (copy data)
- (void)addLoopX:(RecLoop *)loop
{
	RecImage			*img;
	NSMutableArray      *newDms = [NSMutableArray arrayWithArray:dimensions];

	[newDms insertObject:loop atIndex:0];
//	img = [RecImage imageOfType:[self type] withDimensions:newDms];
//	[img copyImage:self];
//	[self copyIvarOf:img];
	img = [self copy];
	dimensions = [NSArray arrayWithArray:newDms];
	[self copyImage:img];
}

- (void)addLoop:(RecLoop *)loop
{
	RecImage			*img;
	NSMutableArray      *loops = [NSMutableArray arrayWithArray:[self loops]];

	[loops insertObject:loop atIndex:0];
	img = [RecImage imageOfType:[self type] withLoopArray:loops];
	[self copyIvarOf:img];
}

- (RecLoop *)addLoopWithLength:(int)len
{
	RecLoop	*lp;
	lp = [RecLoop loopWithDataLength:len];
	[self addLoop:lp];
	return lp;
}

// crop / zero-fill
- (void)replaceLoop:(RecLoop *)loop withLoop:(RecLoop *)newLoop
{
    int     ofs;

	if (loop == newLoop) return;
	ofs = [loop dataLength]/2 - [newLoop dataLength]/2;
    [self replaceLoop:loop withLoop:newLoop offset:ofs];
}

// ofs: start pos (+ or -) in NEW loop
- (void)replaceLoop:(RecLoop *)lp withLoop:(RecLoop *)newLp offset:(int)ofs
{
    RecLoopControl  *lc = [self control];
    RecLoopControl  *newLc;
    RecImage        *img;
    NSRange         rg, newRg;
    int             len = [lp dataLength];
    int             newLen = [newLp dataLength];
    int             u = [self unitForLoop:lp];	// save unit of old loop

    newLc = [lc copy];
    [newLc replaceLoop:lp withLoop:newLp];

	if (ofs < 0) {
		rg.location = 0;
		newRg.location = -ofs;
		rg.length = newRg.length = Rec_min(len, newLen + ofs);
	} else {
		rg.location = ofs;
		newRg.location = 0;
		rg.length = newRg.length = Rec_min(len - ofs, newLen);
	}
	[lc setRange:rg forLoop:lp];
	[newLc setRange:newRg forLoop:newLp];

    // create new image
    img = [RecImage imageOfType:[self type] withControl:newLc];
    [img copyUnitOfImage:self];
	[img setUnit:u forLoop:newLp];

    // copy image
    [img copyImage:self dstControl:newLc srcControl:lc];
    [self copyIvarOf:img];
 }

- (RecImage *)replaceLoop:(RecLoop *)lp withTab:(RecImage *)tab
{
	RecLoop			*newLp = [tab xLoop];
    RecLoopControl  *lc = [self control];
    RecLoopControl  *newLc;
	RecLoopIndex	*li, *newLi;
	float			*newIx;
	float			*src, *dst;
    RecImage        *img;
	int				len = [tab xDim];
	int				i, ii, j, k, n, loopLen;
    int             u = [self unitForLoop:lp];	// save unit of old loop

    // create new image
    img = [RecImage imageWithImage:self];
	[img replaceLoop:lp withLoop:newLp];
    [img copyUnitOfImage:self];
	[img setUnit:u forLoop:newLp];
	newIx = [tab data];

    // copy image data ### not finished yet
	lc = [self control];	// src
	li = [lc loopIndexForLoop:lp];
	newLc = [RecLoopControl controlWithControl:lc forImage:img];
	newLi = [newLc loopIndexForLoop:newLp];
	[lc deactivateLoop:lp];

// assuming lp is not innermost... (fix special case later) ###########
	if ([lc dim] >= 2) {
		[lc deactivateInner];
		n = [self xDim];
	} else {
		n = 1;
	}
	loopLen = [lc loopLength];
	for (ii = 0; ii < len; ii++) {
		[newLi setCurrent:ii];
		[li setCurrent:(int)newIx[ii]];
		for (i = 0; i < loopLen; i++) {
			src = [self currentDataWithControl:lc];
			dst = [img currentDataWithControl:newLc];
			for (k = 0; k < pixSize; k++) {
				for (j = 0; j < n; j++) {
					dst[j] = src[j];
				}
				src += [self dataLength];
				dst += [img dataLength];
			}
			[lc increment];
		}
	}

	return img;
 }

- (void)changeLoop:(RecLoop *)lp dataLength:(int)newLen offset:(int)ofs  // if new loop is not used by others...
{
    RecLoop *newLp = [RecLoop loopWithDataLength:newLen];
    [self replaceLoop:lp withLoop:newLp offset:ofs];
}

- (RecLoop *)zeroFill:(RecLoop *)lp to:(int)newDim
{
    RecLoop *newLp;
    int     dim;

    dim = [lp dataLength];
    if (dim != newDim) {
        newLp = [RecLoop loopWithDataLength:newDim];
        [self replaceLoop:lp withLoop:newLp];
    }
    return newLp;
}

- (RecLoop *)zeroFill:(RecLoop *)lp to:(int)newDim offset:(int)ofs
{
    RecLoop *newLp;
    int     dim;

    dim = [lp dataLength];
    if (dim != newDim) {
        newLp = [RecLoop loopWithDataLength:newDim];
        [self replaceLoop:lp withLoop:newLp offset:ofs];
    }
    return newLp;
}

// returns nil if dim is already po2
- (RecLoop *)zeroFillToPo2:(RecLoop *)lp
{
    int     dim = [lp dataLength];
    int     newDim = Rec_po2(dim);
    RecLoop *newLp = nil;

    if (dim != newDim) {
        newLp = [self zeroFill:lp to:newDim];
    } else {
		newLp = lp;
	}
    return newLp;
}

- (RecLoop *)cycFill:(RecLoop *)lp to:(int)newDim	// cyclic fill for cyclic convolution
{
    int     dim = [lp dataLength];
    RecLoop *newLp = nil;
	RecLoopControl	*lc;
	int		i, j;
	int		m, n, nLp, d1, d2;
	float	*p, *q;

    if (dim != newDim) {
		m = [lp dataLength];
        newLp = [self zeroFill:lp to:newDim];
		n = [newLp dataLength];
		d2 = (n - m) / 2;
		d1 = n - m - d2;
		lc = [self control];
		[lc deactivateLoop:newLp];
		nLp = [lc loopLength];

		for (i = 0; i < nLp; i++) {
			p = [self currentDataWithControl:lc];
			q = p + [self dataLength];
			// cyclic fill
			for (j = 0; j < n; j++) {
				if (j < d1) {
					p[j] = p[m + j];
					q[j] = q[m + j];
				} else
				if (j >= n - d2) {
					p[j] = p[j - m];
					q[j] = q[j - m];
				}
			}
			[lc increment];
		}
    } else {
		newLp = lp;
	}
    return newLp;
}

- (void)zeroFillToPo2		// zerofill xy
{
	[self zeroFillToPo2:[self xLoop]];
	[self zeroFillToPo2:[self yLoop]];
}

- (RecLoop *)crop:(RecLoop *)lp to:(int)newDim
{
    RecLoop *newLp;
    if ([lp dataLength] != newDim) {
        newLp = [self zeroFill:lp to:newDim];
    }
    return newLp;
}

- (RecLoop *)crop:(RecLoop *)lp to:(int)newDim startAt:(int)st // returns newly created loop
{
	RecLoop		*newLp;
    if ([lp dataLength] != newDim) {
		newLp = [RecLoop loopWithDataLength:newDim];
        [self replaceLoop:lp withLoop:newLp offset:st];
    }
    return newLp;
}

- (RecLoop *)cropToPo2:(RecLoop *)lp // returns newly created loop
{
    int     dim = [lp dataLength];
    int     newDim = Rec_po2(dim);
    RecLoop *newLp = nil;

    if (dim != newDim) {
        newLp = [self crop:lp to:newDim/2];
    } else {
		newLp = lp;
	}
    return newLp;
}

- (void)cropToPo2
{
	[self cropToPo2:[self xLoop]];
	[self cropToPo2:[self yLoop]];
}

// copy other image to self
// entries are all objects now... should be ok
- (void)copyIvarOf:(RecImage *)img
{
	dimensions  = img->dimensions;
	type        = img->type;
	pixSize     = img->pixSize;
	dataLength  = img->dataLength;
	data        = img->data;
	name        = img->name;
}

// copy image data ignoring loopControl
// total size must be equal
- (void)copyImageData:(RecImage *)img
{
	int		i;
	int		len = dataLength * pixSize;
	float	*p, *q;

	if (len != [img dataLength] * [img pixSize]) return;	// size not equal
	q = [self data];
	p = [img data];
	for (i = 0; i < len; i++) {
		q[i] = p[i];
	}
}

- (void)copyDimensionsOf:(RecImage *)img
{
    if ([self dim] != [img dim]) return;
    if ([self dataLength] != [img dataLength]) return;
    [self setDimensions:[img dimensions]];
}

- (void)copyLoopsOf:(RecImage *)img
{
    [self copyDimensionsOf:img];
}

- (void)copyXYLoopsOf:(RecImage *)img
{
	int	ix = [self dim] - 1;	// xLoop
	NSMutableArray	*newDms = [NSMutableArray arrayWithArray:dimensions];
	if ([self xDim] != [img xDim] || [self yDim] != [img yDim]) return;
	[newDms replaceObjectAtIndex:ix     withObject:[img xLoopAx]];
	[newDms replaceObjectAtIndex:ix - 1 withObject:[img yLoopAx]];
	dimensions = [NSArray arrayWithArray:newDms];
}

- (void)copyXYZLoopsOf:(RecImage *)img
{
	int	ix = [self dim] - 1;	// xLoop
	NSMutableArray	*newDms = [NSMutableArray arrayWithArray:dimensions];
	if ([self xDim] != [img xDim] || [self yDim] != [img yDim]) return;
	[newDms replaceObjectAtIndex:ix     withObject:[img xLoopAx]];
	[newDms replaceObjectAtIndex:ix - 1 withObject:[img yLoopAx]];
	[newDms replaceObjectAtIndex:ix - 2 withObject:[img zLoopAx]];
	dimensions = [NSArray arrayWithArray:newDms];
}

//
// === copyImage method group ===
// - copyImage:img
//      copy img to self using control for larger of two. uses -copyImage: withControl:.
//      actual processing are done for innermost among active loops of self.
// - copyImage:img withControl:control
//      copy img to self using control. separate srcControl and dstControl (with common states) are created,
//      and used for copying. passed control is not modified.
// - copyImage:img withSrcControl:sLc andDstControl:dLc
//      special case, in which sLc and dLc are separately incremented. sLc/dLc should not have common states.
//

// two images may have different loop structure (trans etc)
- (void)copyImage:(RecImage *)img
{
    if ([self dim] >= [img dim]) {
        [self copyImage:img withControl:[self control]];
    } else {
        [self copyImage:img withControl:[img control]];
    }
}

// ver.4
- (void)copyImage:(RecImage *)img withControl:(RecLoopControl *)control
{
    void    (^proc)(float *src, int srcSkip, float *dst, int dstSkip, int len);

    proc = ^void(float *src, int srcSkip, float *dst, int dstSkip, int len) {
        int     i, srcIx, dstIx;
        for (i = srcIx = dstIx = 0; i < len; i++) {
            dst[dstIx] = src[srcIx];
            srcIx += srcSkip;
            dstIx += dstSkip;
        }
    };
    [self apply2ImageProc:proc withImage:img andControl:control];
}

// src and dst are independent (no common state)
// a special case
// range of inner loop not handled ###
- (void)copyImage:(RecImage *)img dstControl:(RecLoopControl *)dLc srcControl:(RecLoopControl *)sLc
{
	int				i, j, k, len;
	int				loopLength;
	float			*src, *dst;
	RecLoop			*srcLp, *dstLp;
	int				srcPos, dstPos;
	int				srcSkip, dstSkip;
	int				srcDataLength;
    RecLoopControl  *srcLc = [sLc copy];    // flags will be modified
    RecLoopControl  *dstLc = [dLc copy];    // flags will be modified

	if ([dLc isEqual:srcLc]) {
		[self copyImage:img withControl:sLc];
		return;
	}

// innner loop has range, too
	dstLp = [dstLc innerLoop];
	srcLp = [srcLc innerLoop];
//    len = [dstLc loopLengthOfLoop:dstLp];   // has to be equal to src loopLength
    len = [[[dstLc loopIndexForLoop:dstLp] state] loopLength];   // skip active flag

	srcSkip = [img skipSizeForLoop:srcLp];
	dstSkip = [self skipSizeForLoop:dstLp];
	srcDataLength = [img dataLength];

	[dstLc rewind];
	[srcLc rewind];
	[dstLc deactivateInner];	// has to be after rewind
	[srcLc deactivateInner];	// has to be after rewind
	loopLength = [dstLc loopLength];

	for (i = 0; i < loopLength; i++) {
		src = [img currentDataWithControl:srcLc];
		dst = [self currentDataWithControl:dstLc];
		// no vDSP_copy?
		for (k = 0; k < pixSize; k++) {
			srcPos = dstPos = 0;
			for (j = 0; j < len; j++) {
				dst[dstPos] = src[srcPos];
				srcPos += srcSkip;
				dstPos += dstSkip;
			}
			src += srcDataLength;
			dst += dataLength;
		}
		[dstLc increment];
		[srcLc increment];
	}
//	[self copyLoopsOf:img];
}

// accumulate
- (void)accumImage:(RecImage *)img
{
    if ([self dim] >= [img dim]) {
        [self accumImage:img withControl:[self control]];
    } else {
        [self accumImage:img withControl:[img control]];
    }
}

- (void)accumImage:(RecImage *)img withControl:(RecLoopControl *)lc
{
    void    (^proc)(float *src, int srcSkip, float *dst, int dstSkip, int len);

    proc = ^void(float *src, int srcSkip, float *dst, int dstSkip, int len) {
        int     i, srcIx, dstIx;
        for (i = srcIx = dstIx = 0; i < len; i++) {
            dst[dstIx] += src[srcIx];	// accum
            srcIx += srcSkip;
            dstIx += dstSkip;
        }
    };
    [self apply2ImageProc:proc withImage:img andControl:lc];
}

- (void)accumImage:(RecImage *)img dstControl:(RecLoopControl *)dLc srcControl:(RecLoopControl *)sLc
{
	int				i, j, k, len;
	int				loopLength;
	float			*src, *dst;
	RecLoop			*srcLp, *dstLp;
	int				srcPos, dstPos;
	int				srcSkip, dstSkip;
	int				srcDataLength;
    RecLoopControl  *srcLc = [sLc copy];    // flags will be modified
    RecLoopControl  *dstLc = [dLc copy];    // flags will be modified

	if ([dLc isEqual:srcLc]) {
		[self accumImage:img withControl:sLc];
		return;
	}

// innner loop has range, too
	dstLp = [dstLc innerLoop];
	srcLp = [srcLc innerLoop];
//    len = [dstLc loopLengthOfLoop:dstLp];   // has to be equal to src loopLength
    len = [[[dstLc loopIndexForLoop:dstLp] state] loopLength];   // skip active flag

	srcSkip = [img skipSizeForLoop:srcLp];
	dstSkip = [self skipSizeForLoop:dstLp];
	srcDataLength = [img dataLength];

	[dstLc rewind];
	[srcLc rewind];
	[dstLc deactivateInner];	// has to be after rewind
	[srcLc deactivateInner];	// has to be after rewind
	loopLength = [dstLc loopLength];

	for (i = 0; i < loopLength; i++) {
		src = [img currentDataWithControl:srcLc];
		dst = [self currentDataWithControl:dstLc];
		// no vDSP_copy?
		for (k = 0; k < pixSize; k++) {
			srcPos = dstPos = 0;
			for (j = 0; j < len; j++) {
				dst[dstPos] += src[srcPos];	// accum
				srcPos += srcSkip;
				dstPos += dstSkip;
			}
			src += srcDataLength;
			dst += dataLength;
		}
		[dstLc increment];
		[srcLc increment];
	}
//	[self copyLoopsOf:img];
}

- (RecImage *)sliceAtIndex:(int)ix
{
    RecImage        *img;
    RecLoopControl  *lc;
    int             i;

    lc = [self control];
    [lc deactivateXY];
    for (i = 0; i < ix; i++) {
        [lc increment];
    }
    [lc deactivateAll];
    [lc activateXY];
    img = [RecImage imageOfType:[self type] withLoops:[self yLoop], [self xLoop], nil];
    [img copyImage:self withControl:lc];
	[img setUnit:REC_FREQ forLoop:[img xLoop]];
	[img setUnit:REC_FREQ forLoop:[img yLoop]];
    
    return img;
}

- (RecImage *)firstSlice
{
    return [self sliceAtIndex:0];
}

// axis is now copied, rather than referenced
- (RecImage *)sliceAtIndex:(int)ix forLoop:(RecLoop *)lp
{
    RecImage        *img;
    RecLoopControl  *lc;
    NSMutableArray  *dims;
	RecAxis			*ax;
    int             i, n;

    lc = [self control];
    [lc deactivateAll];
    [lc activateLoop:lp];
    for (i = 0; i < ix; i++) {
        [lc increment];
    }
    [lc invertActive];

    dims = [NSMutableArray arrayWithArray:[self copyOfDimensions]];
	n = (int)[dims count];
	for (i = 0; i < n; i++) {
		ax = [dims objectAtIndex:i];
		if ([ax loop] == lp) {
			[dims removeObject:ax];
			break;
		}
	}
//	[dims removeObject:[self axisForLoop:lp]];

    img = [RecImage imageOfType:[self type] withDimensions:dims];
    [img copyImage:self withControl:lc];

    return img;
}

// new slice is returned (self is changed)
- (RecLoop *)removeSliceAtIndex:(int)ix forLoop:(RecLoop *)lp
{
    RecImage        *img;
    RecLoopControl  *srcLc, *dstLc;
    RecLoopIndex    *srcLi,*dstLi;
    RecLoop         *newLp;
    int             i, j, len;

	if (![self containsLoop:lp]) return nil;
    if ([lp dataLength] < 2) return nil;    // or should return self?

    len = [lp dataLength] - 1;
 //   newLp = [RecLoop loopWithName:@"new" dataLength:len]; // was a bug with @"" -> should be OK now
    newLp = [RecLoop loopWithDataLength:len];
//    img = [RecImage imageWithImage:self];
//    [img replaceLoop:lp withLoop:newLp];
	img = [self copy];
	[self replaceLoop:lp withLoop:newLp];

// src:img, dst:self
    srcLc = [img control];
    [srcLc deactivateLoop:lp];
    srcLi = [srcLc loopIndexForLoop:lp];
    dstLc = [self control];
    [dstLc deactivateLoop:newLp];
    dstLi = [dstLc loopIndexForLoop:newLp];

    for (i = j = 0; i < len; i++, j++) { // i: dst, j:src (i <= j)
        if (i == ix) j++;
        [srcLi setCurrent:j];
        [dstLi setCurrent:i];
        [self copyImage:img dstControl:dstLc srcControl:srcLc];
    }

    return newLp;
}

// inverse of sliceAtIndex:
- (void)copySlice:(RecImage *)slc atIndex:(int)ix
{
	RecLoopControl	*lc;
	int				i;

	lc = [self control];
	[lc deactivateXY];
	for (i = 0; i < ix; i++) {
		[lc increment];
	}
	[lc deactivateAll];
	[lc activateXY];
    [self copyImage:slc withControl:lc];
}

// inverse of sliceAtIndex:forLoop:
- (void)copySlice:(RecImage *)slc atIndex:(int)ix forLoop:(RecLoop *)lp
{
	RecLoopControl	*lc;
	RecLoop			*currentLp;
	int				i, dim;

	lc = [self control];
	dim = [lc dim];

//	[lc deactivateXY];	-> deactivate upto lp
// make method of loopControl
	for (i = 0; i < dim; i++) {
		currentLp = [lc loopAtIndex:dim - i - 1];
        if ([currentLp isEqual:lp]) {
			break;
		}
		[lc deactivateLoop:currentLp];
	}
	for (i = 0; i < ix; i++) {
		[lc increment];
	}
	[lc invertActive];
	[lc rewind];
    [self copyImage:slc withControl:lc];
}

- (void)accumSlice:(RecImage *)slc atIndex:(int)ix
{
	RecLoopControl	*lc;
	int				i;

	lc = [self control];
	[lc deactivateXY];
	for (i = 0; i < ix; i++) {
		[lc increment];
	}
	[lc deactivateAll];
	[lc activateXY];
    [self accumImage:slc withControl:lc];
}

- (void)accumSlice:(RecImage *)slc atIndex:(int)ix forLoop:(RecLoop *)lp
{
	RecLoopControl	*lc;
	RecLoop			*currentLp;
	int				i, dim;

	lc = [self control];
	dim = [lc dim];

//	[lc deactivateXY];	-> deactivate upto lp
// make method of loopControl
	for (i = 0; i < dim; i++) {
		currentLp = [lc loopAtIndex:dim - i - 1];
        if ([currentLp isEqual:lp]) {
			break;
		}
		[lc deactivateLoop:currentLp];
	}
	for (i = 0; i < ix; i++) {
		[lc increment];
	}
	[lc invertActive];
	[lc rewind];
    [self accumImage:slc withControl:lc];
}

- (RecImage *)pixPlaneAtIndex:(int)ix
{
    RecImage    *img;
    float       *src, *dst;
    int         i, len;

    img = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
    len = [self dataLength];
    src = [self data] + len * ix;
    dst = [img data];
    for (i = 0; i < len; i++) {
        dst[i] = src[i];
    }
    return img;
}

// ====  block version ====
- (RecImage *)subImage:(RecImage *)img
{
    void    (^proc)(float *src, int srcSkip, float *dst, int dstSkip, int len);

    proc = ^void(float *src, int srcSkip, float *dst, int dstSkip, int len) {
    //    vDSP_vsub(src, srcSkip, dst, dstSkip, dst, dstSkip, len);   // actual processing
		int		i;
		for (i = 0; i < len; i++) {
			dst[i * dstSkip] -= src[i * srcSkip];
		}
    };
    // src is img, dst is self
    [self apply2ImageProc:proc withImage:img];

    return self;
}

- (RecImage *)scaleAndSubImage:(RecImage *)img scale:(float)sc	// make avg of two equal, then subtract
{
	float		av1, av2;
	RecImage	*sub = [self copy];	// to avoid adv effect

	av1 = [sub meanVal] * sc;
	av2 = [img meanVal];
	av2 /= av1;
	[sub multByConst:av2];
	return [sub subImage:img];
}

- (RecImage *)addImage:(RecImage *)img
{
    void    (^proc)(float *src, int srcSkip, float *dst, int dstSkip, int len);

    proc = ^void(float *src, int srcSkip, float *dst, int dstSkip, int len) {
        vDSP_vadd(src, srcSkip, dst, dstSkip, dst, dstSkip, len);   // actual processing
    };
    // src is img, dst is self
    [self apply2ImageProc:proc withImage:img];

    return self;
}

- (RecImage *)mulImage:(RecImage *)img
{
    void    (^proc)(float *src, int srcSkip, float *dst, int dstSkip, int len);

    proc = ^void(float *src, int srcSkip, float *dst, int dstSkip, int len) {
        vDSP_vmul(src, srcSkip, dst, dstSkip, dst, dstSkip, len);   // actual processing
    };
    // src is img, dst is self
    [self apply2ImageProc:proc withImage:img];

    return self;
}

- (RecImage *)divImage:(RecImage *)img
{
    void    (^proc)(float *src, int srcSkip, float *dst, int dstSkip, int len);

    proc = ^void(float *src, int srcSkip, float *dst, int dstSkip, int len) {
//        vDSP_vdiv(src, srcSkip, dst, dstSkip, dst, dstSkip, len);   // actual processing
		int j;
		for (j = 0; j < len; j++) {
			if (src[j] != 0) {
				dst[j] /= src[j];
			} else {
				dst[j] = 0;
			}
		}
    };
    // src is img, dst is self
    [self apply2ImageProc:proc withImage:img];
	[self checkNaN];

    return self;
}

- (RecImage *)cpxDivImage:(RecImage *)img	// self /= img (src:img, dst:self)
{
    void    (^proc)(float *srcp, float *srcq, int srcSkip, float *dstp, float *dstq, int dstSkip, int len);
    proc = ^void(float *srcp, float *srcq, int srcSkip, float *dstp, float *dstq, int dstSkip, int len) {
		DSPSplitComplex	A, B;	// A /= B
		int		i, ix;
        float   mg;

		B.realp = srcp;
		B.imagp = srcq;
		A.realp = dstp;
		A.imagp = dstq;
  
        // add zero-check ####
        for (i = 0; i < len; i++) {
            ix = i * srcSkip;
            mg = srcp[ix] * srcp[ix] + srcq[ix] * srcq[ix];
            if (mg == 0) {
                dstp[i*dstSkip] = dstq[i*dstSkip] = 0;
            }
        }

        vDSP_zvdiv(&B, srcSkip, &A, dstSkip, &A, dstSkip, len);   // actual processing
		for (i = 0; i < len; i++) {
			dstp[i*dstSkip] = A.realp[i*srcSkip];
			dstq[i*dstSkip] = A.imagp[i*srcSkip];
		}
    };
    // src is img, dst is self
    [self apply2CpxImageProc:proc withImage:img];
	[self checkNaN];

    return self;
}

- (RecImage *)histogram2dWithX:(RecImage *)xImg andY:(RecImage *)yImg
{
    float	xMax, yMax; // range of histogram. not necessarily range of xy images
	float	xMin, yMin;

    xMax = [xImg maxVal];
	xMin = [xImg minVal];
    yMax = [yImg maxVal];
	yMin = [yImg minVal];

	return [self histogram2dWithX:xImg andY:yImg xMin:xMin xMax:xMax yMin:yMin yMax:yMax];
}

// not correct yet ### 8-15-2017
// -> make single slice again ### 3-11-2020
- (RecImage *)histogram2dWithX:(RecImage *)xImg andY:(RecImage *)yImg
	xMin:(float)xMin xMax:(float)xMax yMin:(float)yMin yMax:(float)yMax	// low level
{
    int             xDim, yDim;	// x/y dim of dst (hist)
	int				srcZDim;		// z-dim of input
	int				dstZDim;		// z-dim of self
	RecLoopControl	*lcX, *lcY, *lcHist;
	float			*xp, *yp;
    float			*hist;
	float			xVal, yVal;
	int				i, j, n, len;		// index of image, pixel
	int				histX, histY;

//    printf("xMax = %f, yMax = %f\n", xMax, yMax);
    xDim = [self xDim];
    yDim = [self yDim];
	dstZDim = [self zDim];
	srcZDim = [xImg zDim];

//	lcHist = [self control];
	lcX = [xImg control];
//	lcX = [RecLoopControl controlWithControl:lcHist forImage:xImg];
	lcY = [RecLoopControl controlWithControl:lcX forImage:yImg];
	lcHist = [RecLoopControl controlWithControl:lcX forImage:self];

//	[lcHist deactivateXY];
	[lcX deactivateXY];
	len = [lcX loopLength];
	n = [xImg xDim] * [xImg yDim];
	[self clear];

	for (i = 0; i < len; i++) {	// lcHist loop
		hist = [self currentDataWithControl:lcHist];
		xp = [xImg currentDataWithControl:lcX];
		yp = [yImg currentDataWithControl:lcY];
//		printf("%lx/%lx/%lx\n", xp, yp, hist);
		for (j = 0; j < n; j++) {
			xVal = xp[j];
			yVal = yp[j];
			histX = (xVal - xMin) * (float)xDim / (xMax - xMin);
 			histY = (yVal - yMin) * (float)yDim / (yMax - yMin);
	//	if (histX != 81) {
	//		printf("%f/%f %d/%d\n", xVal, yVal, histX, histY);
	//	}
			if (histX < 0) {
				histX = 0;
			}
			if (histY < 0) {
				histY = 0;
			}
		    if (histX >= xDim) {
				histX = xDim - 1;
			}
			if (histY >= yDim) {
				histY = yDim - 1;
			}
			hist[(yDim - histY - 1) * xDim + histX] += 1.0;
		}
		[lcX increment];
	}
	[self logWithMin:1.0];

    return self;    // result is self
}

- (float)correlationWith:(RecImage *)img	// normalized correlation, compares real part only
{
	float	sum;
	int		i, n;
	float	*p1, *p2;
	float	m1, m2, s1, s2;

	n = [self dataLength];
	if (n != [img dataLength]) {
		printf("image size not equal\n");
		return 0;
	}
	p1 = [self data];
	p2 = [img data];
	m1 = [self meanVal];
	m2 = [img meanVal];
	s1 = [self varWithMean:m1];
	s2 = [img varWithMean:m2];
	s1 = sqrt(s1);	// SD
	s2 = sqrt(s2);	// SD

	sum = 0;
	for (i = 0; i < n; i++) {
		sum += (p1[i] - m1) * (p2[i] - m2) / s1 / s2;
	}
	return sum / n;
}

- (void)subtractMeanForLoop:(RecLoop *)lp
{
    RecImage        *mnImg;

    mnImg = [self avgForLoop:lp];
    [self subImage:mnImg];
}

- (RecImage *)divImage:(RecImage *)img withLimit:(float)lmt   // real/complex / real, truncate
{
    float   *src = [img data];
    float   mx = [img maxVal];
    int     i, len = [img dataLength] * [img pixSize];

    lmt *= mx;
    for (i = 0; i < len; i++) {
        if (src[i] >= 0 && src[i] < lmt) src[i] = lmt;
        if (src[i] < 0 && src[i] > -lmt) src[i] = -lmt;
    }
    return [self divImage:img];
}

- (RecImage *)divImage:(RecImage *)img withNoiseLevel:(float)lvl   // real/complex / real, baysian
{
    RecImage    *tmp;

    lvl *= [img maxVal];
    lvl *= lvl;
    [self mulImage:img];
    tmp = [img copy];
    [tmp magnitudeSq];
    [tmp addConst:lvl];
    return [self divImage:tmp];
}

// ======= filter ======
- (RecImage *)fir2d:(RecImage *)kernImg   // 2D FIR filter
{
	RecImage		*img = [RecImage imageWithImage:self];
    RecLoopControl  *lc;
    int             i, k, n;
    int             xDim, yDim;
    int             wx, wy;
    float           *p1, *p2;
    float           *kern;

    xDim = [self xDim];
    yDim = [self yDim];

    wx = [kernImg xDim];
    wy = [kernImg yDim];
    kern = [kernImg data];

	lc = [self control];
	[lc deactivateXY];
	n = [lc loopLength];

    for (i = 0; i < n; i++) {
        p1 = [self currentDataWithControl:lc];
        p2 = [img currentDataWithControl:lc];   // same loop structure
        for (k = 0; k < pixSize; k++) {
            vDSP_imgfir(p1, yDim, xDim, kern, p2, wy, wx);
            p1 += dataLength;
            p2 += dataLength;
        }
        [lc increment];
    }

    return img;
}

// moving average (rect)
- (RecImage *)smooth2d:(int)w
{
    RecImage    *kern;
    float       *k, wt;
    int         wid = w * 2 + 1;
    int         i, j, ix;

    kern = [RecImage imageOfType:RECIMAGE_REAL xDim:wid yDim:wid];
    k = [kern data];
    wt = 1.0 / (wid * wid);
    for (i = ix = 0; i < wid; i++) {
        for (j = 0; j < wid; j++) {
            k[ix++] = wt;
        }
    }
    return [self fir2d:kern];
}

- (void)rectWin1DforLoop:(RecLoop *)lp width:(float)wid
{
    void    (^proc)(float *p, int n, int skip);

    proc = ^void(float *p, int n, int skip) {
        int     i, ix;
        float   wt, x;

        for (i = ix = 0; i < n; i++, ix += skip) {
            x = ((float)i - n/2) * 2 / n / wid;
            wt = 1.0 - fabs(x);
            if (wt < 0) {
                wt = 0;
            } else {
                wt = 1.0;
            }
            p[ix] *= wt;
        }
    };
    [self apply1dProc:proc forLoop:lp];
}

- (void)rect1DLP:(float)width forLoop:(RecLoop *)lp
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);
    RecLoop *newLp = lp;

    if (!cpx) {
        [self makeComplex];
    }
    [self fft1d:newLp direction:REC_INVERSE];
    [self fRect1DLP:width forLoop:newLp];
    [self fft1d:newLp direction:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
}

- (void)rect2DLP:(float)width
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);

    if (!cpx) {
        [self makeComplex];
    }
    [self fft2d:REC_INVERSE];
    [self fRect2DLP:width];
    [self fft2d:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
}

- (void)rect3DLP:(float)width
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);
//    int     zDim = [self zDim];
	RecLoop	*zLp = [self zLoop];

    if (!cpx) {
        [self makeComplex];
    }
    [self zeroFillToPo2:[self zLoop]];

    [self fft1d:[self xLoop] direction:REC_INVERSE];
    [self fft1d:[self yLoop] direction:REC_INVERSE];
    [self fft1d:[self zLoop] direction:REC_INVERSE];

    [self fRect3DLP:width];

    [self fft1d:[self xLoop] direction:REC_FORWARD];
    [self fft1d:[self yLoop] direction:REC_FORWARD];
    [self fft1d:[self zLoop] direction:REC_FORWARD];

    if (!cpx) {
        [self takeRealPart];
    }
	[self replaceLoop:[self zLoop] withLoop:zLp];
}

- (void)fRect1DLP:(float)width forLoop:(RecLoop *)lp
{
	[self rectWin1DforLoop:lp width:width];
}

- (void)fRect2DLP:(float)width    // without FT step
{
    [self fRect1DLP:width forLoop:[self xLoop]];
    [self fRect1DLP:width forLoop:[self yLoop]];
}

- (void)fRect3DLP:(float)width    // without FT step
{
    [self fRect1DLP:width forLoop:[self xLoop]];
    [self fRect1DLP:width forLoop:[self yLoop]];
    [self fRect1DLP:width forLoop:[self zLoop]];
}

- (RecImage *)gauss2d:(int)w
{
    RecImage    *kern;
    float       *k, wt, wx, wy, wtot;
    float       x, y;
    int         wid = w * 2 + 1;
    int         i, j, ix;

    kern = [RecImage imageOfType:RECIMAGE_REAL xDim:wid yDim:wid];
    k = [kern data];
    wtot = 0;
    for (i = ix = 0; i < wid; i++) {
        y = (i - w) / 2.0;
        wy = exp(-y*y);
        for (j = 0; j < wid; j++) {
            x = (j - w) / 2.0;
            wx = exp(-x*x);
            wt = wx * wy;
            k[ix++] = wt;
            wtot += wt;
        }
    }
    wtot = 1.0 / wtot;
    for (i = ix = 0; i < wid; i++) {
        for (j = 0; j < wid; j++) {
            k[ix++] *= wtot;
        }
    }
    return [self fir2d:kern];
}

- (void)gauss1DLP:(float)width forLoop:(RecLoop *)lp
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);

    if (!cpx) {
        [self makeComplex];
    }
    [self fft1d:lp direction:REC_INVERSE];
    [self fGauss1DLP:width forLoop:lp];
    [self fft1d:lp direction:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
}

- (void)gauss2DLP:(float)width
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);

    if (!cpx) {
        [self makeComplex];
    }
    [self fft2d:REC_INVERSE];
    [self fGauss2DLP:width];
    [self fft2d:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
}

// "Half" gaussian
- (void)hGauss2DLP:(float)width
{
	int		i, len;
	float	*p, mx, tmp;
	BOOL	found = NO;

	[self gauss2DLP:width];

	len = [self dataLength] * [self pixSize];
	p = [self data];
	mx = [self maxVal];
	for (i = 0; i < len; i++) {
		tmp = p[i] * 2 - mx;
		if (tmp <= 0) {
			tmp = 0;
			found = YES;
		}
		p[i] = tmp;
	}
	if (found) {
		printf("neg value removed ####\n");
	}
}

// xy dim is assumed to be power_of_2
// if zdim is not po2 zerofill / filter / crop
- (void)gauss3DLP:(float)width
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);
//    int     zDim = [self zDim];
	RecLoop	*zLp = [self zLoop];

    if (!cpx) {
        [self makeComplex];
    }
    [self zeroFillToPo2:[self zLoop]];

    [self fft1d:[self xLoop] direction:REC_INVERSE];
    [self fft1d:[self yLoop] direction:REC_INVERSE];
    [self fft1d:[self zLoop] direction:REC_INVERSE];

    [self fGauss3DLP:width];

    [self fft1d:[self xLoop] direction:REC_FORWARD];
    [self fft1d:[self yLoop] direction:REC_FORWARD];
    [self fft1d:[self zLoop] direction:REC_FORWARD];

    if (!cpx) {
        [self takeRealPart];
    }
	[self replaceLoop:[self zLoop] withLoop:zLp];
}

- (void)fGauss1DLP:(float)width forLoop:(RecLoop *)lp
{
	[self fGauss1DLP:width forLoop:lp center:0];
}

- (void)fGauss1DLP:(float)width forLoop:(RecLoop *)lp center:(int)ct
{
    void    (^proc)(float *p, int n, int skip);
    float   *wt, x;
    int     i, len = [lp dataLength];

    wt = (float *)malloc(sizeof(float) * len);
    for (i = 0; i < len; i++) {
        x = ((float)i - ct - len/2) * 2.0/len;
		wt[i] = exp(-x * x / (2 * width * width));
    }

    proc = ^void(float *p, int n, int skip) {
        int     i, ix;
        for (i = ix = 0; i < n; i++, ix += skip) {
            p[ix] *= wt[i];
        }
    };
    [self apply1dProc:proc forLoop:lp];
    free(wt);
}

- (void)fGauss2DLP:(float)width
{
    [self fGauss1DLP:width forLoop:[self xLoop]];
    [self fGauss1DLP:width forLoop:[self yLoop]];
}

- (void)fGauss3DLP:(float)width    // without FT step
{
    [self fGauss1DLP:width forLoop:[self xLoop]];
    [self fGauss1DLP:width forLoop:[self yLoop]];
    [self fGauss1DLP:width forLoop:[self zLoop]];
}

// High-pass filter (new)
- (void)fGauss1DHP:(float)width forLoop:(RecLoop *)lp frac:(float)frac
{
	[self fGauss1DHP:width forLoop:lp center:0 frac:frac];
}

- (void)fGauss1DHP:(float)width forLoop:(RecLoop *)lp center:(int)ct frac:(float)frac
{
    RecImage    *wt = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
    [wt setConst:1.0];
    [wt fGauss1DLP:width forLoop:lp center:ct];
    [wt multByConst:-frac];
    [wt addConst:1.0];
    [self mulImage:wt];
}

- (void)fGauss2DHP:(float)width frac:(float)frac
{
    RecImage    *wt = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
    [wt setConst:1.0];
    [wt fGauss2DLP:width];
    [wt multByConst:-frac];
    [wt addConst:1.0];
    [self mulImage:wt];
}

- (void)fGauss3DHP:(float)width frac:(float)frac
{
    RecImage    *wt = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
    [wt setConst:1.0];
    [wt fGauss3DLP:width];
    [wt multByConst:-frac];
    [wt addConst:1.0];
    [self mulImage:wt];
}

- (void)gauss1DHP:(float)width forLoop:(RecLoop *)lp frac:(float)frac
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);
    RecLoop *newLp;

    if (!cpx) {
        [self makeComplex];
    }
    newLp = [self zeroFillToPo2:lp];
    [self fft1d:newLp direction:REC_INVERSE];
    [self fGauss1DHP:width forLoop:newLp frac:frac];
    [self fft1d:newLp direction:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
	[self replaceLoop:newLp withLoop:lp];	// original lp
}

- (void)gauss2DHP:(float)width frac:(float)frac
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);

    if (!cpx) {
        [self makeComplex];
    }
    [self fft2d:REC_INVERSE];
    [self fGauss2DHP:width frac:frac];
    [self fft2d:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
}

- (void)gauss3DHP:(float)width frac:(float)frac
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);
	RecLoop	*zLp = [self zLoop];

    if (!cpx) {
        [self makeComplex];
    }

    [self zeroFillToPo2:zLp];

    [self fft1d:[self xLoop] direction:REC_INVERSE];
    [self fft1d:[self yLoop] direction:REC_INVERSE];
    [self fft1d:[self zLoop] direction:REC_INVERSE];

    [self fGauss3DHP:width];

    [self fft1d:[self xLoop] direction:REC_FORWARD];
    [self fft1d:[self yLoop] direction:REC_FORWARD];
    [self fft1d:[self zLoop] direction:REC_FORWARD];

    if (!cpx) {
        [self takeRealPart];
    }
	[self replaceLoop:[self zLoop] withLoop:zLp];
}

- (void)fGauss1DHP:(float)width forLoop:(RecLoop *)lp
{
	[self fGauss1DHP:width forLoop:lp frac:1.0];
}

- (void)fGauss2DHP:(float)width
{
	[self fGauss2DHP:width frac:1.0];
}

// ok (fGuss2DHP fixed)
- (void)gauss2DHP:(float)width
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);

    if (!cpx) {
        [self makeComplex];
    }
    [self fft2d:REC_INVERSE];
    [self fGauss2DHP:width];
    [self fft2d:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
}

- (void)fGauss3DHP:(float)width    // without FT step
{
	[self fGauss3DHP:width frac:1.0];
}

// ok
- (void)gauss3DHP:(float)width
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);

    if (!cpx) {
        [self makeComplex];
    }
    [self fft1d:[self xLoop] direction:REC_INVERSE];
    [self fft1d:[self yLoop] direction:REC_INVERSE];
    [self fft1d:[self zLoop] direction:REC_INVERSE];

    [self fGauss3DHP:width];

    [self fft1d:[self xLoop] direction:REC_FORWARD];
    [self fft1d:[self yLoop] direction:REC_FORWARD];
    [self fft1d:[self zLoop] direction:REC_FORWARD];

    if (!cpx) {
        [self takeRealPart];
    }
}

// assymmetric
- (void)fGauss1DcBP:(float)width center:(float)cf forLoop:(RecLoop *)lp
{
    void    (^proc)(float *p, int n, int skip);
    float   *wt, x;
    int     i, len = [lp dataLength];

	cf *= len;
    wt = (float *)malloc(sizeof(float) * len);
    for (i = 0; i < len; i++) {
    //    x = ((float)i - cf - len/2) * 2.0/len;
   //     wt[i] = exp(-x * x / (2 * width * width));
		x = ((float)i + cf - len/2) * 2.0/len;
        wt[i] = exp(-x * x / (2 * width * width));
   }

    proc = ^void(float *p, int n, int skip) {
        int     i, ix;
        for (i = ix = 0; i < n; i++, ix += skip) {
            p[ix] *= wt[i];
        }
    };
    [self apply1dProc:proc forLoop:lp];
    free(wt);
}

// assymmetric
- (void)gauss1DcBP:(float)width center:(float)cf forLoop:(RecLoop *)lp
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);
    RecLoop *newLp;

    if (!cpx) {
        [self makeComplex];
    }
    newLp = [self zeroFillToPo2:lp];
    [self fft1d:newLp direction:REC_INVERSE];
    [self fGauss1DcBP:width center:cf forLoop:newLp];
    [self fft1d:newLp direction:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
	[self replaceLoop:newLp withLoop:lp];	// original lp
}


// symmetric
- (void)fGauss1DBP:(float)width center:(float)cf forLoop:(RecLoop *)lp
{
    void    (^proc)(float *p, int n, int skip);
    float   *wt, x;
    int     i, len = [lp dataLength];

	cf *= len;
    wt = (float *)malloc(sizeof(float) * len);
    for (i = 0; i < len; i++) {
        x = ((float)i - cf - len/2) * 2.0/len;
        wt[i] = exp(-x * x / (2 * width * width));
        x = ((float)i + cf - len/2) * 2.0/len;
       wt[i] += exp(-x * x / (2 * width * width));
   }

    proc = ^void(float *p, int n, int skip) {
        int     i, ix;
        for (i = ix = 0; i < n; i++, ix += skip) {
            p[ix] *= wt[i];
        }
    };
    [self apply1dProc:proc forLoop:lp];
    free(wt);
}

// cos2 window for GRAPPA type processing
- (void)fCos1DLPc:(int)w forLoop:(RecLoop *)lp	// width is # of pixels (central)
{
    void    (^proc)(float *p, int n, int skip);
    float   *wt, x;
    int     i, len = [lp dataLength];

    wt = (float *)malloc(sizeof(float) * len);
    for (i = 0; i < len; i++) {
        x = (float)i - len/2;
		if (x < -w || x > w) {
			wt[i] = 0;
		} else {
			wt[i] = 0.5 * cos((float)x / w * M_PI) + 0.5;
		}
   }

    proc = ^void(float *p, int n, int skip) {
        int     i, ix;
        for (i = ix = 0; i < n; i++, ix += skip) {
            p[ix] *= wt[i];
        }
    };
    [self apply1dProc:proc forLoop:lp];
    free(wt);
}

- (void)fCos1DLPp:(int)w forLoop:(RecLoop *)lp	// width is # of pixels (peripheral)
{
    void    (^proc)(float *p, int n, int skip);
    float   *wt, x;
    int     i, len = [lp dataLength];

    wt = (float *)malloc(sizeof(float) * len);
    for (i = 0; i < len; i++) {
        if (i < len/2) {
            x = (float)i;
        } else {
            x = (float)len - i;
        }
		if (x > w) {
			wt[i] = 1.0;
		} else {
			wt[i] = 0.5 - 0.5 * cos((float)x / w * M_PI);
		}
//printf("%d %f\n", i, wt[i]);
   }

    proc = ^void(float *p, int n, int skip) {
        int     i, ix;
        for (i = ix = 0; i < n; i++, ix += skip) {
            p[ix] *= wt[i];
        }
    };
    [self apply1dProc:proc forLoop:lp];
    free(wt);
}

- (void)cos2DLPc:(int)w	// width is # of pixels (central)
{
    [self fft2d:REC_INVERSE];
    [self fCos1DLPc:w forLoop:[self xLoop]];
    [self fCos1DLPc:w forLoop:[self yLoop]];
    [self fft2d:REC_FORWARD];
}

- (void)cos2DLPp:(int)w	// width is # of pixels (peripheral)
{
    [self fft2d:REC_INVERSE];
    [self fCos1DLPp:w forLoop:[self xLoop]];
    [self fCos1DLPp:w forLoop:[self yLoop]];
    [self fft2d:REC_FORWARD];
}

- (void)cos3DLPc:(int)w	// width is # of pixels (central)
{
    [self fft3d:REC_INVERSE];
    [self fCos1DLPc:w forLoop:[self xLoop]];
    [self fCos1DLPc:w forLoop:[self yLoop]];
    [self fCos1DLPc:w forLoop:[self zLoop]];
    [self fft3d:REC_FORWARD];
}

- (void)cos3DLPp:(int)w	// width is # of pixels (peripheral)
{
    [self fft3d:REC_INVERSE];
    [self fCos1DLPc:w forLoop:[self xLoop]];
    [self fCos1DLPc:w forLoop:[self yLoop]];
    [self fCos1DLPc:w forLoop:[self zLoop]];
    [self fft3d:REC_FORWARD];
}

// symmetric
- (void)gauss1DBP:(float)width center:(float)cf forLoop:(RecLoop *)lp
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);
    RecLoop *newLp;

// ### not done yet
    if (!cpx) {
        [self makeComplex];
    }
    newLp = [self zeroFillToPo2:lp];
    [self fft1d:newLp direction:REC_INVERSE];
    [self fGauss1DBP:width center:cf forLoop:newLp];
    [self fft1d:newLp direction:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
	[self replaceLoop:newLp withLoop:lp];	// original lp
}

- (void)fGauss1DN:(float)width center:(float)cf forLoop:(RecLoop *)lp
{
    void    (^proc)(float *p, int n, int skip);
    float   *wt, x;
    int     i, len = [lp dataLength];

	cf *= len;
    wt = (float *)malloc(sizeof(float) * len);
    for (i = 0; i < len; i++) {
        x = ((float)i - cf - len/2) * 2.0/len;
        wt[i] = exp(-x * x / (2 * width * width));
		x = ((float)i + cf - len/2) * 2.0/len;
        wt[i] += exp(-x * x / (2 * width * width));
		wt[i] = 1.0 - wt[i];
   }

    proc = ^void(float *p, int n, int skip) {
        int     i, ix;
        for (i = ix = 0; i < n; i++, ix += skip) {
            p[ix] *= wt[i];
        }
    };
    [self apply1dProc:proc forLoop:lp];
    free(wt);
}

- (void)gauss1DN:(float)width center:(float)cf forLoop:(RecLoop *)lp
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);
    RecLoop *newLp;

    if (!cpx) {
        [self makeComplex];
    }
    newLp = [self zeroFillToPo2:lp];
    [self fft1d:newLp direction:REC_INVERSE];
    [self fGauss1DN:width center:cf forLoop:newLp];
    [self fft1d:newLp direction:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
	[self replaceLoop:newLp withLoop:lp];	// original lp
}

- (void)f1DPF:(int)cf forLoop:(RecLoop *)lp	// point filter
{
    void    (^proc)(float *p, int n, int skip);

    proc = ^void(float *p, int n, int skip) {
		p[cf * skip] = 0;
		p[(n - cf + 1) * skip] = 0;
    };
    [self apply1dProc:proc forLoop:lp];
}

- (void)t1DPF:(int)cf forLoop:(RecLoop *)lp	// point filter
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);
    RecLoop *newLp;

    if (!cpx) {
        [self makeComplex];
    }
//    newLp = [self zeroFillToPo2:lp];
    [self fft1d:lp direction:REC_INVERSE];
    [self f1DPF:cf forLoop:lp];
    [self fft1d:lp direction:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
//	[self replaceLoop:newLp withLoop:lp];	// original lp
}

// FIR (freq domain)
- (void)f1DFIR:(RecImage *)kern forLoop:(RecLoop *)lp
{
    void    (^proc)(float *p, float *q, int skip, int len);

    proc = ^void(float *p, float *q, int skip, int len) {
		int		i;
		float	re, im;
		float	*pp, *qq;
		pp = [kern real];
		qq = [kern imag];
		for (i = 0; i < len; i++) {
			re = p[i * skip];
			im = q[i * skip];
			p[i * skip] =  re * pp[i] + im * qq[i];
			q[i * skip] = -re * qq[i] + im * pp[i];
		}
    };
    [self applyComplex1dProc:proc forLoop:lp];
}

- (void)t1DFIR:(RecImage *)kern forLoop:(RecLoop *)lp
{
    BOOL		cpx = (type == RECIMAGE_COMPLEX);
    RecLoop		*newLp;
	RecImage	*fKern;

    if (!cpx) {
        [self makeComplex];
    }
    newLp = [self zeroFillToPo2:lp];
	fKern = [kern copy];
	[fKern replaceLoop:[fKern xLoop] withLoop:newLp];
	[fKern fft1d:newLp direction:REC_INVERSE];
    [self fft1d:newLp direction:REC_INVERSE];
    [self f1DFIR:fKern forLoop:newLp];
    [self fft1d:newLp direction:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
	[self replaceLoop:newLp withLoop:lp];	// original lp
}

- (void)fTriWin1DforLoop:(RecLoop *)lp
{
	[self fTriWin1DforLoop:lp center:0.0 width:1.0];
}

- (void)fTriWin1DforLoop:(RecLoop *)lp center:(float)ct width:(float)wid
{
    void    (^proc)(float *p, int n, int skip);

    proc = ^void(float *p, int n, int skip) {
        int     i, ix;
        float   wt, x;

        for (i = ix = 0; i < n; i++, ix += skip) {
            x = ((float)i - n/2 - ct*n) * 2 / n / wid;
            wt = 1.0 - fabs(x);
            if (wt < 0) wt = 0;
            p[ix] *= wt;
        }
    };
    [self apply1dProc:proc forLoop:lp];
}

- (void)fTriWin2D
{
    [self fTriWin1DforLoop:[self xLoop] center:0.0 width:1.0];
    [self fTriWin1DforLoop:[self yLoop] center:0.0 width:1.0];
}

- (void)fTriWin3D
{
    [self fTriWin1DforLoop:[self xLoop] center:0.0 width:1.0];
    [self fTriWin1DforLoop:[self yLoop] center:0.0 width:1.0];
    [self fTriWin1DforLoop:[self zLoop] center:0.0 width:1.0];
}

- (void)triWin2D	// FT included
{
	[self fft2d:REC_INVERSE];
	[self fTriWin2D];
	[self fft2d:REC_FORWARD];
}

// Lanczos window
- (void)fLanczWin1DforLoop:(RecLoop *)lp center:(float)ct width:(float)w
{
    void    (^proc)(float *p, int n, int skip);
	float	*wt, th;
	int		i, n;

	n = [lp dataLength];
	wt = (float *)malloc(sizeof(float) * n);
	for (i = 0; i < n; i++) {
		th = ((float)i - (n - 1.0) / 2.0 - ct * n) * 2 * M_PI / (n - 1) / w;
		if (th < -M_PI || th > M_PI) {
			wt[i] = 0;
		} else {
			wt[i] = sin(th) / th;	// th != 0
		}
	}

    proc = ^void(float *p, int n, int skip) {
        int     i, ix;

        for (i = ix = 0; i < n; i++, ix += skip) {
            p[ix] *= wt[i];
        }
    };
    [self apply1dProc:proc forLoop:lp];
	free(wt);
}

- (void)fLanczWin2D
{
    [self fLanczWin1DforLoop:[self xLoop] center:0.0 width:1.0];
    [self fLanczWin1DforLoop:[self yLoop] center:0.0 width:1.0];
}

- (void)fLanczWin3D
{
    [self fLanczWin1DforLoop:[self xLoop] center:0.0 width:1.0];
    [self fLanczWin1DforLoop:[self yLoop] center:0.0 width:1.0];
    [self fLanczWin1DforLoop:[self zLoop] center:0.0 width:1.0];
}

- (void)lanczWin2D
{
	[self fft2d:REC_INVERSE];
	[self fLanczWin2D];
	[self fft2d:REC_FORWARD];
}

// full-cosine window
- (void)fullCosWin1DforLoop:(RecLoop *)lp
{
	void    (^proc)(float *p, int n, int skip);
	float	*wt, th;
	int		i, len;

	len = [self yDim];
	wt = (float *)malloc(sizeof(float) * len);
	for (i = 0; i < len; i++) {
		th = ((float)i - len/2) * 2 * M_PI / len;
		wt[i] = cos(th);
	//	printf("%d %f\n", i, cos(th));
	}
	proc = ^void(float *p, int n, int skip) {
		int j;
		for (j = 0; j < n; j++) {
			p[j * skip] *= wt[j];
		}
	};
	[self apply1dProc:proc forLoop:[self yLoop]];
	free(wt);
}

- (void)sinFilt:(int)mode ang:(float)ang
{
    void	(^proc)(float *p, float *q, int xDim, int yDim);

    proc = ^void(float *p, float *q, int xDim, int yDim) {
        // sin filt
		int		i, j, ix;
		float	x, y, th, w;

        for (i = ix = 0; i < yDim; i++) {
            y = (float)i - yDim/2;
            for (j = 0; j < xDim; j++, ix++) {
                x = (float)j - xDim/2;
				switch (mode) {
				default :
				case 0 :	// dipole
					th = atan2(y, x) - ang;  // was + ang
					break;
				case 1 :	// quadrupole
					th = atan2(y, x) * 2 - ang;  // was + ang
					break;
				}
				w = sin(th);
                p[ix] *= w;
                q[ix] *= w;
            }
        }
    };

    [self applyComplex2dProc:proc]; // main proc
}

- (void)fLaplace1dForLoop:(RecLoop *)lp direction:(int)dir
{
	float		x, a;
	int			i, len;
	RecImage	*win = [RecImage imageOfType:RECIMAGE_REAL withLoops:lp, nil];
	float		*w = [win data];
    void		(^cproc)(float *p, float *q, int skip, int len);
    void		(^rproc)(float *p, int skip, int len);
    cproc = ^void(float *p, float *q, int skip, int len) {
		int		i, ix;
		for (i = 0; i < len; i++) {
			ix = i * skip;
			p[ix] *= w[i];
			q[ix] *= w[i];
		}
    };
    rproc = ^void(float *p, int skip, int len) {
		int		i, ix;
		for (i = 0; i < len; i++) {
			ix = i * skip;
			p[ix] *= w[i];
		}
    };

	len = [lp dataLength];
	a = -2.0 * M_PI / len;
	if (dir == REC_FORWARD) {
		for (i = 0; i < len; i++) {
			x = (float)i - len/2;
			w[i] = a * x*x;
		}
	} else {
		for (i = 0; i < len; i++) {
			x = (float)i - len/2;
			if (i == len/2) {
				w[i] = 0;
			} else {
				w[i] = 1.0 / (a * x*x);
			}
		}
	}
	if (type == RECIMAGE_COMPLEX) {
		[self applyComplex1dProc:cproc forLoop:lp control:[self control]];
	} else {
		[self apply1dProc:rproc forLoop:lp];
	}
}

- (void)fLaplace2d:(int)dir
{
	int			i, j;
	float		a, x, y;
	int			nx = [self xDim];
	int			ny = [self yDim];
	RecImage	*win = [RecImage imageOfType:RECIMAGE_REAL withLoops:[self xLoop], [self yLoop], nil];;
	float		*w = [win data];

    void    (^cproc)(float *p, float *q, int xDim, int yDim);
    void    (^rproc)(float *p, int xDim, int yDim);
    cproc = ^void(float *p, float *q, int xDim, int yDim) {
		int		i, len = xDim * yDim;
		for (i = 0; i < len; i++) {
			p[i] *= w[i];
			q[i] *= w[i];
		}
    };
    rproc = ^void(float *p, int xDim, int yDim) {
		int		i, len = xDim * yDim;
		for (i = 0; i < len; i++) {
			p[i] *= w[i];
		}
    };
	// make weight
	nx = [self xDim];
	ny = [self yDim];
	a = -4.0 * M_PI * M_PI / (nx * ny);
	if (dir == REC_FORWARD) {
		for (i = 0; i < ny; i++) {
			y = (float)i - ny/2;
			for (j = 0; j < nx; j++) {
				x = (float)j - nx/2;
				w[i * nx + j] = a * (x*x + y*y);
			}
		}
	} else {
		for (i = 0; i < ny; i++) {
			y = (float)i - ny/2;
			for (j = 0; j < nx; j++) {
				x = (float)j - nx/2;
				if (i == ny/2 && j == nx/2) {
					w[i * nx + j] = 0;
				} else {
					w[i * nx + j] = 1.0 / (a * (x*x + y*y));
				}
			}
		}
	}
	if (type == RECIMAGE_COMPLEX) {
		[self applyComplex2dProc:cproc];
	} else {
		[self apply2dProc:rproc];
	}
}

// DCT version (real)
- (void)fLaplace2dc:(int)dir
{
	int			i, j;
	float		a, x, y, r;
	int			nx = [self xDim];
	int			ny = [self yDim];
	RecImage	*win = [RecImage imageOfType:RECIMAGE_REAL withLoops:[self xLoop], [self yLoop], nil];;
	float		*w = [win data];

    void    (^rproc)(float *p, int xDim, int yDim);
    rproc = ^void(float *p, int xDim, int yDim) {
		int		i, len = xDim * yDim;
		for (i = 0; i < len; i++) {
			p[i] *= w[i];
		}
    };
	// make weight
	nx = [self xDim];
	ny = [self yDim];
//	a = -4.0 * M_PI * M_PI / (nx * ny);
	a = 1.0;		// fix later
	if (dir == REC_FORWARD) {
		for (i = 0; i < ny; i++) {
			y = (float)i;
			for (j = 0; j < nx; j++) {
				x = (float)j;
				r = sqrt(x*x + y*y)/sqrt(nx*nx + ny*ny);
				w[i * nx + j] = a * (2 * cos(M_PI * r) - 2);
			}
		}
	} else {
		for (i = 0; i < ny; i++) {
			y = (float)i;
			for (j = 0; j < nx; j++) {
				x = (float)j;
				if (i == 0 && j == 0) {
					w[i * nx + j] = 0;
				} else {
					r = sqrt(x*x + y*y)/sqrt(nx*nx + ny*ny);
					w[i * nx + j] = 1.0 / (a * (2 * cos(M_PI * r) - 2));
				}
			}
		}
	}
	[self apply2dProc:rproc];
}

- (void)fLaplace3d:(int)dir
{
	int			i, j, k;
	float		a, x, y, z;
	int			nx = [self xDim];
	int			ny = [self yDim];
	int			nz = [self zDim];
	RecImage	*win = [RecImage imageOfType:RECIMAGE_REAL xDim:nx yDim:ny zDim:nz];;
	float		*w = [win data];

    void    (^cproc)(float *p, float *q, int xDim, int yDim, int zDim);
    void    (^rproc)(float *p, int xDim, int yDim, int zDim);
    cproc = ^void(float *p, float *q, int xDim, int yDim, int zDim) {
		int		i, len = xDim * yDim * zDim;
		for (i = 0; i < len; i++) {
			p[i] *= w[i];
			q[i] *= w[i];
		}
    };
    rproc = ^void(float *p, int xDim, int yDim, int zDim) {
		int		i, len = xDim * yDim * zDim;
		for (i = 0; i < len; i++) {
			p[i] *= w[i];
		}
    };

	a = -8.0 * M_PI * M_PI * M_PI / (nx * ny * nz);
	if (dir == REC_FORWARD) {
		for (i = 0; i < ny; i++) {
			y = (float)i - ny/2;
			for (j = 0; j < nx; j++) {
				x = (float)j - nx/2;
				for (k = 0; k < nz; k++) {
					z = (float)k - nz/2;
					w[((k * ny) + i) * nx + j] = a * (x*x + y*y + z*z);
				}
			}
		}
	} else {
		for (i = 0; i < ny; i++) {
			y = (float)i - ny/2;
			for (j = 0; j < nx; j++) {
				x = (float)j - nx/2;
				for (k = 0; k < nz; k++) {
					z = (float)k - nz/2;
					if (i == ny/2 && j == nx/2 && k == nz/2) {
						w[((k * ny) + i) * nz + j] = 0;
					} else {
						w[((k * ny) + i) * nx + j] = 1.0 / (a * (x*x + y*y + z*z));
					}
				}
			}
		}
	}
	if (type == RECIMAGE_COMPLEX) {
		[self applyComplex3dProc:cproc];
	} else {
		[self apply3dProc:rproc];
	}
}

- (void)laplace1dForLoop:(RecLoop *)lp direction:(int)dir
{
    if (type != RECIMAGE_COMPLEX) {
        [self makeComplex];
    }
    [self fft1d:lp direction:REC_INVERSE];
    [self fLaplace1dForLoop:lp direction:dir];
    [self fft1d:lp direction:REC_FORWARD];
    if (type != RECIMAGE_COMPLEX) {
        [self takeRealPart];
    }
}

// zerofill should be done in outer loop
// (for better boundary condition)
- (void)laplace2d:(int)direction
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);
//	RecLoop	*xLp, *yLp;

    if (!cpx) {
        [self makeComplex];
    }
//	xLp = [self xLoop];
//	yLp = [self yLoop];
//	[self zeroFillToPo2];
    [self fft2d:REC_INVERSE];
    [self fLaplace2d:direction];
    [self fft2d:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
//	[self replaceLoop:[self xLoop] withLoop:xLp];
//	[self replaceLoop:[self yLoop] withLoop:yLp];
}

// real only
- (void)laplace2dc:(int)direction
{
    [self dct2d];
    [self fLaplace2dc:direction];
    [self dct2d];
}

- (void)laplace3d:(int)direction
{
    BOOL    cpx = (type == RECIMAGE_COMPLEX);

    if (!cpx) {
        [self makeComplex];
    }
    [self fft3d:REC_INVERSE];
    [self fLaplace3d:direction];
    [self fft3d:REC_FORWARD];
    if (!cpx) {
        [self takeRealPart];
    }
}

// gradient magnitude
- (void)fGrad1dForLoop:(RecLoop *)lp;
{
	float		x, a;
	int			i, len;
	RecImage	*win = [RecImage imageOfType:RECIMAGE_REAL withLoops:lp, nil];
	float		*w = [win data];
    void		(^cproc)(float *p, float *q, int skip, int len);
    cproc = ^void(float *p, float *q, int skip, int len) {
		int		i, ix;
		for (i = 0; i < len; i++) {
			ix = i * skip;
			p[ix] *= w[i];
			q[ix] *= w[i];
		}
    };

	len = [lp dataLength];
	a = M_PI / len;
	for (i = 0; i < len; i++) {
		x = (float)i - len/2;
		w[i] = a * x;
	}
	[self applyComplex1dProc:cproc forLoop:lp control:[self control]];
}

// gradient
- (void)grad1dForLoop:(RecLoop *)lp
{
	[self fft1d:lp direction:REC_INVERSE];
	[self fGrad1dForLoop:lp];
	[self fft1d:lp direction:REC_FORWARD];
	[self takeImagPart];
}

- (void)grad1dForLoop:(RecLoop *)lp width:(float)w	// with LPF
{
	[self fft1d:lp direction:REC_INVERSE];
	[self fGrad1dForLoop:lp];
	[self fGauss1DLP:w forLoop:lp];
	[self fft1d:lp direction:REC_FORWARD];
	[self takeImagPart];
}

- (void)grad2d
{
	[self fft2d:REC_INVERSE];
	[self fGrad1dForLoop:[self xLoop]];
	[self fGrad1dForLoop:[self yLoop]];
	[self fft2d:REC_FORWARD];
	[self takeImagPart];
}

- (void)grad3d
{
	[self fft3d:REC_INVERSE];
	[self fGrad1dForLoop:[self xLoop]];
	[self fGrad1dForLoop:[self yLoop]];
	[self fGrad1dForLoop:[self zLoop]];
	[self fft3d:REC_FORWARD];
	[self takeImagPart];
}

- (void)gradMag2d
{
	RecImage	*gx, *gy;
	int			i, n;
	float		*p, *q, *pp;

	gx = [self copy];
	[gx fft2d:REC_INVERSE];
	[gx fGrad1dForLoop:[gx xLoop]];
	[gx fft2d:REC_FORWARD];
	gy = [self copy];
	[gy fft2d:REC_INVERSE];
	[gy fGrad1dForLoop:[gx yLoop]];
	[gy fft2d:REC_FORWARD];
	p = [gx data];
	q = [gy data];
	pp = [self data];
	n = [self dataLength];
	for (i = 0; i < n; i++) {
		pp[i] = sqrt(p[i]*p[i] + q[i]*q[i]);
	}
}

- (void)gradMag3d
{
	RecImage	*gx, *gy, *gz;
	int			i, n;
	float		*p1, *p2, *p3, *pp;

	gx = [self copy];
	[gx fft2d:REC_INVERSE];
	[gx fGrad1dForLoop:[gx xLoop]];
	[gx fft2d:REC_FORWARD];
	gy = [self copy];
	[gy fft2d:REC_INVERSE];
	[gy fGrad1dForLoop:[gx yLoop]];
	[gy fft2d:REC_FORWARD];
	gz = [self copy];
	[gz fft2d:REC_INVERSE];
	[gz fGrad1dForLoop:[gz zLoop]];
	[gz fft2d:REC_FORWARD];
	p1 = [gx data];
	p2 = [gy data];
	p3 = [gz data];
	pp = [self data];
	n = [self dataLength];
	for (i = 0; i < n; i++) {
		pp[i] = sqrt(p1[i]*p1[i] + p2[i]*p2[i] + p3[i]*p3[i]);
	}
}

// phase gradient (for unwrapping)
// shift not correct yet ### -> make consistent with Chambolle 2004
- (RecImage *)pGrad1dForLoop:(RecLoop *)lp
{
	RecImage	*gr;
	int			i, n;
	float		*p;
//	float		cs, sn;

	gr = [self copy];
	[gr shift1d:lp by:1];
	[gr subImage:self];

	p = [gr data];
	n = [gr dataLength];
	for (i = 0; i < n; i++) {
		float	thres = M_PI;
		if (p[i] > thres) p[i] -= M_PI * 2;
		if (p[i] < -thres) p[i] += M_PI * 2;
	// probably equvalent with above
	//	cs = cos(p[i]);
	//	sn = sin(p[i]);
	//	if (cs == -1) {
	//		p[i] = M_PI;
	//	} else {
	//		p[i] = 2 * atan(sn / (1 + cs));
	//	}
	}

	return gr;
}

- (void)fGrad1dInvForLoop:(RecLoop *)lp;
{
	float		x, a;
	int			i, len;
	RecImage	*win = [RecImage imageOfType:RECIMAGE_REAL withLoops:lp, nil];
	float		*wr = [win real];
//	float		*wi = [win imag];
    void		(^cproc)(float *p, float *q, int skip, int len);
    cproc = ^void(float *p, float *q, int skip, int len) {
		int		i, ix;
		for (i = 0; i < len; i++) {
			ix = i * skip;
			p[ix] *= wr[i];
			q[ix] *= wr[i];
		}
    };

	len = [lp dataLength];
	for (i = 0; i < len; i++) {
		x = (float)i - len/2;
		x = M_PI * x * 2 / len;
		a = 1.0 - cos(x);
		if (a == 0) {
			wr[i] = 0;
		} else {
			wr[i] = 1.0 / a;
		}
	}
	[self applyComplex1dProc:cproc forLoop:lp control:[self control]];
}


- (RecImage *)pGrad2d
{
	RecImage	*gx, *gy;

	gx = [self pGrad1dForLoop:[self xLoop]];
	gy = [self pGrad1dForLoop:[self yLoop]];
	[gx makeComplexWithIm:gy];

	return gx;
}

- (RecImage *)pGrad3d
{
	RecImage	*gx, *gy, *gz;

	return gx;
}

// real, space domain
// shift not correct yet ###
- (RecImage *)pGrad1dInvForLoop:(RecLoop *)lp
{
	RecImage	*gr;
    void		(^proc)(float *p, int len, int skip);

	gr = [self copy];
    proc = ^void(float *p, int len, int skip) {
        int     j, ix;
		float	sum;
		ix = 0;
		sum = 0;
		for (j = 0; j < len-1; j++) {
			sum += p[ix];
			p[ix] = sum;
			ix += skip;
		}
    };
    [gr apply1dProc:proc forLoop:lp];

	return gr;
}

// fourier based
- (RecImage *)pGrad1dInvForLoop_f:(RecLoop *)lp
{
	RecImage	*gr;

	gr = [self copy];
	[gr fft2d:REC_INVERSE];
	[gr fGrad1dInvForLoop:[gr xLoop]];
	[gr fft2d:REC_FORWARD];

	return gr;
}

// not correct yet###
// input (self) is complex
- (RecImage *)div2d
{
	RecImage	*gx, *gy, *div;

	gx = [self copy];
	[gx takeRealPart];
	gy = [self copy];
	[gy takeImagPart];

	gx = [gx pGrad1dForLoop:[gx xLoop]];
	[gx shift1d:[gx xLoop] by:-1];

	gy = [gy pGrad1dForLoop:[gy yLoop]];
	[gy shift1d:[gy yLoop] by:-1];

	div = [gx copy];
	[div addImage:gy];

	return div;
}

void
rmBase(float *p, int n, int skip, float a)
{
	int		i, ix;
	for (i = ix = 0; i < n; i++, ix+=skip) {
		p[ix] -= a;
	}
}

// ### single slice
- (RecImage *)pGrad2dInv	// fourier based invert grad 2d
{
	RecImage	*img;
	RecImage	*gx, *gy;
//	RecImage	*mask;
	float		*px, *py, *spx, *spy;
	float		a;
	int			i, k, nx, ny, nz;
//	int			x0, y0;

//	mask = [self copy];
//	[mask magnitude];
//	[mask thresAt:0.3];
//	[mask addConst:-1.0];
//	[mask negate];
//	[mask saveAsKOImage:@"IMG_mask.img"];
//	[self maskWithImage:mask invert:YES smooth:NO];
//	[self saveAsKOImage:@"IMG_grad_mask.img"];

	gx = [self copy];
	[gx takeRealPart];
	gx = [gx pGrad1dInvForLoop:[gx xLoop]];
	gy = [self copy];
	[gy takeImagPart];
	gy = [gy pGrad1dInvForLoop:[gy yLoop]];

	nx = [self xDim];
	ny = [self yDim];
	nz = [self zDim];

	for (k = 0; k < nz; k++) {
		spx = [gx data] + k * nx * ny;
		spy = [gy data] + k * nx * ny;
		// gx0
		px = spx + ny/2 * nx;
		a = px[nx/2];
		rmBase(px, nx, 1, a);
		py = spy + nx/2;
		a = py[ny/2 * nx];
		rmBase(py, ny, nx, a);

		// gx
		py = spy + nx/2;
		for (i = 0; i < ny; i++) {
			px = spx + i * nx;
			a = px[nx/2] - py[i * nx];
			rmBase(px, nx, 1, a);
		}
		// gy
		px = spx + ny/2 * nx;
		for (i = 0; i < nx; i++) {
			py = spy + i;
			a = py[ny/2 * nx] - px[i];
			rmBase(py, nx, nx, a);
		}
	}
	[gx saveAsKOImage:@"IMG_gx_base.img"];
	[gy saveAsKOImage:@"IMG_gy_base.img"];
	[gx subImage:gy];
	
	px = [gx data];
	for (i = 0; i < nx * ny * nz; i++) {
		px[i] = round(px[i] / (M_PI * 2));
	}
	[gx saveAsKOImage:@"IMG_gx_dif.img"];

exit(0);


	return img;
}

- (void)makeZeroMeanWithMask:(RecImage *)mask
{
	int	i,	n = [self dataLength];
	float	*p = [self data];
	float	*pm = [mask data];
	float	m;

	m = 0;
	for (i = 0; i < n; i++) {
		if (pm[i] > 0) {
			m += p[i];
		}
	}
	m /= n;

	for (i = 0; i < n; i++) {
		p[i] -= m;
	}
}

- (void)maxImage:(RecImage *)img
{
	float	*dst = [self data];
	float	*src = [img data];
	int		size = dataLength * [self pixSize];

	vDSP_vmax(src, 1, dst, 1, dst, 1, size);
}

- (void)minImage:(RecImage *)img
{
	float	*dst = [self data];
	float	*src = [img data];
	int		size = dataLength * [self pixSize];

	vDSP_vmin(src, 1, dst, 1, dst, 1, size);
}

- (void)vectorLen:(RecImage *)img	// z = sqrt(x^2 + y^2)
{
	float	*dst = [self data];
	float	*src = [img data];
	float	mg;
	int		i, size = dataLength * [self pixSize];

	for (i = 0; i < size; i++) {
		mg = src[i]*src[i] + dst[i] + dst[i];
		mg = sqrt(mg);
		dst[i] = mg;
	}
}

// clear all
- (void)clear
{
	float	*p = [self data];
	int		size = dataLength * [self pixSize];

	vDSP_vclr(p, 1, size);
}

- (void)setConst:(float)val
{
	float	*p = [self data];
	int		size = dataLength * [self pixSize];

	vDSP_vfill(&val,p, 1, size);
}

- (RecImage *)multByConst:(float)val
{
	float	*p = [self data];
	int		size = dataLength * [self pixSize];

	vDSP_vsmul(p, 1, &val, p, 1, size);
    return self;
}

- (RecImage *)addConst:(float)val
{
	float	*p = [self data];
	int		size = dataLength * [self pixSize];

	vDSP_vsadd(p, 1, &val, p, 1, size);
    return self;
}

- (RecImage *)addReal:(float)val
{
	float	*p = [self real];
	int		size = dataLength;

	vDSP_vsadd(p, 1, &val, p, 1, size);
    return self;
}

- (RecImage *)addImag:(float)val
{
	float	*p = [self imag];
	int		size = dataLength;

	vDSP_vsadd(p, 1, &val, p, 1, size);
    return self;
}

// img is real, single-slice 2D image -> ### removed
/*
- (void)scaleByImage:(RecImage *)img
{
	float	*w = [img data];

    void    (^cproc)(float *p, float *q, int xDim, int yDim);
    void    (^rproc)(float *p, int xDim, int yDim);
    cproc = ^void(float *p, float *q, int xDim, int yDim) {
		int		i, len = xDim * yDim;
		for (i = 0; i < len; i++) {
			p[i] *= w[i];
			q[i] *= w[i];
		}
    };
    rproc = ^void(float *p, int xDim, int yDim) {
		int		i, len = xDim * yDim;
		for (i = 0; i < len; i++) {
			p[i] *= w[i];
		}
    };
	if (type == RECIMAGE_COMPLEX) {
		[self applyComplex2dProc:cproc];
	} else {
		[self apply2dProc:rproc];
	}
}
*/

// ---> real image, less than or equal dim of self ###
// (not finishted yet ###)
/*
- (void)scaleByImage_sav:(RecImage *)img
{
	RecLoopControl	*dstLc;		// control
    RecLoopControl  *srcLc;
	int				i, j, k;
	int				loopLen;
	float			*src, *dst;
	int				len;

	dstLc = [self control];
    srcLc = [RecLoopControl controlWithControl:dstLc forImage:img];
    [dstLc deactivateInner];
	len = [self xDim];
    loopLen = [dstLc loopLength];
	
// rewind to range.position
	[dstLc rewind];
	src = [img data];
	for (i = 0; i < loopLen; i++) {
		dst = [self currentDataWithControl:dstLc];
        src = [img currentDataWithControl:srcLc];
		for (k = 0; k < pixSize; k++) {
			for (j = 0; j < len; j++) {
				dst[j] *= src[j];
			}
			dst += dataLength;
		}
		[dstLc increment];
	}
}
*/

// self:real or complex, img:real
- (void)multByCImage:(RecImage *)img
{
	RecLoopControl	*lc;		// dst (self) control
    RecLoopControl  *srcLc;     // src (img) control
	int				i, j;
	int				loopLength;
	float			*p1, *q1, pp, qq;	// src
	float			*p2, *q2, re, im;	// dst
	int				len;
	int				srcDataLength = [img dataLength];
	int				srcType = [img type];

	if (srcType != RECIMAGE_COMPLEX) {
		printf("Mult by complex only\n");
		exit(0);
	}
	if (type != RECIMAGE_COMPLEX) {
		[self makeComplex];
	}
	lc = [self control];	// dst
	srcLc = [img controlWithControl:lc];
	len = [self xDim];
	[lc deactivateInner];
	
// rewind to range.position
	[lc rewind];
	loopLength = [lc loopLength];
	for (i = 0; i < loopLength; i++) {
		p1 = [img currentDataWithControl:srcLc];		// 1: src (img), 2: dst (self)
		p2 = [self currentDataWithControl:lc];
		q1 = p1 + srcDataLength;
		q2 = p2 + dataLength;
		// complex only
		for (j = 0; j < len; j++) {
			re = p2[j];
			im = q2[j];
			pp = p1[j];
			qq = q1[j];

			p2[j] = re * pp - im * qq;
			q2[j] = re * qq + im * pp;
		}
		[lc increment];
	}
	[self checkNeg0];
}

// self:real or complex, img:complex
- (void)multByImage:(RecImage *)img
{
	RecLoopControl	*lc;		// dst (self) control
    RecLoopControl  *srcLc;     // src (img) control
	int				i, j;
	int				loopLength;
	float			*p1;	// src
	float			*p2, *q2;	// dst
	int				len;

	if ([img type] == RECIMAGE_COMPLEX) {
		[self multByCImage:img];
		return;
	}

	lc = [self control];	// dst
	srcLc = [img controlWithControl:lc];
	len = [self xDim];
	[lc deactivateInner];	// == deactivateX
	
	[lc rewind];
	loopLength = [lc loopLength];
	// src type is always real
	if (type == RECIMAGE_COMPLEX) {
		for (i = 0; i < loopLength; i++) {
			p1 = [img currentDataWithControl:srcLc];		// 1: src (img), 2: dst (self)
			p2 = [self currentDataWithControl:lc];
			q2 = p2 + dataLength;
			// complex only
			for (j = 0; j < len; j++) {
				p2[j] *= p1[j];
				q2[j] *= p1[j];
			}
			[lc increment];
		}
	} else {
		for (i = 0; i < loopLength; i++) {
			p1 = [img currentDataWithControl:srcLc];		// 1: src (img), 2: dst (self)
			p2 = [self currentDataWithControl:lc];
			for (j = 0; j < len; j++) {
				p2[j] *= p1[j];
			}
			[lc increment];
		}
	}
	[self checkNeg0];
}

// scale self by 1D scaling factor array (fix for above for 1d case)
// ### refine definition of this method ... corr for which loop ? -> lp

// ex1: calc resp img	[avg, blk, y, x] [blk]
// ex2: calc rindex		[avg, blk] [blk]
- (void)multBy1dImage:(RecImage *)img //forLoop:(RecLoop *)lp
{
	RecImage		*slc;
	RecLoop			*lp = [img xLoop];
	int				i, n = [img xDim];
	float			*p;		// src

	if ([img type] == RECIMAGE_COMPLEX) {
	//	[self multByCImage:img];
		printf("scaling by complex array is not supported yet.\n");
		return;
	}

	if ([img dim] > 1) {
		printf("scaling array must be 1d\n");
		return;
	}

	p  = [img data];
	for (i = 0; i < n; i++) {
		slc = [self sliceAtIndex:i forLoop:lp];
		[slc multByConst:p[i]];
		[self copySlice:slc atIndex:i forLoop:lp];
	}
}

// loop dim may be different #####
- (void)maskWithImage:(RecImage *)mask
{
    void			(^proc)(float *src, int srcSkip, float *dst, int dstSkip, int n);

    proc = ^void(float *src, int srcSkip, float *dst, int dstSkip, int n) {
        int     i;
		for (i = 0; i < n; i++) {
			if (src[i * srcSkip] == 0) {
				dst[i * dstSkip] = 0;
			}
		}
	};

    [self apply2ImageProc:proc withImage:mask andControl:[self control]];
}

- (void)maskWithImage:(RecImage *)mask invert:(BOOL)inv smooth:(BOOL)flt
{
    void        (^proc)(float *p, int xDim, int yDim);
    RecImage    *m;

    // make mask
    m = [mask copy];    // non-destructive
    [m takeRealPart];
    proc = ^void(float *p, int xDim, int yDim) {
        int     j, n = xDim * yDim;
        if (inv) {
            for (j = 0; j < n; j++) {
                if (p[j] > 0) {
                    p[j] = 0.0;
                } else {
                    p[j] = 1.0;
                }
            }
        } else {
            for (j = 0; j < n; j++) {
                if (p[j] > 0) {
                    p[j] = 1.0;
                } else {
                    p[j] = 0.0;
                }
            }
        }
    };
    [m apply2dProc:proc];

    // filt
    if (flt) {
        [m gauss2DLP:0.1];
    }
//[m saveAsKOImage:@"IMG_mask"];
    // multiply
    [self multByImage:m];
}

// change name !!###
// absorption to x-ray image
- (void)expWin:(float)tc       // tc: [0..1]
{
	float	*p = [self data];
    float   mx = [self maxVal];
	int		size = dataLength * [self pixSize];
    int     i;

    for (i = 0; i < size; i++) {
        p[i] = 1 - exp(-p[i]/(tc * mx));
    }
}

- (void)SCIC
{
	RecImage	*mg, *inv_mg;
	float		width = 8.0 / [self xDim];   // -> 8 / 256
	float		frac = 0.7;

	mg = [self copy];
	inv_mg = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
	[mg gauss3DLP:width];
    [mg copyLoopsOf:self];  // zLoop is replaced in the filter process

//	[mg saveAsKOImage:@"../test_img/test_SCIC_mask.img"];
	[mg scaleToVal:frac];
	[inv_mg setConst:1.0];
	[inv_mg subImage:mg];
	[self mulImage:inv_mg];
}

// check if contains NaN -> set to 0 and return BOOL(contains NaN)
- (BOOL)checkNaN
{
	float	val;
	int		i, k, len;
	float	*p;
    BOOL    found = NO;

	p = [self data];
	len = [self dataLength];

	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
			val = p[i];
            if (val != val) {
                p[i] = 0;
                found = YES;
            }
		}
		p += len;
	}
    return found;
}

- (BOOL)checkNeg0		// fix and returns "contains -0"
{
	float	val;
	int		i, k, len;
	float	*p;
    BOOL    found = NO;

	p = [self data];
	len = [self dataLength];

	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
			val = p[i];
            if (val == -0) {
                p[i] = +0;
                found = YES;
            }
		}
		p += len;
	}
    return found;
}

- (float)maxVal
{
	float	mx, val;
	int		i, k, len;
	float	*p;

	p = [self data];
	len = [self dataLength];
	mx = -MAXFLOAT;

	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
			val = p[i];
            if (val != val) {
                printf("RecImage:maxVal NaN found\n");
                exit(0);
            }
			if (val > mx) mx = val;
		}
		p += len;
	}

	return mx;
}

- (float)minVal
{
	float	mn, val;
	int		i, k, len;
	float	*p;

	p = [self data];
	len = [self dataLength];
	mn = MAXFLOAT;

	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
			val = p[i];
            if (val != val) {
                printf("RecImage:minVal NaN found\n");
                exit(0);
            }
			if (val < mn) mn = val;
		}
		p += len;
	}

	return mn;
}

- (float)rmsVal
{
	float	sum;
	int		i, k, len;
	float	*p;

	p = [self data];
	len = [self dataLength];
	sum = 0;

	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
			sum += (p[i] * p[i]);
		}
		p += len;
	}
    sum /= len * pixSize;

	return sqrt(sum);
}

- (float)meanVal
{
	float	sum;
	int		i, k, len;
	float	*p;

	p = [self data];
	len = [self dataLength];
	sum = 0;

	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
			sum += p[i];
		}
		p += len;
	}
    sum /= len * pixSize;

	return sum;
}

- (float)varWithMean:(float)mn
{
	float	sum;
	int		i, k, len;
	float	*p;

	p = [self data];
	len = [self dataLength];
	sum = 0;

	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
			sum += (p[i] - mn) * (p[i] - mn);
		}
		p += len;
	}
    sum /= len * pixSize;

	return sum;
}

- (int)nonZeroPix		// # of non-zero pixels
{
	int		i, k;
	int		n;
	float	*p = [self data];

	n = 0;
	for (i = 0; i < dataLength; i++) {
		for (k = 0; k < pixSize; k++) {
			if (p[k * dataLength + i] != 0) {
				n++;
				break;
			}
		}
	}
	return n;
}

- (void)intDiv:(float)d
{
	int		i;
	float	*p = [self data];

	for (i = 0; i < dataLength; i++) {
		p[i] = d * rint(p[i] / d);
	}
}

- (void)fMod:(float)d
{
	int		i;
	float	*p = [self data];

	for (i = 0; i < dataLength; i++) {
		p[i] = fmod(p[i], d);
	}
}

void
histogram(float *hst, int nbin, float *p, int ndata, float mn, float mx)
{
    int     i, ix;

    for (i = 0; i < nbin; i++) {
        hst[i] = 0;
    }
    for (i = 0; i < ndata; i++) {
        ix = (p[i] - mn) * nbin / (mx - mn);
        if (ix < 0) {
            hst[0] += 1;
        } else
        if (ix >= nbin) {
            hst[nbin-1]++;
        } else {
            hst[ix] += 1;
        }
    }
}
/*
- (void)histogram:(float *)hist min:(float)min max:(float)max binSize:(int)n filt:(BOOL)flt
{
    int     len;
    float   *p;

    p = [self data];
    len = [self dataLength];

    histogram(hist, n, p, len, min, max);
	if (flt) {
		Rec_smooth(hist, n, 5);
	}
}
*/

// real part only
- (void)histogram:(float *)hist x:(float *)x min:(float)min max:(float)max binSize:(int)n filt:(BOOL)flt
{
    int     i, len;
    float   *p;

    p = [self data];
    len = [self dataLength];
	for (i = 0; i < n; i++) {
		x[i] = min + (max - min) * i / n;
	}
    histogram(hist, n, p, len, min, max);
	if (flt) {
		Rec_smooth(hist, n, 5);
	}
}

- (void)scaleToVal:(float)max
{
	float	mx, scale;
	int		i, k, len;
	float	*p;

	p = [self data];
	len = [self dataLength];
	mx = [self maxVal];

	scale = max / mx;
	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
			p[i] *= scale;
		}
		p += len;
	}
}

- (void)limitToVal:(float)max
{
	int		i, k, len;
	float	*p;

	p = [self data];
	len = [self dataLength];

	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
			if (p[i] > max) p[i] = max;
			if (p[i] < -max) p[i] = -max;
		}
		p += len;
	}
}

// for projection ...
// make better name ##
- (void)limitLowToVal:(float)min
{
	int		i, k, len;
	float	*p;

	p = [self data];
	len = [self dataLength];

	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
            p[i] -= min;
			if (p[i] < 0) p[i] = 0;
		}
		p += len;
	}
}

- (void)scaleEachSliceToVal:(float)val
{
    void    (^proc)(float *p, int xDim, int yDim);

    proc = ^void(float *p, int xDim, int yDim) {
        int     n = xDim * yDim;
        float   mx;

        vDSP_maxv(p, 1, &mx, n);
        mx = val / mx;
        vDSP_vsmul(p, 1, &mx, p, 1, n);
    };
    [self apply2dProc:proc];
}

- (void)conjugate
{
	int		len;
	float	*p;

	len = [self dataLength];
	p = [self data] + len;

	vDSP_vneg(p, 1, p, 1, len);
}

// real only
- (void)negate
{
	int		len = [self dataLength] * [self pixSize];
	float	*p = [self data];
	vDSP_vneg(p, 1, p, 1, len);
}

// real & complex
- (void)invert
{
	int		i, len;
	float	*p, *q;
	float	mg, re, im;

	len = [self dataLength];
	p = [self data];

	if ([self type] == RECIMAGE_COMPLEX) {
		q = p + len;
		for (i = 0; i < len; i++) {
			re = p[i];
			im = q[i];
			mg = re * re + im * im;
			p[i] = re / mg;
			q[i] = -im / mg;
		}
	} else {	// real
		for (i = 0; i < len; i++) {
			if (p[i] != 0) {
				p[i] = 1.0 / p[i];
			} else {
				p[i] = 0;
			}
		}
	}
}

// functionally same as old recutil.c
- (void)fermi
{
	[self fermiWithRx:0.5 ry:0.5 d:0.3 x:0 y:0 invert:NO half:NO];
}

// dir of y is downward
- (void)fermiWithRx:(float)rx ry:(float)ry d:(float)d x:(float)xc y:(float)yc invert:(BOOL)inv half:(BOOL)hf
{
	RecImage		*kern;	// 2D kernel
	RecLoop			*kx, *ky;
	float			*p, x, y, r;
	int				i, j, xdim, ydim, skip;

	kx = [self xLoop];
	ky = [self yLoop];
	xdim = [kx dataLength];
	ydim = [ky dataLength];
	skip = [self skipSizeForLoop:ky];

	kern = [RecImage imageOfType:RECIMAGE_REAL withLoops:ky, kx, nil];
	p = [kern data];
	for (i = 0; i < ydim; i++, p += skip) {
		y = (float)(i - ydim/2) / ydim - yc;
		for (j = 0; j < xdim; j++) {
			x = (float)(j - xdim/2) / xdim - xc;
			r = x*x/rx/rx + y*y/ry/ry;
			r = sqrt(r);
			if (r > 1.0) {
				p[j] = 0;
			} else
			if (r < 1.0 - d) {
				p[j] = 1.0;
			} else {
				if (hf) {
					p[j] = cos((r - 1.0 + d) * 0.5 * M_PI / d);
				} else {
					p[j] = cos((r - 1.0 + d) * M_PI / d) * 0.5 + 0.5;
				}
			}
			if (inv) {
				p[j] = 1.0 - p[j];
			}
		}
	}
	//[kern saveAsKOImage:@"../test_img/kern.tmp"];
	[self multByImage:kern];
}

- (void)thresAt:(float)th		// make mask image: 1 if val > max * th, otherwise 0
{
	[self thresAt:th frac:YES];
}

- (void)thresAt:(float)th frac:(BOOL)fr	// make mask image: 1 if val > th (abs), otherwise 0
{
	float	mx;
	float	*p;
	int		i, len;

	if (fr) {
		[self magnitude];
		mx = [self maxVal];
		th *= mx;
	}
	p = [self data];
	len = [self dataLength];
	for (i = 0; i < len; i++) {
		if (p[i] > th) {
			p[i] = 1.0;
		} else {
			p[i] = 0.0;
		}
	}
	[self checkNeg0];

}

// not done yet... loop size is different (img is smaller)
- (void)thresWithImage:(RecImage *)img
{
	int		i, n;
	float	*p, *q;

printf("not done yet\n");
	q = [self data];
	p = [img data];
	n = [self dataLength] * [self pixSize];

	for (i = 0; i < n; i++) {
		if (q[i] > p[i]) {
			q[i] = 0;
		}
	}
}

// mag input
- (void)thresEachSliceAt:(float)th
{
    void    (^proc)(float *p, int xDim, int yDim);

    proc = ^void(float *p, int xDim, int yDim) {
        int     i, n = xDim * yDim;
        float   mx;

        vDSP_maxv(p, 1, &mx, n);
        mx *= th;
//printf("mx = %f\n", mx);
        for (i = 0; i < n; i++) {
			if (p[i] > mx) {
				p[i] = 1.0;
			} else {
				p[i] = 0.0;
			}
		}
    };
    [self apply2dProc:proc];
}

- (RecImage *)varMaskForLoop:(RecLoop *)lp	// make mask for phase image
{
	RecImage	*mask;
	float	thres = 0.2;

	mask = [self sdForLoop:lp];	// central sd
	[mask thresAt:thres];
	[mask logicalInv];

	return mask;
}

- (RecImage *)magMask:(float)th	// make mask for phase image
{
	RecImage	*mask;

	mask = [self avgForLoop:[self zLoop]];	// central sd
	[mask magnitude];
	[mask thresAt:th];

	return mask;
}

- (void)logicalInv			// 0 <-> 1
{
	int		i, len = [self dataLength];
	float	*p = [self data];

	for (i = 0; i < len; i++) {
		if (p[i] == 0) {
			p[i] = 1;
		} else {
			p[i] = 0;
		}
	}
}

- (void)addGWN:(float)sd relative:(BOOL)rel
{
	float       mx, nz;
	int         i, k, len;
	float       *p;
	RecNoise	*rnd = [RecNoise noise];

	p = [self data];
	len = [self dataLength];
    if (rel) {
        mx = [self maxVal];
        sd *= mx;
    }

	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < len; i++) {
            nz = [rnd nrml] * sd;
			p[i] += nz;
		}
		p += len;
	}
}

- (void)addRician:(float)sd relative:(BOOL)flg
{
	if ([self type] != RECIMAGE_COMPLEX) {
		[self makeComplex];
	}
	[self addGWN:sd relative:flg];
	[self magnitude];
}

- (void)corrForRician:(float)sd	// Hakon paper
{
	int		i;
	float	*p, mg;

//	sd *= [self maxVal];
	p = [self data];
	for (i = 0; i < [self dataLength]; i++) {
		mg = p[i] * p[i];
		mg -= sd * sd;
		if (mg < 0) {
			p[i] = sqrt(-mg);
		} else {
			p[i] = sqrt(mg);
		}
	}
}

- (void)corrForRician2:(float)sd	// Oshio mod
{
	int		i;
	float	*p, mg;

//	sd *= [self maxVal];
	p = [self data];
	for (i = 0; i < [self dataLength]; i++) {
		mg = p[i] * p[i];
		mg -= sd * sd;
		if (mg < 0) {
			p[i] = -sqrt(-mg);
		} else {
			p[i] = sqrt(mg);
		}
	}
}

- (RecLoop *)innerLoop			// innermost looop
{
	return [[dimensions lastObject] loop];
}

- (RecLoop *)topLoop			// outermost looop
{
	return [[dimensions objectAtIndex:0] loop];
}

- (RecLoop *)xLoop
{
	return [[dimensions lastObject] loop];
}

- (RecLoop *)yLoop
{
	int		loopIx = (int)[dimensions count] - 2;
	if (loopIx < 0) {
		return [RecLoop pointLoop];
	} else {
		return [[dimensions objectAtIndex:loopIx] loop];
	}
}

- (RecLoop *)zLoop
{
	int		loopIx = (int)[dimensions count] - 3;
	if (loopIx < 0) {
		return [RecLoop pointLoop];
	} else {
		return [[dimensions objectAtIndex:loopIx] loop];
	}
}

- (RecAxis *)xLoopAx
{
	return [dimensions lastObject];
}

- (RecAxis *)yLoopAx
{
	int		loopIx = (int)[dimensions count] - 2;
	if (loopIx < 0) {
		return [RecAxis pointAx];
	} else {
		return [dimensions objectAtIndex:loopIx];
	}
}

- (RecAxis *)zLoopAx
{
	int		loopIx = (int)[dimensions count] - 3;
	if (loopIx < 0) {
		return [RecAxis pointAx];
	} else {
		return [dimensions objectAtIndex:loopIx];
	}
}

- (RecLoop *)loopAtIndex:(int)ix
{
	if (ix >= 0 && ix < [dimensions count]) {
		return [[dimensions objectAtIndex:ix] loop];
	} else {
		NSLog(@"RecImage:loopAtIndex: index out of range");
		exit(0);
	}
}

- (RecAxis *)axisForLoop:(RecLoop *)lp
{
    RecAxis *ax;
    int     i, n = [self dim];

    for (i = 0; i < n; i++) {
        ax = [dimensions objectAtIndex:i];
        if ([[ax loop] isEqual:lp]) {
            return ax;
        }
    }
    return nil; // not found
}

- (RecLoop *)chLoop
{
	return [RecLoop findLoop:@"Channel"];
}

- (int)chDim
{
	return [[self chLoop] dataLength];
}

// FFT
- (void)makeComplex	// add empty imag part
{
	RecImage	*img;
    float       *src, *dst;
    int         i;

// make new complex image
	if ([self type] == RECIMAGE_COMPLEX) return;
	img = [RecImage imageOfType:RECIMAGE_COMPLEX withImage:self];
// copy real part
    src = [self data];
    dst = [img data];
    for (i = 0; i < dataLength; i++) {
        dst[i] = src[i];
    }
	[self copyIvarOf:img];
}

- (void)takeRealPart	// remove imag part
{
	RecImage	*img;
    float       *src, *dst;
    int         i;

// make new real image
	if ([self type] == RECIMAGE_REAL) return;
	img = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
// copy real part
    src = [self data];
    dst = [img data];
    for (i = 0; i < dataLength; i++) {
        dst[i] = src[i];
    }
	[self copyIvarOf:img];
}

- (void)takeImagPart	// remove real part
{
	RecImage	*img;
    float       *src, *dst;
    int         i;

// make new real image
	if ([self type] == RECIMAGE_REAL) return;
	img = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
// copy real part
    src = [self data] + dataLength;
    dst = [img data];
    for (i = 0; i < dataLength; i++) {
        dst[i] = src[i];
    }
	[self copyIvarOf:img];
}

- (void)takePlaneAtIndex:(int)ix	// 0:real, 1:imag, 2:weight, etc
{
	RecImage	*img;
    float       *src, *dst;
    int         i;

// make new real image
	if (pixSize <= ix) return;
	img = [RecImage imageOfType:RECIMAGE_REAL withImage:self];
// copy real part
    src = [self data] + dataLength * ix;
    dst = [img data];
    for (i = 0; i < dataLength; i++) {
        dst[i] = src[i];
    }
	[self copyIvarOf:img];
}

- (void)removeRealPart	// clear real part (keep complex format)
{
	float		*p;
	int			len;

	if ([self type] == RECIMAGE_REAL) return;
	p = [self data];
	len = [self dataLength];
	vDSP_vclr(p, 1, len);
}

- (void)removeImagPart	// clear imag part (keep complex format)
{
	float		*p;
	int			len;

	if ([self type] == RECIMAGE_REAL) return;
	p = [self data];
	len = [self dataLength];
    p += len;
	vDSP_vclr(p, 1, len);
}


- (void)copyRealOf:(RecImage *)img
{
    int     i;
    float   *p, *q;

    p = [img data];
    q = [self data];
    q += dataLength;
    for (i = 0; i < dataLength; i++) {
        q[i] = p[i];
    }
}

- (void)copyImagOf:(RecImage *)img
{
    int     i;
    float   *p, *q;

    p = [img data];
    q = [self data];
    p += dataLength;
    for (i = 0; i < dataLength; i++) {
        q[i] = p[i];
    }
}

- (void)setRealToZero
{
    int     i;
    float   *p;

    p = [self data];
    for (i = 0; i < dataLength; i++) {
        p[i] = 0;
    }
}

- (RecImage *)makeColorWithR:(RecImage *)r G:(RecImage *)g B:(RecImage *)b
{
    float       *p, *q;
    int         i, n = [g dataLength];
    RecImage    *img = [RecImage imageOfType:RECIMAGE_COLOR withImage:g];

    if (r) {
        p = [r data];
        q = [img r];
        for (i = 0; i < n; i++) {
            q[i] = p[i];
        }
    }
    if (g) {
        p = [g data];
        q = [img g];
        for (i = 0; i < n; i++) {
            q[i] = p[i];
        }
    }
    if (b) {
        p = [b data];
        q = [img b];
        for (i = 0; i < n; i++) {
            q[i] = p[i] * 2;
        }
    }
    return img;
}

- (RecImage *)toDipole
{
    RecImage    *x, *y;

    x = [self copy];
    [x fft2d:REC_INVERSE];				// to freq
    y = [x copy];

    [x sinFilt:0 ang: 0.0];				// sin(th), odd func
    [x fft2d:REC_FORWARD];				// to space (pure imag)

    [y sinFilt:0 ang: M_PI/2.0];		// cos(th), odd func
    [y fft2d:REC_FORWARD];				// to space (pure imag)

    [x copyImagOf:y];					// make complex
    return x;
}

- (RecImage *)toQuadrupole
{
    RecImage    *x, *y;

    x = [self copy];
    [x fft2d:REC_INVERSE];				// to freq
    y = [x copy];

    [x sinFilt:1 ang: 0.0];				// sin(2*th), even func
    [x fft2d:REC_FORWARD];				// to space (pure real)

    [y sinFilt:1 ang: M_PI/4.0];		// cos(2*th), even func
    [y fft2d:REC_FORWARD];				// to space (pure real)

    [y copyRealOf:x];					// make complex
    return y;
}

- (void)magnitude		// take magnitude, and remove imag part
{
	int		i, len;
	float	*p, *q, *r;

	len = [self dataLength];
	p = [self data];
	if (type == RECIMAGE_REAL) {
		for (i = 0; i < len; i++) {
			p[i] = fabs(p[i]);
		}
	} else
	if (type == RECIMAGE_COMPLEX) {
		q = p + len;
		for (i = 0; i < len; i++) {
			p[i] = sqrt(p[i]*p[i] + q[i]*q[i]);	// -> vDSP
			q[i] = 0;
		}
		[self takeRealPart];
	} else
    if (type == RECIMAGE_VECTOR) {
		q = p + len;
        r = q + len;
		for (i = 0; i < len; i++) {
			p[i] = sqrt(p[i]*p[i] + q[i]*q[i] + r[i]*r[i]);
			q[i] = r[i] = 0;
		}
		[self takeRealPart];
    }
}

- (void)phase			// take phase, and remove imag part
{
	int		i, len;
	float	*p, *q;

	if (type == RECIMAGE_COMPLEX) {
		[self checkNeg0];
		len = [self dataLength];
		p = [self data];
		q = p + len;
		for (i = 0; i < len; i++) {
			p[i] = atan2(q[i], p[i]);
			q[i] = 0;
		}
		[self takeRealPart];
	}
}

- (void)makeComplexWithPhs:(RecImage *)phs	// make complex image from mg/phs pair 
{
	int		i, len;
	float	*p, *q, *th;
	float	re, im, cs, sn;

	[self makeComplex];
	len = [self dataLength];
	th = [phs data];
	p = [self real];
	q = [self imag];
	
	for (i = 0; i < len; i++) {
		cs = cos(th[i]);
		sn = sin(th[i]);
		re = p[i] * cs;
		im = p[i] * sn;
		p[i] = re;
		q[i] = im;
	}
}

- (void)makeComplexWithIm:(RecImage *)im	// make complex image from mg/phs pair 
{
	int		i, len;
	float	*p, *q;

	[self makeComplex];
	len = [self dataLength];
	p = [im data];
	q = [self imag];
	
	for (i = 0; i < len; i++) {
		q[i] = p[i];
	}
}

- (void)phaseWithMaskSigma:(float)sg
{
	RecImage	*msk = [self makeMask:sg];

	[self phase];
	[self maskWithImage:msk];
}

- (void)magnitudeSq		// take magnitude^2, and remove imag part
{
	int		i, len;
	float	*p, *q;

	len = [self dataLength];
	p = [self data];
	if (type == RECIMAGE_REAL) {
		for (i = 0; i < len; i++) {
			p[i] *= p[i];
		}
	} else
	if (type == RECIMAGE_COMPLEX) {
		q = p + len;
		for (i = 0; i < len; i++) {
			p[i] = p[i]*p[i] + q[i]*q[i];	// -> vDSP
			q[i] = 0;
		}
		[self takeRealPart];
	}
}

- (void)sqroot			// take square root
{
	int		i, len;
	float	*p;

	[self takeRealPart];
	len = [self dataLength];
	p = [self data];
	for (i = 0; i < len; i++) {
		if (p[i] > 0) {
			p[i] = sqrt(p[i]);
		} else {
			p[i] = 0;
		}
	}
}

- (void)square			// take square (if cpx, take mg^2)
{
	int		i, len;
	float	*p, *q;

	len = [self dataLength];
	if (type == RECIMAGE_COMPLEX) {
		p = [self data];
		q = p + len;
		for (i = 0; i < len ;i++) {
			p[i] = p[i] * p[i] + q[i] * q[i];
		}
		[self takeRealPart];
	} else {
		p = [self data];
		for (i = 0; i < len; i++) {
			p[i] *= p[i];
		}
	}
}

- (void)exp
{
	int		i, len;
	float	*p;

	[self takeRealPart];
	len = [self dataLength];
	p = [self data];
	for (i = 0; i < len; i++) {
		p[i] = exp(p[i]);
	}
}

- (void)logWithMin:(float)mn
{
	int		i, len;
	float	*p;

	[self takeRealPart];
	len = [self dataLength];
	p = [self data];
	for (i = 0; i < len; i++) {
		if (p[i] < mn) {
			p[i] = 0;
		} else {
			p[i] = log(p[i] + mn);
		}
	}
}

- (void)takeEvenLines	// take even lines (for epi pcorr etc)
{
	int		i, j, k, xDim, yDim, nImages;
	float	*p, *q;

	xDim = [self xDim];
	yDim = [self yDim];
	nImages = [self dataLength] / xDim / yDim;

	for (k = 0; k < nImages; k++) {
		for (i = 0; i < yDim; i++) {
			if (i % 2 == 1) {
				p = [self data] + k * xDim * yDim + i * xDim;
				q = p + [self dataLength];
				for (j = 0; j < xDim; j++) {
					p[j] = q[j] = 0;
				}
			}
		}
		
	}
}

- (void)takeOddLines	// take odd lines (for epi pcorr etc)
{
	int		i, j, k, xDim, yDim, nImages;
	float	*p, *q;

	xDim = [self xDim];
	yDim = [self yDim];
	nImages = [self dataLength] / xDim / yDim;

	for (k = 0; k < nImages; k++) {
		for (i = 0; i < yDim; i++) {
			if (i % 2 == 0) {
				p = [self data] + k * xDim * yDim + i * xDim;
				q = p + [self dataLength];
				for (j = 0; j < xDim; j++) {
					p[j] = q[j] = 0;
				}
			}
		}
		
	}
}

- (void)copyEvenLines:(RecImage *)img	// copy even lines (for epi pcorr etc)
{
	int		i, j, k, xDim, yDim, nImages;
	float	*p1, *q1;	// dst
	float	*p2, *q2;	// src

	xDim = [self xDim];
	yDim = [self yDim];
	nImages = [self dataLength] / xDim / yDim;

	for (k = 0; k < nImages; k++) {
		for (i = 0; i < yDim; i++) {
			if (i % 2 == 0) {
				p1 = [self data] + k * xDim * yDim + i * xDim;
				q1 = p1 + [self dataLength];
				p2 = [img data] + k * xDim * yDim + i * xDim;
				q2 = p2 + [img dataLength];
				for (j = 0; j < xDim; j++) {
					p1[j] = p2[j];
					q1[j] = q2[j];
				}
			}
		}
		
	}
}
- (void)copyOddLines:(RecImage *)img	// copy odd lines (for epi pcorr etc)
{
	int		i, j, k, xDim, yDim, nImages;
	float	*p1, *q1;	// dst
	float	*p2, *q2;	// src

	xDim = [self xDim];
	yDim = [self yDim];
	nImages = [self dataLength] / xDim / yDim;

	for (k = 0; k < nImages; k++) {
		for (i = 0; i < yDim; i++) {
			if (i % 2 == 1) {
				p1 = [self data] + k * xDim * yDim + i * xDim;
				q1 = p1 + [self dataLength];
				p2 = [img data] + k * xDim * yDim + i * xDim;
				q2 = p2 + [img dataLength];
				for (j = 0; j < xDim; j++) {
					p1[j] = p2[j];
					q1[j] = q2[j];
				}
			}
		}
		
	}
}

- (void)logP1
{
	RecImage	*img;
	int			i, len;
	float		*p;

	len = [self dataLength] * [self pixSize];
	p = [self data];
	for (i = 0; i < len; i++) {
        if (p[i] >= 0) {
            p[i] = log(p[i] + 1);
        } else {
            p[i] = -log(-p[i] + 1);
        }
	}
}

- (RecImage *)logP1X
{
	RecImage	*img;
	int			i, len;
	float		*p;

	img = [self copy];
	len = [img dataLength] * [img pixSize];
	p = [img data];
	for (i = 0; i < len; i++) {
        if (p[i] >= 0) {
            p[i] = log(p[i] + 1);
        } else {
            p[i] = -log(-p[i] + 1);
        }
	}
	return img;
}

- (RecImage *)pwrx:(float)x		// take pow(x, p)
{
	RecImage	*img;
	int			i, len;
	float		*p;

	img = [self copy];
	len = [img dataLength] * [img pixSize];
	p = [img data];
	for (i = 0; i < len; i++) {
        if (p[i] >= 0) {
            p[i] = pow(p[i], x);
        } else {
            p[i] = -pow(-p[i], x);
        }
	}
	return img;
}

- (void)fft1d_ref:(RecLoop *)lp direction:(int)dir
{
	RecLoopControl		*lc = [self control];

	[lc deactivateLoop:lp];
	[self fft1d:lp withControl:lc direction:dir];
}

// inner loop common to ref / op
// lc : outerloop for lp
- (void)fft1d:(RecLoop *)lp withControl:(RecLoopControl *)lc direction:(int)dir
{
	int		len = [lp dataLength];

	// FFT
	if (len == Rec_po2(len)) {
		//printf("FFT\n");
		[self fft1d_FFT:lp withControl:lc direction:dir];
		return;
	} else
	// DFT
	if (vDSP_DFT_zop_CreateSetup(NULL, len, vDSP_DFT_FORWARD) != NULL) {
		//printf("DFT\n");
		[self fft1d_DFT:lp withControl:lc direction:dir];
		return;
	} else
	// ChirpZ
	{
		//printf("CHZ\n");
		[self fft1d_CZ:lp withControl:lc direction:dir];
	//	[self dft1d:lp withControl:lc direction:dir];
		return;
	}
}

- (void)fft1d_FFT:(RecLoop *)lp withControl:(RecLoopControl *)lc direction:(int)dir	// vDSP_fft_zip
{
	FFTSetup			setup;
	DSPSplitComplex		src;
	vDSP_Length         lg2;
	int					len, len2;	// length of inner loop
	float				scale;
	int					direction;
	int					i;
	int					src_skip, loopLen = [lc loopLength];

	len = [lp dataLength];
	lg2 = log2(len);
	scale = 1.0 / len;
	src_skip = [self skipSizeForLoop:lp];
	len2 = len / 2;
	setup = vDSP_create_fftsetup(lg2, kFFTRadix2);
	if (dir == REC_FORWARD) {
		direction = kFFTDirection_Forward;
	} else {
		direction = kFFTDirection_Inverse;
	}
	[lc rewind];
	for (i = 0; i < loopLen; i++) {
		src.realp = [self currentDataWithControl:lc];
		src.imagp = src.realp + dataLength;
		vDSP_vswap(src.realp, src_skip, src.realp + len2 * src_skip, src_skip, len2);
		vDSP_vswap(src.imagp, src_skip, src.imagp + len2 * src_skip, src_skip, len2);

		vDSP_fft_zip(setup, &src, src_skip, lg2, direction); 

		vDSP_vswap(src.realp, src_skip, src.realp + len2 * src_skip, src_skip, len2);
		vDSP_vswap(src.imagp, src_skip, src.imagp + len2 * src_skip, src_skip, len2);
		if (direction == kFFTDirection_Inverse) {
			vDSP_vsmul(src.realp, src_skip, &scale, src.realp, src_skip, len);
			vDSP_vsmul(src.imagp, src_skip, &scale, src.imagp, src_skip, len);
		}
		[lc increment];
	}
	vDSP_destroy_fftsetup(setup);
}

- (void)fft1d_DFT:(RecLoop *)lp withControl:(RecLoopControl *)lc direction:(int)dir	// vDSP_DFT_zop
{
	vDSP_DFT_Setup		setup;
	DSPSplitComplex		src, dst;
	float				*p, *q;
	int					len, len2;	// length of inner loop
	float				scale;
	int					direction;
	int					i, j, ix;
	int					src_skip, loopLen = [lc loopLength];

	len = [lp dataLength];
	src.realp = (float *)malloc(sizeof(float) * len);
	src.imagp = (float *)malloc(sizeof(float) * len);
	dst.realp = (float *)malloc(sizeof(float) * len);
	dst.imagp = (float *)malloc(sizeof(float) * len);

	scale = 1.0 / len;
	src_skip = [self skipSizeForLoop:lp];
	len2 = len / 2;
	if (dir == REC_FORWARD) {
		direction = vDSP_DFT_FORWARD;
	} else {
		direction = vDSP_DFT_INVERSE;
	}
	setup = vDSP_DFT_zop_CreateSetup(NULL, len, direction);

	[lc rewind];
	loopLen = [lc loopLength];
	for (i = 0; i < loopLen; i++) {
		p = [self currentDataWithControl:lc];
		q = p + dataLength;
		// copy one line to src
		for (j = ix = 0; j < len; j++, ix += src_skip) {
			src.realp[j] = p[ix];
			src.imagp[j] = q[ix];
		}
		vDSP_vswap(src.realp, 1, src.realp + len2, 1, len2);
		vDSP_vswap(src.imagp, 1, src.imagp + len2, 1, len2);

		vDSP_DFT_Execute(setup, src.realp, src.imagp, dst.realp, dst.imagp); 

		vDSP_vswap(dst.realp, 1, dst.realp + len2, 1, len2);
		vDSP_vswap(dst.imagp, 1, dst.imagp + len2, 1, len2);
		if (direction == kFFTDirection_Inverse) {
			vDSP_vsmul(dst.realp, 1, &scale, dst.realp, 1, len);
			vDSP_vsmul(dst.imagp, 1, &scale, dst.imagp, 1, len);
		}
		for (j = ix = 0; j < len; j++, ix += src_skip) {
			p[ix] = dst.realp[j];
			q[ix] = dst.imagp[j];
		}
		[lc increment];
	}
	vDSP_DFT_DestroySetup(setup);
	free(src.realp);
	free(src.imagp);
	free(dst.realp);
	free(dst.imagp);
}

// ### not done yet
- (void)fft1d_CZ:(RecLoop *)lp withControl:(RecLoopControl *)lc direction:(int)dir
{
	RecCftSetup			*setup;
	DSPSplitComplex		src;
	int					len, len2;	// length of inner loop
	float				scale;
	int					direction;
	int					i;
	int					src_skip, loopLen = [lc loopLength];

	len = [lp dataLength];

	scale = 1.0 / len;
	src_skip = [self skipSizeForLoop:lp];
	len2 = len / 2;
	if (dir == REC_FORWARD) {
		direction = vDSP_DFT_FORWARD;
	} else {
		direction = vDSP_DFT_INVERSE;
	}
	setup = Rec_cftsetup(len);

	[lc rewind];
	for (i = 0; i < loopLen; i++) {
		src.realp = [self currentDataWithControl:lc];
		src.imagp = src.realp + dataLength;
		vDSP_vswap(src.realp, src_skip, src.realp + len2 * src_skip, src_skip, len2);
		vDSP_vswap(src.imagp, src_skip, src.imagp + len2 * src_skip, src_skip, len2);

		Rec_cft(setup, &src, src_skip, direction);

		vDSP_vswap(src.realp, src_skip, src.realp + len2 * src_skip, src_skip, len2);
		vDSP_vswap(src.imagp, src_skip, src.imagp + len2 * src_skip, src_skip, len2);
		if (direction == kFFTDirection_Inverse) {
			vDSP_vsmul(src.realp, src_skip, &scale, src.realp, src_skip, len);
			vDSP_vsmul(src.imagp, src_skip, &scale, src.imagp, src_skip, len);
		}
		[lc increment];
	}
	Rec_destroy_cftsetup(setup);
}


- (void)fft1d:(RecLoop *)lp direction:(int)dir
{
    if (type != RECIMAGE_COMPLEX) {
        [self makeComplex];
    }
    switch (fft_mode) {
    case 0 :	// default (single CPU, Accelerate)
        [self fft1d_ref:lp direction:dir];
        break;
    case 1 :	// NSOperation
        if ([self realDim] > 2) {
            [self fft1d_op:lp direction:dir];
        } else {
            [self fft1d_ref:lp direction:dir];
        }
        break;
    case 2 :	// OpenCL, not working yet
//		[self fft1d_CL:lp direction:dir]; 
        [self fft1d_ref:lp direction:dir];
        break;
    }
    [self changeUnit:dir forLoop:lp];
}

// NSOperation version (ver3) ... speed-gain as expected
- (void)fft1d_op:(RecLoop *)lp direction:(int)dir
{
	RecLoopControl		*lc = [self outerLoopControlForLoop:lp];
	NSArray				*subControls = [lc subControls];
	NSOperationQueue	*queue = [[NSOperationQueue alloc] init];
	RecFFT1dOp			*op;
	int					i, n;

	[queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];

	n = (int)[subControls count];
	for (i = 0; i < n; i++) {
		lc = [subControls objectAtIndex:i];
		op = [RecFFT1dOp opWithImage:self control:lc loop:lp direction:dir];
		[queue addOperation:op];
	}
	[queue waitUntilAllOperationsAreFinished];
}

//- (void)dft1d:(RecLoop *)lp direction:(int)dir
//{
//	RecLoopControl		*lc = [self control];
//	RecLoopIndex		*li = [lc loopIndexForLoop:lp];
//
//	[li setActive:NO];
//	[self dft1d:lp withControl:lc direction:dir];
//}


- (void)dft1d:(RecLoop *)lp withControl:(RecLoopControl *)lc direction:(int)dir
{
	RecDftSetup			*setup;
	DSPSplitComplex		src;
	int					len, len2;	// length of inner loop
	float				scale;
	int					i;
	int					src_skip, loopLen = [lc loopLength];

	len = [lp dataLength];
	scale = 1.0 / len;
	src_skip = [self skipSizeForLoop:lp];
	len2 = len / 2;
	setup = Rec_dftsetup(len);

	[lc rewind];
	for (i = 0; i < loopLen; i++) {
		src.realp = [self currentDataWithControl:lc];
		src.imagp = src.realp + dataLength;
		vDSP_vswap(src.realp, src_skip, src.realp + len2 * src_skip, src_skip, len2);
		vDSP_vswap(src.imagp, src_skip, src.imagp + len2 * src_skip, src_skip, len2);
//		vDSP_fft_zip(setup, &src, src_skip, lg2, direction);
		Rec_dft(setup, &src, src_skip, dir);	// no inverse scaling (following vDSP convention)

		vDSP_vswap(src.realp, src_skip, src.realp + len2 * src_skip, src_skip, len2);
		vDSP_vswap(src.imagp, src_skip, src.imagp + len2 * src_skip, src_skip, len2);
		if (dir == REC_INVERSE) {
			vDSP_vsmul(src.realp, src_skip, &scale, src.realp, src_skip, len);
			vDSP_vsmul(src.imagp, src_skip, &scale, src.imagp, src_skip, len);
		}
		[lc increment];
	}
	Rec_destroy_dftsetup(setup);
}

- (void)shift1d:(RecLoop *)lp
{
	RecLoopControl		*lc = [self outerLoopControlForLoop:lp];
	DSPSplitComplex		src;
	int					src_skip;
	int					len, len2;	// length of inner loop
	int					i, n = [lc loopLength];

	len = [lp dataLength];
	src_skip = [self skipSizeForLoop:lp];
	len2 = len / 2;

	[lc rewind];
	for (i = 0; i < n; i++) {
		src.realp = [self currentDataWithControl:lc];
		src.imagp = src.realp + dataLength;
		vDSP_vswap(src.realp, src_skip, src.realp + len2 * src_skip, src_skip, len2);
		vDSP_vswap(src.imagp, src_skip, src.imagp + len2 * src_skip, src_skip, len2);
		[lc increment];
	}
}

// block version
// with DSP support ?
// ### negative nPix doesn't work
- (void)shift1d:(RecLoop *)lp by:(int)nPix
{
    float           *buf;
    int             len = [lp dataLength];
    void            (^proc)(float *p, int len, int skip);

	buf = (float *)malloc(sizeof(float) * len);
	if (nPix < 0) {
		nPix += len;
	}
	if (nPix >= len) {
		nPix -= len;
	}

    proc = ^void(float *p, int len, int skip) {
        int     j, jj, ix;
		ix = 0;
		for (j = 0; j < len; j++) {
			buf[j] = p[ix];
			ix += skip;
		}
		ix = 0;
		jj = nPix;
		for (j = 0; j < len - nPix; j++, jj++) {
			p[ix] = buf[jj];
			ix += skip;
		}
		jj = 0;
		for ( ; j < len; j++, jj++) {
			p[ix] = buf[jj];
			ix += skip;
		}
    };
    [self apply1dProc:proc forLoop:lp];

	free(buf);
}

- (void)rotate1d:(RecLoop *)lp by:(float)d
{
	int				i, j;
	int				len = [lp dataLength];
	int				skip = [self skipSizeForLoop:lp];
	
	RecLoopControl	*lc;
	float			*p, *q;
	float			re, im;
	float			*cs, *sn, th, n2;

	cs = (float *)malloc(len * sizeof(float));
	sn = (float *)malloc(len * sizeof(float));
	n2 = (float)(len + 1) / 2;
	for (j = 0; j < len; j++) {
		th = d * M_PI * 2 * (j - n2)/len;
		cs[j] = cos(th);
		sn[j] = sin(th);
	}
// ft
	[self fft1d:lp direction:REC_FORWARD];
// lin phase
	lc = [self outerLoopControlForLoop:lp];
	for (i = 0; i < [lc loopLength]; i++) {
		p = [self currentDataWithControl:lc];
		q = p + [self dataLength];
		for (j = 0; j < len; j++) {
			re = *p * cs[j] - *q * sn[j];
			im = *p * sn[j] + *q * cs[j];
			*p = re;
			*q = im;
			p += skip;
			q += skip;
		}
		[lc increment];
	}
// ift
	[self fft1d:lp direction:REC_INVERSE];

	free(cs);
	free(sn);
}

- (void)fft2d:(int)dir
{
	[self fft1d:[self xLoop] direction:dir];
	[self fft1d:[self yLoop] direction:dir];
}

- (void)fft3d:(int)dir
{
	[self fft1d:[self xLoop] direction:dir];
	[self fft1d:[self yLoop] direction:dir];
	[self fft1d:[self zLoop] direction:dir];
}

// DCT
// not done yet #####
- (void)dct1dX:(RecLoop *)lp // for entire image
{
	vDSP_DFT_Setup		setup;
	vDSP_Length         len;
	int					skip;
	int					i, j, ix;
	float				*p;
	float				*src, *dst;
	RecLoopControl		*lc;
	int					loopLen;
//	RecLoop				*newLp;

// zerofillToPo2
//    newLp = [self zeroFillToPo2:lp];

	lc = [self control];
	len = [lp dataLength];
	skip = [self skipSizeForLoop:lp];

	setup = vDSP_DCT_CreateSetup(NULL, len, vDSP_DCT_IV);
	src = (float *)malloc(sizeof(float) * len);
	dst = (float *)malloc(sizeof(float) * len);
	[lc rewind];
	[lc deactivateLoop:lp];
	loopLen = [lc loopLength];
	for (i = 0; i < loopLen; i++) {
		p = [self currentDataWithControl:lc];
		for (j = ix = 0; j < len; j++, ix += skip) {
			src[j] = p[ix];
		}
		vDSP_DCT_Execute(setup, src, dst);
		for (j = ix = 0; j < len; j++, ix += skip) {
			p[ix] = dst[j];
		}
		[lc increment];
	}
    // crop
    //    [self replaceLoop:newLp withLoop:lp offset:-20];    // original lp

    free(src);
    free(dst);
}

// DCT (new version)(slow)
- (RecImage *)dct1d:(RecLoop *)lp order:(int)odr // for entire image
{
    RecDctSetup     *setup;
    RecImage        *coef;
    float           *p, *q;
    RecLoop         *cLp;
    RecLoopControl  *srcLc, *dstLc;
    int             i, loopLen;
    int             srcSkip, dstSkip;
    int             dim;

    dim = [lp dataLength];
    coef = [RecImage imageWithImage:self];
    cLp = [coef crop:lp to:odr];

    setup = Rec_dct_setup(dim, odr);
    srcLc = [self control];
    dstLc = [coef controlWithControl:srcLc];
    srcSkip = [self skipSizeForLoop:lp];
    dstSkip = [coef skipSizeForLoop:cLp];
    
    [srcLc deactivateLoop:lp];
    loopLen = [srcLc loopLength];
    for (i = 0; i < loopLen; i++) {
        p = [self currentDataWithControl:srcLc];
        q = [coef currentDataWithControl:dstLc];
        Rec_dct_1d(p, srcSkip, q, dstSkip, setup, REC_INVERSE);
        [srcLc increment];
    }
    Rec_free_dct_setup(setup);

    return coef;
}


- (void)dct2d
{
	float	scale = sqrt([self xDim] * [self yDim]) / 2;
	[self dct1d:[self xLoop]];
	[self dct1d:[self yLoop]];
	[self multByConst:1.0/scale];
}

// Wavelet (not implemented yet)
- (void)wave1d:(RecLoop *)lp level:(int)lv direction:(int)dir
{
	RecWaveSetup		*setup;
	int					len;
	int					skip;
	int					i, j, ix;
	float				*p;
	float				*buf;	// in-place op
	RecLoopControl		*lc;
	int					loopLen;

	lc = [self control];
	len = [lp dataLength];
	skip = [self skipSizeForLoop:lp];

	setup = Rec_wave_setup(len);
	buf = (float *)malloc(sizeof(float) * len);
	[lc rewind];
	[lc deactivateLoop:lp];
	loopLen = [lc loopLength];
	if (dir == REC_FORWARD) {
		for (i = 0; i < loopLen; i++) {
			p = [self currentDataWithControl:lc];
			for (j = ix = 0; j < len; j++, ix += skip) {
				buf[j] = p[ix];
			}
			Rec_wvt(buf, lv, setup);
			for (j = ix = 0; j < len; j++, ix += skip) {
				p[ix] = buf[j];
			}
			[lc increment];
		}
	} else {
		for (i = 0; i < loopLen; i++) {
			p = [self currentDataWithControl:lc];
			for (j = ix = 0; j < len; j++, ix += skip) {
				buf[j] = p[ix];
			}
			Rec_iwvt(buf, lv, setup);
			for (j = ix = 0; j < len; j++, ix += skip) {
				p[ix] = buf[j];
			}
			[lc increment];
		}
	}

	free(buf);
}

- (void)wave2d:(int)dir level:(int)lv
{
	[self wave1d:[self xLoop] level:lv direction:dir];
	[self wave1d:[self yLoop] level:lv direction:dir];
}

// single slice
// take slice etc avg before calling this
- (RecImage *)waveEnergyWithLevel:(int)lv
{
	RecImage	*coef;
	RecImage	*mg;
	int			xDim, yDim;	// self
	int			nc;			// coef (== lv + 1)
	int			i, j;
	int			xSz, ySz, x0, y0;
	int			sz;
	float		*q;
	Rec2DRef	*ref;

	mg = [self copy];
	[mg magnitude];
	if ([mg zDim] > 1) {
		mg = [mg avgForLoop:[mg zLoop]];
	}
	xDim = [mg xDim];
	yDim = [mg yDim];
	nc = lv + 1;

	ref = [Rec2DRef refForImage:mg];
	coef = [RecImage imageOfType:RECIMAGE_REAL xDim:nc yDim:nc];
	q = [coef data];

	for (i = 0; i < nc; i++) {
		sz = lv - i + 1;
		if (sz > lv) {
			y0 = 0;
			ySz = yDim * pow(2, -lv);
		} else {
			y0 =  yDim * pow(2, -sz);
			ySz = yDim * pow(2, -sz);
		}
		for (j = 0; j < nc; j++) {
			sz = lv - j + 1;
			if (sz > lv) {
				x0 = 0;
				xSz = xDim * pow(2, -lv);
			} else {
				x0 =  xDim * pow(2, -sz);
				xSz = xDim * pow(2, -sz);
			}
			[ref setX:x0 y:y0 nX:xSz nY:ySz];
			q[i * nc + j] = [ref avg];
		}
	}

	return coef;
}

// single slice first -> multi-slice
- (void)waveFiltWithCoef:(RecImage *)coef
{
//	RecImage	*coef;
//	RecImage	*wav;
	int			xDim, yDim;	// self
	int			nc, lv;			// coef (== lv + 1)
	int			i, j;
	int			xSz, ySz, x0, y0;
	int			sz;
	float		*q;
	Rec2DRef	*ref;

	

	xDim = [self xDim];
	yDim = [self yDim];
	nc = [coef xDim];
	lv = nc - 1;

	[self wave2d:REC_FORWARD level:lv];
	q = [coef data];
	ref = [Rec2DRef refForImage:self];

	for (i = 0; i < nc; i++) {
		sz = lv - i + 1;
		if (sz > lv) {
			y0 = 0;
			ySz = yDim * pow(2, -lv);
		} else {
			y0 =  yDim * pow(2, -sz);
			ySz = yDim * pow(2, -sz);
		}
		for (j = 0; j < nc; j++) {
			sz = lv - j + 1;
			if (sz > lv) {
				x0 = 0;
				xSz = xDim * pow(2, -lv);
			} else {
				x0 =  xDim * pow(2, -sz);
				xSz = xDim * pow(2, -sz);
			}
			[ref setX:x0 y:y0 nX:xSz nY:ySz];
			[ref multBy:q[i * nc + j]];
		}
	}
	[self wave2d:REC_INVERSE level:lv];
}

- (int)xDim
{
	return [[self xLoop] dataLength];
}

- (int)yDim
{
	return [[self yLoop] dataLength];
}

- (int)zDim
{
	return [[self zLoop] dataLength];
}

- (int)topDim
{
	return [[self topLoop] dataLength];
}

- (int)outerLoopDim	// all loops outer to x
{
	int				i, n = (int)[dimensions count];
	int				len = 1;
	RecAxis			*ax;

	for (i = 0; i < n - 1; i++) {	// if (n < 2), inside is not executed
		ax = [dimensions objectAtIndex:i];
		len *= [ax dataLength];
	}
	return len;
}

- (int)nImages	// all loops outer to xy
{
	int				i, n = (int)[dimensions count];
	int				len = 1;
	RecAxis			*ax;

	for (i = 0; i < n - 2; i++) {	// if (n < 2), inside is not executed
		ax = [dimensions objectAtIndex:i];
		len *= [ax dataLength];
	}
	return len;
}

- (int)indexOfLoop:(RecLoop *)loop
{
    int     i, n = (int)[dimensions count];
    RecLoop *lp;

    for (i = 0; i < n; i++) {
        lp = [[dimensions objectAtIndex:i] loop];
        if ([lp isEqual:loop]) {
            break;
        }
    }
    if (i == n) i = -1; // not fould
	return i;
}

- (BOOL)containsLoop:(RecLoop *)loop
{
    int     i, n = (int)[dimensions count];
    BOOL    found = NO;
    RecLoop *lp;

    for (i = 0; i < n; i++) {
        lp = [[dimensions objectAtIndex:i] loop];
        if ([lp isEqual:loop]) {
            found = YES;
            break;
        }
    }
	return found;
}

- (BOOL)isPointImage
{
    return ([self dataLength] == 1);
}

// === convenience methods === 
- (RecLoopControl *)control
{
    return [RecLoopControl controlForImage:self];
}

- (RecLoopControl *)controlWithControl:(RecLoopControl *)control
{
    return [RecLoopControl controlWithControl:control forImage:self];
}

- (RecLoopControl *)outerLoopControl
{
    RecLoopControl  *lc = [self control];
    [lc deactivateInner];
    return lc;
}

- (RecLoopControl *)outerLoopControlForLoop:(RecLoop *)lp
{
    RecLoopControl  *lc = [self control];
    [lc deactivateLoop:lp];
    return lc;
}

- (RecImage *)xyCorrelationWith:(RecImage *)img
{
    return [self xyCorrelationWith:img width:0.3 triFilt:YES];
}

// phase correlation
// removed "takeRealPart" (3-21-2017)
- (RecImage *)xyCorrelationWith:(RecImage *)src width:(float)width triFilt:(BOOL)flt
{
	RecImage		*img1, *img2;			// complex
	int				xDim = [self xDim];
	int				yDim = [self yDim];

// chk dim
	if ((xDim != [src xDim]) || (yDim != [src yDim])) {
		NSLog(@"XYCorr: image dims are not equal");
		exit(0);
	}
// 2d FT
    img1 = [src copy];  [img1 makeComplex];
    img2 = [self copy]; [img2 makeComplex];

	if (flt) {
		[img1 fTriWin2D];
		[img2 fTriWin2D];
	}
    
	[img1 fft2d:REC_INVERSE];   // src
	[img2 fft2d:REC_INVERSE];   // dst

    [img1 conjugate];
    [img2 multByImage:img1];

    [img1 toUnitImage];
    [img2 toUnitImage];

// filter
    [img2 fGauss2DLP:width];

// 2d IFT
	[img2 fft2d:REC_FORWARD];
 //   [img2 takeRealPart];

    return img2;	// scale ??? max != 1.0 ###
}

// self, src are not altered
- (RecImage *)xCorrelationWith:(RecImage *)src width:(float)w triFilt:(BOOL)flt
{
	RecImage		*img1, *img2;			// complex
	int				xDim = [self xDim];
//	int				yDim = [self yDim];

// chk dim
	if ((xDim != [src xDim])) {
		NSLog(@"XYCorr: image dims are not equal");
		exit(0);
	}
// 1d FT
    img1 = [src copy];  [img1 makeComplex];
    img2 = [self copy]; [img2 makeComplex];
    
	if (flt) {
		[img1 fTriWin1DforLoop:[self xLoop] center:0.0 width:1.0];
		[img2 fTriWin1DforLoop:[self xLoop] center:0.0 width:1.0];
	}
    
	[img1 fft1d:[img1 xLoop] direction:REC_INVERSE];   // src
	[img2 fft1d:[img2 xLoop] direction:REC_INVERSE];   // dst

    [img1 conjugate];
    [img2 multByImage:img1];

    [img1 toUnitImage];
    [img2 toUnitImage];

// filter
    [img2 fGauss1DLP:w forLoop:[img2 xLoop]];

// 2d IFT
	[img2 fft1d:[img2 xLoop] direction:REC_FORWARD];
    [img2 takeRealPart];

    return img2;
}

- (RecImage *)yCorrelationWith:(RecImage *)src width:(float)w triFilt:(BOOL)flt
{
	RecImage		*img1, *img2;			// complex
	int				xDim = [self xDim];
	int				yDim = [self yDim];

// chk dim
	if ((xDim != [src xDim]) || (yDim != [src yDim])) {
		NSLog(@"XYCorr: image dims are not equal");
		exit(0);
	}
// 1d FT
    img1 = [src copy];  [img1 makeComplex];
    img2 = [self copy]; [img2 makeComplex];

	[img1 zeroFillToPo2:[img1 yLoop]];
	[img2 zeroFillToPo2:[img2 yLoop]];

	if (flt) {
		[img1 fTriWin1DforLoop:[self yLoop] center:0.0 width:1.0];
		[img2 fTriWin1DforLoop:[self yLoop] center:0.0 width:1.0];
	}
    
	[img1 fft1d:[img1 yLoop] direction:REC_INVERSE];   // src
	[img2 fft1d:[img2 yLoop] direction:REC_INVERSE];   // dst

    [img1 conjugate];
    [img2 multByImage:img1];

    [img1 toUnitImage];
    [img2 toUnitImage];

// filter
    [img2 fGauss1DLP:w forLoop:[img2 yLoop]];

// 2d IFT
	[img2 fft1d:[img2 yLoop] direction:REC_FORWARD];
    [img2 takeRealPart];

    return img2;
}

- (RecImage *)xyzCorrelationWith:(RecImage *)img
{
    return [self xyzCorrelationWith:img width:0.3 triFilt:YES];
}

- (float)noiseSigma
{										// thres = th * sigma
	float		*hist, *x;
	float		maxVal = [self maxVal];
	float		pk;
	int			i, n = 200;
	RecImage	*mask;

	mask = [self copy];
	[mask magnitude];

	// make hist
	hist = (float *)malloc(sizeof(float) * n);
	x    = (float *)malloc(sizeof(float) * n);
	[mask histogram:hist x:x min:0 max:maxVal/10 binSize:n filt:NO];
	hist[0] = 0;
	Rec_smooth(hist, n, 50);

	// find peak
	pk = 0;
	for (i = 1; i < n; i++) {
		if (pk < hist[i]) {
			pk = hist[i];
		} else {
			break;
		}
	}
	i--;	// peak position
	free(hist);
	free(x);

	return (float)i / n / 10;
}

- (void)thresAtSigma:(float)sg	// threshold at sg * signa of Reighley noise dist
{
	float	thres = [self noiseSigma] * sg;
	[self thresAt:thres];
}

- (RecImage *)makeMask					// automatic thresholding
{
	return [self makeMask:4.0];
}

- (RecImage *)makeMask:(float)th		// thresholding based on Reighley dist
{
	RecImage	*mask = [self copy];
	float		thres = [self noiseSigma] * th;

	[mask thresAt:thres];

	return mask;
}

// phase correlation
- (RecImage *)xyzCorrelationWith:(RecImage *)src width:(float)width triFilt:(BOOL)flt
{
	RecImage		*img1, *img2;			// complex
	int				xDim = [self xDim];
	int				yDim = [self yDim];
	int				zDim = [self zDim];
//    float           width = 0.3;

// chk dim
	if ((xDim != [src xDim]) || (yDim != [src yDim]) || zDim != [src zDim]) {
		NSLog(@"XYZCorr: image dims are not equal");
		exit(0);
	}

// 3d FT
    img1 = [src copy];  [img1 makeComplex];
    img2 = [self copy]; [img2 makeComplex];

// image tri filter
	if (flt) {
		[img1 fTriWin3D];
		[img2 fTriWin3D];
	}
    
	[img1 fft3d:REC_INVERSE];   // src
	[img2 fft3d:REC_INVERSE];   // dst
    [img1 toUnitImage];
    [img2 toUnitImage];

    [img1 setLoops:[img2 loops]];
    [img1 conjugate];
    [img2 multByImage:img1];
// freq filter (psf)
    [img2 fGauss3DLP:width];

// 3d IFT
	[img2 fft3d:REC_FORWARD];
    [img2 takeRealPart];

    return img2;
}

// old... replace with below
- (NSPoint)findPeak2D
{
    return Rec_find_peak2([self data], [self xDim], [self yDim]);
}

- (RecVector)findPeak3D
{
    return Rec_find_peak3([self data], [self xDim], [self yDim], [self zDim]);
}

// new... returns position & max value
// unit: pixels
- (NSPoint)findPeak2DwithMax:(float *)mx
{
    return Rec_find_peak2_mx([self data], [self xDim], [self yDim], mx);
}

- (NSPoint)findPeak2DwithPhase:(float *)phs
{
    return Rec_find_peak2_phs([self real], [self imag], [self xDim], [self yDim], phs);
}

- (RecVector)findPeak3DwithMax:(float *)mx
{
    return Rec_find_peak3_mx([self data], [self xDim], [self yDim], [self zDim], mx);
}

- (float)findEchoCenterForLoop:(RecLoop *)lp
{
	RecImage	*tmp;
	int			len;
	float		pk;

	tmp = [self avgToLoop:lp];
	[tmp magnitude];
	len = [lp dataLength];
	pk = Rec_find_peak([tmp data], 1, len);
	pk -= len / 2;

	return pk;
}

- (void)dilate2d
{
    void            (^proc)(float *p, int xDim, int yDim);
    __block float   *buf = (float *)malloc(sizeof(float) * [self xDim] * [self yDim]);

    proc = ^void(float *p, int xDim, int yDim) {
        int     i, j, ix;

        for (i = 0; i < xDim * yDim; i++) {
            buf[i] = p[i];
        }
        for (i = 1; i < yDim-1; i++) {
            for (j = 1; j < xDim-1; j++) {
                ix = i*xDim + j;
                if (buf[ix] == 0) continue;
                p[ix - 1] = 1;
                p[ix + 1] = 1;
                p[ix - xDim] = 1;
                p[ix + xDim] = 1;
            }
        }
    };
    [self apply2dProc:proc];
    free(buf);
}

- (void)erode2d
{
    void    (^proc)(float *p, int xDim, int yDim);
    __block float   *buf = (float *)malloc(sizeof(float) * [self xDim] * [self yDim]);

    proc = ^void(float *p, int xDim, int yDim) {
        int     i, j, ix;
        for (i = 0; i < xDim * yDim; i++) {
            buf[i] = p[i];
        }
        for (i = 1; i < yDim-1; i++) {
            for (j = 1; j < xDim-1; j++) {
                ix = i*xDim + j;
                if (buf[ix] == 1) continue;
                p[ix - 1] = 0;
                p[ix + 1] = 0;
                p[ix - xDim] = 0;
                p[ix + xDim] = 0;
            }
        }
    };
    [self apply2dProc:proc];
    free(buf);
}

// phase correlation version
// ----- plans -----
// - ref is not correct (phantom ok, chk with se_epi)
// * calc peak shape, and fit to model (gauss)
// ---- freq version ---
// * direct shift est from logP1 img (space version is better)


- (void)rotShift
{
    [self rotShiftWithRef:0];
}

- (void)rotShiftWithRef:(int)ix
{
    RecImage        *img, *pol, *ref, *corr, *param, *map;
    int             xDim, yDim;
    int             nTheta = 256;
    int             nRad = 32;
    int             dim;

    img = [self copy];

//	[img makeComplex];
    [img fft2d:REC_INVERSE];
    pol = [img toPolarWithNTheta:nTheta nRad:nRad rMin:1 logR:NO]; 
    xDim = [pol xDim];
    yDim = [pol yDim];
    dim = [pol dim];

    [pol magnitude];
    [pol logP1];
    ref = [pol sliceAtIndex:ix];
    corr = [pol xyCorrelationWith:ref];
    param = [corr estRot];
//[param dumpParam];

    map = [self mapForRotate:param];
    img = [RecImage imageWithImage:self];
    [img resample:self withMap:map];
//[img saveAsKOImage:@"../test_img/test9_image5.img"];

    ref = [img sliceAtIndex:ix];
    corr = [img xyCorrelationWith:ref];
    param = [corr estShift];
    img = [img ftShiftBy:param];
//[img saveAsKOImage:@"../test_img/test9_image9.img"];
    [self copyIvarOf:img];
}


// estimate rot / shift, then make combined map -> resample in 1 step with oversampling
- (RecImage *)rotShiftForEachOfLoop:(RecLoop *)lp scale:(float)scale
{
    RecImage        *img, *pol, *ref, *corr, *map;
    RecImage        *rotParam, *sftParam;
    int             xDim, yDim;
    int             nTheta = 256;
    int             nRad = 32;
    int             dim;

    if (lp == nil) {
        lp = [RecLoop pointLoop];
    }
    img = [self copy];

// === rotation ====
    [img fft2d:REC_INVERSE];
    pol = [img toPolarWithNTheta:nTheta nRad:nRad rMin:1 logR:NO]; 
    xDim = [pol xDim];
    yDim = [pol yDim];
    dim = [pol dim];

    [pol magnitude];
    [pol logP1];
    ref = [RecImage imageOfType:[pol type] withLoops:lp, [pol yLoop], [pol xLoop], nil];
    [ref copyImage:pol withControl:[ref control]];
    corr = [pol xyCorrelationWith:ref];
    rotParam = [corr estRot];
//[rotParam dumpParam];
    map = [self mapForRotate:rotParam];
    img = [RecImage imageWithImage:self];
    [img resample:self withMap:map];

// === translation ====
// create ref series
    ref = [RecImage imageOfType:[img type] withLoops:lp, [img yLoop], [img xLoop], nil];
    [ref copyImage:img withControl:[ref control]];
    corr = [img xyCorrelationWith:ref];
    sftParam = [corr estShift];
//[sftParam dumpParam];

    img = [self scaleXBy:scale andYBy:scale crop:NO];
    map = [img mapForRot:rotParam shift:sftParam];
//[map saveAsKOImage:@"rotShift_map.img"];
    [img resample:self withMap:map];

    return img;
}

- (RecImage *)estRot   // space domain version (better)
{
    RecImage        *img;
    NSArray         *outerLoops;
    RecLoopControl  *lc;
    RecLoopIndex    *yLi;
    float           *p, *q;
    float           th;
    int             i, len, nTheta, yDim;
    float           pos;

    lc = [self control];
    [lc rewind];
    [lc deactivateXY];
    outerLoops = [lc activeLoops];
    len = [lc loopLength];
    img = [RecImage imageOfType:RECIMAGE_REAL withLoopArray:outerLoops];
    nTheta = [self xDim];
    yDim = [self yDim];

    p = [img data];

    yLi = [lc loopIndexForLoop:[self yLoop]];
    [yLi setCurrent:yDim/2];
    for (i = 0; i < len; i++) {
        q = [self currentDataWithControl:lc];
        pos = Rec_find_peak(q, 1, nTheta);
        th = (pos - nTheta/2) * M_PI * 2 / nTheta;
        p[i] = -th;
        [lc increment];
    }

    return img;
}

// frequency domain version ... based on Ahn method
- (RecImage *)estRotFreq   // calc rotation angle from correlation (freq) image, and return warp param
{
    RecImage        *img;
    NSArray         *outerLoops;
    RecLoopControl  *lc;
    RecLoop         *xLoop;
    float           *p, *q;
    float           th;
    int             i, nSlc, nTheta, yDim;

    lc = [self control];
    [lc deactivateXY];
    outerLoops = [lc activeLoops];
    nSlc = [lc loopLength];
    img = [RecImage imageOfType:RECIMAGE_REAL withLoopArray:outerLoops];
    nTheta = [self xDim];
    yDim = [self yDim];

    p = [img data];

    xLoop = [self xLoop];
    [lc rewind];
    for (i = 0; i < nSlc; i++) {
        q = [self currentDataWithControl:lc];
        th = [self est1dForLoop:xLoop atSlice:q];
        p[i] = -th / nTheta;
        [lc increment];
    }
    return img;
}

- (RecImage *)estShift // calc linear shift from 2D correlation, and return warp param
{
    RecImage        *img;
    RecLoop         *xLp, *yLp;
    NSArray         *outerLoops;
    RecLoopControl  *lc;
    NSPoint         pos;
    float           *p, *q, *pp;
    int             i, len;
    int             xDim, yDim;

    lc = [self control];
    [lc rewind];
    [lc deactivateXY];

    outerLoops = [lc activeLoops];
    len = [lc loopLength];
    img = [RecImage imageOfType:RECIMAGE_MAP withLoopArray:outerLoops];

    xLp = [self xLoop];
    yLp = [self yLoop];
    xDim = [self xDim];
    yDim = [self yDim];

    p = [img data];
    q = p + [img dataLength];

    for (i = 0; i < len; i++) {
        pp = [self currentDataWithControl:lc];
        pos = Rec_find_peak2(pp, xDim, yDim);
        p[i] = pos.x / xDim;   // frac of FOV
        q[i] = pos.y / yDim;
        [lc increment];
    }

    return img;
}

// 1d version of above
- (RecImage *)estShift1d
{
    RecImage        *img;
    RecLoop         *xLp;
    NSArray         *outerLoops;
    RecLoopControl  *lc;
    NSPoint         pos;
    float           *p, *q, *pp;
    int             i, len;
    int             xDim, yDim;

    lc = [self control];
    [lc rewind];
    [lc deactivateX];

    outerLoops = [lc activeLoops];
    len = [lc loopLength];
    img = [RecImage imageOfType:RECIMAGE_MAP withLoopArray:outerLoops];

    xLp = [self xLoop];
    xDim = [self xDim];
	yDim = [self yDim];

    p = [img data];
    q = p + [img dataLength];

    for (i = 0; i < len; i++) {
        pp = [self currentDataWithControl:lc];
        pos = Rec_find_peak2(pp, xDim, yDim);
        p[i] = pos.x / xDim;   // frac of FOV
       [lc increment];
    }

    return img;
}

// low level
// ### not working yet
- (float)estRotWithImage:(RecImage *)img
{
	float		th, pos, *p;
	RecImage	*slc1, *slc2;
	RecImage	*pol1, *pol2;
	RecImage	*ref, *corr;
	int			nTheta = 256;
	int			nRad = 32;

	slc1 = [self copy];
	if ([slc1 dim] > 2) {
		slc1 = [slc1 avgForLoop:[slc1 zLoop]];	// self is preserved
	}
	slc2 = [img copy];
	if ([slc2 dim] > 2) {
		slc2 = [slc2 avgForLoop:[slc2 zLoop]];
	}

// === polar correlation ====
[slc1 fGauss2DLP:0.4];
[slc2 fGauss2DLP:0.4];
 [slc1 saveAsKOImage:@"IMG_win1"];
[slc2 saveAsKOImage:@"IMG_win2"];
   [slc1 fft2d:REC_INVERSE];
    [slc2 fft2d:REC_INVERSE];
[slc1 saveAsKOImage:@"IMG_ft1"];
[slc2 saveAsKOImage:@"IMG_ft2"];
    pol1 = [slc1 toPolarWithNTheta:nTheta nRad:nRad rMin:1 logR:NO]; 
    pol2 = [slc2 toPolarWithNTheta:nTheta nRad:nRad rMin:1 logR:NO]; 

    [pol1 magnitude];
    [pol1 logP1];
    [pol2 magnitude];
    [pol2 logP1];
[pol1 saveAsKOImage:@"IMG_pol1"];
[pol2 saveAsKOImage:@"IMG_pol2"];

    ref = [RecImage imageOfType:[pol1 type] withLoops:[pol1 yLoop], [pol1 xLoop], nil];
    [ref copyImage:pol1 withControl:[ref control]];
    corr = [pol2 xyCorrelationWith:ref];
	p = [corr data];

	pos = Rec_find_peak(p, 1, nTheta);
	th = (pos - nTheta/2) * M_PI * 2 / nTheta;

printf("th = %f\n", th);
//exit(0);

	return th;
}

- (void)rotXYBy:(float)th
{
	RecImage	*param, *map;
	float		*ang;
	int			i, zDim = [self zDim];

	param = [RecImage imageOfType:RECIMAGE_REAL xDim:[self zDim]];
	ang = [param data];
	for (i = 0; i < zDim; i++) {
		ang[i] = th;
	}
	map = [self mapForRotate:param];
//    img = [RecImage imageWithImage:self];
//    [img resample:self withMap:map];
}

- (NSPoint)estShift2dWithImage:(RecImage *)img
{
	NSPoint		sft;
	// not done yet

	return sft;
}

- (RecVector)estShift3dWithImage:(RecImage *)img
{
	RecVector	sft;
	// not done yet

	return sft;
}

- (void)trans
{
	[self swapLoop:[self xLoop] withLoop:[self yLoop]];
}

- (void)nopCrop
{
	RecLoop		*yLoop, *newYLoop;
	int			newYDim;

	yLoop = [self yLoop];
	newYDim = [yLoop dataLength] / 2;
	newYLoop = [RecLoop loopWithName:@"ky_NOP" dataLength:newYDim];

	[self replaceLoop:yLoop withLoop:newYLoop];
}

- (void)freqCrop
{
	RecLoop		*xLoop, *newXLoop;
	int			newXDim;

	xLoop = [self xLoop];
	newXDim = [xLoop dataLength] / 2;
	newXLoop = [RecLoop loopWithName:@"kx_NOF" dataLength:newXDim];

	[self replaceLoop:xLoop withLoop:newXLoop];
}

- (void)cropByFactor:(float)fct
{
	RecLoop		*lp, *newLp;
	int			newDim;

	lp = [self xLoop];
	newDim = [lp dataLength] / fct;
	newLp = [RecLoop loopWithName:@"kx_CROP" dataLength:newDim];
	[self replaceLoop:lp withLoop:newLp];

	lp = [self yLoop];
	newDim = [lp dataLength] / fct;
	newLp = [RecLoop loopWithName:@"ky_CROP" dataLength:newDim];
	[self replaceLoop:lp withLoop:newLp];
}

- (void)pFOV:(float)pf
{
	RecImage	*src, *map, *param;

	src = [self copy];
//	pf = 1.0/pf;		// inverse
	param = [RecImage pointImageOfType:RECIMAGE_MAP];
	[param setVal1:1.0 val2:1/pf];
	map = [self mapForScale:param];
	[self resample:src withMap:map];
}

// pre-processing for halfFT



// cuppen
- (void)halfFT:(RecLoop *)lp
{
	RecLoop         *newLp;
	int             dim, newDim;
	RecImage        *phs, *neg_phs, *raw;
	RecLoopControl	*lc;
	int				i;
    BOOL            hnex;
	int				st, len, hovr, ofs;

    dim = [lp dataLength];
	newDim = Rec_po2(dim);
    hovr = dim - newDim/2;
	newLp = [RecLoop loopWithDataLength:newDim];
    if ([lp isEqual:[self yLoop]]) {
        hnex = YES;
        ofs = 0;
    } else {
        hnex = NO;
        ofs = dim - newDim;
    }
	[self replaceLoop:lp withLoop:newLp offset:ofs];
	[self setUnit:REC_FREQ forLoop:newLp];

    phs = [RecImage imageWithImage:self];
	lc = [self control];
	st = newDim/2 - hovr;
	len = hovr*2;
	[lc setRange:NSMakeRange(st, len) forLoop:newLp];
	[phs copyImage:self withControl:lc];
	// ft and take phase
	[phs fft1d:newLp direction:REC_FORWARD];
	[phs toUnitImage];
	neg_phs = [phs copy];
	[neg_phs conjugate];

//=== iter loop ===
	raw = [self copy];	// initial
    if (hnex) {
		st = 0;
		len = newDim/2 + hovr;
    } else {
		st = newDim/2 - hovr;
		len = newDim/2 + hovr;
    }
	for (i = 0; i < 2; i++) {
		// ft data
		[self fft1d:newLp direction:REC_FORWARD]; // forward
		[self multByImage:neg_phs];
		[self conjugate];
		[self multByImage:phs];	// re-apply phase
		[self fft1d:newLp direction:REC_INVERSE]; //
		// merge
		[lc resetRange];
		[lc setRange:NSMakeRange(st, len) forLoop:newLp];
		[self copyImage:raw withControl:lc];
	}
    [self fft1d:newLp direction:REC_FORWARD];
}

// real only, remove low freq component
- (void)cosFilter:(RecLoop *)lp order:(int)order keepDC:(BOOL)dc
{
	int			i, j, n;
	RecImage	*kern;
	float		*coef;
	float		*low;
	float		*kn, th;
    void		(^proc)(float *p, int len, int skip);


	// make kernel
	n = [lp dataLength];
	kern = [RecImage imageOfType:RECIMAGE_REAL xDim:[lp dataLength] yDim:order];
    kn = [kern data];
    for (i = 0; i < order; i++) {
        for (j = 0; j < n; j++) {
            th = i * (j + 0.5) * M_PI / n;
            kn[i * n + j] = cos(th);
        }
    }
	coef = (float *)malloc(sizeof(float) * order);
	low = (float *)malloc(sizeof(float) * n);
    proc = ^void(float *p, int len, int skip) {
		int i, j;
		for (i = 0; i < order; i++) {
			coef[i] = 0;
			for (j = 0; j < len; j++) {
				coef[i] += p[j * skip] * kn[i * len + j];
			}
			if (i == 0) {
				if (dc) {
					coef[i] = 0;
				} else {
					coef[i] /= len;
				}
			} else {
				coef[i] /= len * 0.5;
			}
		}
		for (j = 0; j < len; j++) {
			low[j] = 0;
		}
		for (i = 0; i < order; i++) {
			for (j = 0; j < len; j++) {
				low[j] += coef[i] * kn[i * len + j];
			}
		}
		for (j = 0; j < len; j++) {
			p[j * skip] -= low[j];
		}
		
	};

//	for (j = 0; j < n; j++) {
//		printf("%d ", j);
//		for (i = 0; i < order; i++) {
//			printf("%f ", p[i * n + j]);
//		}
//		printf("\n");
//	}

	[self apply1dProc:proc forLoop:lp];

	free(coef);
	free(low);
}

- (void)xFlip
{
	RecLoop	*lp = [self xLoop];
	[self flipForLoop:lp];
}

- (void)yFlip
{
	RecLoop		*lp = [self yLoop];
	[self flipForLoop:lp];
}

// center = (N-1)/2
- (void)flipForLoop:(RecLoop *)lp
{
	int				i, k, n;
	int				len;
	int				skip;
	float			*p;
	RecLoopControl	*lc = [self outerLoopControlForLoop:lp];

	len = [lp dataLength];
	skip = [self skipSizeForLoop:lp];
	n = [lc loopLength];

	[lc rewind];
	for (i = 0; i < n; i++) {
		p = [self currentDataWithControl:lc];
		for (k = 0; k < pixSize; k++) {
			vDSP_vrvrs(p, skip, len);
			p += dataLength;
		}
		[lc increment];
	}
}

- (void)rotate:(int)code
{
//	clockwise
	switch (code) {
    case 0 :    // 0
    default :   // do nothing
        break;
	case 1 :	// 90
		[self trans];
		[self yFlip];
		break;
	case 2 :	// 180
		[self xFlip];
		[self yFlip];
		break;
	case 3 :	// 270
		[self trans];
		[self xFlip];
		break;
	}
}

// real / cpx sum (block version) ### doesn't work for complex ???
- (RecImage *)sumForLoop:(RecLoop *)lp
{
    void    (^proc)(float *q, float *p, int len, int skip);
  
    proc = ^void(float *q, float *p, int len, int skip) {
        vDSP_sve(p, skip, q, len);
    };
	return [self applyProjProc:proc forLoop:lp];
}

//- (RecImage *)applyComplexProjProc:(void (^)(float *dp, float *dq, float *sp, float *sq, int len, int skip))proc forLoop:(RecLoop *)lp;

// real / cpx
- (RecImage *)avgForLoop:(RecLoop *)lp
{
	RecImage		*img;
	int				n;
	float			fn;

	img = [self sumForLoop:lp];
	n = [lp dataLength];
	if (n == 0) return nil;
	fn = 1.0 / n;
	[img multByConst:fn];
	return img;
}

// real / cpx
- (RecImage *)avgToLoop:(RecLoop *)targetLp	// make 1D sum image
{
	RecImage	*avg;
	RecLoop		*lp;
	NSArray		*loops;
	int			i, n;

	loops = [self loops];
	n = (int)[loops count];
	avg = [self copy];
	for (i = n - 1; i >= 0; i--) {
		lp = [loops objectAtIndex:i];
		if ([lp isEqualTo:targetLp]) {
			continue;
		}
		avg = [avg avgForLoop:lp];
	}
	return avg;	
}

// real / cpx
- (RecImage *)sdForLoop:(RecLoop *)lp withMean:(RecImage *)m
{
	RecImage	*sd = [self varForLoop:lp withMean:m];
	[sd sqroot];
	return sd;
}

- (RecImage *)sdForLoop:(RecLoop *)lp	// central sd
{
	RecImage	*mn;
	mn = [self avgForLoop:lp];
	return [self sdForLoop:lp withMean:mn];
}

// real / complex
- (RecImage *)varForLoop:(RecLoop *)lp withMean:(RecImage *)m
{
	RecImage	*var;

	var = [self copy];
	[var subImage:m];
	[var square];				// ok for cpx
	var = [var avgForLoop:lp];

	return var;
}

- (RecImage *)varForLoop:(RecLoop *)lp	// central sd
{
	RecImage	*mn;
	mn = [self avgForLoop:lp];
	return [self varForLoop:lp withMean:mn];
}
/*
// block version ??? (above)
- (RecImage *)sdWithMean:(RecImage *)m forLoop:(RecLoop *)lp
{
	RecLoopControl		*srcLc, *dstLc;
	RecImage			*img;
	float				*p, *pm, mn;
	float				*pp;
	float				sum;
	int					i, j, k, loopLen;
	int					dstDataLength;
	int					nChan;
	int					skip, ix;

	srcLc = [self outerLoopControlForLoop:lp];	// [*ch z y x]
	img = [RecImage imageOfType:type withControl:srcLc];
	dstLc = [img control];						//    [z y x]
	srcLc = [self controlWithControl:dstLc];

	skip = [self skipSizeForLoop:lp];
	nChan = [lp dataLength];
	dstDataLength = [img dataLength];

	[dstLc rewind];
	loopLen = [dstLc loopLength];
	for (i = 0; i < loopLen; i++) {
		p = [self currentDataWithControl:srcLc];
		pp = [img currentDataWithControl:dstLc];
		pm = [m currentDataWithControl:dstLc];
		for (k = 0; k < pixSize; k++) {
			sum = 0;
			mn = *pm;
			for (j = 0, ix = 0; j < nChan; j++, ix += skip) {
				sum += (p[ix] - mn) * (p[ix] - mn);
			}
			*pp = sqrt(sum / nChan);
			p += dataLength;
			pp += dstDataLength;
			pm += dstDataLength;
		}
		[dstLc increment];
	}
	return img;
}
*/
- (RecImage *)maxForLoop:(RecLoop *)lp
{
    void    (^proc)(float *q, float *p, int len, int skip);
 
    proc = ^void(float *q, float *p, int len, int skip) {
        vDSP_maxv(p, skip, q, len);
    };
	return [self applyProjProc:proc forLoop:lp];
}

//  lp only: 13.329264 (sec)
//  lp + rd : 1.032277 (sec)
- (RecImage *)combineForLoop:(RecLoop *)lp
{
    RecImage    *img;
    void    (^proc)(float *qr, float *qi, float *pr, float *pi, int llen, int lskip, int rlen, int rskip);
 
    proc = ^void(float *qr, float *qi, float *pr, float *pi, int llen, int lskip, int rlen, int rskip) {
        int     i;
        float sumr, sumi;
        for (i = 0; i < rlen; i++) {
            vDSP_svesq(pr, lskip, &sumr, llen);
            vDSP_svesq(pi, lskip, &sumi, llen);
            *qr = sqrt(sumr + sumi);
            qr += rskip;
            pr += rskip;
            pi += rskip;
        }
    };
	img = [self applyCombineProc:proc forLoop:lp];
    [img takeRealPart];
    return img;
}

// 2.317437 (sec)
- (RecImage *)combineForLoop:(RecLoop *)lp withCoil:(int)coilID
{
    RecImage        *img;
    RecImage        *wt;
    RecCoilProfile  *cp;
    void    (^proc)(float *qr, float *qi, float *pr, float *pi, int llen, int lskip, int rlen, int rskip);

    proc = ^void(float *qr, float *qi, float *pr, float *pi, int llen, int lskip, int rlen, int rskip) {
        int     i;
        float sumr, sumi;
        for (i = 0; i < rlen; i++) {
            vDSP_svesq(pr, lskip, &sumr, llen);
            vDSP_svesq(pi, lskip, &sumi, llen);
            *qr = sqrt(sumr + sumi);
            qr += rskip;
            pr += rskip;
            pi += rskip;
        }
    };
	if (coilID == Coil_None) {
		return [self combineForLoop:lp];
	}
    cp = [RecCoilProfile profileForCoil:coilID];
    [cp initWithImage:self];
    wt = [cp weight];
//[wt saveAsKOImage:@"../test_img/test_coil_profie.img"];
    [self multByImage:wt];
//[self saveAsKOImage:@"../test_img/test_coil_wted.img"];
	img = [self applyCombineProc:proc forLoop:lp];
    [img takeRealPart];
    return img;
}

// new... 2.207595 (sec)
- (RecImage *)combinePWForLoop:(RecLoop *)lp withCoil:(int)coilID
{
    RecImage        *img;
    RecImage        *wt;
    RecCoilProfile  *cp;
    void    (^proc)(float *qr, float *qi, float *pr, float *pi, int llen, int lskip, int rlen, int rskip);

    proc = ^void(float *qr, float *qi, float *pr, float *pi, int llen, int lskip, int rlen, int rskip) {
        int     i;
        float sumr, sumi;
        for (i = 0; i < rlen; i++) {
            vDSP_svesq(pr, lskip, &sumr, llen);
            vDSP_svesq(pi, lskip, &sumi, llen);
            *qr = sqrt(sumr + sumi);
            qr += rskip;
            pr += rskip;
            pi += rskip;
        }
    };
    cp = [RecCoilProfile profileForCoil:coilID];
    [cp initWithPWImage:self];
    wt = [cp weight];
//[wt saveAsKOImage:@"../test_img/test_coil_profie.img"];
    [self multByImage:wt];
//[self saveAsKOImage:@"../test_img/test_coil_wted.img"];
	img = [self applyCombineProc:proc forLoop:lp];
    [img takeRealPart];
    return img;
}

//
- (RecImage *)complexCombineForLoop:(RecLoop *)lp              // mg2 weighted sum
{
    RecImage    *img;
    void    (^proc)(float *qr, float *qi, float *pr, float *pi, int llen, int lskip, int rlen, int rskip);
 
    proc = ^void(float *qr, float *qi, float *pr, float *pi, int llen, int lskip, int rlen, int rskip) {
        int     i, j, ix;
        float   sumr, sumi, mg, summg;
        for (i = 0; i < rlen; i++) {
            sumr = sumi = summg = 0;
            for (j = ix = 0; j < llen; j++, ix += lskip) {
                mg = pr[ix] * pr[ix] + pi[ix] * pi[ix];
                sumr += pr[ix] * mg;
                sumi += pi[ix] * mg;
                summg += mg;
            }
            *qr = sumr / summg;
            *qi = sumi / summg;

            qr += rskip;
            qi += rskip;
            pr += rskip;
            pi += rskip;
        }
    };
//    [self pcorr];
    [self pcorr3];
	img = [self applyCombineProc:proc forLoop:lp];
    return img;
}

//
- (RecImage *)complexCombineForLoop:(RecLoop *)lp withCoil:(int)coilID  // mg2 weighted sum
{
    RecImage        *img;
    RecImage        *wt;
    RecCoilProfile  *cp;
    void    (^proc)(float *qr, float *qi, float *pr, float *pi, int llen, int lskip, int rlen, int rskip);
 
    proc = ^void(float *qr, float *qi, float *pr, float *pi, int llen, int lskip, int rlen, int rskip) {
        int     i, j, ix;
        float   sumr, sumi, mg, summg;
        for (i = 0; i < rlen; i++) {
            sumr = sumi = summg = 0;
            for (j = ix = 0; j < llen; j++, ix += lskip) {
                mg = pr[ix] * pr[ix] + pi[ix] * pi[ix];
                sumr += pr[ix] * mg;
                sumi += pi[ix] * mg;
                summg += mg;
            }
            if (summg != 0) {
                *qr = sumr / summg;
                *qi = sumi / summg;
            } else {
                *qr = 0;
                *qi = 0;
            }

            qr += rskip;
            qi += rskip;
            pr += rskip;
            pi += rskip;
        }
    };
    cp = [RecCoilProfile profileForCoil:coilID];
    [cp initWithImage:self];
    wt = [cp weight];
    [self multByImage:wt];
    [self pcorr];
	img = [self applyCombineProc:proc forLoop:lp];
    return img;
}

- (RecImage *)complexCombineForLoopX:(RecLoop *)ch withCoil:(int)coilID    // complex-weighted-sum
{
	RecLoop				*xLoop;
	RecLoopControl		*srcLc, *dstLc;
	RecImage			*img;
	float				*p, *q;
	float				*pp, *qq;
	float				wt = 1.0;
    float               *wt_sum;
	int					i, j, k, len, nImg;
	int					nChan;
	int					skip, ix;
    int                 dstDataLength;
	RecLoopIndex		*yLi, *zLi;
	float				xPos, yPos, zPos;
//	RecCoilProfile		*cp = [RecCoilProfile profileForCoil:coilID];

	xLoop = [self xLoop];
	len = [xLoop dataLength];
	wt_sum = (float *)malloc(len * sizeof(float));

	srcLc = [self outerLoopControlForLoop:ch];	// [*ch z y x]
	img = [RecImage imageOfType:RECIMAGE_COMPLEX withControl:srcLc];		//     [z y x]
    dstDataLength = [img dataLength];
	dstLc = [img outerLoopControl];				//    [z y *x]
	srcLc = [RecLoopControl controlWithControl:dstLc forImage:self];	// [ch z y *x]
	skip = [self skipSizeForLoop:ch];
	nChan = [ch dataLength];

	zLi = [dstLc loopIndexAtIndex:0];
	yLi = [dstLc loopIndexAtIndex:1];

	[dstLc rewind];
	nImg = [dstLc loopLength];
	for (i = 0; i < nImg; i++) {
		p = [self currentDataWithControl:srcLc];
		q = p + dataLength;
		pp = [img currentDataWithControl:dstLc];
        qq = pp + dstDataLength;
		yPos = (float)[yLi current] / [yLi dataLength];
		zPos = (float)[zLi current] / [zLi dataLength];
		for (j = 0; j < len; j++) {
			pp[j] = 0;
            wt_sum[j] = 0;
			xPos = (float)j / len;
			for (k = 0, ix = j; k < nChan; k++, ix += skip) {
			//	wt = [cp weightForCh:k X:xPos Y:yPos Z:zPos];	// ## bottle neck here: rewrite CoilProfile
                                                                // make weight separable to x, y, z
				pp[j] += p[ix] * wt;
                qq[j] += q[ix] * wt;
                wt_sum[j] += wt;
			}
		}
        if (0) {
            for (j = 0; j < len; j++) {
                if (wt_sum[j] != 0) {
                    pp[j] /= wt_sum[j];
                }
            }
        }
		[dstLc increment];
	}
	free(wt_sum);
	return img;
}

// defined in RecImage (PW) (real version)
// add this to PW version
/*
- (void)normalizeForLoop:(RecLoop *)lp
{
	RecLoopControl	*lc;
	int				loopLen;
	int				i, j, ix, len, skip;
	float			mg, *p, *q;

	lc = [self control];
	[lc removeLoop:lp];
	loopLen = [lc loopLength];
	len = [lp dataLength];
	skip = [self skipSizeForLoop:lp];

	[lc rewind];
	for (i = 0; i < loopLen; i++) {
		mg = 0;
		p = [self currentDataWithControl:lc];
		q = p + [self dataLength];
		for (j = ix = 0; j < len; j++, ix += skip) {
			mg += p[ix]*p[ix] + q[ix]*q[ix];
		}
		if (mg != 0) {
			mg = 1.0 / sqrt(mg);
			for (j = ix = 0; j < len; j++, ix += skip) {
				p[ix] *= mg;
				q[ix] *= mg;
			}
		}
		[lc increment];
	}
}
*/

// L1 ### remove block (chk apply1dProc)
- (void)normalizeForLoop:(RecLoop *)lp
{
    void		(^proc)(float *p, int len, int skip);
    void		(^cproc)(float *p, float *q, int len, int skip);

	if ([self type] == RECIMAGE_COMPLEX) {
		cproc = ^void(float *p, float *q, int len, int skip) {
			int     i, ix;
			float	mx, mg;

			mx = 0;
			for (i = ix = 0; i < len; i++, ix += skip) {
				mg = p[ix]*p[ix] + q[ix]*q[ix];
				if (mg > mx) {
					mx = mg;
				}
			}
			mx = 1.0 / sqrt(mg);
			for (i = ix = 0; i < len; i++, ix += skip) {
				p[ix] *= mx;
			}
		};
		[self applyComplex1dProc:cproc forLoop:lp];
	} else {
		proc = ^void(float *p, int len, int skip) {
			int     i, ix;
			float	mx;

			mx = 0;
			for (i = ix = 0; i < len; i++, ix += skip) {
				if (p[ix] > mx) {
					mx = p[ix];
				}
			}
			for (i = ix = 0; i < len; i++, ix += skip) {
				p[ix] /= mx;
			}
		};
		[self apply1dProc:proc forLoop:lp];
	}
}

// L2 (move to RecKit)
- (void)normalize2ForLoop:(RecLoop *)lp
{
	RecLoopControl	*lc;
	float			*p, *q, mg;
	int				i, k, ix;
	int				skip, len, loopLen;

	lc = [self control];
	[lc deactivateLoop:lp];
	loopLen = [lc loopLength];
	len = [lp dataLength];
	skip = [self skipSizeForLoop:lp];

	if ([self type] == RECIMAGE_COMPLEX) {
		for (k = 0; k < loopLen; k++) {
			mg = 0;
			p = [self currentDataWithControl:lc];
			q = p + [self dataLength];
			for (i = ix = 0; i < len; i++, ix += skip) {
				mg += p[ix]*p[ix] + q[ix]*q[ix];
			}
			if (mg != 0) {
				mg = 1.0 / sqrt(mg);
				for (i = ix = 0; i < len; i++, ix += skip) {
					p[ix] *= mg;
					q[ix] *= mg;
				}
			}
			[lc increment];
		}
	} else {
		for (k = 0; k < loopLen; k++) {
			mg = 0;
			p = [self currentDataWithControl:lc];
			for (i = ix = 0; i < len; i++, ix += skip) {
				mg += p[ix]*p[ix];
			}
			if (mg != 0) {
				mg = 1.0 / sqrt(mg);
				for (i = ix = 0; i < len; i++, ix += skip) {
					p[ix] *= mg;
				}
			}
			[lc increment];
		}
	}
}

void
err_proj(RecImage *proj, RecImage *im1, RecImage *im2, RecLoop *lp)
{
	RecLoopControl	*lc;
	int				i, j, n, len;
	int				ix, skip;
	float			*p0, *q0;
	float			*p1, *p2;
	float			*q1, *q2;
	float			mg1, mg2, pr, pi;

	lc = [im1 control];
	[lc deactivateLoop:lp];
	n = [lc loopLength];
	len = [lp dataLength];
	skip = [im1 skipSizeForLoop:lp];
	p0 = [proj real];
	q0 = [proj imag];
	for (i = 0; i < n; i++) {
		p1 = [im1 currentDataWithControl:lc];
		q1 = p1 + [im1 dataLength];
		p2 = [im2 currentDataWithControl:lc];
		q2 = p2 + [im2 dataLength];

		mg1 = mg2 = 0;
		pr = pi = 0;
		for (j = ix = 0; j < len; j++, ix += skip) {
			mg1 += p1[ix]*p1[ix] + q1[ix]*q1[ix];
			mg2 += p2[ix]*p2[ix] + q2[ix]*q2[ix];
			pr  += p1[ix]*p2[ix] + q1[ix]*q2[ix];
			pi  += p2[ix]*q1[ix] - p1[ix]*q2[ix];
		}
		mg1 = sqrt(mg1);
		mg2 = sqrt(mg2);
		p0[i] = pr/mg1/mg2;
		q0[i] = pi/mg1/mg2;
		[lc increment];
	}
}

// === coil profile estimation
- (RecImage *)coilProfile2DForLoop:(RecLoop *)ch
{
	RecLoop		*lp;
	NSArray		*loops;
	int			i, n;

	RecImage	*y, *yy, *s, *ss, *m, *err, *pr;
	float		w = 0.05, gain = 0.5, en;
	int			iter;

	// avg for outer loops (except for ch)
	loops = [self loops];
	n = [self dim] - 2;	// exclude x-y
	y = [self copy];
	if (n < 0) return nil;
	for (i = 0; i < n; i++) {
		lp = [loops objectAtIndex:i];
		if (lp != ch) {
			y = [y avgForLoop:lp];
		}
	}

	// == (1) initial est (S-o-S)
	m = [y copy];
	m = [y combineForLoop:ch];
	pr = [RecImage imageOfType:RECIMAGE_COMPLEX withImage:m];

	s = [y copy];
	[s divImage:m];	// raw profile

	// == (2) LPF / normalize
	[s gauss2DLP:w];
	[s normalize2ForLoop:ch];

	for (iter = 1; iter < 20; iter++) {
		// == (3) update data consistency
		ss = [s copy];
		[ss conjugate];
		yy = [y copy];
		[yy multByImage:ss];
		m = [yy sumForLoop:ch];

		// === project to coil image
		yy = [s copy];
		[yy multByImage:m];
		err = [yy copy];
		[err subImage:y];
		
		// calc error energy
		en = [err rmsVal];
	//	printf("%d %f\n", iter, en);
		[err multByImage:yy];

		err_proj(pr, yy, err, ch);	// expand this ###
		[pr multByConst:gain];

	// === update coil profile
		int ver = 3;
		switch (ver) {
		case 1:	// ver 1	(prof error correction)
			[err cpxDivImage:m];
			[s subImage:err];
			break;
		case 2:	// ver 2 (bi-directional projection, equivalent to 1)
			// update profile
			s = [y copy];
			[s cpxDivImage:m];
			break;
		case 3: // ver 3 (feedback err/coil correlation to m)
			[m addImage:pr];
			s = [y copy];
			[s cpxDivImage:m];
			break;
		}
		[s gauss2DLP:w];
		[s normalize2ForLoop:ch];
	}
//	[m saveAsKOImage:@"IMG_final"];
	[s conjugate];
//	[s saveAsKOImage:@"IMG_prof_final"];
	
//	y = [self copy];
//	[y multByImage:s];
//	y = [y sumForLoop:ch];
//	[y saveAsKOImage:@"IMG_comb_final"];

//exit(0);
	return s;
}

- (RecImage *)coilProfile3DForLoop:(RecLoop *)ch
{
	// ###
}

- (RecImage *)combineForLoop:(RecLoop *)ch withProfile:(RecImage *)prof
{
	RecImage	*img = [self copy];

	[img multByImage:prof];
	img = [img sumForLoop:ch];
	return img;
}

// maximum intensity projection
// block version
- (RecImage *)mipForLoop:(RecLoop *)lp
{
    void    (^proc)(float *q, float *p, int len, int skip);
 
    proc = ^void(float *q, float *p, int len, int skip) {
        int     j, ix;
        float   mx;
        mx = 0;
        for (j = 0, ix = 0; j < len; j++, ix += skip) {
            if (mx < p[ix]) mx = p[ix];
        }
        *q = mx;
    };
	return [self applyProjProc:proc forLoop:lp];
}

- (RecImage *)mnpForLoop:(RecLoop *)lp
{
    void    (^proc)(float *q, float *p, int len, int skip);
 
    proc = ^void(float *q, float *p, int len, int skip) {
        int     j, ix;
        float   mn;
        mn = p[0];
        for (j = 0, ix = 0; j < len; j++, ix += skip) {
            if (mn > p[ix]) mn = p[ix];
        }
        *q = mn;
    };
	return [self applyProjProc:proc forLoop:lp];
}

- (RecImage *)maxIndexForLoop:(RecLoop *)lp		// position of maximum intensity pixel in lp
{
    void    (^proc)(float *q, float *p, int len, int skip);
 
    proc = ^void(float *q, float *p, int len, int skip) {
        int     j, ix, mix;
        float   mx;
        mx = p[0];
		mix = 0;
        for (j = 0, ix = 0; j < len; j++, ix += skip) {
            if (mx < p[ix]) {
				mx = p[ix];
				mix = j;
			}
        }
        *q = mix;
    };
	return [self applyProjProc:proc forLoop:lp];
}

- (RecImage *)peakIndexForLoop:(RecLoop *)lp;		// for step-shift correction ... take first peak
{
    void    (^proc)(float *q, float *p, int len, int skip);
 
    proc = ^void(float *q, float *p, int len, int skip) {
        int     j, ix, mix;
        float   mx, prev;
		BOOL	found = NO;

        mx = prev = p[0];
		mix = 0;
        for (j = 0, ix = 0; j < len; j++, ix += skip) {
            if (mx < p[ix]) {
				mx = p[ix];
				mix = j;
				found = YES;
			}
			if (found && p[ix] < prev) break;
			prev = p[ix];
        }
        *q = mix;
    };
	return [self applyProjProc:proc forLoop:lp];
}
- (RecImage *)projectToBasis:(float *)b forLoop:(RecLoop *)lp // extract component of basis
{
    void    (^proc)(float *q, float *p, int len, int skip);
 
    proc = ^void(float *q, float *p, int len, int skip) {
        int     j, ix;
        float	a = 0;
        for (j = 0, ix = 0; j < len; j++, ix += skip) {
            a += p[ix] * b[j];
        }
        *q = a;
    };
	return [self applyProjProc:proc forLoop:lp];
}
- (RecImage *)partialMipForLoop:(RecLoop *)lp depth:(int)dp
{
	RecLoopControl		*srcLc, *dstLc;
	RecLoop				*newLp;
	int					newDim;
	RecImage			*img;
	float				*p;
	float				*pp;
	float				mx;
	int					i, j, loopLen;
	int					ii, jj, ix;
	int					dstDataLength;
	int					len, srcSkip, dstSkip;
	BOOL				found = NO;

	newDim = [lp dataLength] - dp;
	newLp = [RecLoop loopWithDataLength:newDim];
	srcLc = [self outerLoopControlForLoop:lp];
	dstLc = [self controlWithControl:srcLc];
	[dstLc replaceLoop:lp withLoop:newLp];
	img = [RecImage imageOfType:type withControl:dstLc];
	[img clear];
	[dstLc deactivateLoop:newLp];

	srcSkip = [self skipSizeForLoop:lp];
	dstSkip = [img skipSizeForLoop:newLp];
	len = [newLp dataLength]; // src len = len + dp
	dstDataLength = [img dataLength];

	[dstLc rewind];
	loopLen = [dstLc loopLength];

	for (i = 0; i < loopLen; i++) {
		p = [self currentDataWithControl:srcLc];
		pp = [img currentDataWithControl:dstLc];
        for (j = 0; j < pixSize; j++) {
        // actual proc along lp
			for (ii = 0; ii < len; ii++) {
				// sequential/fast version	(5.48 vs. 7.89sec)
				found = NO;
				if (ii > 0) {
					if (p[(ii - 1) * srcSkip] != mx && p[(ii + dp - 1) * srcSkip] < mx) {
						found = YES;
					}
				}
				if (!found) {
					mx = 0;
					for (jj = 0; jj < dp; jj++) {
						ix = (ii + jj) * srcSkip;
						if (p[ix] > mx) mx = p[ix];
					}
				}
				pp[ii * dstSkip] = mx;
			}
            p += dataLength;
            pp += dstDataLength;
        }
		[dstLc increment];
	}
	return img;
}

- (RecImage *)tip:(int)dpth forLoop:(RecLoop *)lp  // top intensity projection
{
    void            (^proc)(float *q, float *p, int len, int skip);
    __block float   *top;
    RecImage        *img;

    top = (float *)malloc(sizeof(float) * dpth);
 
    proc = ^void(float *q, float *p, int len, int skip) {
        int     j, jj, ix;
        float   minp, pix;
        int     minix;

			for (jj = 0; jj < dpth; jj++) {
                top[jj] = 0;
            }
            minp = 0.0;
            minix = 0;
			for (j = 0, ix = 0; j < len; j++, ix += skip) {
                pix = p[ix];
                // if pix value is less than current top values, continue
                if (pix <= minp) continue;
                // else update top list
                top[minix] = pix;
                minp = top[0];
                minix = 0;
                for (jj = 1; jj < dpth; jj++) {
                    if (top[jj] < minp) {
                        minp = top[jj];
                        minix = jj;
                        if (minp == 0) break;
                    }
                }
            }
            // sum of top values
            pix = 0;
            for (jj = 0; jj < dpth; jj++) {
                pix += top[jj];
            }
			*q = pix / dpth;
    };
	img = [self applyProjProc:proc forLoop:lp];
    free(top);
    return img;
}

// DSP version is slower than this
- (void)toUnitImage
{
	float	re, im, mg;
	int		i;
	float	*p, *q;

	if (type != RECIMAGE_COMPLEX) return;

	p = [self data];
	q = p + dataLength;

	for (i = 0; i < dataLength; i++) {
		re = p[i];
		im = q[i];
		mg = sqrt(re * re + im * im);
		if (mg != 0) {
			re /= mg;
			im /= mg;
		} else {
			re = 1.0;
			im = 0.0;
		}
		p[i] = re;
		q[i] = im;
	}
}

- (void)thToExp			// exp(i th)
{
	float	*p, *q;
	float	th;
	int		i, len;

	[self makeComplex];
	len = [self dataLength];
	p = [self real];
	q = [self imag];
	for (i = 0; i < len; i++) {
		th = p[i];
		p[i] = cos(th);
		q[i] = sin(th);
	}
}

- (void)thToSin
{
	float	*p;
	float	th;
	int		i, len;

	len = [self dataLength];
	p = [self data];
	for (i = 0; i < len; i++) {
		th = p[i];
		p[i] = sin(th);
	}
}

- (void)thToCos
{
	float	*p;
	float	th;
	int		i, len;

	len = [self dataLength];
	p = [self data];
	for (i = 0; i < len; i++) {
		th = p[i];
		p[i] = cos(th);
	}
}

- (void)atan2
{
	float	*p, *q;
	int		i, n = [self dataLength];

	p = [self real];
	q = [self imag];
	for (i = 0; i < n; i++) {
		p[i] = atan2(q[i], p[i]);
	}
	[self takeRealPart];
}

- (void)atan2:(RecImage *)im
{
	float	*p, *q;
	int		i, n = [self dataLength];

	p = [self data];
	q = [im data];
	for (i = 0; i < n; i++) {
		p[i] = atan2(q[i], p[i]);
	}
}

- (void)sigmoid:(float)a	// 1 / (1 + exp(-ax))
{
	float	*p;
	float	x;
	int		i, len;

	len = [self dataLength];
	p = [self data];
	for (i = 0; i < len; i++) {
		x = p[i];
		p[i] = 1 / (1 + exp(-a * x));
	}
}

- (float)est0
{
	float		*p = [self real];
	float		*q = [self imag];
	int			n = [self dataLength];
	return Rec_est_0th(p, q, 1, n);
}

float   Rec_est_0th(float *re, float *im, int skip, int len);
void    Rec_corr0th(float *re, float *im, int skip, int len, float p0);	// const p0

// global corr with single phase number
- (void)pcorr0
{
	float	*p = [self real];
	float	*q = [self imag];
	int		n = [self dataLength];
	float	a0 = Rec_est_0th(p, q, 1, n);
	Rec_corr0th(p, q, 1, n, a0);
}

- (void)pcorr0EachSlice            // 0th
{
    void    (^proc)(float *p, float *q, int xDim, int yDim);
    proc = ^void(float *p, float *q, int xDim, int yDim) {
        float       p0;
        p0 = Rec_est_0th(p, q, 1, xDim * yDim);
        Rec_corr0th(p, q, 1, xDim * yDim, p0);
    };
    [self applyComplex2dProc:proc];
}

- (float)est1dForLoop:(RecLoop *)lp
{
	float	*p = [self data];
	return [self est1dForLoop:lp atSlice:p];
}

- (float)est1dForLoop:(RecLoop *)lp atSlice:(float *)slc
{
    float   *p, *q;
    int     i, lpSkip, lnSkip, len, nLp;
    int     xDim = [self xDim];
    int     yDim = [self yDim];
    float   ph = 0;
 
    p = slc;
    q = p + dataLength;
    len = [lp dataLength];
    if ([lp isEqualTo:[self xLoop]]) {
        lpSkip = 1;
        lnSkip = xDim;
        nLp = yDim;
    } else {
        lpSkip = xDim;
        lnSkip = 1;
        nLp = xDim;
    }
    for (i = 0; i < nLp; i++) {
        ph += Rec_est_1st(p, q, lpSkip, len);
        p += lnSkip;
        q += lnSkip;
    }
    return ph / nLp;
}

// ### global 1D phase corr (### not correct yet)
- (void)pcorr1dForLoop:(RecLoop *)lp
{
	float			a1;		// global
	float			*p, *q;
	float			sumr, sumi;
	RecLoopControl	*lc;
	int				i, n, loopLen;
	int				skip;

	lc = [self control];
	[lc deactivateLoop:lp];
	loopLen = [lc loopLength];
	n = [lp dataLength];
	skip = [self skipSizeForLoop:lp];

	sumr = sumi = 0;
	for (i = 0; i < loopLen; i++) {
		p = [self currentDataWithControl:lc];
		q = p + [self dataLength];
		Rec_est_correl(p, q, skip, n, &sumr, &sumi);
		[lc increment];
	}
	sumr /= loopLen * n;
	sumi /= loopLen * n;
	a1 = atan2(sumi, sumr);
	for (i = 0; i < loopLen; i++) {
		p = [self currentDataWithControl:lc];
		q = p + [self dataLength];
		Rec_corr1st(p, q, skip, n, a1);
		[lc increment];
	}
}

// ok
- (void)pcorrForLoop:(RecLoop *)lp
{
    void    (^proc)(float *p, float *q, int skip, int len);
 
    proc = ^void(float *p, float *q, int skip, int len) {
        float   ph;
        // lp
        ph = Rec_est_1st(p, q, skip, len);
        Rec_corr1st(p, q, skip, len, ph);
        // 0th
        ph = Rec_est_0th(p, q, skip, len);
        Rec_corr0th(p, q, skip, len, ph);
    };

    [self applyComplex1dProc:proc forLoop:lp control:[self control]];
}

// ## not tested yet
- (void)pcorr2
{
    [self pcorr1dForLoop:[self xLoop]];
    [self pcorr1dForLoop:[self yLoop]];
    [self pcorr0];
}

// ## not tested yet
- (void)pcorr3
{
    [self pcorrForLoop:[self xLoop]];
    [self pcorrForLoop:[self yLoop]];
    [self pcorrForLoop:[self zLoop]];
	[self pcorr0];
}

- (void)pcorr
{
    void    (^proc)(float *p, float *q, int xDim, int yDim);
    proc = ^void(float *p, float *q, int xDim, int yDim) {
        float       p0, p1;
        float       *pp, *qq;
        float       sumr, sumi;
        RecLoop     *lp;
        int         i, skip, len;
        // x
        sumr = sumi = 0;
        lp = [self xLoop];
        skip = [self skipSizeForLoop:lp];
        len = [lp dataLength];
        for (i = 0; i < yDim; i++) {
            pp = p + i * xDim;
            qq = pp + dataLength;
            Rec_est_correl(pp, qq, skip, len, &sumr, &sumi);
        }
        p1 = atan2(sumi, sumr) * len;
        for (i = 0; i < yDim; i++) {
            pp = p + i * xDim;
            qq = pp + dataLength;
            Rec_corr1st(pp, qq, skip, len, p1);
        }
        // y
        sumr = sumi = 0;
        lp = [self yLoop];
        skip = [self skipSizeForLoop:lp];
        len = [lp dataLength];
        for (i = 0; i < xDim; i++) {
            pp = p + i;
            qq = pp + dataLength;
            Rec_est_correl(pp, qq, skip, len, &sumr, &sumi);
        }
        p1 = atan2(sumi, sumr) * len;
         for (i = 0; i < xDim; i++) {
            pp = p + i;
            qq = pp + dataLength;
            Rec_corr1st(pp, qq, skip, len, p1);
        }
        // 0th
        p0 = Rec_est_0th(p, q, 1, xDim * yDim);
        Rec_corr0th(p, q, 1, xDim * yDim, p0);
    };
    [self applyComplex2dProc:proc];
}

- (void)pcorrFine
{
    void    (^proc)(float *p, float *q, int xDim, int yDim);
    proc = ^void(float *p, float *q, int xDim, int yDim) {
        Rec_pcorr_fine(p, q, xDim, yDim);
    };
    [self applyComplex2dProc:proc];
}

// outer loop size of self and coef should match
- (void)pestPoly1dForLoop:(RecLoop *)lp coef:(RecImage *)coef
{
	void			(^proc)(float *p, float *q, int skip, int len);
	int				order = [coef xDim];
	RecLoopControl	*lc_coef, *lc_self;

	lc_self = [self control];
	lc_coef = [coef controlWithControl:lc_self];

    proc = ^void(float *p, float *q, int skip, int len) {
		float *cp = [coef currentDataWithControl:lc_coef];
		Rec_est_poly_1d(cp, order, p, q, skip, len);
    };
    [self applyComplex1dProc:proc forLoop:lp control:lc_self];
}

// usually outer loop size of self is larger
- (void)pcorrPoly1dForLoop:(RecLoop *)lp coef:(RecImage *)coef
{
	void			(^proc)(float *p, float *q, int skip, int len);
	int				order = [coef xDim];
	RecLoopControl	*lc_coef, *lc_self;

	lc_self = [self control];
	lc_coef = [coef controlWithControl:lc_self];
    proc = ^void(float *p, float *q, int skip, int len) {
		float *cp = [coef currentDataWithControl:lc_coef];
		Rec_corr_poly_1d(cp, order, p, q, skip, len);
    };
    [self applyComplex1dProc:proc forLoop:lp control:lc_self];
}

// 1D correction need to be symmetric (orthogonal to 0th)
- (void)pcorr2dx:(float)a1x y:(float)a1y phs:(float)a0
{
    void    (^proc)(float *p, float *q, int xDim, int yDim);

    proc = ^void(float *p, float *q, int xDim, int yDim) {
		int		i, j, ix;
		float	th, re, im, cs, sn;
		
		for (i = 0; i < yDim; i++) {
			for (j = 0; j < xDim; j++) {
				ix = i * xDim + j;
			//	th = ((float)i - yDim/2) / yDim * a1y + ((float)j - xDim/2) / xDim * a1x + a0;
				th = (i - (float)(yDim - 1)/2.0) / yDim * a1y + (j - (float)(xDim - 1)/2.0) / xDim * a1x + a0;
				cs = cos(th);
				sn = sin(th);
				re = p[ix] * cs + q[ix] * sn;
				im = -p[ix] * sn + q[ix] * cs;
				p[ix] = re;
				q[ix] = im;
			}
		}
    };
    [self applyComplex2dProc:proc];
}

// seems to be working, but slow
// 2D polynomial phase correction // ### not done yet (1d unwrap)
// ... coef changed to 2D (4/28) ... should be ok ...
// ### moved to nciRec.m (tmp)
/*
- (void)pestPoly2d:(RecImage *)coef
{
	void			(^proc)(float *p, float *q, int xDim, int yDim);
	int				ordx, ordy;
	int				xDim, yDim;
	RecLoopControl	*lc_coef, *lc_self;

	ordx = [coef xDim];
	ordy = [coef yDim];

	lc_self = [self control];
	lc_coef = [coef controlWithControl:lc_self];

//[lc_self dumpLoops];
//[lc_coef dumpLoops];
//exit(0);
	xDim = [self xDim];
	yDim = [self yDim];

// image method version

    proc = ^void(float *p, float *q, int xDim, int yDim) {
		float *cp = [coef currentDataWithControl:lc_coef];
		Rec_est_poly_2d(cp, ordx, ordy, p, q, xDim, xDim);	// ### not done yet

//		printf("cp = %lx, p = %lx\n", cp, p);
if (0) {
	int i;
	for (i = 0; i < ordx * ordy; i++) {
		printf("%f ", cp[i]);
	}
	printf("\n");
}

    };
    [self applyComplex2dProc:proc control:lc_self];
}
*/

// ok
- (void)pcorrPoly2d:(RecImage *)coef
{
	void			(^proc)(float *p, float *q, int xDim, int yDim);
	int				ordx, ordy;
	RecLoopControl	*lc_coef, *lc_self;

	ordx = [coef xDim];
	ordy = [coef yDim];

	lc_self = [self control];
	lc_coef = [coef controlWithControl:lc_self];
    proc = ^void(float *p, float *q, int xDim, int yDim) {
		float *cp = [coef currentDataWithControl:lc_coef];
		Rec_corr_poly_2d(cp, ordx, ordy, p, q, xDim, xDim);
    };
    [self applyComplex2dProc:proc control:lc_self];
}

// simple version: uses phsae smoothing
- (void)epiPcorr
{
    void            (^proc)(float *p, float *q, int xDim, int yDim);
    int             xDim, yDim;

    proc = ^void(float *p, float *q, int xDim, int yDim) {
  //      Rec_epi_pcorr(p, q, xDim, yDim, YES);
        Rec_epi_pcorr(p, q, xDim, yDim, YES);
    };

    xDim = [self xDim];
    yDim = [self yDim];

// init cos tab
    Rec_epi_pcorr(NULL, NULL, xDim, yDim, YES);

    [self applyComplex2dProc:proc]; // main proc

// dealloc cos tab
    Rec_epi_pcorr((float *)1, (float *)1, 0, 0, YES);
}


- (void)epiPcorrGE
{
    void            (^proc)(float *p, float *q, int xDim, int yDim);
    int             xDim, yDim;

    proc = ^void(float *p, float *q, int xDim, int yDim) {
  //      Rec_epi_pcorr(p, q, xDim, yDim, YES);
        Rec_epi_pcorr(p, q, xDim, yDim, NO);
    };

    xDim = [self xDim];
    yDim = [self yDim];

// init cos tab
    Rec_epi_pcorr(NULL, NULL, xDim, yDim, YES);

    [self applyComplex2dProc:proc]; // main proc

// dealloc cos tab
    Rec_epi_pcorr((float *)1, (float *)1, 0, 0, YES);
}


- (void)dumpCoef
{
	int		i, n = [self dataLength]; //[self xDim];
	float	*p = [self data];
	printf("===\n");
	for (i = 0; i < n; i++) {
		printf("%d %f\n", i, p[i]);
	}
}

// polynomial based, low freq phase is preserved
- (void)epiPcorr2
{
	RecImage		*av, *ev, *od, *tmp;
	RecImage		*sm, *df;
	RecImage		*mask, *phs;
	float			*ps, *pd, *pm, th;
	int				i, len;
	RecLoop			*avg;
	RecLoop			*ord;
	int				order = 5;	// 0 - 4 (4th order is necessary)
	RecImage		*coef, *coef_e, *coef_o;

	[RecImage setFFTdbg:NO];	// turn off FFT unit check

	[self fft2d:REC_INVERSE];
	avg = [RecLoop findLoop:@"avg"];
	if (avg == nil) {
		printf("avg loop not found.\n");
		exit(0);
	}
//	[RecLoop dumpLoops];
//	[self dumpLoops];
	av = [self avgForLoop:avg];


// even
	ev = [av copy];
	[ev takeEvenLines];
	[ev fft2d:REC_FORWARD];
//[ev saveAsKOImage:@"IMG_ev.img"];

	tmp = [ev avgForLoop:[ev yLoop]];
//[tmp saveAsKOImage:@"IMG_ev_avg.img"];
	ord = [RecLoop loopWithDataLength:order];
	coef = [tmp copy];
	[coef replaceLoop:[coef xLoop] withLoop:ord];
	//printf("even\n");
	[tmp pestPoly1dForLoop:[tmp xLoop] coef:coef];
	//[tmp pcorrPoly1dForLoop:[ev xLoop] coef:coef];
	//[tmp saveAsKOImage:@"IMG_ev_avg_corr.img"];
	[ev pcorrPoly1dForLoop:[ev xLoop] coef:coef];
//[coef dumpCoef];
	coef_e = [coef copy];
//[ev saveAsKOImage:@"IMG_ev_corr.img"];
// odd
	od = [av copy];
	[od takeOddLines];
	[od fft2d:REC_FORWARD];
	tmp = [od copy];
//[tmp saveAsKOImage:@"IMG_od.img"];
	// cos filter
	[tmp fullCosWin1DforLoop:[tmp yLoop]];
//[tmp saveAsKOImage:@"IMG_od_flt.img"];

	// avg
	tmp = [tmp avgForLoop:[tmp yLoop]];
//[tmp saveAsKOImage:@"IMG_od_avg.img"];

	coef = [tmp copy];
	[coef replaceLoop:[coef xLoop] withLoop:ord];
	[tmp pestPoly1dForLoop:[tmp xLoop] coef:coef];
	//[tmp pcorrPoly1dForLoop:[tmp xLoop] coef:coef];
	//[tmp saveAsKOImage:@"IMG_od_avg_corr.img"];
	[od pcorrPoly1dForLoop:[od xLoop] coef:coef];
	coef_o = [coef copy];
//[od saveAsKOImage:@"IMG_od_corr.img"];
//[coef dumpCoef];

// initial est
	sm = [ev copy];
	[sm addImage:od];
	//[sm saveAsKOImage:@"IMG_sm.img"];
	df = [ev copy];
	[df subImage:od];
//[df saveAsKOImage:@"IMG_df.img"];
// mask for pure even image
	mask = [RecImage imageOfType:RECIMAGE_REAL withImage:sm];
	pm = [mask data];

	th = 0.025;
	[sm magnitude];
	[sm thresAt:th];
	ps = [sm data];

	[df magnitude];
	[df thresAt:th];
	pd = [df data];

	len = [mask dataLength];
	for (i = 0; i < len; i++) {
		if (ps[i] > 0 && pd[i] == 0) {
			pm[i] = 1;
		} else {
			pm[i] = 0;
		}
	}
	// === mask
	phs = [ev copy];
	[phs cpxDivImage:od];
	[phs maskWithImage:mask];
//[phs saveAsKOImage:@"IMG_phsdif.img"];
	phs = [phs avgForLoop:[phs yLoop]];
//[phs saveAsKOImage:@"IMG_phsav.img"];
	[phs pestPoly1dForLoop:[phs xLoop] coef:coef];
// final pcorr
	// ev
	ev = [self copy];
	[ev takeEvenLines];
	[ev fft2d:REC_FORWARD];
	[ev pcorrPoly1dForLoop:[ev xLoop] coef:coef_e];
	// od
	od = [self copy];
	[od takeOddLines];
	[od fft2d:REC_FORWARD];
	[coef_o subImage:coef];
	[od pcorrPoly1dForLoop:[od xLoop] coef:coef_o];
	sm = [ev copy];
	[sm addImage:od];
	// sm becomes self
	[self copyIvarOf:sm];
}

// phase correlation based...
- (void)epiPcorr3
{
	RecImage		*av, *ev, *od, *tmp;
	RecImage		*sm;
//	RecLoop			*avg, *phs
	RecLoop			*rep;
	NSPoint			pt;
	float			a0, a1x, a1y;

	[RecImage setFFTdbg:NO];	// turn off FFT unit check
	[self fft2d:REC_INVERSE];
//	avg = [RecLoop findLoop:@"avg"];	// make this outer loops of xyz
//	phs = [RecLoop findLoop:@"phs"];
	rep = [RecLoop findLoop:@"rep"];
	av = [self avgForLoop:rep];
	ev = [av copy];
	[ev takeEvenLines];
	tmp = [ev copy];
	[tmp fft2d:REC_FORWARD];
//	[tmp saveAsKOImage:@"IMG_ev.img"];
	od = [av copy];
	[od takeOddLines];
	tmp = [od copy];
	[tmp fft2d:REC_FORWARD];
//	[tmp saveAsKOImage:@"IMG_od.img"];
	sm = [ev copy];

	// gaussian window
	ev = [ev xyCorrelationWith:od width:0.15 triFilt:YES];
//	[ev saveAsKOImage:@"IMG_ev_corr.img"];

	ev = [ev avgForLoop:[tmp zLoop]];
//	[ev saveAsKOImage:@"IMG_ev_corr_avg.img"];

	// 0th/1st order (x, y)
	pt = [ev findPeak2DwithPhase:&a0];
	a1x = pt.x * M_PI * 2;
	a1y = 0; //pt.y * 2 * M_PI;

//	printf("%f %f %f\n", pt.x, pt.y, a0);

	// find peak phase (0th)
	ev = [self copy];
	[ev takeEvenLines];
	[ev fft2d:REC_FORWARD];
	[ev pcorr2dx:-a1x y:-a1y phs:-a0];
//[ev saveAsKOImage:@"../test_img/IMG_ev_pcor2d.img"];


	// final pcorr
	od = [self copy];
	[od takeOddLines];
	[od fft2d:REC_FORWARD];
	sm = [ev copy];
	[sm addImage:od];
//[sm saveAsKOImage:@"../test_img/IMG_sum.img"];
//exit(0);

	// sm becomes self
	[self copyIvarOf:sm];
}

- (void)radPhaseCorr    // in/out : raw [ch sl proj rd]
{
	RecImage		*first, *last;
	RecImage		*corr;
	RecLoop			*ch;
	NSPoint			pt;


	RecLoop			*xLoop, *yLoop;
	RecLoopControl	*lc;		// full
	int				i, len, n;
	float			*re, *im;
	float			phs;

	[self removePointLoops];	// Echo
	yLoop = [self yLoop];
	first = [self sliceAtIndex:0 forLoop:yLoop];
	last = [self sliceAtIndex:[yLoop dataLength] - 1 forLoop:yLoop];
	[last xFlip];		// center of flip is N/2 ... 0.5 pix offset

	ch = [RecLoop findLoop:@"Channel"];
	if ([self containsLoop:ch] && [ch dataLength] > 1) {
		first = [first avgForLoop:ch];
		last  = [last  avgForLoop:ch];
	}
	xLoop = [first xLoop];
	yLoop = [first yLoop];
    [first fLanczWin1DforLoop:xLoop center:0.0 width:0.5];
    [first fLanczWin1DforLoop:yLoop center:0.0 width:1.0];
    [last  fLanczWin1DforLoop:xLoop center:0.0 width:0.5];
    [last  fLanczWin1DforLoop:yLoop center:0.0 width:1.0];
//[first saveAsKOImage:@"first.img"];
//[last  saveAsKOImage:@"last.img"];
	corr = [last xyCorrelationWith:first width:0.2 triFilt:YES];
//[corr  saveAsKOImage:@"corr.img"];
	pt = Rec_find_peak2([corr data], [corr xDim], [corr yDim]);
//	printf("x/y = %f/%f\n", pt.x, pt.y);
	phs = (pt.x + 1.0) * M_PI;

// correction
	xLoop = [self xLoop];
	[self fft1d:xLoop direction:REC_FORWARD];
    lc = [self outerLoopControl];
    [lc rewind];
    n = [lc loopLength];
	len = [self xDim];
    for (i = 0; i < n; i++) {
        re = [self currentDataWithControl:lc];
        im = re + [self dataLength];
        Rec_corr1st(re, im, 1, len, phs);	// center: (N-1)/2, phs: radian / FOV
        [lc increment];
    }
//	[self saveAsKOImage:@"sin_c.img"];
	[self fft1d:xLoop direction:REC_INVERSE];	// sin -> raw
}

- (RecImage *)initRadialTraj
{
	return [self initRadialTrajGolden:NO actualReadDim:[self xDim] startAngle:0 clockWise:YES];
}

- (RecImage *)initRadialToshiba		// -PI/2 - PI/2
{
	return [self initRadialTrajGolden:NO actualReadDim:[self xDim] startAngle:-M_PI/2 clockWise:NO];
}
- (RecImage *)initGoldenRadialTraj
{
	return [self initRadialTrajGolden:YES actualReadDim:[self xDim] startAngle:0 clockWise:YES];
}

- (RecImage *)initRadialTrajGolden:(BOOL)ga actualReadDim:(int)len startAngle:(float)st clockWise:(BOOL)clk
{
	RecImage		*tab;
	float			*theta;
	int				nproj, xdim;
	RecLoopControl	*lc;
	int				i, j;
	float			r, th, cs, sn;
	float			kx, ky, den;
	float			*pkx, *pky, *pden, *pwt;

	xdim = [self xDim];
	nproj = [self yDim];
//	printf("x:%d, y:%d\n", xdim, nproj);

	tab = [RecImage imageOfType:RECIMAGE_REAL withLoops:[self yLoop], nil];
	theta = [tab data];

	lc = [self outerLoopControl];
	[lc rewind];

    for (i = 0; i < nproj; i++) {
		if (ga) {
			th = Rec_golden_angle(i);
		} else {
			th = i * M_PI / nproj;
		}
		if (!clk) {
			th = -th;
		}
		th += st;
		theta[i] = th;
        cs = cos(th);
        sn = sin(th);
		pkx = [self currentDataWithControl:lc];
		pky = pkx + dataLength;
		pden = pky + dataLength;
		pwt = pden + dataLength;
        for (j = 0; j < xdim; j++) {
            r = (j - xdim/2.0) / xdim;	// center is N/2
            kx = r * cs;
            ky = r * sn;
            den = fabs(r) * xdim / nproj;
            if (den < 1.0 / nproj) {
                den = 1.0 / nproj;
            }
            pkx[j] = kx;        // [-0.5..0.5]
            pky[j] = ky;        // [-0.5..0.5]
            pden[j] = den;		// initial value... replaced by iterative density est
			pwt[j] = 1.0;		// [0..1.0], used for view weighting
        }
		[lc increment];
    }
	return tab;
}

// propeller (toshiba trajectory)
//
- (void)initPropTraj:(int)nEnc
{
	[self initPropTraj:nEnc shift:NULL];
}

- (void)initPropTraj:(int)nEnc shift:(NSPoint *)sft
{
	int		i, j, k, ix, n;
	int		nBlade;
	int		xDim = [self xDim];
	int		yDim = [self yDim];
	float	*kxBuf, *kyBuf;		// single blade, xDim x nEnc
	float	*kx, *ky, *den, *wt;
	float	x, y, cs, sn, th;
	float	cx, cy;
	
	nBlade = yDim / nEnc;	// has to be devisible
	n = nEnc * xDim;
	kxBuf = (float *)malloc(sizeof(float) * n);
	kyBuf = (float *)malloc(sizeof(float) * n);
	// single blade
	for(i = ix = 0; i < nEnc; i++) {
		y = (float)i - (nEnc - 1.0) / 2;
		y = y / xDim;
		for (j = 0; j < xDim; j++, ix++) {
			x = (float)j - xDim / 2;
			x /= xDim;
			kxBuf[ix] = x;
			kyBuf[ix] = y;
		}
	}
	// rotate blade
	for (k = 0; k < nBlade; k++) {
		if (sft != NULL) {
			cx = sft[k].x / xDim * 1.0;
			cy = sft[k].y / xDim * 1.0;
		} else {
			cx = cy = 0;
		}
		th =  M_PI / 2 + k * M_PI / nBlade;	// toshiba trajectory
		cs = cos(th);
		sn = sin(th);
		kx = [self data] + n * k;
		ky = kx + dataLength;
		den = ky + dataLength;
		wt = den + dataLength;
		for (i = ix = 0; i < nEnc; i++) {
			for (j = 0; j < xDim; j++, ix++) {
				kx[ix] =  kxBuf[ix] * cs + kyBuf[ix] * sn;// + cx;
				ky[ix] = -kxBuf[ix] * sn + kyBuf[ix] * cs + cy;
				den[ix] = wt[ix] = 1.0;
			//	kx[ix] =  (kxBuf[ix] + cx) * cs + (kyBuf[ix] + cy) * sn;
			//	ky[ix] = -(kxBuf[ix] + cx) * sn + (kyBuf[ix] + cy) * cs;
			}
		}
	}
	free(kxBuf);
	free(kyBuf);
}

- (void)plotTraj:(NSString *)path
{
	const char		*cPath = [path UTF8String];
	FILE			*fp;
	float			*kx, *ky;
	int				i, j, ix, xDim, yDim;

// open file
	fp = fopen(cPath, "w");
    if (fp == NULL) {
        printf("Couldn't open file [%s].\n", cPath);
        return;
    }
// plot
	xDim = [self xDim];
	yDim = [self yDim];
	kx = [self data];
	ky = kx + dataLength;
	for (i = ix = 0; i < yDim; i++) {
		for (j = 0; j < xDim; j++, ix++) {
			fprintf(fp, "%f %f\n", kx[ix], ky[ix]);
		}
		if (i < yDim-1) {
			fprintf(fp, "!eoc\n");
		}
	}

	fclose(fp);
}

// debugging
+ (void)setFFTdbg:(BOOL)flg
{
	fft_dbg = flg;
}

- (void)setName:(NSString *)aName
{
	name = [aName copy];
}

- (NSString *)name
{
	return name;
}

- (void)dumpData
{
	int		i, n;
	float	*floatData = [self data];

    n = [self xDim];
	for (i = 0; i < n; i++) {
		printf("%d %f %f\n", i , floatData[i], floatData[i + dataLength]);
	}
}

+ (RecImage *)pointTraj
{
	RecLoop		*xlp, *ylp;
	RecImage	*k;
	float		*pkx, *pky, *pden, *pwt;
	int			dataLength;

	xlp = [RecLoop pointLoop];
	ylp = [RecLoop pointLoop];
	k = [RecImage imageOfType:RECIMAGE_KTRAJ withLoops:ylp, xlp, nil];
	dataLength = [k dataLength];
	pkx = [k data];
	pky = pkx + dataLength;
	pden = pky + dataLength;
	pwt = pden + dataLength;
	pkx[0] = 0.0;
	pky[0] = 0.0;
	pden[0] = 1.0;
	pwt[0] = 1.0;

	return k;
}

+ (RecImage *)pointData
{
	RecLoop		*xlp, *ylp;
	RecImage	*img;
	float		*re, *im;
	int			dataLength;

	xlp = [RecLoop pointLoop];
	ylp = [RecLoop pointLoop];
	img = [RecImage imageOfType:RECIMAGE_KTRAJ withLoops:ylp, xlp, nil];
	dataLength = [img dataLength];
	re = [img data];
	im = re + dataLength;
    if (re) *re = 1.0;
	if (im) *im = 0.0;

	return img;
}

// convenience methods for dimensions
- (int)unitForLoop:(RecLoop *)lp
{
    return [[self axisForLoop:lp] unit];
}

- (void)setUnit:(int)u forLoop:(RecLoop *)lp
{
    [[self axisForLoop:lp] setUnit:u];
}

- (void)changeUnit:(int)dir forLoop:(RecLoop *)lp
{
    [[self axisForLoop:lp] changeUnit:dir];
}

- (void)copyUnitOfImage:(RecImage *)img
{
    int     i, dim = [self dim];
    RecLoop *lp;

    for (i = 0; i < dim; i++) {
        lp = [self loopAtIndex:i];
        if ([img containsLoop:lp]) {
            [self setUnit:[img unitForLoop:lp] forLoop:lp];
        }
    }
}

- (void)setUnit:(int)u     // set unit of all loops
{
    int         i, n = [self dim];

    for (i = 0; i < n; i++) {
        [[dimensions objectAtIndex:i] setUnit:u];
    }
}

// ====== block based procs =====
- (void)apply2ImageProc:(void (^)(float *src, int srcSkip, float *dst, int dstSkip, int n))proc
        withImage:(RecImage *)img andControl:(RecLoopControl *)control
{
	int				i, k;
	int				loopLength;
	float			*src, *dst;
	RecLoopControl	*ctl, *srcCtl, *dstCtl;
	int				len;
    RecLoop         *lp;    // inner loop of self
    RecLoopIndex    *li;    // inner loop index
    int             dstSkip, srcSkip;
	int				srcDataLength = [img dataLength];
    BOOL            srcIsReal = ([img pixSize] == 1);

	// 3 sets of flags are created (all are necessary)
    // controlWithControl: states are referenced, and flags are copied
	ctl = [RecLoopControl controlWithControl:control]; // common, copy is necessary to preserve flag
	srcCtl = [RecLoopControl controlWithControl:control forImage:img];  // controls need to match img structure
	dstCtl = [RecLoopControl controlWithControl:control forImage:self];

//    li = [control innerLoopIndex];  // innermost among active
    li = [ctl innerLoopIndex];  // innermost among active
    lp = [li loop];
	len = [li loopLength];  // get length before deactivation
    srcSkip = [img  skipSizeForLoop:lp];
    dstSkip = [self skipSizeForLoop:lp];

    [ctl rewind];
	[ctl deactivateLoop:lp];
	loopLength = [ctl loopLength];
    for (i = 0; i < loopLength; i++) {
		src = [img  currentDataWithControl:srcCtl];
		dst = [self currentDataWithControl:dstCtl];
        for (k = 0; k < pixSize; k++) {
            proc(src, srcSkip, dst, dstSkip, len);
            if (!srcIsReal) {
                src += srcDataLength;
            }
			dst += dataLength;
		}
        [ctl increment];
	}
}

- (void)apply2CpxImageProc:(void (^)(float *srcp, float *srcq, int srcSkip, float *dstp, float *dstq, int dstSkip, int n))proc
        withImage:(RecImage *)img andControl:(RecLoopControl *)control
{
	int				i;
	int				loopLength;
	float			*srcp, *srcq, *dstp, *dstq;
	RecLoopControl	*ctl, *srcCtl, *dstCtl;
	int				len;
    RecLoop         *lp;    // inner loop of self
    RecLoopIndex    *li;    // inner loop index
    int             dstSkip, srcSkip;

	// 3 sets of flags are created (all are necessary)
    // controlWithControl: states are referenced, and flags are copied
	ctl = [RecLoopControl controlWithControl:control]; // common, copy is necessary to preserve flag
	srcCtl = [RecLoopControl controlWithControl:control forImage:img];  // controls need to match img structure
	dstCtl = [RecLoopControl controlWithControl:control forImage:self];

//    li = [control innerLoopIndex];  // innermost among active
    li = [ctl innerLoopIndex];  // innermost among active
    lp = [li loop];
	len = [li loopLength];  // get length before deactivation
    srcSkip = [img  skipSizeForLoop:lp];
    dstSkip = [self skipSizeForLoop:lp];

    [ctl rewind];
	[ctl deactivateLoop:lp];
	loopLength = [ctl loopLength];
    for (i = 0; i < loopLength; i++) {
		srcp = [img  currentDataWithControl:srcCtl];
		srcq = srcp + [img dataLength];
		dstp = [self currentDataWithControl:dstCtl];
		dstq = dstp + dataLength;
		proc(srcp, srcq, srcSkip, dstp, dstq, dstSkip, len);
        [ctl increment];
	}
}

- (void)apply2ImageProc:(void (^)(float *src, int srcSkip, float *dst, int dstSkip, int n))proc
            withImage:(RecImage *)img
{
    [self apply2ImageProc:proc withImage:img andControl:[self control]];
}

- (void)apply2CpxImageProc:(void (^)(float *srcp, float *srcq, int srcSkip, float *dstp, float *dstq, int dstSkip, int n))proc
	withImage:(RecImage *)img
{
    [self apply2CpxImageProc:proc withImage:img andControl:[self control]];
}

// === all planes are processed equally (including complex)
- (void)apply1dProc:(void (^)(float *p, int n, int skip))proc forLoop:(RecLoop *)lp
{
    RecLoopControl  *lc;
    int             i, k, n;
    int             dim, skip;
    float           *p;

	lc = [self control];
	[lc deactivateLoop:lp];
	n = [lc loopLength];
    dim = [lp dataLength];
    skip = [self skipSizeForLoop:lp];
    for (i = 0; i < n; i++) {
        p = [self currentDataWithControl:lc];
        for (k = 0; k < pixSize; k++) {
            proc(p, dim, skip);
            p += dataLength;
        }
        [lc increment];
    }
}

// === all planes are processed equally
- (void)apply2dProc:(void (^)(float *p, int xDim, int yDim))proc
{
    RecLoopControl  *lc;
    int             i, k, n;
    int             xDim, yDim;
    float           *p;

	lc = [self control];
	[lc deactivateXY];
	n = [lc loopLength];
    xDim = [self xDim];
    yDim = [self yDim];
    for (i = 0; i < n; i++) {
        p = [self currentDataWithControl:lc];
        for (k = 0; k < pixSize; k++) {
            proc(p, xDim, yDim);
            p += dataLength;
        }
        [lc increment];
    }
}

- (void)apply3dProc:(void (^)(float *p, int xDim, int yDim, int zDim))proc
{
    RecLoopControl  *lc;
    int             i, k, n;
    int             xDim, yDim, zDim;
    float           *p;

	lc = [self control];
	[lc deactivateXY];
    [lc deactivateLoop:[self zLoop]];
	n = [lc loopLength];
    xDim = [self xDim];
    yDim = [self yDim];
    zDim = [self zDim];
    for (i = 0; i < n; i++) {
        p = [self currentDataWithControl:lc];
        for (k = 0; k < pixSize; k++) {
            proc(p, xDim, yDim, zDim);
            p += dataLength;
        }
        [lc increment];
    }
}

// 1D projection (plane by plane)
// no side-effect to self
// added unit support (5-16-2017)
- (RecImage *)applyProjProc:(void (^)(float *dst, float *src, int len, int skip))proc forLoop:(RecLoop *)lp
{
	RecLoopControl		*srcLc, *dstLc;
	RecImage			*img;
	float				*p;
	float				*pp;
	int					i, j, loopLen;
	int					dstDataLength;
	int					len, skip;

	srcLc = [self outerLoopControlForLoop:lp];	// [*ch z y x]
	img = [RecImage imageOfType:type withControl:srcLc];
	[img copyUnitOfImage:self];
	dstLc = [RecLoopControl controlWithControl:srcLc forImage:img];		//    [z y x]

	skip = [self skipSizeForLoop:lp];
	len = [lp dataLength];
	dstDataLength = [img dataLength];

	[dstLc rewind];
	loopLen = [dstLc loopLength];

	for (i = 0; i < loopLen; i++) {
		p = [self currentDataWithControl:srcLc];
		pp = [img currentDataWithControl:dstLc];
        for (j = 0; j < pixSize; j++) {
        // proc
            proc(pp, p, len, skip);
            p += dataLength;
            pp += dstDataLength;
        }
		[dstLc increment];
	}
	return img;
}

// proc for complex image
- (void)applyComplex2dProc:(void (^)(float *p, float *q, int xDim, int yDim))proc
{
    RecLoopControl  *lc;
    int             i, n;
    int             xDim, yDim;
    float           *p, *q;

	lc = [self control];
	[lc deactivateXY];
	n = [lc loopLength];
    xDim = [self xDim];
    yDim = [self yDim];
    for (i = 0; i < n; i++) {
        p = [self currentDataWithControl:lc];
        q = p + dataLength;
        proc(p, q, xDim, yDim);
        [lc increment];
    }
}

- (void)applyComplex2dProc:(void (^)(float *p, float *q, int xDim, int yDim, int ix))proc forLoop:(RecLoop *)lp
{
    RecLoopControl  *lc;
    RecLoopIndex    *li;
    int             i, n, ix;
    int             xDim, yDim, lpDim;
    float           *p, *q;

	lc = [self control];
	[lc deactivateXY];
    [lc deactivateLoop:lp];
    li = [lc loopIndexForLoop:lp];
	n = [lc loopLength];
    lpDim = [lp dataLength];
    xDim = [self xDim];
    yDim = [self yDim];
    for (i = 0; i < n; i++) {
        for (ix = 0; ix < lpDim; ix++) {
            [li setCurrent:ix]; 
            p = [self currentDataWithControl:lc];
            q = p + dataLength;
            proc(p, q, xDim, yDim, ix);
        }
        [lc increment];
    }
}

- (void)applyComplex2dProc:(void (^)(float *p, float *q, int xDim, int yDim))proc control:(RecLoopControl *)lc
{
    int             i, n;
	int				xDim, yDim;
    float           *p, *q;

	xDim = [self xDim];
	yDim = [self yDim];
    [lc deactivateXY];
	n = [lc loopLength];
    for (i = 0; i < n; i++) {
        p = [self currentDataWithControl:lc];
        q = p + dataLength;
        proc(p, q, xDim, yDim);
        [lc increment];
    }
}

// ### doesn't work ???
- (void)applyComplex1dProc:(void (^)(float *p, float *q, int skip, int len))proc forLoop:(RecLoop *)lp
{
	[self applyComplex1dProc:proc forLoop:lp control:[self control]];
}

// ### doesn't work ???
- (void)applyComplex1dProc:(void (^)(float *p, float *q, int skip, int len))proc forLoop:(RecLoop *)lp control:(RecLoopControl *)lc
{
    int             i, n;
    int             skip, len;
    float           *p, *q;

    [lc deactivateLoop:lp];
    skip = [self skipSizeForLoop:lp];
	n = [lc loopLength];
    len = [lp dataLength];
    for (i = 0; i < n; i++) {
        p = [self currentDataWithControl:lc];
        q = p + dataLength;
        proc(p, q, skip, len);
        [lc increment];
    }
}

- (RecImage *)applyComplexProjProc:(void (^)(float *dp, float *dq, float *sp, float *sq, int len, int skip))proc forLoop:(RecLoop *)lp
{
	RecLoopControl		*srcLc, *dstLc;
	RecImage			*img;
	float				*srcp, *srcq;
	float				*dstp, *dstq;
	int					i, loopLen;
	int					dstDataLength;
	int					len, skip;

	srcLc = [self outerLoopControlForLoop:lp];	// [*ch z y x]
	img = [RecImage imageOfType:type withControl:srcLc];
	[img copyUnitOfImage:self];
	dstLc = [RecLoopControl controlWithControl:srcLc forImage:img];		//    [z y x]

	skip = [self skipSizeForLoop:lp];
	len = [lp dataLength];
	dstDataLength = [img dataLength];

	[dstLc rewind];
	loopLen = [dstLc loopLength];

	for (i = 0; i < loopLen; i++) {
		srcp = [self currentDataWithControl:srcLc];
        srcq = srcp + dataLength;
		dstp = [img currentDataWithControl:dstLc];
        dstq = dstp + dstDataLength;
        // proc
        proc(dstp, dstq, srcp, srcq, len, skip);

		[dstLc increment];
	}
	return img;
}

// ch loop is too short...
// proc read loop, too
// llen : loop len, rlen : read len
- (RecImage *)applyCombineProc:(void (^)(float *dp, float *dq, float *sp, float *sq, int chLen, int chSkip, int rdLen, int rdSkip))proc forLoop:(RecLoop *)lp
{
	RecLoopControl		*srcLc, *dstLc;
	RecImage			*img;
    RecLoop             *rd;
	float				*srcp, *srcq;
	float				*dstp, *dstq;
	int					i, loopLen;
	int					dstDataLength;
	int					lpLen, lpSkip;
	int					rdLen, rdSkip;

    rd = [self xLoop];
    if ([rd isEqualTo:lp]) {
        return nil;
    }
	srcLc = [self control]; // ###
    [srcLc deactivateLoop:lp];
	img = [RecImage imageOfType:type withControl:srcLc];
	[img copyUnitOfImage:self];
    [srcLc deactivateLoop:rd];
	dstLc = [RecLoopControl controlWithControl:srcLc forImage:img];		//    [z y x]

	lpSkip = [self skipSizeForLoop:lp];
	lpLen = [lp dataLength];
    rdSkip = [self skipSizeForLoop:rd];
    rdLen = [rd dataLength];
	dstDataLength = [img dataLength];

	[dstLc rewind];
	loopLen = [dstLc loopLength];

	for (i = 0; i < loopLen; i++) {
		srcp = [self currentDataWithControl:srcLc];
        srcq = srcp + dataLength;
		dstp = [img currentDataWithControl:dstLc];
        dstq = dstp + dstDataLength;
        // proc
        proc(dstp, dstq, srcp, srcq, lpLen, lpSkip, rdLen, rdSkip);

		[dstLc increment];
	}
	return img;
}

// proc for complex image
- (void)applyComplex3dProc:(void (^)(float *p, float *q, int xDim, int yDim, int zDim))proc
{
    RecLoopControl  *lc;
    int             i, n;
    int             xDim, yDim, zDim;
    float           *p, *q;

	lc = [self control];
	[lc deactivateXY];
    [lc deactivateLoop:[self zLoop]];
	n = [lc loopLength];
    xDim = [self xDim];
    yDim = [self yDim];
    zDim = [self zDim];
    for (i = 0; i < n; i++) {
        p = [self currentDataWithControl:lc];
        q = p + dataLength;
        proc(p, q, xDim, yDim, zDim);
        [lc increment];
    }
}

- (NumMatrix *)toMatrix
{
	NumMatrix	*mat;
	int			m_type;

	switch (type) {
	case NUM_REAL :
		m_type = NUM_REAL;
		break;
	case NUM_COMPLEX :
		m_type = NUM_COMPLEX;
		break;
	}

	mat = [NumMatrix matrixOfType:m_type nRow:[self yDim] nCol:[self xDim]];
	[mat copyImage:self];

	return mat;
}

- (void)dumpInfo
{
	printf("Image[%s], dim(x/y/z) = %d/%d/%d, min = %f,  max = %f, rms = %f\n",
		[[self name] UTF8String],
        [self xDim], [self yDim], [self nImages],
        [self minVal], [self maxVal], [self rmsVal]);
}

- (BOOL)changedFrom:(RecImage *)img	// to test side effects
{
	float	*p, *q;
	int		i, k;
	BOOL	diff = NO;

	// iver
	if (type != [img type] || dataLength != [img dataLength]) {
		return YES;
	}
	// data
	p = [self data];
	q = [img data];
	for (k = 0; k < pixSize; k++) {
		for (i = 0; i < dataLength; i++) {
			if (p[i] != q[i]) {
				diff = YES;
				break;
			}
		}
		p += dataLength;
		q += dataLength;
	}
	return diff;
}

@end

// =========== fft1d (ver3)==================
@implementation RecFFT1dOp

+ (id)opWithImage:(RecImage *)img control:(RecLoopControl *)lc loop:(RecLoop *)lp direction:(int)dir
{
	RecFFT1dOp *op = [[RecFFT1dOp alloc] init];
	return [op initWithImage:img control:lc loop:lp direction:dir];
}

- (id)initWithImage:(RecImage *)img control:(RecLoopControl *)lc loop:(RecLoop *)lp direction:(int)dir
{
	image = img;
	control = lc;
	loop = lp;
	direction = dir;
	
	return self;
}

- (void)main
{
	[image fft1d:loop withControl:control direction:direction];
}

@end

