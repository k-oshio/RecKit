//
//	RecImage
//
// FFT direction:
//      epicrec: k -> img is INVERSE

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import <OpenCL/OpenCL.h>

// FFT direction (forward is freq -> pos)
#define	REC_FORWARD	1
#define	REC_INVERSE	-1

// position / frequency (unit)
#define	REC_POS		1
#define	REC_FREQ	0

@class RecLoop, RecLoopControl, RecCoilProfile, RecImage;
@class NumMatrix;


// image type
enum {					// dim
	RECIMAGE_REAL = 0,	// 1
	RECIMAGE_COMPLEX,	// 2
	RECIMAGE_MAP,		// 2    -> make 3D (== ktraj) by adding Jacobian (can be 1.0)
	RECIMAGE_KTRAJ,		// 4    -> add weight (in addition to initial density estimate)
	RECIMAGE_AFFINE,	// 6    (affine)
	RECIMAGE_HOMOG,     // 8    (homography)
	RECIMAGE_QUAD,      // 12   (quadrature)
	RECIMAGE_COLOR,     // 3    (RGB image)
	RECIMAGE_VECTOR,	// 3    (3D vector)    
    RECIMAGE_TENSOR,	// 6 (not implemented yet)
    RECIMAGE_4,         // 4 dim (param)
    RECIMAGE_5,         // 5 dim (param)
	RECIMAGE_TYPES
};

typedef struct RecVector {
    float   x;
    float   y;
    float   z;
} RecVector;

typedef struct RecBlock2 {
	int		x0;
	int		y0;
	int		xW;
	int		yW;
} RecBlock2;

typedef struct RecBlock3 {
	int		x0;
	int		y0;
	int		z0;
	int		xW;
	int		yW;
	int		zW;
} RecBlock3;

// multi-processing
enum {
    REC_REF = 0,
    REC_OP,
    REC_CL,
    REC_CL2,
    REC_MP_TYPES
};

// ===== RecAxis ====
@interface RecAxis : NSObject <NSCoding, NSCopying>
{
    RecLoop     *loop;
    int         unit;
}

+ (RecAxis *)axisWithLoop:(RecLoop *)lp;
+ (RecAxis *)pointAx;
- (id)initWithLoop:(RecLoop *)lp;

- (void)setLoop:(RecLoop *)lp;
- (RecLoop *)loop;

// FT direction
- (int)unit;
- (void)setUnit:(int)u;
- (void)changeUnit:(int)dir;

// underlying loop
- (int)dataLength;
- (BOOL)isPointLoop;

@end

extern int		fft_mode;	// 0:vDSP, 1:vDSP + NSOperation
extern BOOL		fft_dbg;	// 0:unit check off, 1:unit check on

// ===== RecImage ====
@interface RecImage : NSObject <NSCoding, NSCopying>
{
    NSArray                 *dimensions;    // array of RecAxis (RecLoop + ft direction)
	int						type;           // 0: real, 1: complex etc
	int						pixSize;        // number of floats per pixel
	int						dataLength;     // total number of pixels
	NSMutableData			*data;          // image data
	NSString				*name;          // optional. added for debugging
}

// creating
+ (RecImage *)imageOfType:(int)tp withDimensions:(NSArray *)dm;
+ (RecImage *)imageOfType:(int)tp withLoopArray:(NSArray *)lp;
+ (RecImage *)imageOfType:(int)tp withControl:(RecLoopControl *)lc;
+ (RecImage *)imageOfType:(int)tp withLoops:(RecLoop *)lp, ...;
+ (RecImage *)imageOfType:(int)tp withImage:(RecImage *)img;
+ (RecImage *)imageOfType:(int)tp xDim:(int)xDim;					// 1D
+ (RecImage *)imageOfType:(int)tp xDim:(int)xDim yDim:(int)yDim;	// 2D
+ (RecImage *)imageOfType:(int)tp xDim:(int)xDim yDim:(int)yDim zDim:(int)zDim;	// 3D
+ (RecImage *)imageOfType:(int)tp xDim:(int)xDim yDim:(int)yDim zDim:(int)zDim chDim:(int)chDim;	// 4D
+ (RecImage *)imageWithImage:(RecImage *)img;   // copy structure (data is not copied)
+ (RecImage *)sliceWithImage:(RecImage *)img;   // xy image (data is not copied)
+ (RecImage *)pointImageOfType:(int)tp;
+ (RecImage *)pointImageWithReal:(float)val;   // real point
+ (RecImage *)pointImageWithReal:(float)re imag:(float)im;   // complex point
+ (RecImage *)pointPoint:(NSPoint)p;                // NSPoint (x, y)
+ (RecImage *)pointVector:(RecVector)v;             // RecVector (x, y, z)

+ (void)setFFTmode:(int)mode;

- (id)initWithDimensions:(NSArray *)dm type:(int)type;  // designated init
+ (NSArray *)loopsFromDimensions:(NSArray *)dm;
+ (NSArray *)dimensionsFromLoops:(NSArray *)lp;

// NSCopying/NSCoding
//- (id)copyWithZone:(NSZone *)zone;				// deep copy
//- (void)encodeWithCoder:(NSCoder *)coder;
//- (id)initWithCoder:(NSCoder *)coder;

// accessors
- (void)setName:(NSString *)aName;
- (NSString *)name;
- (int)type;
- (int)dataLength;
- (int)dim;
- (int)realDim;         // excluding point loops
- (int)pixSize;
- (NSData *)dataObj;
- (float *)data;
- (float *)real;        // for convenience
- (float *)imag;        // for convenience
- (float *)r;        // for convenience
- (float *)g;        // for convenience
- (float *)b;        // for convenience
- (float *)currentDataWithControl:(RecLoopControl *)control;
- (float *)currentDataWithControl:(RecLoopControl *)control line:(int)y;
- (void)setVal:(float)val;
- (void)setVal1:(float)val1 val2:(float)val2;
- (NSArray *)dimensions;
- (NSArray *)copyOfDimensions;
- (NSArray *)loops;
- (void)setLoops:(NSArray *)loops;
- (void)setDimensions:(NSArray *)dim;
- (int)skipSizeForLoop:(RecLoop *)lp;
// these are different from RecLoopControl version. RecImage doesn't have active flag
- (RecLoop *)innerLoop;			// innermost loop
- (RecLoop *)topLoop;			// outermost loop
// z, y, x are last 3 loops in img
- (RecLoop *)xLoop;				// == innerLoop
- (RecLoop *)yLoop;
- (RecLoop *)zLoop;             // one above y loop (!= topLoop)
- (RecLoop *)loopAtIndex:(int)ix;
- (RecAxis *)axisForLoop:(RecLoop *)lp;
- (RecAxis *)xLoopAx;
- (RecAxis *)yLoopAx;
- (RecAxis *)zLoopAx;
- (int)xDim;
- (int)yDim;
- (int)zDim;            // one above y
- (int)topDim;
- (int)outerLoopDim;	// all loops outer to x
- (int)nImages;	// all loops outer to xy
// channel loop is RecLoop with name "Channel"
- (RecLoop *)chLoop;
- (int)chDim;
//
- (int)indexOfLoop:(RecLoop *)lp;
- (BOOL)containsLoop:(RecLoop *)lp;
- (BOOL)isPointImage;


// convenience method
- (RecLoopControl *)control;
- (RecLoopControl *)controlWithControl:(RecLoopControl *)control;
- (RecLoopControl *)outerLoopControl;
- (RecLoopControl *)outerLoopControlForLoop:(RecLoop *)lp;

// image dim comparison
- (BOOL)hasEqualDimWith:(RecImage *)img;

// KOImage (complex)
+ (RecImage *)imageWithKOImage:(NSString *)path;	// read from KOImage
- (void)initWithKOImage:(NSString *)path;			// read from KOImage
- (void)saveAsKOImage:(NSString *)path;				// save as KOImage block
- (void)saveRawAsKOImage:(NSString *)path;			// above + logP1
// Osirix (16bit real only)
- (void)initWithRawImage:(NSString *)path;			// read from raw
- (void)saveAsRawImage:(NSString *)path;			// save as raw
// NSKeyedArchve
+ (RecImage *)imageFromFile:(NSString *)path relativePath:(BOOL)flg;
- (void)saveToFile:(NSString *)path relativePath:(BOOL)flg;
// trajectory
- (void)plotTraj:(NSString *)path;

// type conversion for FFT
- (void)makeComplex;	// add empty imag part
- (void)takeRealPart;	// make real only image
- (void)takeImagPart;	// make imag only (type is real) image
- (void)takePlaneAtIndex:(int)ix;	// 0:real, 1:imag, 2:weight, etc
- (void)removeRealPart; // remove real part, keep complex type
- (void)removeImagPart; // remove imag part, keep complex type
//- (void)copyRealOf:(RecImage *)img;	// copy real part of img to imag of self -> makeComplexWithIm
//- (void)copyImagOf:(RecImage *)img;	// copy imag part of img to real of self
- (RecImage *)makeColorWithR:(RecImage *)r G:(RecImage *)g B:(RecImage *)b;
- (void)setRealToZero;
- (void)magnitude;		// take magnitude, and remove imag part
- (void)phase;			// take phase, and remove imag part
- (void)makeComplexWithPhs:(RecImage *)phs;	// make complex image from mg/phs pair 
- (void)makeComplexWithIm:(RecImage *)im;	// make complex image from re/im pair 
- (void)phaseWithMaskSigma:(float)sg;
- (void)magnitudeSq;	// take magnitude^2, and remove imag part
- (void)sqroot;			// take square root
- (void)square;			// take square
- (void)exp;            // take exponential (real)
- (void)logWithMin:(float)mn;            // take log (n) (real)
- (void)takeEvenLines;	// take even lines (for epi pcorr etc)
- (void)takeOddLines;	// take odd lines (for epi pcorr etc)
- (void)copyEvenLines:(RecImage *)img;	// copy even lines (for epi pcorr etc)
- (void)copyOddLines:(RecImage *)img;	// copy odd lines (for epi pcorr etc)

//- (RecImage *)logP1;		// take log(x) + 1 (for displaying ft data, self is not changed)
- (void)logP1;			// take log(x) + 1 (in-place)
- (RecImage *)pwrx:(float)x;		// take pow(x, p)

// in-place op
- (void)clear;
- (void)setConst:(float)val;
- (BOOL)checkNaN;		// fix and returns "contains NaN"
- (BOOL)checkNeg0;		// fix and returns "contains -0"
//- (void)fixNaN;
- (float)maxVal;
- (float)minVal;
- (float)rmsVal;
- (float)meanVal;
- (float)varWithMean:(float)mn;
- (int)nonZeroPix;		// # of non-zero pixels
- (void)intDiv:(float)d;
- (void)fMod:(float)d;

// func version
void histogram(float *hst, int nbin, float *p, int ndata, float mn, float mx);
// method
//- (void)histogram:(float *)p min:(float)min max:(float)max binSize:(int)n filt:(BOOL)flt;
- (void)histogram:(float *)p x:(float *)x min:(float)min max:(float)max binSize:(int)n filt:(BOOL)flt;
- (void)scaleToVal:(float)max;
- (void)scaleEachSliceToVal:(float)val;
- (void)limitToVal:(float)max;
- (void)limitLowToVal:(float)min;
- (void)conjugate;
- (void)negate;
- (void)invert;
- (void)fermi;
- (void)fermiWithRx:(float)rx ry:(float)ry d:(float)d x:(float)xc y:(float)yc invert:(BOOL)inv half:(BOOL)hf;
- (void)thresAt:(float)th frac:(BOOL)fr;	// make mask image: 1 if val > th (abs), otherwise 0
- (void)thresAt:(float)th;		// make mask image: 1 if val > max * th, otherwise 0
- (void)thresWithImage:(RecImage *)img;
- (void)thresEachSliceAt:(float)th;
- (RecImage *)varMaskForLoop:(RecLoop *)lp;	// make mask for phase image
- (RecImage *)magMask:(float)th;						// make mask for phase image
- (void)logicalInv;				// 0 <-> 1
- (void)thresAtSigma:(float)sg;	// threshold at sg * sigma of Reighley noise dist
- (void)addGWN:(float)sd relative:(BOOL)flg;
- (void)addRician:(float)sd relative:(BOOL)flg;
- (void)corrForRician:(float)sd;	// Hakon paper
- (void)corrForRician2:(float)sd;	// Oshio mod
- (void)maxImage:(RecImage *)img;
- (void)minImage:(RecImage *)img;
- (void)vectorLen:(RecImage *)img;      // z = sqrt(x^2 + y^2)
//- (void)scaleByImage:(RecImage *)img;	// img is real -> ### make this obsolete
- (void)multByImage:(RecImage *)img;	// complex x complex/real -> make this complex x complex (including real)
										// dim of images has to be the same (### probably bug, but be careful to modify)
- (void)multBy1dImage:(RecImage *)img;	// scale self by 1D scaling factor array (fix for above for 1d case)
- (void)maskWithImage:(RecImage *)mask;
- (void)maskWithImage:(RecImage *)mask invert:(BOOL)inv smooth:(BOOL)flt;
- (void)expWin:(float)tc;               // absorption to x-ray image
- (void)SCIC;                   // surface coil intensity correction

// image-scalar op (in-place op, returns self, real/cpx)
- (RecImage *)multByConst:(float)val;
- (RecImage *)addConst:(float)val;	// add val to real / imag
- (RecImage *)addReal:(float)val;	// add val to real part
- (RecImage *)addImag:(float)val;	// add val to imag part
// FIR filter (name !!! ###)
- (RecImage *)fir2d:(RecImage *)kern;   // 2D FIR filter
- (RecImage *)smooth2d:(int)width;      // 2D moving average
- (RecImage *)gauss2d:(int)width;       // 2D gaussian blurring

// --- fourier based filters ---> should be moved to Filter category
// Low-Pass filter
- (void)fGauss1DLP:(float)width forLoop:(RecLoop *)lp center:(int)ct;	// ## remove center
- (void)fGauss1DLP:(float)width forLoop:(RecLoop *)lp;
- (void)fGauss2DLP:(float)width;    // without FT step
- (void)fGauss3DLP:(float)width;    // without FT step
- (void)gauss1DLP:(float)width forLoop:(RecLoop *)lp;
- (void)gauss2DLP:(float)width;
- (void)gauss3DLP:(float)width;
// "Half" gaussian
- (void)hGauss2DLP:(float)width;
// High-pass filter (new)
- (void)fGauss1DHP:(float)width forLoop:(RecLoop *)lp center:(int)ct frac:(float)frac;	// ## remove center
- (void)fGauss1DHP:(float)width forLoop:(RecLoop *)lp frac:(float)frac;
- (void)fGauss2DHP:(float)width frac:(float)frac;
- (void)fGauss3DHP:(float)width frac:(float)frac;
- (void)gauss1DHP:(float)width forLoop:(RecLoop *)lp frac:(float)frac;
- (void)gauss2DHP:(float)width frac:(float)frac;
- (void)gauss3DHP:(float)width frac:(float)frac;

// High-Pass filter (uses above)
- (void)fGauss1DHP:(float)width forLoop:(RecLoop *)lp;
- (void)fGauss2DHP:(float)width;    // without FT step
- (void)fGauss3DHP:(float)width;    // without FT step
- (void)gauss2DHP:(float)width;
- (void)gauss3DHP:(float)width;

// Bandpass / Notch filter
- (void)fGauss1DBP:(float)width center:(float)cf forLoop:(RecLoop *)lp;
- (void)gauss1DBP:(float)width center:(float)cf forLoop:(RecLoop *)lp;
- (void)fGauss1DcBP:(float)width center:(float)cf forLoop:(RecLoop *)lp;	// assymmetric
- (void)gauss1DcBP:(float)width center:(float)cf forLoop:(RecLoop *)lp;	// assymmetric
- (void)fGauss1DN:(float)width center:(float)cf forLoop:(RecLoop *)lp;
- (void)gauss1DN:(float)width center:(float)cf forLoop:(RecLoop *)lp;
- (void)f1DPF:(int)cf forLoop:(RecLoop *)lp;	// point filter
- (void)t1DPF:(int)cf forLoop:(RecLoop *)lp;	// point filter

// FIR (freq domain)
- (void)f1DFIR:(RecImage *)kern forLoop:(RecLoop *)lp;
- (void)t1DFIR:(RecImage *)kern forLoop:(RecLoop *)lp;

// triangle (low-pass) filter
- (void)fTriWin1DforLoop:(RecLoop *)lp center:(float)ct width:(float)w;
- (void)fTriWin1DforLoop:(RecLoop *)lp;
- (void)fTriWin2D;
- (void)fTriWin3D;
- (void)triWin2D;	// FT included

// Lanczos window
- (void)fLanczWin1DforLoop:(RecLoop *)lp center:(float)ct width:(float)w;
- (void)fLanczWin2D;
- (void)fLanczWin3D;
- (void)lanczWin2D;
// rect filter (for POCS)
- (void)rectWin1DforLoop:(RecLoop *)lp width:(float)w;
- (void)fRect1DLP:(float)width forLoop:(RecLoop *)lp;
- (void)fRect2DLP:(float)width;    // without FT step
- (void)fRect3DLP:(float)width;    // without FT step
- (void)rect1DLP:(float)width forLoop:(RecLoop *)lp;
- (void)rect2DLP:(float)width;
- (void)rect3DLP:(float)width;

// cos2 window for GRAPPA type processing
- (void)fCos1DLPc:(int)w forLoop:(RecLoop *)lp;	// width is # of pixels (central)
- (void)fCos1DLPp:(int)w forLoop:(RecLoop *)lp;	// width is # of pixels (peripheral)
- (void)cos2DLPc:(int)w;	// width is # of pixels (central)
- (void)cos2DLPp:(int)w;	// width is # of pixels (peripheral)
- (void)cos3DLPc:(int)w;	// width is # of pixels (central)
- (void)cos3DLPp:(int)w;	// width is # of pixels (peripheral)


// full-cosine window
- (void)fullCosWin1DforLoop:(RecLoop *)lp;
// FFT based Laplacian (freq)
- (void)fLaplace1dForLoop:(RecLoop *)lp direction:(int)dir;
- (void)fLaplace2d:(int)direction;
- (void)fLaplace2dc:(int)direction;	// DCT version
- (void)fLaplace3d:(int)direction;
// FFT based Laplacian (space)
//- (void)laplace1dForLoop:(RecLoop *)lp direction:(int)dir width:(float)w;
//- (void)laplace2d:(int)direction width:(float)w;
//- (void)laplace3d:(int)direction width:(float)w;
- (void)laplace1dForLoop:(RecLoop *)lp direction:(int)dir;
- (void)laplace2d:(int)direction;
- (void)laplace2dc:(int)direction;	// DCT version
- (void)laplace3d:(int)direction;
// gradient
- (void)grad1dForLoop:(RecLoop *)lp;
- (void)grad1dForLoop:(RecLoop *)lp width:(float)w;	// with LPF
- (void)grad2d;
- (void)grad3d;
// gradient magnitude
- (void)gradMag2d;
- (void)gradMag3d;
// phase gradient (for unwrapping)
- (RecImage *)pGrad1dForLoop:(RecLoop *)lp;
- (RecImage *)pGrad2d;
- (RecImage *)pGrad3d;
- (RecImage *)pGrad1dInvForLoop:(RecLoop *)lp;
- (RecImage *)pGrad2dInv;	// fourier based invert grad 2d
// divergence (for unwrapping)
- (RecImage *)div2d;
// 
//- (void)modPI;
//- (void)mod2PI;
- (void)makeZeroMeanWithMask:(RecImage *)mask;
// copying
- (void)copyImage:(RecImage *)img;
- (void)copyImage:(RecImage *)img withControl:(RecLoopControl *)lc;
- (void)copyImage:(RecImage *)img dstControl:(RecLoopControl *)dstLc srcControl:(RecLoopControl *)srcLc;
// accumulate
- (void)accumImage:(RecImage *)img;
- (void)accumImage:(RecImage *)img withControl:(RecLoopControl *)lc;
- (void)accumImage:(RecImage *)img dstControl:(RecLoopControl *)dstLc srcControl:(RecLoopControl *)srcLc;

// slice
- (RecImage *)sliceAtIndex:(int)ix;
- (RecImage *)firstSlice;
- (RecImage *)sliceAtIndex:(int)ix forLoop:(RecLoop *)lp;
//- (RecImage *)removeSliceAtIndex:(int)ix forLoop:(RecLoop *)lp; // self is not modified
- (RecLoop *)removeSliceAtIndex:(int)ix forLoop:(RecLoop *)lp; // new loop is returned (self is changed)
- (RecImage *)pixPlaneAtIndex:(int)ix;
- (void)copySlice:(RecImage *)slc atIndex:(int)ix;
- (void)copySlice:(RecImage *)slc atIndex:(int)ix forLoop:(RecLoop *)lp;
- (void)accumSlice:(RecImage *)slc atIndex:(int)ix;
- (void)accumSlice:(RecImage *)slc atIndex:(int)ix forLoop:(RecLoop *)lp;

// 2-image op (in-place) now uses blocks. returns self for cascading
// self is the result (modified !!!!!!)
- (RecImage *)addImage:(RecImage *)img;
- (RecImage *)subImage:(RecImage *)img;
- (RecImage *)scaleAndSubImage:(RecImage *)img scale:(float)sc;		// make avg of two equal, then subtract
- (RecImage *)mulImage:(RecImage *)img;	// real/complex x real, plane by plane
- (RecImage *)divImage:(RecImage *)img; // real/complex / real, plane by plane
- (RecImage *)divImage:(RecImage *)img withLimit:(float)lmt;        // real/complex / real, truncate
- (RecImage *)divImage:(RecImage *)img withNoiseLevel:(float)lvl;   // real/complex / real, baysian
- (RecImage *)cpxDivImage:(RecImage *)img;	// cpx / cpx
- (RecImage *)histogram2dWithX:(RecImage *)xImg andY:(RecImage *)yImg;
- (RecImage *)histogram2dWithX:(RecImage *)xImg andY:(RecImage *)yImg
	xMin:(float)xMin xMax:(float)xMax yMin:(float)yMin yMax:(float)yMax;	// low level

// 2-image op, returns single number
- (float)correlationWith:(RecImage *)img;	// normalized correlation

// change struct
- (void)removePointLoops;
- (void)swapLoop:(RecLoop *)lp1 withLoop:(RecLoop *)lp2;			// change loop order
- (void)addLoop:(RecLoop *)loop;									// increase dimension (copy data)
- (RecLoop *)addLoopWithLength:(int)len;
- (void)replaceLoop:(RecLoop *)loop withLoop:(RecLoop *)newLoop;	// change loop size
- (void)replaceLoop:(RecLoop *)loop withLoop:(RecLoop *)newLoop offset:(int)ofs;
- (RecImage *)replaceLoop:(RecLoop *)loop withTab:(RecImage *)tab;	// change return type of others too
- (void)changeLoop:(RecLoop *)loop dataLength:(int)len offset:(int)ofs; // if new loop is not used by others...
- (void)copyIvarOf:(RecImage *)img;
- (void)copyImageData:(RecImage *)img;
- (void)copyLoopsOf:(RecImage *)img;        // same as below
- (void)copyDimensionsOf:(RecImage *)img;
- (void)copyXYLoopsOf:(RecImage *)img;
- (void)copyXYZLoopsOf:(RecImage *)img;
// change loop size (calls replaceLoop::)
- (RecLoop *)zeroFill:(RecLoop *)lp to:(int)newDim; // returns newly created loop
- (RecLoop *)zeroFill:(RecLoop *)lp to:(int)newDim offset:(int)ofs; // returns newly created loop
- (RecLoop *)zeroFillToPo2:(RecLoop *)lp; // returns newly created loop
- (RecLoop *)cycFill:(RecLoop *)lp to:(int)newDim;	// cyclic fill for cyclic convolution
- (void)zeroFillToPo2;		// zerofill xy
- (RecLoop *)crop:(RecLoop *)lp to:(int)newDim; // returns newly created loop
- (RecLoop *)crop:(RecLoop *)lp to:(int)newDim startAt:(int)st; // returns newly created loop
- (RecLoop *)cropToPo2:(RecLoop *)lp; // returns newly created loop
- (void)cropToPo2;		// zerofill xy

// FFT
- (void)fft1d:(RecLoop *)lp direction:(int)dir; // for entire image (unbrella)
- (void)fft1d:(RecLoop *)lp withControl:(RecLoopControl *)lc direction:(int)dir;	// for part of image
- (void)fft1d_FFT:(RecLoop *)lp withControl:(RecLoopControl *)lc direction:(int)dir;	// vDSP_fft_zip
- (void)fft1d_DFT:(RecLoop *)lp withControl:(RecLoopControl *)lc direction:(int)dir;	// vDSP_DFT_zop
- (void)fft1d_CZ:(RecLoop *)lp withControl:(RecLoopControl *)lc direction:(int)dir;		// chirpZ

// FFT utility
- (void)shift1d:(RecLoop *)lp;                  // half-fov shift
- (void)shift1d:(RecLoop *)lp by:(int)nPix;     // npix shift
- (void)rotate1d:(RecLoop *)lp by:(float)d;     // sub-pixel shift (ft based)

// DFT (this is called by fft1d::: if len is not po2)
- (void)dft1d:(RecLoop *)lp withControl:(RecLoopControl *)lc direction:(int)dir;
//- (void)dft1d:(RecLoop *)lp direction:(int)dir;

// DCT
- (void)dct1d:(RecLoop *)lp; // for entire image
- (void)dct2d;

// Wavelet (not implemented yet)
- (void)wave1d:(RecLoop *)lp level:(int)lv direction:(int)dir;
- (void)wave2d:(int)direction level:(int)lv;
- (RecImage *)waveEnergyWithLevel:(int)lv;
- (void)waveFiltWithCoef:(RecImage *)coef;

// half fourier
- (void)halfFT:(RecLoop *)lp;

// cosine filter
- (void)cosFilter:(RecLoop *)lp order:(int)order keepDC:(BOOL)dc;

// (mostly) private
- (void)fft1d_op:(RecLoop *)lp direction:(int)dir;	// NSOperation ver
- (void)fft1d_ref:(RecLoop *)lp direction:(int)dir;	// vDSP ver

// 2-D
- (void)trans;
- (void)xFlip;
- (void)yFlip;
- (void)flipForLoop:(RecLoop *)lp;
- (void)rotate:(int)code;
- (void)nopCrop;
- (void)freqCrop;
- (void)cropByFactor:(float)fct;
- (void)pFOV:(float)pf;
- (void)fft2d:(int)dir;						// in-place 2D FFT
- (void)fft3d:(int)dir;						// in-place 3D FFT
// self, src are not altered
- (RecImage *)xCorrelationWith:(RecImage *)img   width:(float)w triFilt:(BOOL)flt;
- (RecImage *)yCorrelationWith:(RecImage *)img   width:(float)w triFilt:(BOOL)flt;
- (RecImage *)xyCorrelationWith:(RecImage *)img  width:(float)w triFilt:(BOOL)flt;
- (RecImage *)xyzCorrelationWith:(RecImage *)img width:(float)w triFilt:(BOOL)flt;
- (RecImage *)xyCorrelationWith:(RecImage *)img;
- (RecImage *)xyzCorrelationWith:(RecImage *)img;
- (NSPoint)findPeak2D;
- (RecVector)findPeak3D;
- (NSPoint)findPeak2DwithMax:(float *)mx;
- (NSPoint)findPeak2DwithPhase:(float *)phs;
- (RecVector)findPeak3DwithMax:(float *)mx;
- (float)findEchoCenterForLoop:(RecLoop *)lp;
- (float)noiseSigma;
- (RecImage *)makeMask:(float)sg;				// automatic thresholding
- (RecImage *)makeMask;							// automatic thresholding

// NCI
- (RecImage *)toDipole;
- (RecImage *)toQuatrupole;

// geometric
- (void)dilate2d;
- (void)erode2d;

// multi-coil / phase correction etc
- (RecImage *)sumForLoop:(RecLoop *)lp;
- (RecImage *)avgForLoop:(RecLoop *)lp;	// sum & div
- (RecImage *)avgToLoop:(RecLoop *)lp;	// make 1D sum image
- (void)subtractMeanForLoop:(RecLoop *)lp;
//- (RecImage *)varWithMean:(RecImage *)m forLoop:(RecLoop *)lp;
- (RecImage *)varForLoop:(RecLoop *)lp withMean:(RecImage *)m;	// block version (arg order changed)
- (RecImage *)varForLoop:(RecLoop *)lp;	// central sd
//- (RecImage *)sdWithMean:(RecImage *)m forLoop:(RecLoop *)lp;
- (RecImage *)sdForLoop:(RecLoop *)lp withMean:(RecImage *)m;	// block version (arg order changed)
- (RecImage *)sdForLoop:(RecLoop *)lp;	// central sd
- (RecImage *)maxForLoop:(RecLoop *)lp;
- (RecImage *)combineForLoop:(RecLoop *)lp;         // (sqrt-of-)sum-of-square
- (RecImage *)combineForLoop:(RecLoop *)lp withCoil:(int)coilID;    // sqrt-of-weighted-sum
- (RecImage *)combinePWForLoop:(RecLoop *)lp withCoil:(int)coilID;	// for rtf3 pw img
- (RecImage *)complexCombineForLoop:(RecLoop *)lp;              // mg2 weighted sum
- (RecImage *)complexCombineForLoop:(RecLoop *)lp withCoil:(int)coilID;    // complex-weighted-sum
- (void)normalizeForLoop:(RecLoop *)lp;		// L1 norm
- (void)normalize2ForLoop:(RecLoop *)lp;	// L2 norm
// === coil profile estimation
- (RecImage *)coilProfile2DForLoop:(RecLoop *)ch;
- (RecImage *)coilProfile3DForLoop:(RecLoop *)ch;
- (RecImage *)combineForLoop:(RecLoop *)ch withProfile:(RecImage *)prof;

// projection
- (RecImage *)mipForLoop:(RecLoop *)lp;             // maximum intensity projection
- (RecImage *)mnpForLoop:(RecLoop *)lp;             // minimum intensity projection
- (RecImage *)maxIndexForLoop:(RecLoop *)lp;		// position of maximum intensity pixel in lp
- (RecImage *)peakIndexForLoop:(RecLoop *)lp;		// position of maximum intensity pixel in lp
- (RecImage *)tip:(int)dpth forLoop:(RecLoop *)lp;  // top intensity projection
- (RecImage *)partialMipForLoop:(RecLoop *)lp depth:(int)dp;
- (RecImage *)projectToBasis:(float *)b forLoop:(RecLoop *)lp; // extract component of basis

// phase correction
- (void)toUnitImage;		// for phase rotation op (to invert, [self multByImage:mg])
- (void)thToExp;			// exp(i th)
- (void)thToSin;			// sin(th)
- (void)thToCos;			// cos(th)
- (void)atan2;				// atan2(im, re)
- (void)atan2:(RecImage *)im;	// atan2(im, self)
- (void)sigmoid:(float)a;	// sigmoid(x, a)

// Ahn phase correction
- (float)est1dForLoop:(RecLoop *)lp;
- (float)est1dForLoop:(RecLoop *)lp atSlice:(float *)p;
- (float)est0;
//- (float)est0ForLoop:(RecLoop *)lp;
- (void)pcorr0;                     // 0th (global, with single phase number)
//- (void)pcorr0ForLoop:(RecLoop *)lp;	// 0th
- (void)pcorr0EachSlice;            // 0th
- (void)pcorr1dForLoop:(RecLoop *)lp;   // 1D (lp)
- (void)pcorrForLoop:(RecLoop *)lp; // 1D (lp + 0)
- (void)pcorr;                      // 2D (x + y + 0th)
- (void)pcorr2;                     // 2D (x + y + 0th)
- (void)pcorr3;                     // 3D (x + y + z + 0th)
- (void)pcorrFine;                  // 2D, 2nd order cos trans based, high precision
- (void)pcorr2dx:(float)a1x y:(float)a1y phs:(float)a0;

// 1D polynomial phase correction
- (void)pestPoly1dForLoop:(RecLoop *)lp coef:(RecImage *)coef;
- (void)pcorrPoly1dForLoop:(RecLoop *)lp coef:(RecImage *)coef;

// 2D polynomial phase correction
//- (void)pestPoly2d:(RecImage *)coef;	// moved to nciRec (for development)
- (void)pcorrPoly2d:(RecImage *)coef;

// EPI
- (void)epiPcorr;       // EPI even/odd phase correction
- (void)epiPcorrGE;		// EPI even/odd phase correction
- (void)epiPcorr2;		// EPI even/odd phase correction, polynomial based
- (void)epiPcorr3;		// EPI even/odd phase correction, phase correlation based

// radial
- (void)radPhaseCorr;			// radial scan phase correction
//	returns thTab
- (RecImage *)initRadialTraj;			// 0 - PI
- (RecImage *)initRadialToshiba;		// PI/2 - -PI/2
- (RecImage *)initGoldenRadialTraj;	// golden angle radial
- (RecImage *)initRadialTrajGolden:(BOOL)ga actualReadDim:(int)len startAngle:(float)st clockWise:(BOOL)dir;
// propeller
- (void)initPropTraj:(int)nEnc;
- (void)initPropTraj:(int)nEnc shift:(NSPoint *)pt;

// registration
- (void)rotShift;
- (void)rotShiftWithRef:(int)ix;
- (RecImage *)rotShiftForEachOfLoop:(RecLoop *)lp scale:(float)scale;
- (RecImage *)estRot;   // calc rotation angle from correlation image, and return warp param
- (RecImage *)estShift; // calc linear shift from 2D correlation, and return warp param
- (RecImage *)estShift1d;
// low level
- (float)estRotWithImage:(RecImage *)img;
- (void)rotXYBy:(float)th;
- (NSPoint)estShift2dWithImage:(RecImage *)img;
- (RecVector)estShift3dWithImage:(RecImage *)img;


// convenience methods for dimensions
- (int)unitForLoop:(RecLoop *)lp;
- (void)setUnit:(int)u forLoop:(RecLoop *)lp;
- (void)changeUnit:(int)dir forLoop:(RecLoop *)lp;
- (void)copyUnitOfImage:(RecImage *)img;
- (void)setUnit:(int)u;     // set unit of all loops

// block ops -> rewrite above methods using blocks
// === block-based methods ====
- (void)apply2ImageProc:(void (^)(float *src, int srcSkip, float *dst, int dstSkip, int n))proc withImage:(RecImage *)img andControl:(RecLoopControl *)control;
- (void)apply2ImageProc:(void (^)(float *src, int srcSkip, float *dst, int dstSkip, int n))proc withImage:(RecImage *)img;
- (void)apply2CpxImageProc:(void (^)(float *srcp, float *srcq, int srcSkip, float *dstp, float *dstq, int dstSkip, int n))proc withImage:(RecImage *)img andControl:(RecLoopControl *)control;
- (void)apply2CpxImageProc:(void (^)(float *srcp, float *srcq, int srcSkip, float *dstp, float *dstq, int dstSkip, int n))proc withImage:(RecImage *)img;
- (void)apply1dProc:(void (^)(float *p, int n, int skip))proc forLoop:(RecLoop *)lp;
- (void)apply2dProc:(void (^)(float *p, int xDim, int yDim))proc;
- (void)apply3dProc:(void (^)(float *p, int xDim, int yDim, int zDim))proc;
- (RecImage *)applyProjProc:(void (^)(float *dst, float *src, int len, int skip))proc forLoop:(RecLoop *)lp;

- (void)applyComplex2dProc:(void (^)(float *p, float *q, int xDim, int yDim))proc;
- (void)applyComplex2dProc:(void (^)(float *p, float *q, int xDim, int yDim))proc control:(RecLoopControl *)lc;
// vvv below is probably not necessary (just use 1d processing inside proc)
- (void)applyComplex2dProc:(void (^)(float *p, float *q, int xDim, int yDim, int ix))proc forLoop:(RecLoop *)lp;

- (void)applyComplex1dProc:(void (^)(float *p, float *q, int skip, int len))proc forLoop:(RecLoop *)lp;
- (void)applyComplex1dProc:(void (^)(float *p, float *q, int skip, int len))proc forLoop:(RecLoop *)lp control:(RecLoopControl *)lc;
- (RecImage *)applyComplexProjProc:(void (^)(float *dp, float *dq, float *sp, float *sq, int len, int skip))proc forLoop:(RecLoop *)lp;
- (RecImage *)applyCombineProc:(void (^)(float *dp, float *dq, float *sp, float *sq, int chLen, int chSkip, int rdLen, int rdSkip))proc forLoop:(RecLoop *)lp;
- (void)applyComplex3dProc:(void (^)(float *p, float *q, int xDim, int yDim, int zDim))proc;

// NumKit
- (NumMatrix *)toMatrix;

// debugging
- (void)dumpData;       // text dump of image data, first xLoop only
- (void)dumpLoops;      // loop name, dim, active flag etc
- (void)dumpInfo;       // image name, xy dim, max val
+ (void)setFFTdbg:(BOOL)flg;
- (BOOL)changedFrom:(RecImage *)img;	// to test side effects

@end

//================= OpenCL -> move this to RecGridder ==================
@interface	RecImage (CL)

// gridding
- (void)grid2d_CL_withTrajectory:(RecImage *)traj andData:(RecImage *)dat;

@end


//================= Warp ===============
@interface	RecImage (Warp)

// common method to make xy map
- (RecImage *)createMapWithParam:(RecImage *)param 
    usingProc:(void (^)(float *mapx, float *mapy, int xDim, int yDim, float *a, int dim))proc;
// for each mode (xy)
- (RecImage *)mapForScale:(RecImage *)param;        // XY scale
- (RecImage *)mapForShift:(RecImage *)param;        // shift only (warp based)
- (RecImage *)mapForShiftScale:(RecImage *)param;        // scale + shift
- (RecImage *)mapForRotate:(RecImage *)param;
- (RecImage *)mapForAffine:(RecImage *)param;       // affine transform, a[6]
- (RecImage *)mapForHomog:(RecImage *)param;		// projective transform, a[8]
- (RecImage *)mapForPolarWithRMin:(int)rMin logR:(BOOL)lgr;
- (RecImage *)mapForRot:(RecImage *)rotParam shift:(RecImage *)sftParam; // make single combined map
- (RecImage *)trajToMap;                            // for inv of gridding
- (RecImage *)mapFor3dPolarWithRMin:(int)rMin logR:(BOOL)lgr;
- (RecImage *)weight;							// return density image (real)

// convenience methods
- (RecImage *)ftShiftBy:(RecImage *)param; // FFT based shift without making map
- (RecImage *)ftShift1d:(RecLoop *)lp by:(RecImage *)param; // FFT based shift without making map
- (RecImage *)rotBy:(RecImage *)param;
- (RecImage *)rotByTheta:(float)th;
- (RecImage *)toPolarWithNTheta:(int)nTheta nRad:(int)nRad rMin:(int)rMin logR:(BOOL)lgr;
- (RecImage *)to3dPolarWithNTheta:(int)nTheta nPhi:(int)nPhi nRad:(int)nRad rMin:(int)rMin logR:(BOOL)lgr;

// xy 2d -> use 1d method
- (RecImage *)scaleXBy:(float)x andYBy:(float)y;
- (RecImage *)scaleXBy:(float)x andYBy:(float)y crop:(BOOL)flg;
- (RecImage *)oversample;   // x-y oversample by 2 (resampler-based)
- (RecImage *)subsample;	// x-y subsample by 2 (resampler-based)
- (RecImage *)ftSubsample;	// x-y subsample by 2 (FT-based)
- (RecImage *)scaleXYBy:(float)scale;
// z (1d)
- (RecImage *)scale1dLoop:(RecLoop *)lp by:(float)scale to:(int)newDim;
- (RecImage *)scale1dLoop:(RecLoop *)lp to:(int)newDim;		// scale is newDim / oldDim
- (RecImage *)scale1dLoop:(RecLoop *)lp by:(float)scale;	// newDim is oldDim * scale
- (RecImage *)scale1dLoop:(RecLoop *)lp by:(float)scale crop:(BOOL)flg;	// newDim = currentDim

- (RecImage *)mapFor1dScale:(float)scale forLoop:(RecLoop *)lp;    // 1D scale for lp
- (RecImage *)mapForZScale:(float)z;
- (RecImage *)scaleZBy:(float)z;
- (RecImage *)mapFor1dShift:(float)sft forLoop:(RecLoop *)lp;
- (RecImage *)shift1dLoop:(RecLoop *)lp by:(float)sft;

// actual resampling is done by RecResampler / RecResampler1d
- (void)resample:(RecImage *)src withMap:(RecImage *)map;       // 2D (x-y)
- (void)resample:(RecImage *)src withTraj:(RecImage *)ktraj;    // inv of gridding (x-y)
- (void)resample1d:(RecImage *)src forLoopIndex:(int)ix map:(RecImage *)map;
- (void)resample3d:(RecImage *)src withMap:(RecImage *)map;     // xyz
- (void)dumpParam;

@end

//================= Unwrap ===============
@interface	RecImage (Unwrap)
- (void)modPI;
- (void)mod2PI;
- (void)unwrap0d;
- (void)unwrap1dForLoop:(RecLoop *)lp;	// 1D phase unwrap (uses Rec_unwrap_1d)
- (void)apply2dx:(float)a1x y:(float)a1y phs:(float)a0;
- (RecImage *)unwrapEst2d;			// initial est using Laplacian
- (RecImage *)unwrap2d;					// one of below
- (RecImage *)unwrap2d_lap;				// 
- (RecImage *)unwrap2d_fudge;				// 2D
- (RecImage *)unwrap2d_block;
- (RecImage *)unwrap2d_block_rec;
- (RecImage *)unwrap2d_work;
- (RecImage *)phsNoiseMask:(float)sg;	// input is complex, output is (soft) mask
- (void)phsNoiseFilt:(float)sg;			// input is complex, self is filtered

@end

// =========== fft1d (ver3)==================
@interface RecFFT1dOp : NSOperation
{
	RecImage			*image;
	RecLoop				*loop;
	RecLoopControl		*control;
	int					direction;
}
+ (id)opWithImage:(RecImage *)img control:(RecLoopControl *)lc loop:(RecLoop *)lp direction:(int)dir;
- (id)initWithImage:(RecImage *)img control:(RecLoopControl *)lc loop:(RecLoop *)lp direction:(int)dir;
- (void)main;
@end



