//
//	plans
//		*zero-fill
//		*FFT
//		*NSOperation
//		*combine with coil profile
//		*gridding
//      *Siemens read
//      *EPI nyquist correction
//      warp
//          *rot, scale ok
//          affine -> chk ###
//	---- rtf3 recon
//		projection / MIP
//
//	=== for static library with categories, "Perform Single-Object Prelink" must be checked ===
//

#import <RecKit/RecKit.h>
#import <NumKit/NumKit.h>

#import <sys/time.h>
#import "timer_macros.h"

int tmptest(void);
int test_type(void);
int test0(void);
int test1(void);
int test2(void);
int	test_comb(void);
int test3(void);
int test4(void);
int test5(void);
int test6(void);
int test7(void);
int test8(void);
int test9(void);
int test10(void);
int test11(void);
int test12(void);
int test13(void);
int test14(void);
int test15(void);
int test16(void);
int test17(void);
int test18(void);
int	test19(void);
int	test20(void);
int	test21(void);
int	test22(void);
int	test23(void);
int	test24(void);
int	test25(void);
int	test26(void);
int	test27(void);
int	test28(void);
int test29(void);
int test30(void);
int test31(void);
int test32(void);
int test33(void);
int test34(void);
int test35(void);
int test36(void);
int test37(void);
int test38(void);
int test39(void);
int test40(void);
int test45(void);

int
main()
{
@autoreleasepool {
	printf("Number of cores : %d\n", (int)[[NSProcessInfo processInfo] processorCount]);

//	tmptest();

// clear test images
//    system("rm ../test_img/test*.img");

//	test_type();    // chk types
//	test0();    // copy / combine
//	test1();    // 3D / GE / maxVal / 1d histogram
//	test2();    // grid
//	test_comb();
//	test3();	// grid inverse kernel / reproj
//	test4();	// warp with single map // 1.688996 (sec) resample (single)
//	test5();	// warp with map array  // 3.203776 / 0.928969 (sec) single/op
//	test6();	// VROM
//	test7();	// oversample
//  test8();    // cos filter
//  test9();    // rotShift
//  test10();   // block
//  test11();   // freq domain filter
//	test12();   // SCIC
//	test13();   // tri filter
//  test14();   // Dicom
//	test15();   // ImageRef (2D and 3D)
//	test16();	// test image gen (color space)
//	test17();	// half-fourier
//	test18();	// pcorr
//	test19();	// fft (func version, DFT, chirp-Z)
//	test20();	// dct
//	test21();	// not used
//	test22();	// pcorrFine(), chebyshev
//	test23();	// phase correlation
//	test24();	// 2D hist + T2C image
//	test25();	// FIFO
//	test26();	// partial MIP
//	test27();	// Toshiba
//	test28();	// traj / propeller
//	test29();	// EPI pcorr
//	test30();	// MATLAB file
//	test31();	// chebychev (1d, 2d)
//	test32();	// trig interp
//	test33();	// complex interp
//	test34();	// unwrap
//	test35();	// Laplacian-base unwrap (complex version)
//	test36();	// wavelet
//	test37();	// phase SNR
//	test38();	// phase noise filter
//	test39();	// coil profile est
//	test40();	// FIR
//	test41();	// high resolution FT pair
//	test42();	// Rician correction
//	test43();	// DICOM / Canon scaling
//	test44();	// pinwheel test
	test45();	// s-transform

	return 0;
} // autoreleasepool
}

int
tmptest()
{
	RecImage	*img1, *img2, *img3;
	RecLoop		*xLp, *yLp, *zLp;
	
	xLp = [RecLoop loopWithName:@"x_loop" dataLength:256];
	yLp = [RecLoop loopWithName:@"y_loop" dataLength:64];
	zLp = [RecLoop loopWithName:@"z_loop" dataLength:256];

	img1 = [RecImage imageOfType:RECIMAGE_REAL withLoops:yLp, xLp, nil];
	img2 = [RecImage imageOfType:RECIMAGE_REAL withLoops:zLp, nil];

	img3 = [img1 xCorrelationWith:img2 width:0.5 triFilt:NO];

	printf("img1\n");
	[img1 dumpLoops];
	printf("img2\n");
	[img2 dumpLoops];
	printf("img3\n");
	[img3 dumpLoops];
	
	return 0;
}

// check type / size (64 bit vs 32 bit)
int
test_type()
{
	printf("int    : %ld\n", sizeof(int));
	printf("float  : %ld\n", sizeof(float));
	printf("long   : %ld\n", sizeof(long));
	printf("double : %ld\n", sizeof(double));
	printf("char * : %ld\n", sizeof(char *));

	return 0;
}

//
//	copy_image test (don't add other tests)
//
int
test0()
{
	RecImage		*im1, *im2;
	RecLoopControl	*lc;
	RecLoopIndex	*li;
    RecLoop         *ch, *newY;
	float			*p;
	int				xDim = 4, yDim = 9;


	printf("Test 0 (copy)\n");
	system("rm ../test_img/test0*.img");
TIMER_ST
//	im1 = [RecImage imageWithKOImage:@"../test_img/IMG_img"];
	im1 = [RecImage imageWithKOImage:@"../test_img/test_grid_comb.img"];
	if (im1 == nil) {
		printf("image not found\n");
	}
	[im1 dumpLoops];
TIMER_END("read image");

// copy0 : src = dst
	im2 = [im1 copy];
	[im2 saveAsKOImage:@"../test_img/test0_image0.img"];
TIMER_END("copy 0");

// copy1 : src > dst
	im2 = [RecImage imageOfType:[im1 type] withLoops:[im1 yLoop], [im1 xLoop], nil];
//	lc = [RecLoopControl controlForImage:im1];
	lc = [im1 control];
	li = [lc loopIndexAtIndex:0];
	[li deactivate];
	[li setCurrent:5];
	[im2 copyImage:im1 withControl:lc];
TIMER_END("copy 1");
	[im2 saveAsKOImage:@"../test_img/test0_image1.img"];
// copy2 : src < dst
	[im1 copyImage:im2];
TIMER_END("copy 2");
	[im1 saveAsKOImage:@"../test_img/test0_image2.img"];
TIMER_END("save ");

    newY = [RecLoop loopWithDataLength:192];
    [im1 replaceLoop:[im1 yLoop] withLoop:newY offset:-30];
	[im1 saveAsKOImage:@"../test_img/test0_image4.img"];

	[im1 trans];
	[im1 saveAsKOImage:@"../test_img/test0_image5.img"];	

TIMER_TOTAL

	return 0;
}

//
//	gen purpose 3D recon
//
int
test1()
{
	RecLoop			*rd, *pe, *ch, *sl;
	RecLoop			*ky, *kx, *kz;
	RecImage		*im1, *im2, *im3;
	RecImage		*logImg;
	RECCTL			ctl;
	int				ix, i;
	float			mx, mn;

printf("test ver\n");
	printf("Test 1 (FFT)\n");
    system("rm ../test_img/test1_image*.*");
TIMER_ST

	im1 = [RecImage imageWithPfile:@"P_3d.7" RECCTL:&ctl];		// 0.08 sec

    [im1 dumpInfo];
TIMER_END("read Pfile");
	if (im1 == nil) {
		printf("image not found\n");
	}
	[im1 saveAsKOImage:@"../test_img/test1_image0.img"];
	[im1 removePointLoops];
	[im1 dumpLoops];

	rd = [RecLoop findLoop:@"Read"];
	pe = [RecLoop findLoop:@"Phase"];
	ch = [RecLoop findLoop:@"Channel"];
	sl = [RecLoop findLoop:@"Slice"];

// ft test ==== 
//    [im1 dumpInfo];
//    [im1 fft1d:sl direction:REC_INVERSE]; // (raw -> inv -> image)
//    [im1 dumpInfo];
//    [im1 fft1d:sl direction:REC_FORWARD]; // (img -> for -> raw)
//    [im1 dumpInfo];
// ft test ====

/*
[im1 zeroFill:[im1 yLoop] to:512];
[im1 zeroFillToPo2:[im1 yLoop]];
[im1 saveAsKOImage:@"../test_img/test_zeroFill.img"];
[im1 crop:[im1 yLoop] to:256];
[im1 saveAsKOImage:@"../test_img/test_zeroFill2.img"];
exit(0);
*/

	[im1 fft1d:sl direction:REC_INVERSE];   // z -> k
TIMER_END("slice IFT");                     // 0.24 sec
	[im1 shift1d:sl];
TIMER_END("slice shift");                   // 0.06 sec
	kz = [RecLoop loopWithName:@"kz" dataLength:64];
	[im1 replaceLoop:sl withLoop:kz];       // k
TIMER_END("slice zero-fill");
	[im1 fft1d:kz direction:REC_FORWARD];		// 0.43 sec
TIMER_END("slice  FFT");
	ky = [RecLoop loopWithName:@"ky" dataLength:256];
	[im1 replaceLoop:pe withLoop:ky];
TIMER_END("ky zero-fill");
	[im1 fft1d:ky direction:REC_FORWARD];
TIMER_END("fft1d (ky)");
	kx = [RecLoop loopWithName:@"kx-ZF" dataLength:256];
	[im1 replaceLoop:rd withLoop:kx];
TIMER_END("kx zero-fill");
// y fft
	[im1 fft1d:kx direction:REC_FORWARD];
    [im1 dumpInfo];
	[im1 saveAsKOImage:@"../test_img/test1_image1.img"];

	[im1 pfSwap:ctl.trans rot:ctl.rot];
	[im1 saveAsKOImage:@"../test_img/test1_image2.img"];

// projection
//	im2 = [im1 mipForLoop:kz];
	im2 = [im1 copy];
	[im2 magnitude];
	im2 = [im2 tip:10 forLoop:kz];
	[im2 saveAsKOImage:@"../test_img/test1_image3.img"];
//exit(0);

// max, histogram
	if (0) {
		float *hist, *x;
		mx = [im1 maxVal];
		printf("max val = %f\n", mx);
		mn = [im1 meanVal];
		printf("mean val = %f\n", mn);
		hist = (float *)malloc(sizeof(float *) * 100);
		x = (float *)malloc(sizeof(float *) * 100);
		[im1 magnitude];
		mn = [im1 meanVal];
		printf("mag mean val = %f\n", mn);
		[im1 histogram:hist x:x min:0 max:mx binSize:100 filt:NO];
		for (i = 0; i < 100; i++) {
			printf("%d %f\n", i, hist[i]);
		}
		free(hist);
	}
// scale / warp
	im3 = [im1 copy];
	[im3 fft2d:REC_INVERSE];
	[im3 fft1d:[im3 zLoop] direction:REC_INVERSE];
	im3 = [im3 to3dPolarWithNTheta:[im3 xDim] nPhi:[im3 zDim] nRad:[im3 yDim] rMin:0 logR:YES];
	logImg = [im3 copy];
	[logImg logP1];
	[logImg saveAsKOImage:@"../test_img/test1_image3f.img"];
	im1 = [im1 scaleXBy:2 andYBy:2];
	im1 = [im1 rotByTheta:M_PI/4];
	[im1 saveAsKOImage:@"../test_img/test1_image4.img"];
	[im1 fft2d:REC_INVERSE];
	im1 = [im1 toPolarWithNTheta:[im1 xDim] nRad:[im1 yDim] rMin:0 logR:YES];
	logImg = [im1 copy];
	[logImg logP1];
	[logImg saveAsKOImage:@"../test_img/test1_image4f.img"];

//	[im3 copyLoopsOf:im1];
//	im2 = [im1 xyPCorrelationWith:im3]; //####
//	[im2 fft2d:REC_FORWARD];

//	[im2 saveAsKOImage:@"../test_img/test1_image5.img"];

TIMER_END("saveAsKOImage (test1)");
TIMER_TOTAL

	return 0;
}

//
//	rtf3 recon
//

// current version (rtf3_recon) : 29 sec (from P to PW/IMG)
int
test2()
{
	RecLoop			*rd, *pe;	// raw, pw
	RecLoop			*rdZF;
	RecLoop			*sl, *ch;	// common
	RecLoop			*kx, *ky;	// img
	RecLoopControl	*lc;
	RecImage		*raw;
	RecImage		*raw_single;	// single channel data for debugging
	RecImage		*img;
	RecImage		*img_comb;
	RecImage		*pw;
	RecImage		*pw_comb;
	RecImage		*traj;
	RECCTL			ctl;
    RecGridder      *grid;

	BOOL			single = NO;
	int				vd = 1;		// 0: GE, 1: Toshiba
	int				coil;

// === start ===
	if (single) {
		printf("test2 (Gridding), single channel\n");
	} else {
		printf("test2 (Gridding), 8 channel\n");
	}

TIMER_ST

	if (1) {	// GE
		vd = 0;
		raw = [RecImage imageWithPfile:@"P_rtf3.7" RECCTL:&ctl];		// 3.18 sec (first time)
		coil = GE_Card_8_new;
	} else {
		vd = 1;
	//	raw = [RecImage imageWithToshibaFile:@"src_Toshiba/Run77.7683.07"];		// 3D pw
	//	raw = [RecImage imageWithToshibaFile:@"../toshiba_images/PaddleWheel.7683.11"];		// 3D pw
		raw = [RecImage imageWithToshibaFile:@"../toshiba_images/2015-9-11/Run124.7718.09"];	// 3D pw
		coil = Coil_None;
	}
	if (raw == nil) {
		printf("image not found\n");
		return 0;
	}
	[raw setName:@"raw"];
TIMER_END("read Pfile ")
	if (vd == 0) {
		printf("da_xres : %d\n", ctl.da_xres);
		printf("da_yres : %d\n", ctl.da_yres);
		printf("rc_xres : %d\n", ctl.rc_xres);
		printf("rc_yres : %d\n", ctl.rc_yres);
	}
	
// these are created by imageWithPfile:
	rd = [RecLoop findLoop:@"Read"];
	pe = [RecLoop findLoop:@"Phase"];
	sl = [RecLoop findLoop:@"Slice"];
	ch = [RecLoop findLoop:@"Channel"];

//raw = [raw combineForLoop:ch];
//[raw logP1];
	[raw saveAsKOImage:@"../test_img/test_raw.img"];
//exit(0);
//	lc = [RecLoopControl controlForImage:raw];
	lc = [raw control];

// single ch for debugging
	if (single) {
		raw_single = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:sl, pe, rd, nil];
		[raw_single setName:@"raw_single"];
		[[lc loopIndexForLoop:ch] setCurrent:4];
		[raw_single copyImage:raw withControl:lc];
		raw = raw_single;	// replace (discard original)
	}
	if (vd == 0) {
	// rtf3 seq was wrong...
		[raw xFlip];
	// slice order ???
		[raw flipForLoop:sl];
	TIMER_END("flipForLoop ")

	// adjust kz center
		[raw fft1d:sl direction:REC_INVERSE];		// 2.28 sec
	TIMER_END("fft1d ")
		[raw shift1d:sl];						// 1.11 sec
	TIMER_END("shift1d ")
	//	[sl setCenter:10];
		[raw fft1d:sl direction:REC_FORWARD];		// 4.61 sec (forward:3.64 sec)
	TIMER_END("fft1d ")

	// zero-fill "Read" to 256
	//	rdZF = [RecLoop loopWithName:@"rdZF" dataLength:256];
	//	[raw replaceLoop:rd withLoop:rdZF];		// 0.93 sec
	//	rd = rdZF;
		rd = [raw zeroFillToPo2:rd];
TIMER_END("zerofillLoop ")
	} else
	if (vd == 1) {	// Toshiba
		sl = [raw zeroFillToPo2:sl];
		[raw fft1d:sl direction:REC_FORWARD];
	//	[raw fft1d:rd direction:REC_INVERSE];
	}

//[raw saveAsKOImage:@"../test_img/test_raw_zf.img"];
	[raw radPhaseCorr];
//[raw saveAsKOImage:@"../test_img/test_pcorr_raw.img"];
	[raw fft1d:[raw xLoop] direction:REC_FORWARD];

//exit(0);

// paddle wheel config
	if (single) {
		pw = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:pe, sl, rd, nil];
	} else {
		pw = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:ch, pe, sl, rd, nil];
	}
	[pw setName:@"pw"];
	[pw copyImage:raw];
TIMER_END("copyImage ")
	[pw saveAsKOImage:@"../test_img/test_pw.img"];
TIMER_END("saveAsKOImage ")

//raw = [pw sliceAtIndex:1 forLoop:ch];
//[raw saveAsKOImage:@"../test_img/test_pw_ch0.img"];
//raw = [pw removeSliceAtIndex:1 forLoop:ch];
//[raw saveAsKOImage:@"../test_img/test_pw_ch1.img"];
//exit(0);
//	[pw saveToFile:@"../test_img/test_pw.recimg" relativePath:YES];
	if (!single) {
		[pw pcorr];
TIMER_END("pcorr ")
		pw_comb = [pw combineForLoop:ch];
	//	pw_comb = [pw combinePWForLoop:ch withCoil:GE_Card_8_new];
	//	pw_comb = [pw avgForLoop:ch];
TIMER_END("combineForLoop ")
		[pw_comb saveAsKOImage:@"../test_img/test_pw_comb.img"];
TIMER_END("saveAsKOImage ")
	}
	[raw fft1d:rd direction:REC_INVERSE];		// 0.44 sec (8ch), time: 0.046772 (sec) single
TIMER_END("fft1d ")
	[raw saveAsKOImage:@"../test_img/test_grid_raw.img"];

// create manually ...
//	kx = [RecLoop loopWithName:@"X" dataLength:ctl.rc_xres];	// square
//	ky = [RecLoop loopWithName:@"Y" dataLength:ctl.rc_xres];	// square
	kx = [RecLoop loopWithName:@"X" dataLength:256];	// square
	ky = [RecLoop loopWithName:@"Y" dataLength:256];	// square

// gridding
	traj = [RecImage imageOfType:RECIMAGE_KTRAJ withLoops:pe, rd, nil];	// traj for 256 x 300
	[traj initRadialTraj];
//[traj plotTraj:@"traj_rad.dat"];

	// reject test
	if (1) {
		int		i;
		float	*p = [traj data] + [traj dataLength] * 2;	// density
		int		xDim = [traj xDim];
		
		for (i = 0; i < xDim; i++) {
			p[10 * xDim + i] = 0;
			p[20 * xDim + i] = 0;
			p[183 * xDim + i] = 0;
		}
	}

	if (single) {
		img = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:sl, ky, kx, nil];
	} else {
		img = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:ch, sl, ky, kx, nil];
	}
//	lc = [RecLoopControl controlForImage:img];
	lc = [img control];

//	[img grid2dWithTrajectory:traj andData:raw]; // Op version : time: 0.8 sec single, 8.0  sec 8ch
//									// CL version : time: 3.2 sec single, 23.0 sec 8ch

	if (0) {
		// test CL version
		[img grid2d_CL_withTrajectory:traj andData:raw];	// Op version : time: 0.8 sec single, 8.0  sec 8ch

	} else {
		RecImage *wt;
		grid = [RecGridder gridderWithTrajectory:traj andRecDim:[img xDim]];
		wt = [traj weight];
		[wt saveAsKOImage:@"../test_img/test_weight.img"];
		[grid grid2d:raw to:img];
	}
	if (vd == 1) {
		[img yFlip];
	}

TIMER_END("grid2d ")

	[img saveAsKOImage:@"../test_img/test_grid.img"];
	[img saveToFile:@"../test_img/test_grid" relativePath:YES];

if (1) {
	raw = [img copy];
	[raw fft2d:REC_INVERSE];
	[raw fft1d:[img zLoop] direction:REC_INVERSE];
	[raw logP1];
	[raw saveAsKOImage:@"../test_img/test_grid_k.img"];
}

TIMER_END("saveAsKOImage ")
	if (!single) {
		img = [img combineForLoop:ch withCoil:coil];
TIMER_END("combineForLoop: withCoil: ") // 5.703851 (sec) combineForLoop: withCoil: 
		[img saveAsKOImage:@"../test_img/test_grid_comb.img"];
	}
//	img = [img sumForLoop:sl];
//	[img saveAsKOImage:@"../test_img/test_grid_proj.img"];

TIMER_TOTAL

	return 0;
}

// make num phantom for gridding
RecImage *
mk_proj(int xdim, int nproj)
{
	int			i, j, skip;
	RecImage	*img;
	float		*p;
	float		mg, r, d = xdim * 0.35;

	img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:xdim yDim:nproj];
	p = [img data];
	skip = [img skipSizeForLoop:[img yLoop]];
	for (j = 0; j < xdim; j++) {
		r = (float)j - xdim/2;
		mg = d*d - r*r;
		if (mg < 0) mg = 0;
		mg = sqrt(mg);
		for (i = 0; i < nproj; i++) {
			p[i * skip + j] = mg;
		}
	}
	return img;
}

// run test2() first to generate multi-ch image (test_grid.recimg)
int
test_comb()
{
	RecImage	*img;
	RecLoop		*ch;

	printf("test_comb\n");
	img = [RecImage imageFromFile:@"../test_img/test_grid.recimg" relativePath:YES];
	ch = [RecLoop findLoop:@"Channel"];
TIMER_ST
//	img = [img combineForLoop:ch withCoil:GE_Card_8_new];
//	img = [img combineForLoop:ch];		//  time: 1.031060 (sec) combineForLoop:
//	img = [img complexCombineForLoop:ch];
	img = [img complexCombineForLoop:ch withCoil:GE_Card_8_new];
TIMER_END("combineForLoop: ")
	[img saveAsKOImage:@"../test_img/test_grid_comb.img"];
exit(0);

	img = [RecImage imageFromFile:@"../test_img/test_pw.recimg" relativePath:YES];
	ch = [RecLoop findLoop:@"Channel"];
TIMER_END("load/save: ")
//	img = [img combinePWForLoop:ch withCoil:GE_Card_8_new];
	img = [img combineForLoop:ch];		//  time: 1.031060 (sec) combineForLoop:
TIMER_END("combineForLoop: ")
	[img saveAsKOImage:@"../test_img/test_pw_comb.img"];

	return 0;
}

// grid2 test
int
test3()
{
	RecImage	*k;		// traj
	RecImage	*mp;	// map (difference with traj ?)
	RecImage	*d;		// data
	RecImage	*r;		// re-sampled k-data
	RecImage	*img;	// image
	RecImage	*dif;	// dif image
	RecLoop		*x, *y;
    RecGridder  *grid;
	float		*p;
	int			xdim = 256;
	int			nproj = 128;

	// =======　psf
	if (0) {
//		k = [RecImage pointImageWithReal:0 imag:0];
		k = [RecImage pointImageOfType:RECIMAGE_KTRAJ];
		p = [k data];
		p[0] = 0.0; p[1] = 0.0; p[2] = 1.0;
		d = [RecImage pointImageWithReal:1 imag:0];
		x = [RecLoop loopWithName:@"x" dataLength:256];
		y = [RecLoop loopWithName:@"y" dataLength:256];
		img = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:y, x, nil];
		grid = [RecGridder gridderWithTrajectory:k andRecDim:[img xDim]];

		[grid grid2d:d to:img];
		[img saveAsKOImage:@"../test_img/psf.img"];
		exit(0);
	}

	// ====== mag fine tune =======
	system("rm ../test_img/test3_*.img");
// rad trajectory
	k = [RecImage imageOfType:RECIMAGE_KTRAJ xDim:xdim yDim:nproj];
//	[k initRadialTraj];
	[k initGoldenRadialTraj];

// testing density modulation
	if (1) {
		int			i, j;
		float		*wt;
		RecImage	*w;
		
		wt = [k data] + [k dataLength] * 3;
		for (i = 0; i < nproj; i++) {
			for (j = 0; j < xdim; j++) {
				wt[i * xdim + j] = (cos((float)i * 50 * M_PI / nproj) + 1) * 0.5;	// weighting
			}
		//	for (j = 0; j< 90; j++) {
		//		wt[i * xdim + j] = 0;	// selection flag
		//	}
		}
		wt = [k data] + [k dataLength] * 2;
		for (i = 0; i < nproj; i++) {
			for (j = 0; j< 90; j++) {
				wt[i * xdim + j] = 0;	// selection flag
			}
				
		}
		[k saveAsKOImage:@"../test_img/test3_k.img"];
		w = [k copy];
		[w takePlaneAtIndex:3];
		[w saveAsKOImage:@"../test_img/test3_w.img"];
	}

// make rad raw data
	d = mk_proj(xdim, nproj);
	[d saveAsKOImage:@"../test_img/test3_proj.img"];	// sin
	[d fft1d:[d xLoop] direction:REC_INVERSE];
	[d saveAsKOImage:@"../test_img/test3_raw.img"];		// k

	if (0) {	// signal weighting
		int		i, j;
		float	*p, *q;
		
		p = [d real];
		q = [d imag];
		for (i = 0; i < nproj; i++) {
			for (j = 0; j < xdim; j++) {
				if (i % 3 != 0) {
					p[i * xdim + j] *= 0.1;
					q[i * xdim + j] *= 0.1;
				}
			}
		}
		[k saveAsKOImage:@"../test_img/test3_k.img"];
	}

// gridding
	img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:xdim yDim:xdim];
	grid = [RecGridder gridderWithTrajectory:k andRecDim:xdim];
	RecImage *wt = [grid gridWeight];
	[wt saveAsKOImage:@"../test_img/test3_weight.img"];
	
	[grid grid2d:d to:img];
	[img saveAsKOImage:@"../test_img/test3_img.img"];	// initial
	[img fft2d:REC_INVERSE];
	[img saveAsKOImage:@"../test_img/test3_img_ft.img"];

// reproj
	if (0) {
		mp = [k trajToMap];	// scale is different ###
		dif = [RecImage imageWithImage:img];
		[dif fft2d:REC_INVERSE];
		r = [d copy];	// copy loop dim too
		[r resample:dif withMap:mp];
		
		[r subImage:d];
		[r saveAsKOImage:@"../test_img/test3_dif_k.img"];		// k
		[r fft1d:[r xLoop] direction:REC_FORWARD];
		[r saveAsKOImage:@"../test_img/test3_dif.img"];		// k
	}

	return 0;
}

void
lanczos_kern_test(int len, int order)
{
    float   *kern;
    float   *dc_err;
    float   w, x;
    int     i, k, n;
    BOOL    dc_corr = YES;

// Lanczos kernel
	kern = (float *)malloc(sizeof(float) * (len + 1));
	for (i = 0; i <= len; i++) {
		if (i == 0) {
			kern[i] = 1.0;
		} else {
			x = (float)i * order * M_PI / len;
			w = (sin(x) / x) * (sin(x/order) / (x/order));
		//	w = (sin(x) / x);
			kern[i] = w;
		}
	}

// DC correction
    if (dc_corr) {
        n = (int)len / order;
        dc_err = (float *)malloc(sizeof(float) * (n + 1));
        for (i = 0; i <= n; i++) {
            dc_err[i] = 0;
        }
    // pos side
        for (k = 0; k < order; k++) {
            for (i = 0; i <= n; i++) {
                w = kern[k * n + i];
                dc_err[i] += w;
            }
        }
    // neg side
        for (k = 0; k < order; k++) {
            for (i = 0; i <= n; i++) {
                w = kern[k * n + n - i];
                dc_err[i] += w;
            }
        }
    // error component
        for (i = 0; i <= n; i++) {
            dc_err[i] -= 1.0;
        //    printf("%d %f\n", i, dc_err[i]);
        }
    // kernel correction
        for (k = 0; k < order; k++) {
            for (i = 0; i <= n; i++) {
         //   for (i = 1; i < n; i++) {
            //    kern[k * n + i] -= dc_err[i] / (order * 2);
                kern[k * n + i] = dc_err[i] / (order * 2);
            }
        }
        free(dc_err);
    }
	// === approximation ===
	for (i = 0; i <= len; i++) {
		float x, est;
		x = (float)i * M_PI * order / len;
		est = - 0.000945 * sin(x) * sin(x) - 0.000031 * sin(x*2) * sin(x*2) - 0.000005 * sin(x*3) * sin(x*3);
		printf("%d %8.8f %f %8.8f\n", i, kern[i], est, kern[i] - est);;
	}
}

// warp with single map file
// functions correctly, but malloc error occurs #####
//		#### with z-loop only, occurs withtout save step
int
test4()
{
	RecImage		*src, *dst;
	float			xyScale = 2.8;
	float			zScale = 8.0;
	int				i, d;
	float			x;

//	src = [RecImage imageWithKOImage:@"../test_img/test_grid_comb.img"];	// PW img, combined, 256 x 256 x 64
//	src = [RecImage imageWithKOImage:@"../test_img/test_pw_comb.img"];	// PW img, combined, 256 x 64 x 300
//	src = [RecImage imageWithKOImage:@"../test_img/img2_03.img"];			// PW img, combined, 256 x 256 x 64
//	src = [RecImage imageWithKOImage:@"../test_img/test1_image2.img"];		// 3D, 256 x 64
	src = [RecImage imageWithKOImage:@"../test_img/test0_1.img"];		// 3D, 256 x 64
//	src = [RecImage imageOfType:RECIMAGE_REAL xDim:256 yDim:256];
//	[src setConst:1.0];

// kern test
	if (0) {
		lanczos_kern_test(300, 3);
		exit(0);
	}
TIMER_ST
//dst = [src shift1dLoop:[src yLoop] by:1.0];
//[dst saveAsKOImage:@"../test_img/test_shift_y.img"];
//exit(0);

	printf("zscale\n");
	dst = [src scale1dLoop:[src xLoop] by:128.0 to:256];
	dst = [dst scale1dLoop:[dst yLoop] by:64.0 to:256];
//	[dst swapLoop:[dst zLoop] withLoop:[dst yLoop]];
	[dst saveAsKOImage:@"../test_img/test_scale_x.img"];
TIMER_END("z scale ")		//  time: 0.768174 (sec) resample 
	printf("xy scale\n");
	src = dst;
	dst = [src scaleXBy:xyScale andYBy:xyScale];
TIMER_END("xy scale ")		//  time: 0.768174 (sec) resample 
	[dst saveAsKOImage:@"../test_img/test_scale_xy.img"];


	return 0;
}

// warp with param loop
int
test5()
{
	RecImage		*map, *param;
	RecImage		*src, *dst;
	RecLoop			*lp, *ch;
	int				i, len, n;
	float			*p;

//	src = [RecImage imageWithKOImage:@"../test_img/test_pw_comb.img"];              // PW, 300 x 64 x 245
	src = [RecImage imageFromFile:@"../test_img/test_pw.recimg" relativePath:YES];  // PW, 8 x 300 x 64 x 256
	[src dumpLoops];
	dst = [RecImage imageOfType:[src type] withImage:src];		// dst has same dim as src
	n = [src dim];

	lp = [[src loops] objectAtIndex:n - 3];
	len = [lp dataLength];
	param = [RecImage imageOfType:RECIMAGE_REAL withLoops:lp, nil];
	p = [param data];
	for (i = 0; i < len; i++) {
		p[i] = (float)i * M_PI * 2 / len;
	}
TIMER_ST
	map = [dst mapForRotate:param];
	[map saveAsKOImage:@"../test_img/test_map.img"];
TIMER_END("map ")	// 0.357959 (sec) map
	[dst resample:src withMap:map];
TIMER_END("resample ") // 11.507804 (sec) resample
	[dst saveAsKOImage:@"../test_img/test_warp.img"];
TIMER_END("save image ");
	ch = [RecLoop findLoop:@"Channel"];
	if ([dst containsLoop:ch]) {
		src = [dst combineForLoop:ch];
	}
TIMER_END("combine "); // 15.718359 (sec) combine
	[src saveAsKOImage:@"../test_img/test_warp_comb.img"];
TIMER_END("save image ");

TIMER_TOTAL

	return 0;
}

// read-only scan params (ImageInfo)
typedef struct scan_param {
	// input (readonly global)
// recon dim
//	int		m_fftDim0_x, m_fftDim0_y, m_fftDim0_z; // -> image obj
// raw data dim
	int		m_dataDim_x, m_dataDim_y, m_dataDim_z;
// RollOff param
	int		m_firstRegridCoord;
	int		m_rollOffNum;
	int		m_firstRoSample[1];
	int		m_numRoSamples[1];
	int		m_imageIndexForArray;
	int		m_numDataSets;
} scan_param;

void
init_scan_param(scan_param *sp)
{
// raw data size
	sp->m_dataDim_x = 128;
	sp->m_dataDim_y = 128;
	sp->m_dataDim_z = 1;
// RollOff param
	sp->m_firstRegridCoord = 0;
	sp->m_rollOffNum = 4;
	sp->m_firstRoSample[0] = 0;
	sp->m_numRoSamples[0] = 128;
	sp->m_imageIndexForArray = 0;
	sp->m_numDataSets = 1;
}

//===
void
ApplyRollOff(RecImage *img, scan_param *sp)
{
	// local
	int				leftBegin, leftEnd, rightBegin, rightEnd;
    int				offset;
	// RecImage object
	float			*p, *q;
	RecLoopControl	*lc = [img control];
	int				xDim = [img xDim];
	int				yDim = [img yDim];
	int				zDim = [img zDim];
	int				i, j, k, loopLen;	
	
// CalcRollOffReadoutDataBoundary
	offset = (xDim - sp->m_dataDim_x)/2;

	leftBegin  = sp->m_firstRoSample[ sp->m_imageIndexForArray ] + offset;
	rightEnd   = leftBegin + sp->m_numRoSamples[ sp->m_imageIndexForArray ] - 1; // inclusive

	leftBegin  += sp->m_firstRegridCoord;
	rightEnd   -= sp->m_firstRegridCoord;

	leftEnd    = leftBegin + sp->m_rollOffNum;
	rightBegin = rightEnd  - sp->m_rollOffNum;
// ====

	[lc rewind];
	[lc deactivateInner];	// deactivate x loop
	loopLen = [lc loopLength];
	for (i = 0; i < loopLen; i++) {
		p = [img currentDataWithControl:lc];
		q = p + [img dataLength];
		for (j = 0; j < leftBegin; j++) {
			p[j] = q[j] = 0;
		}
		for (j = rightEnd+1; j < xDim; j++) {
			p[j] = q[j] = 0;
		}
		for (j = leftBegin; j < leftEnd; j++) {
			p[i] *= (float)(j - leftBegin) / sp->m_rollOffNum;
			q[i] *= (float)(j - leftBegin) / sp->m_rollOffNum;
		}
		for (j = rightEnd; j > rightBegin; j--) {
			p[i] *= (float)(rightEnd - j) / sp->m_rollOffNum;
			q[i] *= (float)(rightEnd - j) / sp->m_rollOffNum;
		}
		[lc increment];
	}
}

void
PerformT2Correction(RecImage *img, scan_param *sp)
{
}

// VROM test
int
test6()
{
	RecImage		*img;
	RecLoop			*lp;
    LP_DIM          lp_dim;

	printf("Test 6 (Siemens)\n");

	img = [RecImage imageWithMeasAsc:@"../test_img/meas.asc" andMeasData:@"../test_img/meas.out" lpDim:&lp_dim];
//	img = [RecImage imageWithMeasAsc:@"../test_img/meas.asc_nci5" andMeasData:@"../test_img/meas.out_nci5" lpDim:&lp_dim];


	[img saveAsKOImage:@"../test_img/test_siemens_raw.img"];

	if (img == nil) {
		printf("image not found\n");
	}
    [img fft2d:REC_FORWARD];
    [img freqCrop];

// ReconProcessor test
	scan_param sp;
	
	ApplyRollOff(img, &sp);
	PerformT2Correction(img, &sp);



	[img saveAsKOImage:@"../test_img/test_siemens_0.img"];
    if (lp_dim.epifactor > 1 && lp_dim.nShot == 1) {
        [img epiPcorr];
    }
	[img pcorr];
    [img saveAsKOImage:@"../test_img/test_siemens_1.img"];

	return 0;
}

int
test7()
{
	RecImage	*src, *dst;

	src = [RecImage imageWithKOImage:@"../nciRecon/IMG_fus1"];
TIMER_ST
	dst = [src oversample];			// new:6.151024, old:4.271497
TIMER_END("oversample ")
	[dst saveAsKOImage:@"../test_img/test_oversample.img"];

	return 0;
}

// cos filter
int
test8()
{
	int			i, n = 256;
	RecImage	*img = [RecImage imageOfType:RECIMAGE_REAL xDim:n];
	float		x, *y;

	y = [img data];
	[img addGWN:1.0 relative:NO];

if (1) {
float mn, vr;
mn = [img meanVal];
vr = [img varWithMean:mn];
printf("%f %f\n", mn, sqrt(vr));
exit(0);
}

	for (i = 0; i < n; i++) {
		x = (float)i * M_PI / n;
		y[i] += cos(x) + 1.0;
		printf("%d %f\n", i, y[i]);
	}
	
	[img cosFilter:[img xLoop] order:4 keepDC:NO];

	for (i = 0; i < n; i++) {
		printf("%d %f\n", i, y[i]);
	}

    return 0;
}

// rot-shift (rigid body registration). move to nciRec when finished
// test outerloops... phs(3) x avg(100), avg(100) only
// make general hires peak finding proc (1D & 2D) with Lanczos interp
int
test9()
{
    RecImage        *ref, *rot, *param, *corr;;
	float			*p, *q;
	float			mx, sft;
	NSPoint			pt;
	int				i, j, n = 100;
	int				xDim, yDim;
	RecLoop			*xLp, *yLp, *zLp;

    system("rm ../test_img/test9_*.*");

	ref = [RecImage imageWithKOImage:@"I00000.img"];
	[ref removePointLoops];
	[ref magnitude];
	xLp = [ref xLoop];
	yLp = [ref yLoop];
	zLp = [RecLoop loopWithDataLength:n];

	rot = [RecImage imageOfType:RECIMAGE_REAL withLoops:zLp, yLp, xLp, nil];
	[rot copyImage:ref];
//[rot saveAsKOImage:@"../test_img/test9_image0"];
	param = [RecImage imageOfType:RECIMAGE_MAP withLoops:zLp, nil];	// array of 2d vectors
	p = [param data];
	q = p + [param dataLength];

// findpeak test (1D, 2D)
	if (1) {
		BOOL d1 = NO;
		mx = 3.0;
		printf("0 to %4.2f pixels, %d steps\n", mx, n);
		for (i = 0; i < n; i++) {
			p[i] = mx * i / n;
			if (d1) {
				q[i] = 0;
			} else {
				q[i] = p[i] * 0.3;
			}
		}
		rot = [rot ftShiftBy:param];
		[rot saveAsKOImage:@"../test_img/test9_image1"];
		corr = [rot xyCorrelationWith:ref];
		[corr saveAsKOImage:@"../test_img/test9_image2"];
		xDim = [corr xDim];
		yDim = [corr yDim];
		for (i = 0; i < n; i++) {
			if (d1) {
				p = [corr data] + i * xDim * yDim + xDim * yDim / 2;
				sft = Rec_find_peak(p, 1, xDim);
				printf("%d %f\n", i, sft);
			} else {
				p = [corr data] + i * xDim * yDim;
				pt = Rec_find_peak2(p, xDim, yDim);
				printf("%d %f %f\n", i, pt.x, pt.y);
			}
		}
	}
//exit(0);
// rotation (1D param)
	if (0) {
		mx = 0.02;
		printf("0 to %4.2f PI, %d steps\n", mx, n);
		for (i = 0; i < n; i++) {
			p[i] = M_PI * mx * i / n;
		}
		rot = [rot rotBy:param];
		[rot saveAsKOImage:@"../test_img/test9_image1"];
	}

// translation (2D param)
	if (1) {
		rot = [RecImage imageOfType:RECIMAGE_REAL xDim:64 yDim:64 zDim:4];
		[rot setConst:1.0];
		[rot zeroFill:[rot xLoop] to:127];
		[rot zeroFill:[rot yLoop] to:128];
		param = [RecImage imageOfType:RECIMAGE_MAP withLoops:[rot zLoop], nil];	// array of 2d vectors
		p = [param data];
		q = p + [param dataLength];

		xDim = [rot xDim];
		yDim = [rot yDim];
		for (i = 0; i < 4; i++) {
		//	p[i] = mx * (float)i / n / xDim;	// FOV frac (0 - 0.039)
//printf("shift = %f (pixels), %f frac\n", p[i] * xDim, p[i]);
		//	q[i] = p[i] * 0.3;
			p[i] = (float)i * 1.5 / xDim;
			q[i] = 0;
		}
		rot = [rot ftShiftBy:param];
		[rot saveAsKOImage:@"../test_img/test9_image2"];
		exit(0);
	}

//    [rot rotShift];
	rot = [rot rotShiftForEachOfLoop:nil scale:2.0];

    [rot saveAsKOImage:@"../test_img/test9_image10.img"];

    return 0;
}

// block
int
test10()
{
    RecImage        *img, *ref, *gr;
    RecLoopControl  *lc;
    RecLoopIndex    *li;

    system("rm ../test_img/test10_*.*");

	img = [RecImage imageWithKOImage:@"../test_img/test3_img.img"];
    [img saveAsKOImage:@"../test_img/test10_image1.img"];

	gr = [img copy];
	[gr grad1dForLoop:[gr xLoop]];
	[gr saveAsKOImage:@"../test_img/img_grad_x.img"];
	gr = [img copy];
	[gr grad1dForLoop:[gr yLoop]];
	[gr saveAsKOImage:@"../test_img/img_grad_y.img"];
	gr = [img copy];
	[gr grad2d];
	[gr saveAsKOImage:@"../test_img/img_grad_2d.img"];
exit(0);

    // ref is 2nd image (maybe a method for this is necessary)
    // sliceForControl:
    ref = [RecImage imageOfType:[img type] withLoops:[img yLoop], [img xLoop], nil];
	lc = [img control];
    li = [lc topLoopIndex];	// top among active
	[li deactivate];
    [li setCurrent:1];
    [ref copyImage:img withControl:lc];

    [ref magnitude];
    [ref saveAsKOImage:@"../test_img/test10_image2.img"];

    [img divImage:ref withNoiseLevel:0.01];
    [img saveAsKOImage:@"../test_img/test10_image3.img"];

    return 0;
}

int
test11()
{
    RecImage    *img;

    system("rm ../test_img/test11_*.*");
    img = [RecImage imageOfType:RECIMAGE_REAL xDim:256 yDim:256];
    [img setConst:1.0];
    [img fGauss2DLP:0.5];
    [img saveAsKOImage:@"../test_img/test11_image0.img"];

    [img setConst:1.0];
    [img fGauss2DHP:0.5];
    [img saveAsKOImage:@"../test_img/test11_image1.img"];

    return 0;
}

// SCIC
int
test12()
{
	RecImage	*img , *imgH, *mask;

	printf("test12 SCIC\n");
//	img = [RecImage imageWithKOImage:@"../test_img/test_grid_comb.img"];
//	img = [RecImage imageWithKOImage:@"../rtfRecon/img_S.img"];
//	img = [RecImage imageWithKOImage:@"../rtfRecon/img.img"];
	img = [RecImage imageWithKOImage:@"../test_img/test3_img.img"];
// SCIC
//	[img SCIC];
//	[img saveAsKOImage:@"../test_img/test_SCIC.img"];

// test hi-pass
	imgH = [img oversample];
	[imgH gauss2DHP:1.0 frac:1.0];
	[imgH saveAsKOImage:@"../test_img/test_HP.img"];
	imgH = [imgH avgForLoop:[imgH zLoop]];
	[imgH saveAsKOImage:@"../test_img/test_HP_avg.img"];

// test half gauss
	mask = [img copy];
	[mask thresAtSigma:500.0];	// threshold at sg * signa of Reighley noise dist
	[mask saveAsKOImage:@"../test_img/test_12_mask.img"];
	[mask hGauss2DLP:0.25];
	if ([mask minVal] < 0) {
		printf("### neg value deteceted\n");
	}
	[mask saveAsKOImage:@"../test_img/test_12_gGauss.img"];

// test BPF
	mask = [RecImage imageOfType:RECIMAGE_REAL xDim:256 yDim:256];
	[mask setConst:1.0];
	[mask fGauss1DBP:0.1 center:0.25 forLoop:[mask xLoop]];
	[mask saveAsKOImage:@"../test_img/test_12_fGaussBPF.img"];
	mask = [img copy];
	[mask gauss1DBP:0.1 center:0.25 forLoop:[mask xLoop]];
	[mask saveAsKOImage:@"../test_img/test_12_gaussBPF.img"];

	return 0;
}

int
test13()
{
	RecImage	*img;

	printf("test13 Tri filter\n");
	img = [RecImage imageOfType:RECIMAGE_REAL xDim:256 yDim:256];
	[img setConst:1.0];

//	[img fTriWin1DforLoop:[img xLoop] center:0.0 width:0.5];
//	[img rectWin1DforLoop:[img xLoop] width:0.5];
	[img fLanczWin1DforLoop:[img xLoop] center:0 width:0.5];
	[img saveAsKOImage:@"../test_img/test_Tri.img"];

// test hi-pass

	return 0;
}

int
test14()
{
    NSArray     *paths, *URLs;
	NSURL		*url1, *url2;
//    NSString    *path1 = @"Dicom/CT0001.dcm";
//    NSString    *path1 = @"Dicom/IM1";
    NSString    *path1 = @"Dicom/IM-0001-0001.dcm";
    NSString    *path2 = @"Dicom/CT0002.dcm";
    RecImage    *img;

	[RecImage initDicomDict];
//    paths = [NSArray arrayWithObjects:	[NSURL fileURLWithPath:path1],
//										[NSURL fileURLWithPath:path2], nil];

//    paths = [NSArray arrayWithObjects:path1, path2, nil];
	url1 = [NSURL URLWithString:path1];
	url2 = [NSURL URLWithString:path2];
	URLs = [NSArray arrayWithObjects:url1, nil];
    img = [RecImage imageWithDicomFiles:URLs];
    [img saveAsKOImage:@"Dicom/dicom.img"];

    return 0;
}

int
test15()
{
    RecImage        *img, *corr;
    Rec3DRef        *ref1, *ref2;
    RecLoopControl  *lc;
//    float           mn, sd;
	int				wx = 15;
	int				wz = 1;
	int				xDim = wx * 2 + 1;
	int				zDim = wz * 2 + 1;
    
    img = [RecImage imageWithKOImage:@"../test_img/test1_image2.img"];
//    lc = [RecLoopControl controlForImage:img];
	lc = [img control];
    ref1 = [Rec3DRef refForImage:img control:lc];

    [ref1 setX:70 y:70 z:10 nX:32 nY:32 nZ:5];
    ref2 = [ref1 copy];
//    mn = [ref1 mean];
//    sd = [ref1 sdWithMean:mn];
//    printf("mean = %f, sd = %f\n", mn, sd);

    [[ref1 makeImage] saveAsKOImage:@"../test_img/test15_image0.img"];
	corr = [RecImage imageOfType:RECIMAGE_REAL xDim:xDim yDim:xDim zDim:zDim];
TIMER_ST
    [ref1 normalizedCorrelationWith:ref2 result:corr];
TIMER_END("corr");
    [corr saveAsKOImage:@"../test_img/test15_corr.img"];

    return 0;
}

// color space
int
test16()
{
	RecImage		*img;
	int				i, j, ix;
	int				xDim, yDim;
	float			mg, phs, x, y, r;
	float			*p, *q;

	xDim = yDim = 256;
	img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:xDim yDim:yDim];
	p = [img data];
	q = p + [img dataLength];

	for (i = ix = 0; i < yDim; i++) {
		y = ((float)i - yDim/2) * 2 / yDim;
		for (j = 0; j < xDim; j++) {
			x = ((float)j - xDim/2) * 2 / xDim;
			r = sqrt(x*x + y*y);
			if (r > 1.0) {
				mg = 0;
			} else {
				mg = r * 4000;
			}
			phs = atan2(y, x);
			p[ix] = mg * cos(phs);
			q[ix] = mg * sin(phs);
			ix++;
		}
	}
	[img saveAsKOImage:@"../test_img/test_color.img"];
	return 0;
}

void
make_half_test(RecImage *raw)
{
	int				i, j, xDim, yDim;
	RecLoopControl	*lc;
	float			*p, *q;
	int				st, ed, dataLength;
	int				hovr = 8;

	xDim = [raw xDim];
	yDim = [raw yDim];
	dataLength = [raw dataLength];
	
	// set half of lines to 0 (simulates half-fourier acquisision)
//	lc = [RecLoopControl controlForImage:raw];
	lc = [raw control];
	[lc deactivateXY];
	dataLength = [raw dataLength];
	
	st = yDim / 2 + hovr;
	ed = yDim;
	for (i = st; i < ed; i++) {
		p = [raw currentDataWithControl:lc line:i];
		q = p + dataLength;
		for (j = 0; j < xDim; j++) {
			p[j] = q[j] = 0;
		}
	}
}

// half fourier
// *multi-slice
// ## multi-coil
RecImage *
makeHalfData(RecImage *img, int fullY, int ovr)
{
	RecLoop			*newY;
	RecImage		*hf;
	int				ofs;

	ofs = (fullY - [img yDim]) / 2;
	newY = [RecLoop loopWithDataLength:fullY/2 + ovr];
	hf = [img copy];
	[hf replaceLoop:[hf yLoop] withLoop:newY offset:-ofs];

	return hf;
}

int
test17()
{
	RecImage		*img, *raw, *pw;
	RecLoop			*ch, *sl, *pe, *rd;
	RecLoop			*yLp;
	RECCTL			ctl;
	int				mode = 2;

	if (1) {
		int	ii, n1, n2;

		printf("in, down, up\n");
		for (ii = 1; ii <= 32; ii++) {
			n1 = Rec_down2Po2(ii);
			n2 = Rec_up2Po2(ii);
			printf("%d %d %d\n", ii, n1, n2);
		}
		exit(0);
	}

    system("rm ../test_img/test_half*.*");
	switch (mode) {
	case 0 :	// single slice
		raw = [RecImage imageWithPfile:@"P_hnex.7" RECCTL:&ctl];		// 256x256
		break;
	case 1 :	// multi-slice 2D
		raw = [RecImage imageWithPfile:@"P_3d.7" RECCTL:&ctl];
		[raw fft1d:[raw zLoop] direction:REC_FORWARD];
		raw = makeHalfData(raw, 256, 8);
		break;
	case 2 :	// multi-channel ### not working yet
		raw = [RecImage imageWithPfile:@"P_rtf3.7" RECCTL:&ctl];
        rd = [RecLoop findLoop:@"Read"];
        pe = [RecLoop findLoop:@"Phase"];
        ch = [RecLoop findLoop:@"Channel"];
        sl = [RecLoop findLoop:@"Slice"];
		[raw removePointLoops];
		[raw flipForLoop:sl];
        [raw fft1d:sl direction:REC_INVERSE];
        [raw shift1d:sl];
        pw = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:ch, pe, sl, rd, nil];
        [pw copyImage:raw]; // sinogram -> pw
		raw = pw;
		raw = makeHalfData(raw, 64, 8);
		[raw zeroFillToPo2:[raw xLoop]];
		break;
	}
[raw saveAsKOImage:@"test.img"];
//exit(0);

	yLp = [raw yLoop];
	[raw fft1d:[raw xLoop] direction:REC_FORWARD];

	[raw halfFT:yLp];	// half-fourier (1d), other axes have to be space

	[raw pfSwap:ctl.trans rot:ctl.rot];
	[raw saveAsKOImage:@"../test_img/test_half.img"];

	return 0;
}

// pcorr
int
test18()
{
	RecImage		*img;
	RecLoopControl	*lc;
	RecLoop			*lp;
	float			p0, p1;
	int				i, j, xDim = 256, yDim = 256;
	float			*p, *q;
	float			th, cs, sn;

	printf("pcorr test\n");

	img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:xDim yDim:yDim];
	lc = [img control];
	[lc deactivateLoop:[img xLoop]];
	[img addConst:1.0];

	p0 = 0.5 * M_PI;
	p1 = 5.0 * M_PI;
	for (i = 0; i < yDim; i++) {
		p = [img currentDataWithControl:lc];
		q = p + [img dataLength];
		Rec_corr1st(p, q, 1, xDim, -p1);	// ok
		Rec_corr0th(p, q, 1, xDim, -p0);	// ok
		[lc increment];
	}
	[img saveAsKOImage:@"../test_img/test_18_img1.img"];

	lp = [img xLoop];
TIMER_ST
//	[img pcorrForLoop:lp];		// ok
//	[img pcorr];	// 0.012985 (sec)			// ok
	[img pcorr2];	// 0.013751 (sec)
//	[img pcorr3];
TIMER_END("pcorr");
	[img saveAsKOImage:@"../test_img/test_18_img2.img"];

	return 0;
}

// primes less than 100
// 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 
// 53, 59, 61, 67, 71, 73, 79, 83, 89, 97
int
test19()
{
	RecImage	*img;
	RecLoop		*lp;
	float		*p, *q;
	int			i, j, k, ix;
	int			xDim = 240, yDim = 240, zDim = 200;
	float		x, y, r;

	printf("test 19\n");

// DFT test
if (0) {
	int	n = 2048;
	
	for (i = 0; i <= n; i++) {
		if (vDSP_DFT_zop_CreateSetup(NULL, i, vDSP_DFT_FORWARD) != NULL) {
			printf("%d\n", i);
		}
	}

	exit(0);
}

// convolution with zero-padding -> make method
if (0) {
	int			i, n = 99, np = 256;;
	RecImage	*img1, *img2;
	RecImage	*tmp1, *tmp2;
	float		*p;

	img1 = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:n];
	img2 = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:n];

	p = [img1 real];
	for (i = 0; i < n; i++) {
		p[i] = i + 100;
	}
	p = [img2 real];
	for (i = 0; i < n; i++) {
		p[i] = 100 - i;
	}
	[img1 saveAsKOImage:@"img_in1.img"];
	[img2 saveAsKOImage:@"img_in2.img"];

// reference
	tmp1 = [img1 copy];
	tmp2 = [img2 copy];

	[tmp1 fft1d:[tmp1 xLoop] direction:REC_FORWARD];
	[tmp2 fft1d:[tmp2 xLoop] direction:REC_FORWARD];
	[tmp1 multByImage:tmp2];
	[tmp1 fft1d:[tmp1 xLoop] direction:REC_INVERSE];
	[tmp1 saveAsKOImage:@"img_conv1.img"];

// test
	tmp1 = [img1 copy];
	tmp2 = [img2 copy];

	[tmp1 zeroFill:[tmp1 xLoop] to:np];
	[tmp2 cycFill:[tmp2 xLoop] to:np];
//	[tmp2 zeroFill:[tmp2 xLoop] to:np];
	[tmp1 saveAsKOImage:@"img_in21.img"];
	[tmp2 saveAsKOImage:@"img_in22.img"];
	[tmp1 fft1d:[tmp1 xLoop] direction:REC_FORWARD];
	[tmp2 fft1d:[tmp2 xLoop] direction:REC_FORWARD];
	[tmp1 multByImage:tmp2];
	[tmp1 fft1d:[tmp1 xLoop] direction:REC_INVERSE];
	[tmp1 crop:[tmp1 xLoop] to:n];
	[tmp1 saveAsKOImage:@"img_conv2.img"];


	exit(0);
}

// chirp-z test
if (0) {
	RecCftSetup			*setup;
	RecDftSetup			*setup_d;
	int					i, len = 150;
	DSPSplitComplex		src;


// setup
	setup = Rec_cftsetup(len);
	setup_d = Rec_dftsetup(len);
/*
	for (i = 0; i < setup->dim; i++) {
		printf("%d %f %f\n", i, setup->cp.realp[i], setup->cp.imagp[i]);
	}
	for (i = 0; i < setup->dim2; i++) {
		printf("%d %f %f\n", i, setup->cpf.realp[i], setup->cpf.imagp[i]);
	}
*/
// input
	src.realp = (float *)malloc(sizeof(float) * len);
	src.imagp = (float *)malloc(sizeof(float) * len);

	for (i = 0; i < len; i++) {
		src.realp[i] = src.imagp[i] = 0;
	}
	for (i = 0; i < 10; i++) {
		src.realp[i] = 1.0;
	}
	Rec_cft(setup,   &src, 1, REC_INVERSE);
//	Rec_dft(setup_d, &src, 1, REC_FORWARD);
	Rec_dft(setup_d, &src, 1, REC_FORWARD);
	for (i = 0; i < len; i++) {
		src.realp[i] /= len;
		src.imagp[i] /= len;
	}
	
	for (i = 0; i < len; i++) {
		printf("%d %f %f\n", i, src.realp[i], src.imagp[i]);
	}

	Rec_destroy_cftsetup(setup);
	Rec_destroy_dftsetup(setup_d);
	exit(0);
}

	img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:xDim yDim:yDim zDim:zDim];
	p = [img data];
	q = p + [img dataLength];
	for (k = 0; k < zDim; k++) {
	for (i = 0; i < yDim; i++) {
		for (j = 0; j < xDim; j++) {
			ix = k * xDim * yDim + i * xDim + j;
			r = (i - yDim/2) * (i - yDim/2) + (j - xDim/2 - 5) * (j - xDim/2 - 5);
			r = sqrt(r);
			if (r < xDim/4) {
				p[ix] = 1.0;
				q[ix] = 0.5 * j / xDim;
			}
		}
	}
	}

//lp = [img xLoop];

float mx = [img maxVal];
printf("mx = %f\n", mx);

TIMER_ST
for (i = 0; i < 1; i++) {
//	[img fft1d:[img yLoop] direction:REC_INVERSE];
//	[img fft1d:[img yLoop] direction:REC_FORWARD];
	[img gauss1DLP:0.2 forLoop:[img yLoop]];
}
TIMER_END("fft/dft");
//  time: 0.008075 (sec) fft/dft
// time: 1.354152 (sec) fft/dft  (pre-vDSP)
// time: 1.524338 (sec) fft/dft (using vDSP ###)
// time: 1.370247 (sec) fft/dft (no vDSP, using DSPSplitComplex)

mx = [img maxVal];
printf("mx = %f\n", mx);

	[img saveAsKOImage:@"../test_img/test_19_2.img"];
	return 0;
}

int
test20()
{
	RecImage		*img, *th;
	float			*p, *pp;
	float			*coef;
	int				order = 3;
	int				i, j, ix;
	int				xDim = 64, yDim = 64;
	RecDctSetup		*setup_d;
	RecChebSetup	*setup_c;
	BOOL			dct = NO;

	printf("test 20\n");

	setup_d = Rec_dct_setup(xDim, order);
	setup_c = Rec_cheb_setup(xDim, order);
	coef = (float *)malloc(sizeof(float) * order * order);

	th = [RecImage imageOfType:RECIMAGE_REAL xDim:xDim yDim:yDim];
	pp = [th data];
	img = [RecImage imageOfType:RECIMAGE_REAL xDim:xDim yDim:yDim];
	p = [img data];
//	q = p + [img dataLength];

// 1D
	if (0) {
		for (i = 0; i < xDim; i++) {
			pp[i] = (float)(i - xDim/2) * (i - xDim/2) / xDim;
		}
		if (dct) {
			Rec_dct_1d(pp, 1, coef, 1, setup_d, REC_INVERSE);
			Rec_dct_1d(p, 1, coef, 1, setup_d, REC_FORWARD);
		} else {
			Rec_cheb_1d(pp, 1, coef, 1, setup_c, REC_INVERSE);
			Rec_cheb_1d(p, 1, coef, 1, setup_c, REC_FORWARD);
		}
		for (i = 0; i < xDim; i++) {
			printf("%d %f %f\n", i, p[i], pp[i]);
		}
	}

	// RecImage method
	if (1) {
		RecImage	*img = [RecImage imageOfType:RECIMAGE_REAL xDim:64 yDim:64];
		RecImage	*coef;
		float		*p;
		int			i, j;
		
		p = [img data];
		for (i = 16; i < 48; i++) {
			for (j = 16; j < 48; j++) {
				p[i * 64 + j] = 1.0;
			}
		}
		coef = [img dct1d:[img xLoop] order:20];
		[coef saveAsKOImage:@"../test_img/test_20.img"];
		exit(0);
	}
// 2D
	coef[0] = 0.1; coef[1] = 0.2; coef[2] = 0.3;
	coef[3] = 0.4; coef[4] = 0.5; coef[5] = 0.6;
	coef[6] = 0.7; coef[7] = 0.8; coef[8] = 0.2;

	p = [img data];
	if (dct) {
		Rec_dct_2d(p, coef, setup_d, REC_FORWARD);
	} else {
		Rec_cheb_2d(p, coef, setup_c, REC_FORWARD);
	}
	[img saveAsKOImage:@"../test_img/test_20_1.img"];

	for (i = 0; i < order; i++) {
		for (j = 0; j < order; j++) {
			coef[i * order + j] = 0;
		}
	}
	if (dct) {
		Rec_dct_2d(p, coef, setup_d, REC_INVERSE);
	} else {
		Rec_cheb_2d(p, coef, setup_c, REC_INVERSE);
	}
	for (i = 0; i < order; i++) {
		for (j = 0; j < order; j++) {
			printf("%3.1f ", coef[i * order + j]);
		}
		printf("\n");
	}

	Rec_free_dct_setup(setup_d);
	Rec_free_cheb_setup(setup_c);
	free(coef);

	return 0;
}

int
test21()
{

	return 0;
}

int
test22()
{
	RecImage		*img;
	RecChebSetup	*setup;
	float			*coef;
	int				order = 5;
	int				xDim = 256;

	setup = Rec_cheb_setup(xDim, order);
	coef = (float *)malloc(sizeof(float) * order * order);
exit(0);
	

	img = [RecImage imageWithKOImage:@"../test_img/test3_img.img"];
TIMER_ST
	[img pcorrFine];
TIMER_END("pcorrFine");		// time: 1.831787 (sec) pcorrFine
	[img saveAsKOImage:@"../test_img/test_22.img"];

	return 0;
}

// rtf3, pw shift correction
int
test23()
{
	RecImage		*img, *ref, *cor, *sft, *map, *img0;
	RecLoopControl	*lc;
	int				xDim, yDim, i, nProj;
	NSPoint			pt;
	float			*p, *x, *y;

	img = [RecImage imageWithKOImage:@"../rtfRecon/pw.img"];
	ref = [RecImage imageWithKOImage:@"../rtfRecon/pwr0.img"];
	[ref copyLoopsOf:img];
TIMER_ST
	cor = [img xyCorrelationWith:ref];
TIMER_END("xyCorrelation");		// time: 1.460259 (sec) xyCorrelation
	[cor saveAsKOImage:@"../test_img/test_23.img"];
//exit(0);
	sft = [RecImage imageOfType:RECIMAGE_MAP withLoops:[cor zLoop], nil];
	x = [sft data];
	y = x + [sft dataLength];

	xDim = [cor xDim];
	yDim = [cor yDim];
	nProj = [cor zDim];
	lc = [cor control];
	[lc deactivateXY];
	for (i = 0; i < nProj; i++) {
		p = [cor currentDataWithControl:lc];
		pt = Rec_find_peak2(p, xDim, yDim);
		x[i] = pt.x / xDim;	// -0.5 .. 0.5
		y[i] = pt.y / yDim;	// -0.5 .. 0.5
		printf("%d %f %f\n", i, pt.x, pt.y);
		[lc increment];
	}
	map = [img mapForShift:sft];
	img0 = [RecImage imageWithImage:img];
    [img0 resample:img withMap:map];
	[img0 saveAsKOImage:@"../test_img/test23_c.img"];

	return 0;
}

int
test24()
{
    NSArray     *paths;
    NSString    *path1 = @"Dicom/prostate/1.DCM";
//    NSString    *path2 = @"Dicom/prostate/2.DCM";
    NSString    *path2 = @"Dicom/prostate/3.DCM";
//    NSString    *path2 = @"Dicom/prostate/4.DCM";
//    NSString    *path2 = @"Dicom/prostate/5.DCM";
    RecImage    *img1, *img2;
	RecImage	*hist, *t2c;
	float		frac;

	img1 = [RecImage imageOfType:RECIMAGE_REAL xDim:128 yDim:128 zDim:10];
	img2 = [RecImage imageWithImage:img1];
	[img1 addGWN:1.0 relative:NO];
	[img2 addGWN:1.0 relative:NO];
//	[img1 addConst:2.0];
//	[img2 addConst:2.0];
	hist = [RecImage imageOfType:RECIMAGE_REAL withLoops:[img1 zLoop], [RecLoop loopWithDim:100], [RecLoop loopWithDim:100], nil];
	[hist histogram2dWithX:img1 andY:img2];
	
    [hist saveAsKOImage:@"hist2d.img"];
    [img1 saveAsKOImage:@"img1.img"];
    [img1 saveAsKOImage:@"img2.img"];
exit(0);

	[RecImage initDicomDict];
    paths = [NSArray arrayWithObjects:	[NSURL fileURLWithPath:path1], nil];
    img1 = [RecImage imageWithDicomFiles:paths];
    paths = [NSArray arrayWithObjects:	[NSURL fileURLWithPath:path2], nil];
    img2 = [RecImage imageWithDicomFiles:paths];
	[img2 copyLoopsOf:img1];

	hist = [RecImage imageOfType:RECIMAGE_REAL xDim:256 yDim:256];
	[hist histogram2dWithX:img1 andY:img2];
//hist = [hist oversample];
//hist = [hist oversample];
    [hist saveAsKOImage:@"Dicom/philips-hist.img"];

	t2c = [img2 copy];
	frac = exp(- 1.0);	// thres = 1.0
	img1 = [img1 multByConst:frac];
	[img2 subImage:img1];
    [img2 saveAsKOImage:@"Dicom/philips-t2c.img"];

    return 0;
}

int
test25()
{
//	RecIntFIFO	*fifo = [RecIntFIFO fifo];
	RecIntLIFO	*fifo = [RecIntLIFO lifo];
	int			i, val, n = 41;

	for (i = 0; i < n; i++) {
		[fifo push:i];
	}

//	val = [fifo pop];
//	[fifo push:val];

	for (i = 0; i < n; i++) {
		if ([fifo empty]) {
			printf("fifo empty\n");
		} else {
			val = [fifo pop];
			printf("%d %d\n", i, val);
		}
	}
	return 0;
}

int
test26()
{
	RecImage	*src, *dst;
	src = [RecImage imageWithKOImage:@"../rtfRecon/img_s.img"];
TIMER_ST
	dst = [src partialMipForLoop:[src zLoop] depth:16];
TIMER_END("MIP");
	[dst saveAsKOImage:@"../test_img/test26.img"];
	
	src = [RecImage imageWithKOImage:@"../rtfRecon/img_s_coro.img"];
	dst = [src partialMipForLoop:[src zLoop] depth:16];
	[dst saveAsKOImage:@"../test_img/test26_coro.img"];

	return 0;
}

int
test27()
{
	RecImage	*img, *raw, *traj;

//	img = [RecImage imageWithToshibaFile:@"src_Toshiba/Run22486.7303.04"];	// rect phantom
//	img = [RecImage imageWithToshibaFile:@"src_Toshiba/Run77.7683.03"];		// 3D multi-coil
//	img = [RecImage imageWithToshibaFile:@"src_Toshiba/Run77.7683.07"];		// 3D pw
//	img = [RecImage imageWithToshibaFile:@"../toshiba_images/PaddleWheel.7683.11"];		// 3D pw
//	img = [RecImage imageWithToshibaFile:@"../toshiba_images/JET5ETL.7683.16"];		// JET
//	img = [RecImage imageWithToshibaFile:@"../toshiba_images/JET15ETL.7683.13"];		// JET
//	img = [RecImage imageWithToshibaFile:@"../toshiba_images/data_2015Sep11/Run124.7718.09"];	// 3D pw
//	[img saveAsKOImage:@"../test_img/test27_raw.img"];
//	img = [RecImage imageWithToshibaFile:@"../toshiba_images/2017-09-28/Run23531.-5213.03" vOrder:&traj];	// FFE,  1, 729, 1, 8
//	img = [RecImage imageWithToshibaFile:@"../toshiba_images/2017-09-28/Run23531.-5213.04" traj:&traj];	// SSFP, 1, 729, 1, 8
//	img = [RecImage imageWithToshibaFile:@"../toshiba_images/2017-09-28/Run23531.-5213.05" traj:&traj];	// FFE,  1, 600, 1, 8
//	img = [RecImage imageWithToshibaFile:@"../toshiba_images/2017-09-28/Run23531.-5213.06" traj:&traj];	// SSFP, 1, 600, 1, 8
//	img = [RecImage imageWithToshibaFile:@"../toshiba_images/2017-09-28/Run23531.-5213.07" traj:&traj];	// SSFP, 0.5, 600, 1, 8

system("rm ../test_img/test27*.*");

	raw = [img copy];
	[raw logP1];
	[raw saveAsKOImage:@"../test_img/test27_raw.img"];
	[traj saveAsKOImage:@"../test_img/test27_traj.img"];

	img = [img avgForLoop:[img topLoop]];

	[img zeroFillToPo2:[img zLoop]];
//	[img zeroFillToPo2:[img yLoop]];
//	[img zeroFillToPo2:[img xLoop]];

	[img fft1d:[img zLoop] direction:REC_FORWARD];
//	[img fft1d:[img yLoop] direction:REC_FORWARD];
	[img fft1d:[img xLoop] direction:REC_FORWARD];
	[img saveAsKOImage:@"../test_img/test27_sin.img"];

	return 0;
}

// ==== PROPELLER -> move to rtf3Recon
RecImage *
raw2blades(RecImage *img, int nBlades)
{
	int			xDim, yDim;
	RecImage	*bl;

	xDim = [img xDim];
	yDim = [img yDim] / nBlades;
	bl = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:xDim yDim:yDim zDim:nBlades];
	[bl copyImageData:img];
    [bl setUnit:REC_FREQ forLoop:[bl xLoop]];
	[bl setUnit:REC_FREQ forLoop:[bl yLoop]];
	return bl;
}

void
pcorrBlades(RecImage *bl)
{
	int			xDim = [bl xDim];
	int			yDim = [bl yDim];
	int			nBlades = [bl zDim];
	RecImage	*ct;
	RecImage	*traj, *img;
	RecGridder	*grid;
	float		phs;
	float		*p, *q;
	int			i, centerIx;

	// copy center lines to ct
	centerIx = yDim / 2;
	ct = [bl sliceAtIndex:centerIx forLoop:[bl yLoop]];
	if (0) {
		[ct radPhaseCorr];
		[ct fft1d:[ct xLoop] direction:REC_INVERSE];
		traj = [RecImage imageOfType:RECIMAGE_KTRAJ xDim:[ct xDim] yDim:[ct yDim]];
		[traj initRadialTraj];
		grid = [RecGridder gridderWithTrajectory:traj andRecDim:256];
		img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:256 yDim:256];
		[grid grid2d:ct to:img];
	//[ct saveAsKOImage:@"../test_img/test28_ct.img"];
		[img saveAsKOImage:@"../test_img/test28_ct_rad.img"];
	exit(0);
	}
	// 1d ft
	[ct fft1d:[ct xLoop] direction:REC_FORWARD];
	[bl fft1d:[bl xLoop] direction:REC_FORWARD]; // fft unit ###
	
	// 1st est
	phs = 0;
	p = [ct data];
	q = p + [ct dataLength];
    for (i = 0; i < nBlades; i++) {
        phs += Rec_est_1st(p, q, 1, xDim);
        p += xDim;
        q += xDim;
    }
    phs /= nBlades;

	// 1st corr
	p = [bl data];
	q = p + [bl dataLength];
    for (i = 0; i < yDim * nBlades; i++) {
		Rec_corr1st(p, q, 1, xDim, phs);
        p += xDim;
        q += xDim;
	}
	// 0th est
	p = [ct data];
	q = p + [ct dataLength];
	phs = Rec_est_0th(p, q, 1, [ct dataLength]);

	// 0th corr
	p = [bl data];
	q = p + [bl dataLength];
	Rec_corr0th(p, q, 1, [bl dataLength], phs);

	[bl fft1d:[bl xLoop] direction:REC_INVERSE];
	if (0) {
		ct = [bl sliceAtIndex:centerIx forLoop:[bl yLoop]];
	//	[ct fft1d:[ct xLoop] direction:REC_INVERSE];
		traj = [RecImage imageOfType:RECIMAGE_KTRAJ xDim:[ct xDim] yDim:[ct yDim]];
		[traj initRadialTraj];
		grid = [RecGridder gridderWithTrajectory:traj andRecDim:256];
		img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:256 yDim:256];
		[grid grid2d:ct to:img];
	//[ct saveAsKOImage:@"../test_img/test28_ct.img"];
		[img saveAsKOImage:@"../test_img/test28_ct_rad.img"];
	exit(0);
	}
}

// return amount of shift in pixels
NSPoint *
sftBlades(RecImage *bl)
{
	RecImage	*param;		// rot angle
	RecImage	*ct;		// central overlapping part
	RecImage	*rot;
	RecImage	*ref;
	RecImage	*cor;
	float		*p, *q, *th;
	float		x, y, cs, sn;
	int			i, nBlade = [bl zDim];
	int			xDim = [bl xDim];
	int			yDim = [bl yDim];
	int			ftDim;
	int			len;
	NSPoint		*pt;
	RecImage	*bltmp;

	ct = [bl copy];
	[ct crop:[bl xLoop] to:yDim];
	[ct saveAsKOImage:@"../test_img/test28_bl_ct.img"];

	param = [RecImage imageOfType:RECIMAGE_MAP withLoops:[bl zLoop], nil];
	th = [param data];
	for (i = 0; i < nBlade; i++) {
		th[i] = M_PI/2 - M_PI *  i / nBlade;
	}
	rot = [ct rotBy:param];
	[rot zeroFillToPo2:[rot xLoop]];
	ftDim = [[rot zeroFillToPo2:[rot yLoop]] dataLength];
	[rot saveAsKOImage:@"../test_img/test28_rot.img"];
	ref = [rot sliceAtIndex:0];
	cor = [rot xyCorrelationWith:ref];	// ft unit ###
	[cor saveAsKOImage:@"../test_img/test28_cor.img"];

	pt = (NSPoint *)malloc(sizeof(NSPoint) * nBlade);
	p = [cor data];
	len = ftDim * ftDim;
	for (i = 0; i < nBlade; i++) {
		pt[i] = Rec_find_peak2(p + len * i, ftDim, ftDim);
		x = pt[i].x;
		y = pt[i].y;
		cs = cos(th[i]);
		sn = sin(th[i]);
		// rotate back to blade xy
		pt[i].x = x * cs + y * sn;
		pt[i].y = y * cs - x * sn;
	//	printf("%d %f %f\n", i, pt[i].x, pt[i].y);
	//	printf("%d %f %f\n", i, x, y);

	}

	if (1) {	// correction
		// map based shift
		param = [RecImage imageOfType:RECIMAGE_MAP withLoops:[bl zLoop], nil];	// array of 2d vectors
		p = [param data];
		q = p + [param dataLength];
		for (i = 0; i < nBlade; i++) {
			p[i] = pt[i].x / xDim;
			q[i] = pt[i].y / yDim;
		//	printf("%d %f %f\n", i, p[i], q[i]);
		}
		bltmp = [bl ftShiftBy:param]; // FFT based shift without making map
		[bltmp copyLoopsOf:bl];
		[bl copyImage:bltmp];	// ### copy doesn't work (yLoop is different)

		pt = NULL;	// ## no traj correction
	}

	return pt;
}

void
pcorr2Blades(RecImage *bl)
{
	RecImage	*param;		// rot angle
	RecImage	*ct;		// central overlapping part
	RecImage	*rot;
	RecImage	*ref;
	RecImage	*cor;
	float		*p, *q, *th;
	float		x, y, cs, sn;
	int			i, nBlade = [bl zDim];
	int			xDim = [bl xDim];
	int			yDim = [bl yDim];
	int			ftDim;
	int			len;
	NSPoint		*pt;
	RecImage	*bltmp;

// cutout ct
	ct = [bl copy];
	[ct crop:[bl xLoop] to:yDim];
	[ct fGauss2DLP:0.3];
[ct saveAsKOImage:@"../test_img/test28_bl_ct.img"];

// rotate to image cood
	param = [RecImage imageOfType:RECIMAGE_MAP withLoops:[bl zLoop], nil];
	th = [param data];
	for (i = 0; i < nBlade; i++) {
		th[i] = M_PI/2 - M_PI *  i / nBlade;
	}
	rot = [ct rotBy:param];
	[rot zeroFillToPo2:[rot xLoop]];
	[rot zeroFillToPo2:[rot yLoop]];
[rot saveAsKOImage:@"../test_img/test28_rot.img"];

// make avg phase (complex avg)
//	[rot avgForLoop:[rot zLoop]];
//[rot saveAsKOImage:@"../test_img/test28_rot_avg.img"];

// sub (div) avg phase from ct

// rotate back to bl coord
	for (i = 0; i < nBlade; i++) {
		th[i] = -M_PI/2 + M_PI *  i / nBlade;
	}
	rot = [rot rotBy:param];
[rot saveAsKOImage:@"../test_img/test28_rot.img"];

//##############
rot = [bl copy];
//[rot fGauss2DLP:0.3];
//[rot fTriWin2D];

//##############

// zerofill rot & bl to rec dim
	[rot zeroFill:[rot xLoop] to:256];
	[rot zeroFill:[rot yLoop] to:256];
// make unit vector (phase rotator)
	[rot fft2d:REC_FORWARD];
// ===
	if (0) {
		th = [param data];
		for (i = 0; i < nBlade; i++) {
			th[i] = M_PI/2 - M_PI *  i / nBlade;
		}
		rot = [rot rotBy:param];
		[rot saveAsKOImage:@"../test_img/test28_rot_ft.img"];
		exit(0);
	}
//=====
	[rot toUnitImage];
	[rot conjugate];
[rot saveAsKOImage:@"../test_img/test28_rot_ft_u.img"];
//exit(0);	

// ft bltmp, mul, ift
	[bl zeroFill:[bl yLoop] to:256];
	[bl fft2d:REC_FORWARD];
	[rot copyLoopsOf:bl];
	[bl multByImage:rot];
[bl saveAsKOImage:@"../test_img/test28_bl_corr.img"];
	[bl fft2d:REC_INVERSE];
// crop
	[bl crop:[bl yLoop] to:yDim];
[bl saveAsKOImage:@"../test_img/test28_bl_pcor2.img"];

// copy back to bl
}

void
chemShift(RecImage *bl, float cs)
{
	RecImage	*blTmp;
	RecImage	*param = [RecImage pointImageOfType:RECIMAGE_MAP];
	float		*p = [param data];

	p[0] = cs/[bl xDim];
	p[1] = 0;

	[bl fft2d:REC_FORWARD];
	blTmp = [bl ftShiftBy:param];
	[blTmp fft2d:REC_INVERSE];
	[blTmp copyLoopsOf:bl];
	[bl copyImage:blTmp];
}

void
echoCorrBlades(RecImage *bl)
{
	int			xDim = [bl xDim];
	int			yDim = [bl yDim];
	int			nBlades = [bl zDim];
	int			i, j, k1, k2, ix1, ix2;
	BOOL		firstHalf = YES;
	RecImage	*ct;	// central part
	float		*mg, *ph;
	float		re1, re2, im1, im2;
	float		summg1, summg2;
	float		sumr, sumi;
	float		*p1, *q1;	// target
	float		*p2, *q2;	// ref

	ct = [bl copy];
	[ct crop:[bl xLoop] to:yDim];
	[ct saveAsKOImage:@"../test_img/test28_bl_ct.img"];

	mg = (float *)malloc(sizeof(float) * nBlades * yDim);
	ph = (float *)malloc(sizeof(float) * nBlades * yDim);

	for (k1 = 0; k1 < nBlades; k1++) {
		k2 = k1 + nBlades/2;
		if (k2 >= nBlades) {
			k2 -= nBlades;
			firstHalf = NO;
		} else {
			firstHalf = YES;
		}
		p1 = [ct data] + k1 * yDim * yDim;
		q1 = p1 + [ct dataLength];
		p2 = [ct data] + k2 * yDim * yDim;
		q2 = p2 + [ct dataLength];
		for (i = 0; i < yDim; i++) {	// target encode direction
			summg1 = summg2 = 0;
			sumr = sumi = 0;
			for (j = 0; j < yDim; j++) {	// target readout direction
				ix1 = i * yDim + j;
				if (firstHalf) {
					ix2 = j * yDim + (yDim - i - 1);
				} else {
					ix2 = (yDim - j - 1) * yDim + i;
				}
				re1 = p1[ix1]; im1 = q1[ix1];
				re2 = p2[ix2]; im2 = q2[ix2];
			// mg
				summg1 += sqrt(re1 * re1 + im1 * im1);
				summg2 += sqrt(re2 * re2 + im2 * im2);
			// ph
				sumr += re1 * re2 + im1 * im2;
				sumi += im1 * re2 - re1 * im2;
			}
			ix1 = k1 * yDim + i;
			mg[ix1] = summg1 / summg2;
			ph[ix1] = atan2(sumi, sumr);
		}
	}

	if (0) {	// dump mg
		for (i = 0; i < yDim; i++) {
			printf("%d ", i);
			for (k1 = 0; k1 < nBlades; k1++) {
				printf("%6.3f ", mg[k1 * yDim + i]);
			}
			printf("\n");
		}
	}
	if (0) {	// dump mg
		for (i = 0; i < yDim; i++) {
			printf("%d ", i);
			for (k1 = 0; k1 < nBlades; k1++) {
				printf("%6.3f ", ph[k1 * yDim + i]);
			}
			printf("\n");
		}
	}

// correction
	p1 = [bl data];
	q1 = p1 + [bl dataLength];
	for (k1 = 0; k1 < nBlades; k1++) {
		for (i = 0; i < yDim; i++) {
			re1 = 1.0 / mg[k1 * yDim + i];
			im1 = ph[k1 * yDim + i];
			sumr = re1 * cos(im1);
			sumi = re1 * sin(im1);
			for (j = 0; j < xDim; j++) {
				ix1 = ((k1 * yDim) + i) * xDim + j;
				re2 = p1[ix1];
				im2 = q1[ix1];
				p1[ix1] = re2 * sumr + im2 * sumi;
				q1[ix1] = im2 * sumr - re2 * sumi;
			}
		}
	}
	free(mg);
	free(ph);
}

// PROPELLER (Toshiba)
int
test28()
{
	RecImage	*raw, *img, *traj, *bl;
	RecImage	*rot, *param;
	RecLoop		*xLoop;
	float		*p;
	int			xdim = 256;
	int			ydim = 256;
	int			nEnc = 5;
	int			nBlade, i;
	RecGridder	*grid;
	NSPoint		*sft;

//	[img initRadialTraj];
//	[traj plotTraj:@"prop_traj.dat"];

	system("rm ../test_img/test28*.img");

	raw = [RecImage imageWithToshibaFile:@"../toshiba_images/JET5ETL.7683.16"]; nEnc = 5;	// JET
//	raw = [RecImage imageWithToshibaFile:@"../toshiba_images/JET15ETL.7683.13"]; nEnc = 15;		// JET
	nBlade = [raw yDim] / nEnc;

	[raw saveAsKOImage:@"../test_img/test28_raw.img"];

// LP filter to 256
	xLoop = [raw xLoop];
	[raw fft1d:xLoop direction:REC_FORWARD];
	[raw crop:xLoop to:256];
	xLoop = [raw xLoop];
	[raw fft1d:xLoop direction:REC_INVERSE];

	bl = raw2blades(raw, [raw yDim]/nEnc);
	[bl saveAsKOImage:@"../test_img/test28_bl.img"];

//	pcorrBlades(bl);
//	[bl saveAsKOImage:@"../test_img/test28_bl_pcorr.img"];

	for (i = 0; i < 2; i++) {
		sft = sftBlades(bl);
	}
	[bl saveAsKOImage:@"../test_img/test28_bl_sft.img"];

if (0) {
	[bl fft1d:[bl xLoop] direction:REC_FORWARD];
	[bl saveAsKOImage:@"../test_img/test28_bl_1ft.img"];
	exit(0);
}
	pcorr2Blades(bl);	// ###

	chemShift(bl, 0.0);	// -2.0

//	echoCorrBlades(bl);
//	[bl saveAsKOImage:@"../test_img/test28_bl_echo.img"];
//exit(0);
	if (0) {
	//	[bl zeroFillToPo2:[bl yLoop]];
	[bl zeroFill:[bl yLoop] to:128];
		[bl fft2d:REC_FORWARD];
		[bl saveAsKOImage:@"../test_img/test28_bl_img.img"];
		exit(0);
	}

	if (0) {
		RecImage *ref;
		[bl zeroFill:[bl yLoop] to:256];
		
		param = [RecImage imageOfType:RECIMAGE_MAP withLoops:[bl zLoop], nil];
		p = [param data];
		for (i = 0; i < nBlade; i++) {
			p[i] = -M_PI/2 - M_PI *  i / nBlade;
		}
		rot = [bl rotBy:param];
		ref = [rot sliceAtIndex:0];
		[ref saveAsKOImage:@"../test_img/test28_bl_ref.img"];
		[rot logP1];
		[rot saveAsKOImage:@"../test_img/test28_rot.img"];

	//	[rot subImage:ref];
	//	[rot saveAsKOImage:@"../test_img/test28_rot_sub.img"];

	//	[rot fft2d:REC_FORWARD];
	//	[rot saveAsKOImage:@"../test_img/test28_rot_ft.img"];
	exit(0);
	}

	[raw copyImageData:bl];

	xdim = [raw xDim];
	ydim = [raw yDim];
	traj = [RecImage imageOfType:RECIMAGE_KTRAJ xDim:xdim yDim:ydim];
	[traj initPropTraj:nEnc shift:sft];
	[traj plotTraj:@"../test_img/test28_traj.dat"];
	grid = [RecGridder gridderWithTrajectory:traj andRecDim:xdim];
	img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:xdim yDim:xdim];
	[grid grid2d:raw to:img];
	[img saveAsKOImage:@"../test_img/test28_img.img"];
	[img fft2d:REC_INVERSE];
//	img = [img logP1];
	[img saveAsKOImage:@"../test_img/test28_img_ft.img"];

	if (sft) free(sft);

	return 0;
}

void
linear_phs(float *p, float *q, int xDim, int yDim, float dx, float dy)
{
	int		i, j;
	float	x, y;
	float	phs;

	for (i = 0; i < yDim; i++) {
		y = ((float)i - yDim/2) / yDim;
		for (j = 0; j < xDim; j++) {
			x = ((float)j - xDim/2) / xDim;
			phs = x * dx + y * dy;
			p[i*xDim + j] = cos(phs);
			q[i*xDim + j] = sin(phs);
		}
	}
}

RecImage *
chen_forward(RecImage *ev, RecImage *od, RecImage *phs)
{
	RecImage	*p1, *e1, *e2, *denom;

	e1 = [phs copy];
	e2 = [phs copy];
	[e2 shift1d:[e1 yLoop]];
	denom = [e1 copy];
	[ev multByImage:e2];
	[ev addImage:od];
	p1 = [ev cpxDivImage:denom];

	return p1;
}

int
find_peak_ix(float *p, float *q, int len)
{
	float	mx, mg;
	int		i, ix;

	mx = 0;
	for (i = 0; i < len; i++) {
		mg = p[i] * p[i] + q[i] * q[i];
		if (mx < mg) {
			mx = mg;
			ix = i;
		}
	}
	return ix;
}

void
chk_phs(float *phs, int len)
{
	float	th;
	int		i;
	for (i = 0; i < len; i++) {
		th = phs[i] / M_PI;
		if (th > 0.9) {
			phs[i] -= M_PI;
			printf("th = %3.2f %3.2f %3.2f\n", phs[i-1]/M_PI, th, phs[i+1]/M_PI);
		}
		if (th < -0.9) {
			phs[i] += M_PI;
			printf("th = %3.2f %3.2f %3.2f\n", phs[i-1]/M_PI, th, phs[i+1]/M_PI);
		}
	}
}

RecImage *
nyq_pest(RecImage *im, RecImage *msk)
{
	RecImage	*x1 = [RecImage imageOfType:RECIMAGE_REAL withImage:im];
	RecImage	*phs, *est, *cor;
	float		*p, *q, x, th, err;
	int			i, j, iter, xDim, yDim, len;
	float		a0, a1, mg;

// DCT / Cheb
	BOOL			dct = NO;	//Cheb is better
	int				order = 3;
	int				pdim = order * order;
	RecDctSetup		*setup_d;
	RecChebSetup	*setup_c;
	float			*coef, *accum;

// powell
	Num_param	*param;
    float		(^cost)(float *);

	phs = [im copy];
	[phs phase];
//	[phs maskWithImage:msk];	// for -0
//chk_phs([phs data], [phs dataLength]);

	est = [RecImage imageWithImage:phs];

// DCT version
	xDim = [im xDim];
	setup_d = Rec_dct_setup(xDim, order);
	setup_c = Rec_cheb_setup(xDim, order);
	p = [phs data];
	coef = (float *)malloc(sizeof(float) * order * order);
	accum = (float *)malloc(sizeof(float) * order * order);
	for (i = 0; i < order * order; i++) {
		accum[i] = 0;
	}
	p = [phs data];
	q = [est data];
	xDim = [phs xDim];
	yDim = [phs yDim];
	len = xDim * yDim;

    cost = ^float(float *prm) {
        int     i, j;
		float	x, y;
        float   val, cst = 0;
		// calc ms error over image (within mask)
		Rec_cheb_2d(q, prm, setup_c, REC_FORWARD);
		[est maskWithImage:msk];
		cst = Rec_L2_dist(p, q, len);
        return cst;    
    };

	if (0) {	// ======= ART type iterative loop ====== (powell is better)
		for (iter = 0; iter < 1000; iter++) {	// 1000
		// == inverse (coef)
			if (dct) {
				Rec_dct_2d(p, coef, setup_d, REC_INVERSE);
			} else {
				Rec_cheb_2d(p, coef, setup_c, REC_INVERSE);
			}
		// forward (phase est)
			if (dct) {
				Rec_dct_2d(q, coef, setup_d, REC_FORWARD);
			} else {
				Rec_cheb_2d(q, coef, setup_c, REC_FORWARD);
			}
			[est maskWithImage:msk];
		// === error (phs)
			[phs subImage:est];
		// === calc error norm, break if small enough
			err = Rec_L2_norm(p, xDim * yDim);
	//		printf("%d %5.3f\n", iter, err);
		// === accum coef
			for (i = 0; i < order * order; i++) {
				accum[i] += coef[i];
			}
		}
	} else {	// ======== non-linear minimization =====
		param = Num_alloc_param(pdim);
		for (i = 0; i < pdim; i++) {
			param->data[i] = 0;
		}
		iter = Num_powell(param, cost, &err);
		printf("iter:%d, err = %f\n", iter, err);
		for (i = 0; i < pdim; i++) {
			accum[i] = param->data[i];
		}
	}


	// === calc final est using accumulated coef
	if (dct) {
		Rec_dct_2d(q, accum, setup_d, REC_FORWARD);
	} else {
		Rec_cheb_2d(q, accum, setup_c, REC_FORWARD);
	}
 
	return est;
}

// even/odd correction (oshio2 method)
// ## multi-coil ?
int
test29()
{
	RecImage	*img, *raw, *avg;
	RecImage	*ev, *od;
	RecImage	*sm, *df;
	RecImage	*mask, *phs, *est, *tmp;
	RecLoop		*sl, *ph, *av, *kx, *ky;
    LP_DIM		lp_dim;
	int			i, j, ix, xDim, yDim, dataLen;
	int			nimg;
	float		cx, cy;
	float		*p, *q;

	system("rm ../test_img/test*.img");
	raw = [RecImage imageWithMeasAsc:@"../test_img/meas.asc" andMeasData:@"../test_img/meas.out" lpDim:&lp_dim];
//	raw = [RecImage imageWithMeasVD:@"../nciRecon/meas_files/meas_MID25_Checkerboard_block_FID37691.dat" lpDim:&lp_dim]; // 11/28

	sl = [RecLoop findLoop:@"kz"];
//	raw = [raw sliceAtIndex:1 forLoop:sl];
	img = [raw copy];
	[img fft2d:REC_FORWARD];
    [img freqCrop];

	[img saveAsKOImage:@"IMG_29_in"];
	[img epiPcorr2];
	[img saveAsKOImage:@"IMG_29_epipcorr"];
exit(0);
	

if (0) {
//	[raw epiPcorr];			// se
//	[raw saveAsKOImage:@"../test_img/test_epi2_SE.img"];
//	[raw epiPcorrGE];		// se, ge
//	[raw saveAsKOImage:@"../test_img/test_epi2_GE.img"];
//	[raw epiPcorr2];		// se (best)
//	[raw saveAsKOImage:@"../test_img/test_epi2_2.img"];
//	[raw epiPcorr3];		// X(se), ge ok
//	[raw saveAsKOImage:@"../test_img/test_epi2_3.img"];
	exit(0);
}
	[raw saveAsKOImage:@"../test_img/test_epi2_in.img"];
	[raw fft2d:REC_INVERSE];
	[raw saveAsKOImage:@"../test_img/test_epi2.raw"];
	xDim = [raw xDim];
	yDim = [raw yDim];
	dataLen = xDim * yDim;

	sl = [RecLoop findLoop:@"kz"];
	ph = [RecLoop findLoop:@"phs"];
	av = [RecLoop findLoop:@"avg"];
	kx = [raw xLoop];
	ky = [raw yLoop];
//[avg saveAsKOImage:@"../test_img/test_epi2_avg.img"];
//exit(0);

// #### -> epiEchoCenterWithControl:lc


// #### ====== epiPcorrFineWithControl:lc

// #2 divide into ev/od images, and 1st/0th correction (x direction)
	ev = [raw copy];
	[ev takeEvenLines];
	[ev shift1d:[raw xLoop] by:cx];	// 1st
	[ev pcorr0];
	[ev fft2d:REC_FORWARD];
	[ev saveAsKOImage:@"../test_img/test_epi2_ev.img"];

	od = [raw copy];
	[od takeOddLines];
	p = [od data];
	q = p + [od dataLength];
	ix = find_peak_ix(p, q, dataLen);
	cx = ix % xDim - xDim/2;
	if (cx != 0) {
		[od shift1d:[od xLoop] by:cx];	// 1st
	}
	[od pcorr0];
	[od fft2d:REC_FORWARD];
[od saveAsKOImage:@"../test_img/test_epi2_od.img"];

// #3 first estimation
	sm = [ev copy];
	[sm addImage:od];
	[sm saveAsKOImage:@"../test_img/test_epi2_im1.img"];
	df = [ev copy];
	[df subImage:od];
[df saveAsKOImage:@"../test_img/test_epi2_im2.img"];

exit(0);

	return 0;
}

int
test30()
{
	RecImage	*img;

//	img = [RecImage imageWithMatfile:@"../test_img/test_matlab.mat"];
//	img = [RecImage imageWithMatfile:@"/Users/oshio/Downloads/TestData/CLFA.mat"];
	img = [RecImage imageWithMatfile:@"/Users/oshio/Downloads/TestData/GRE_Multi_Contrast.mat"];
	[img saveAsKOImage:@"../test_img/test_matlab.img"];

	return 0;
}

float
model(float t)
{
	float	a;
	float	m1, m2;
	float	r1, r2;

	m1 = 0.0; m2 = 0.5;
	r1 = 1.0 / 60;
	r2 = 1.0 / 600;

	a = m1 * exp(-t * r1) + m2 * exp(-t * r2);
	return a;
}

int
test31()
{
	RecChebSetup *setup;
	RecImage	*kern;
	RecImage	*img, *est, *err;
	int			i, j, iter;
	float		*p, *q, t, sum;
	float		*tk,*nm;
	float		*cp;
	int			xDim = 128;
	int			yDim = 128;
	int			ordx = 3;
	int			ordy = 3;
	int			order = 9;

	system("rm ../test_img/test_31*.img");

// 1D
	img = [RecImage imageOfType:RECIMAGE_REAL xDim:xDim];
	p = [img data];
	for (i = 0; i < xDim; i++) {
		t = (float)i * 8;
		p[i] = model(t);
	}
	[img saveAsKOImage:@"../test_img/test_31_data.img"];
	setup = Rec_cheb_setup(xDim, order);
	tk = setup->Tk;
	
	// non-orthogonal expansion
	est = [RecImage imageWithImage:img];
	q = [est data];
	err = [RecImage imageWithImage:img];

	for (iter = 0; iter < 1; iter++) {
		for (i = 0; i <= order; i++) {
			sum = 0;
			for (j = 0; j < xDim; j++) {
				sum += p[j] * tk[i * xDim + j];
			}
			printf("%f\n", sum);
			for (j = 0; j < xDim; j++) {
				q[j] += sum * tk[i * xDim + j];
			}
		}
		err = [img copy];
		[err subImage:est];
	}
	[est saveAsKOImage:@"../test_img/test_31_est.img"];
	[err saveAsKOImage:@"../test_img/test_31_err.img"];

	Rec_free_cheb_setup(setup);
	exit(0);


// 2d
	kern = Rec_cheb_mk_2d_kern(xDim, yDim, ordx, ordy);
	[kern saveAsKOImage:@"../test_img/test_31_kern.img"];
	img = [RecImage imageOfType:RECIMAGE_REAL xDim:xDim yDim:yDim];
	p = [img data];
	cp = (float *)malloc(sizeof(float) * ordx * ordy);
	cp[0] = 0; cp[1] = 0.2; cp[2] = 0;
	cp[3] = 0.3; cp[4] = 0; cp[5] = 0;
	cp[6] = 0; cp[7] = 0.2; cp[8] = 0.4;
TIMER_ST
	Rec_cheb_2d_expansion(p, cp, kern);
TIMER_END("cheb") // time: 0.022611 (sec) cheb

	[img saveAsKOImage:@"../test_img/test_31_1.img"];
	
	free(cp);

	return 0;
}

int
test32()	// trig interp
{
	RecImage	*img = [RecImage imageOfType:RECIMAGE_REAL xDim:4];
	RecLoop		*lp = [img xLoop];
	float		*p = [img data];
	float		x;
	int			i, n = 64;

	p[0] = 1.0;
	p[1] = 0.5;
	p[2] = -0.5;
	p[3] = -1.5;

	for (i = 0; i < 4; i++) {
		printf("%d %f\n", i, p[i]);
	}
	[img fft1d:lp direction:REC_FORWARD];

	lp = [img zeroFill:lp to:n];
	[img multByConst:n/4];

	[img fft1d:lp direction:REC_INVERSE];
	p = [img data];
	for (i = 0; i < n; i++) {
		x = (float)i * 4 / n;
		printf("%f %f\n", x, p[i]);
	}


	return 0;
}

int
test33()	// trig interp
{
	RecImage	*img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:4];
//	RecLoop		*lp = [img xLoop];
	float		*p = [img real];
	float		*q = [img imag];
	float		x, mg, phs;
	int			i, n = 64;

	p[0] = 1.0;		q[0] = 1.2;
	p[1] = 1.5;		q[1] = -1.0;
	p[2] = -0.5;	q[2] = 0.5;
	p[3] = -1.5;	q[3] = 0;

	for (i = 0; i < 4; i++) {
	//	printf("%d %f %f\n", i, p[i], q[i]);
		mg = p[i]*p[i] + q[i]*q[i];
		mg = sqrt(mg);
		phs = atan2(q[i], p[i]);
		printf("%d %f %f\n", i, mg, phs);
	}
	[img fft1d:[img xLoop] direction:REC_FORWARD];

	[img zeroFill:[img xLoop] to:n];
	[img multByConst:n/4];

	// complex smoothing
	[img fft1d:[img xLoop] direction:REC_INVERSE];
	p = [img real];
	q = [img imag];
	for (i = 0; i < n; i++) {
		x = (float)i * 4 / n;
	//	printf("%d %f %f\n", i, p[i], q[i]);
		mg = p[i]*p[i] + q[i]*q[i];
		mg = sqrt(mg);
		phs = atan2(q[i], p[i]);
		printf("%f %f %f\n", x, mg, phs);
	}
	// mag-phsae smoothing
	

	return 0;
}

// unwrapping phantom
RecImage *
mk_phsphantom(int dim, float a, float nz)
{
	int			i, j;
	float		x, y, r, mg, th;
	float		*p, *q;
	RecImage	*img;

	img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:dim yDim:dim];
	p = [img real];
	q = [img imag];
	for (i = 0; i < dim; i++) {
		y = ((float)i - dim/2) * 2 / dim;
		for (j = 0; j < dim; j++) {
			x = ((float)j - dim/2) * 2 / dim;
			r = sqrt(x*x + y*y);
			if (r < 0.5) {
				mg = 1.0;
				th = r * a * 10 + x * 10.0;
			} else {
				mg = 0;
				th = 0;
			}
			p[i * dim + j] = mg * cos(th);
			q[i * dim + j] = mg * sin(th);
		}
	}
//	[img phase];
	[img addGWN:nz relative:YES];
	return img;
}

// phase unwrapping
int
test34()
{
	RecImage	*img, *phs, *mask;
	RecImage	*avg, *blk;
	RecLoop		*blkLp, *avgLp;
//	extern		BOOL unwrap_dbg;
	float		mx, sd;
system("rm IMG_*.*");

//	unwrap_dbg = YES;

	// unwrap test
//	img = mk_phsphantom(128, 6.0, 0.2);
//	img = [RecImage imageWithKOImage:@"../test_img/b500-test-cpx-0"];//	img = [img sliceAtIndex:5];	// 0 , 5
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-rinkan-1024/b500.img"];	img = [img sliceAtIndex:40];
//	img = [RecImage imageWithKOImage:@"../toshiba_images/img.img"];	img = [img sliceAtIndex:618];	// 105, 618
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-rinkan-4/b200-cor-si/img1.cpx"];
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-rinkan-5/b200-sag-si-1/img1.cpx"];	// multi-slice
//	img = [RecImage imageWithKOImage:@"/Users/oshio/Math/phase-unwrap/IMG.img"];	//### convert old KO_IMAGE to RecImage
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-nasu-1/run62546/b1000-ax-si/img0.cpx"];
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-nasu-1/run62546/b1000-cor-si/img0.cpx"];
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-nasu-1/run62546/b1000-cor-lr/img0.cpx"];
	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-nasu-1/run62546/b1000-cor-ap/img0.cpx"];
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-nasu-1/run62547/b200-cor-si/img0.cpx"];
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-nasu-1/run62548/b1000-cor-si/img0.cpx"];
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-nasu-1/run62549/b1000-cor-si/img0.cpx"];

	[img saveAsKOImage:@"../test_img/IMG_34_in.img"];
// crop
	if (0) {
		[img crop:[img xLoop] to:32];
		[img crop:[img yLoop] to:32 startAt:10];
		[img saveAsKOImage:@"../test_img/IMG_34_crop.img"];
	}
	phs = [img copy];
	[phs phase];
	
	mask = [img avgForLoop:[img zLoop]];
	[mask magnitude];
	[mask thresAt:0.01];
	[mask saveAsKOImage:@"../test_img/IMG_34_mask.img"];
	
	


//[img phsNoiseFilt:2.0];
	phs = [img unwrap2d];	// not perfect, but works
							// -> add zloop chk
//	phs = [img unwrap2d_lap];	// not working yet
//	[phs unwrap1dForLoop:[phs yLoop]];	// 1D phase unwrap (uses Rec_unwrap_1d)
	if (0) {
		[phs multByImage:mask];
	}
	[phs saveAsKOImage:@"../test_img/IMG_34_out.img"];

	blkLp = [RecLoop loopWithDataLength:2];
	avgLp = [RecLoop loopWithDataLength:[phs zDim]/2];
	avg = [RecImage imageOfType:RECIMAGE_REAL withLoops:blkLp, avgLp, [phs yLoop], [phs xLoop], nil];
	[avg copyImageData:phs];
//	avg = [phs avgForLoop:[phs zLoop]];
	avg = [avg avgForLoop:avgLp];
	[avg saveAsKOImage:@"../test_img/IMG_34_pavg.img"];
	
	return 0;
}

int
test35()
{
	RecImage	*img = [RecImage imageWithKOImage:@"../test_img/nps_img2.img"];
	RecImage	*lp1, *lp2, *mask;
	RecImage	*pnp, *ph1;
	NSString	*path;
	int			i, j;
	int			xDim, yDim, len;
	float		*p, *q;
	float		x, y;

system("rm IMG_*.*");
	[img saveAsKOImage:@"IMG_in.img"];
	mask = [img copy];
	[mask magnitude];
	[mask thresAt:0.2];
	[mask hGauss2DLP:0.5];	// "Half" gaussian filter
	[mask saveAsKOImage:@"IMG_mask.img"];

	lp1 = [img copy];
//[lp1 scaleByImage:mask];
	[lp1 laplace2d:REC_FORWARD];
	[lp1 saveAsKOImage:@"IMG_lp.img"];

//[lp1 scaleByImage:mask];

	if (0) {
		[lp1 cpxDivImage:img];
	} else {
		lp2 = [img copy];
		[lp2 toUnitImage];
		[lp2 conjugate];
		[lp1 multByImage:lp2];
	}
//	[lp1 scaleByImage:mask];

	[lp1 takeImagPart];
	[lp1 saveAsKOImage:@"IMG_lpd.img"];

	[lp1 laplace2d:REC_INVERSE];
	[lp1 saveAsKOImage:@"IMG_est.img"];

	ph1 = [img copy];
	[ph1 phase];

// iterative correction
	for (i = 0; i < 4; i++) {
		pnp = [ph1 copy];
		[pnp subImage:ph1];
//		[pnp makeZeroMeanWithMask:mask];
		path = [NSString stringWithFormat:@"IMG_np%d.img", i];
		[pnp saveAsKOImage:path];
		[pnp mod2PI];
		path = [NSString stringWithFormat:@"IMG_mod%d.img", i];
		[pnp saveAsKOImage:path];
		[ph1 addImage:pnp];
		[ph1 makeZeroMeanWithMask:mask];
		path = [NSString stringWithFormat:@"IMG_ps%d.img", i];
		[ph1 saveAsKOImage:path];
	}
	[ph1 multByImage:mask];
	[ph1 saveAsKOImage:@"IMG_masked.img"];

	return 0;
}

int
test36()	// wavelet
{
	int			i, n, lev;
	float		*p = (float *)malloc(sizeof(float) * n);
	RecWaveSetup	*setup = Rec_wave_setup(n);
	RecImage	*img, *coef;

	if (0) {	// 1d
		n = 256;
		lev = 3;
		setup = Rec_wave_setup(n);
		for (i = 0; i < n; i++) {
			p[i] = sin((float)i * 5 * M_PI / n);
		}
		Rec_wvt(p, lev, setup);
		for (i = 0; i < n; i++) {
			printf("%d %f\n", i, p[i]);
		}
		Rec_iwvt(p, lev, setup);
		for (i = 0; i < n; i++) {
			printf("%d %f\n", i, p[i]);
		}
		Rec_free_wave_setup(setup);
	}
	
	if (1) {	// 2d
		lev = 3;
		float	*cf;

		// wav transform
		img = [RecImage imageWithKOImage:@"../test_img/b500-test-cpx-0"];
		[img magnitude];
		setup = Rec_wave_setup([img xDim]);
		[img wave2d:REC_FORWARD level:lev];
		[img saveAsKOImage:@"IMG_wav.img"];
	//	[img wave2d:REC_INVERSE level:lev];
	//	[img saveAsKOImage:@"IMG_iwav.img"];

		// energy
		coef = [img waveEnergyWithLevel:lev];
		[coef saveAsKOImage:@"IMG_coef.img"];


		// filter
		[img wave2d:REC_INVERSE level:lev];

		cf = [coef data];	// 4 x 4
		for (i = 0; i < 16; i++) {
			cf[i] = 1.0;
		}
		cf[10] = cf[15] = 0;
		
		
		[img waveFiltWithCoef:coef];
		[img saveAsKOImage:@"IMG_filt.img"];




		Rec_free_wave_setup(setup);
	}

	return 0;
}

int
test37()	// phase SNR
{
	RecImage	*cpx, *phs;
	RecImage	*tmp;
	RecImage	*hist;
	float		sd, sim, x;
	
	int			i, j;
	int			xDim = 256;
	int			yDim = 256;
	int			nBin = 64;
	float		ncyc = 0.0; //10.0;
	float		nsd = 0.8;
	float		*p, *q, *pp;
	float		*buf;
	float		mg, th;

	cpx = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:xDim yDim:yDim];
	p = [cpx real];
	q = [cpx imag];
	for (i = 0; i < yDim; i++) {
		for (j = 0; j < xDim; j++) {
			th = (float)i / yDim * ncyc * M_PI;	// 10
		//	mg = exp(-(float)i / yDim * M_E * 2);
			mg = (float)(yDim - i + 1) / yDim;
			p[i * xDim + j] = mg * cos(th);
			q[i * xDim + j] = mg * sin(th);
		}
	}
	[cpx addGWN:nsd relative:NO];
	[cpx saveAsKOImage:@"IMG_cpx"];

// mag ditribution
	tmp = [cpx copy];
	[tmp magnitude];
	hist = [RecImage imageOfType:RECIMAGE_REAL xDim:nBin yDim:yDim];
	for (i = 0; i < yDim; i++) {
		p = [tmp data] + i * xDim;
		pp = [hist data] + i * nBin;
		histogram(pp, nBin, p, xDim, 0.0, 2.0);
	}
	[hist saveAsKOImage:@"IMG_hist_mg"];

// phase ditribution
	tmp = [cpx copy];
	[tmp phase];
	for (i = 0; i < yDim; i++) {
		p = [tmp data] + i * xDim;
		pp = [hist data] + i * nBin;
		histogram(pp, nBin, p, xDim, -4.0, 4.0);
	}
	[hist saveAsKOImage:@"IMG_hist_p"];

// phase sd
	p = [tmp data];
	for (i = 0; i < yDim; i++) {
		sd = 0;
		for (j = 0; j < xDim; j++) {
			sd += p[i * xDim + j] * p[i * xDim + j];
		}
		mg = (float)(yDim - i + 1) / yDim;
		x = mg / nsd;
		sd /= xDim;
		sd = sqrt(sd);
	//	sim = (M_PI / sqrt(3.0) - nsd) * exp(0.7*(x - 1)/nsd) + nsd;	// 1st attempt (not theoretical)
		float	a = 2.0;
		float	b = 1.5;
		float	e = a * x * exp(-b * x);
		sim = 1.0 / (x + sqrt(3.0) / M_PI) + e;
		printf("%f %f %f\n", x, sd, sim);
	}
	phs = [cpx unwrap2d];
	[phs saveAsKOImage:@"IMG_unwrap"];

	return 0;
}

int
test38()
{
	RecImage	*img;
	float		*p;
	int			i, len;

	img = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:64 yDim:64 zDim:16];
	p = [img real];
	len = [img dataLength] * [img pixSize];
	for (i = 0; i < len; i++) {
		p[i] = 1.0;
	}
	[img saveAsKOImage:@"../test_img/test38-1.img"];
	img = [img avgForLoop:[img zLoop]];
	[img saveAsKOImage:@"../test_img/test38-2.img"];
	exit(0);

	img = [RecImage imageWithKOImage:@"../test_img/b500-test-cpx-0"];
	img = [img sliceAtIndex:5];	// 0 , 5
	[img phsNoiseFilt:5.0];
	[img saveAsKOImage:@"IMG_phsfilt_c"];

	return 0;
}

int
test39()
{
	RecImage	*img_in, *img, *mn;
	RecImage	*prof;

	RecLoop		*ch, *avg, *phs, *xLp, *yLp;
	img_in = [RecImage imageWithKOImage:@"/Users/oshio/images/NCI/NIRS/2018-0611-1/results/1/IMG_epipcorr"];
	ch = [RecLoop loopWithDataLength:12];
	phs = [RecLoop loopWithDataLength:10];
	avg = [RecLoop loopWithDataLength:390];
	xLp = [RecLoop loopWithDataLength:64];
	yLp = [RecLoop loopWithDataLength:64];
	img = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:ch, avg, phs, xLp, yLp, nil];
	[img copyImageData:img_in];
//	avg = [img crop:avg to:20];
	[img saveAsKOImage:@"../test_img/test39_in.img"];

//	img = [img avgForLoop:avg];
//	[img saveAsKOImage:@"../test_img/test39_1.img"];

//	mn = [img avgForLoop:phs];
//	mn = [mn avgForLoop:avg];
//	[mn saveAsKOImage:@"../test_img/test39_0.img"];
printf("prof\n");
	prof = [img coilProfile2DForLoop:ch];
	[prof saveAsKOImage:@"../test_img/test39_1.img"];
	
	img = [img combineForLoop:ch withProfile:prof];
	[img saveAsKOImage:@"../test_img/test39_2.img"];
	img = [img avgForLoop:avg];
	[img saveAsKOImage:@"../test_img/test39_3.img"];

// test baseline removal
	mn = [img avgForLoop:[img zLoop]];
	[mn saveAsKOImage:@"../test_img/test39_4.img"];
	[mn conjugate];
	[mn toUnitImage];
	[img multByImage:mn];
	[img saveAsKOImage:@"../test_img/test39_5.img"];

	return 0;
}

int
test40()
{
	RecImage	*img, *kern;
	float		*p, *q, x, a, k;
	int			i, j;
	
	img = [RecImage imageOfType:RECIMAGE_REAL xDim:64 yDim:64];
	kern = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:1000];

// kern test
a = 10;
p = [kern data];
for (i = 0; i < 1000; i++) {
	x = (float)i * 10;
//	k = x * x * exp(-x / a);	// gamma
	k = (2 * x - x * x / a) * exp(-x / a);	// dgamma
	p[i] = k;
//	printf("%f %f\n", x, k);
	printf("%d %f\n", i, k);
}
[kern shift1d:[kern xLoop]];
[kern fft1d:[kern xLoop] direction:REC_INVERSE];
p = [kern real];
q = [kern imag];
for (i = 0; i < 1000; i++) {
	printf("%d %f %f %f\n", i, p[i], q[i], sqrt(p[i]*p[i] + q[i]*q[i]));
}


exit(0);

	p = [img data];
	for (i = 0; i < 64; i++) {
		for (j = 0; j < 64; j++) {
			p[i * 64 + j] = j % 8 + 100;
		}
	}
	[img saveAsKOImage:@"../test_img/test40_1.img"];

	p = [kern data];
	for (i = 0; i < 8; i++) {
		p[i] = i - 4;
	}
	[img t1DFIR:kern forLoop:[img xLoop]];
	[img saveAsKOImage:@"../test_img/test40_2.img"];

	return 0;
}

int
test41()	// high resolution FT pair
{
	RecImage	*freq, *time;
	float		*p, *q;
	float		x, a;
	int			i;
	int			fDim = 1000;
	int			tDim = 1000;
	int			fDim0;
	int			tDim0;

	freq = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:fDim];
	time = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:tDim];

	p = [time real];
	for (i = 0; i < 100; i++) {
	//	x = i * M_PI * 2 * 5 / 100;
		x = (float)i * 5 / 100;
		p[i] = exp(-x);
	}
	[time saveAsKOImage:@"../test_img/test41_1.img"];
	freq = [time copy];
	[freq shift1d:[freq xLoop]];
	[freq fft1d:[freq xLoop] direction:REC_INVERSE];
	[freq saveAsKOImage:@"../test_img/test41_2.img"];
	
	return 0;
}

int
test42()
{
	int			i, j, k, n = 20;
	float		x, y, y2, nr, ni, sg = 1.0;
	float		sum1, sum2;
	RecNoise	*rnd = [RecNoise noise];
	RecImage	*img1, *img2, *img3, *img4;	// img: noiseless, 2:rician, 3:Hakocn diff, 4:OShio diff
	RecImage	*tmp;
	int			xDim = 100;
	int			yDim = 10000;
	float		*p, *q;
	float		m, v;

// GWN test

//	for (i = 0; i < n; i++) {
//		x = (float)i * 5.0 / n;
//		y = sqrt(x*x + M_PI/2 * sg*sg);
//		printf("%f %f %f\n", x * 20, x * 4000 / 5, y * 4000 / 5);
//	}
//	exit(0);

	img1 = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:xDim yDim:yDim];
	p = [img1 real];
	q = [img1 imag];
	for (i = 0; i < yDim; i++) {
		for (j = 0; j < xDim; j++) {
			p[i * xDim + j] = (float)j * 5.0 / xDim;
		}
	}
	tmp = [img1 avgForLoop:[img1 yLoop]];
	[tmp saveAsKOImage:@"../test_img/test42_1.img"];	// noiseless

	img2 = [img1 copy];
	[img2 addRician:sg relative:NO];	// Rician
	tmp = [img2 copy];
//	[tmp subImage:img1];
	tmp = [tmp avgForLoop:[tmp yLoop]];

	[tmp real][[tmp xDim] - 1] = 5;
	[tmp saveAsKOImage:@"../test_img/test42_2.img"];	// Rician

	img3 = [img2 copy];
	[img3 corrForRician:sg];	// Hakon

	tmp = [img3 copy];
	[tmp subImage:img1];
	tmp = [tmp avgForLoop:[tmp yLoop]];
	[tmp real][[tmp xDim] - 1] = 5;
	[tmp saveAsKOImage:@"../test_img/test42_3.img"];
	
	img4 = [img2 copy];
	[img4 corrForRician2:sg];	// Oshio mod

	tmp = [img4 copy];
	[tmp subImage:img1];
	tmp = [tmp avgForLoop:[tmp yLoop]];
	[tmp real][[tmp xDim] - 1] = 5;
	[tmp saveAsKOImage:@"../test_img/test42_4.img"];
	
	return 0;
}


int
test43()
{
	RecImage	*img;
	NSString	*path, *url;

	path = @"../toshiba_images/DWI-nasu-6/Data/8000-all_AX-3rd_4.2.105008.29560.8001/Se8000Vo001No0001.dcm";
    url = [NSURL fileURLWithPath:path];
	img = [RecImage imageWithDicomFile:url];
	[img saveAsKOImage:@"test.img"];
	printf("max val = %f\n", [img maxVal]);

	return 0;
}


int
test44()
{
	int			dim;
//	int			k, l;
	int			i, j, imgSize, len;
	int			n = 8; //8;		// limit n to even for now
	int			ix, nn, cnt;
	RecImage	*img, *kl, *knl, *knlf, *param, *comp;
	RecImage	*tmp, *err;
	float		*pp, *qq, val, mx, mx0;
	float		sd = 0.008;

	printf("simple pinwheel framelet\n");

	param = Rec_pinwheel_param(n);
//	knlf = Rec_pinwheel_kernel(param, dim);
//	knl = [knlf copy];
//	[knl fft2d:REC_FORWARD];
	
//	img = [RecImage imageWithKOImage:@"test.img"];
//	img = [RecImage imageWithKOImage:@"../lungDef/VEO/VEO_sub.img"];
//	img = [RecImage imageWithKOImage:@"../lungDef/VEO/REF_sub.img"];
//	img = [RecImage imageWithKOImage:@"../lungDef/VEO/VEO.img"];
//	img = [img sliceAtIndex:110];
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-nasu-7/Anatomical/cor.img"];
//	img = [img sliceAtIndex:5];
//	img = [RecImage imageWithKOImage:@"../../MRCalc2/img1.img"];
	img = [RecImage imageWithKOImage:@"../test_img/CT01.img"];

	if (img == nil) {
		exit(0);
	}

if (0) {	// scale test
	tmp = [img copy];
	[img fft2d:REC_INVERSE];
	[img fft2d:REC_FORWARD];
	[img takeRealPart];
printf("%f %f\n", [tmp rmsVal], [img rmsVal]);
//	[img subImage:tmp];
//	[img saveAsKOImage:@"IMG.sub"];
	exit(0);
}

//[img cropToPo2];

//[img addGWN:sd relative:YES];

// scale test
[img crop:[img xLoop] to:128];
[img crop:[img yLoop] to:128];
[img saveAsKOImage:@"IMG.in"];

	mx0 = [img maxVal];
printf("in:mx = %f\n", mx0);
	err = [img copy];
	dim = [img xDim];
	kl = Rec_pinwheel_param(n);
	knl = Rec_pinwheel_kernel(img, kl);	// freq domain
	[knl saveAsKOImage:@"IMG.kernf"];
	tmp = [knl copy];
	[tmp fft2d:REC_FORWARD];
	[tmp takeRealPart];
	[tmp crop:[tmp xLoop] to:64];
	[tmp crop:[tmp yLoop] to:64];
	[tmp saveAsKOImage:@"IMG.kern"];
	

printf("knl_mx = %f\n", [knl maxVal]);

	len = [knl zDim];
//[knl saveAsKOImage:@"IMG.kern"];
	comp = Rec_pinwheel_decomp(img, knl);
	[comp saveAsKOImage:@"IMG.coef"];
	printf("coef mx = %f\n", [comp maxVal]);

// filter
	pp = [comp real];	// real only
	mx = [comp maxVal];
	imgSize = [comp xDim] * [comp yDim];
	cnt = 0;
	for (i = 0; i < imgSize; i++) {
		for (j = 0; j < len; j++) {
			val = pp[j * imgSize + i];
			if (fabs(val/mx) < sd * 1.5) {	// 1.5
				val *= 0.3;		// 0.3
				cnt++;
			}
			pp[j * imgSize + i] = val;
		}
	}
	[comp saveAsKOImage:@"IMG.filt"];
	printf("filt mx = %f\n", [comp maxVal]);
	val = (float)cnt / (imgSize * len);
	printf("removed %f %% of data\n", val * 100.0);

	img = Rec_pinwheel_synth(comp, knl);
	[img takeRealPart];
	mx = [img maxVal];
printf("out:mx = %f, mx0/mx = %f\n", val, mx0/mx);
//	[img multByConst:mx0/mx];
	[img saveAsKOImage:@"IMG.synth"];
	tmp = [RecImage imageWithImage:err];
	[tmp copyImageData:img];
printf("err/tmp = %f %f\n", [err maxVal], [tmp maxVal]);
	[err subImage:tmp];
	[err saveAsKOImage:@"IMG.err"];

	return 0;
}

int
test45()
{
	int			i, ix, n, skip, dim;
	float		*p, *q, *pp;
	RecImage	*img, *tser, *strans;
	int			k = 1;		// wave number
	int			x, f;		// position, frequency
	float		w, fxi;
	float		er, ei, th;
	int			xx, yy;

	printf("S-transform\n");
//	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-nasu-1/Run62547/b200-cor-si/img0.cpx"]; xx = 35; yy = 21;
	img = [RecImage imageWithKOImage:@"../toshiba_images/DWI-nasu-5/4V/img0.phs"]; xx = 62; yy = 81; //75;
	if ([img type] == RECIMAGE_COMPLEX) {
		[img phase];
	}
	n = [img zDim];
	dim = [img xDim];
	tser = [RecImage imageOfType:RECIMAGE_REAL xDim:n];
	printf("n = %d\n", n);
	// generate test input
	if (1) {
		n = 256;
		tser = [RecImage imageOfType:RECIMAGE_REAL xDim:n];
		pp = [tser data];
		for (i = 0; i < n; i++) {
			th = (float)i * i * 0.8 * M_PI / n;
		//	th = 0.5 * i;
			pp[i] = sin(th);
		//	printf("%d %f\n", i, pp[i]);
		}
	} else {
	// copy input time series
		p = [img data];
		pp = [tser data];
		skip = [img skipSizeForLoop:[img zLoop]];
		for (i = 0; i < n; i++) {
			ix = yy * dim + xx + i * skip;
			pp[i] = p[ix];
		//	printf("%d %f\n", i, q[i]);
		}
	}

	[tser saveAsKOImage:@"IMG.in"];
	if (1) {
		strans = Rec_dst(tser);
		[strans saveAsKOImage:@"IMG.str"];
	} else {


	// kernel test
	/*
		f = 50;
		x = 130;
		for (i = 0; i < n; i++) {
			fxi = f * (float)(x - i) / n / k;
			w = (float)abs(f) / (k * n * sqrt(2 * M_PI)) * exp(-0.5 * fxi * fxi);
			th = 2 * M_PI * i * f / n;
			er = cos(th);
			ei = sin(th);
			printf("%d %f %f\n", i, w * er, w * ei);
		}
	*/

		// S transform
		strans = [RecImage imageOfType:RECIMAGE_COMPLEX xDim:n yDim:n];
		p = [strans real];
		q = [strans imag];
		pp = [tser data];

		for (f = 0; f < n; f++) {
			for (x = 0; x < n; x++) {
				for (i = 0; i < n; i++) {
					fxi = f * (float)(x - i) / n / k;
					w = (float)abs(f) / (k * n * sqrt(2 * M_PI)) * exp(-0.5 * fxi * fxi);
					th = 2 * M_PI * i * f / n;
					er = cos(th);
					ei = sin(th);
				//	printf("%d %f %f\n", i, w * er, w * ei);
					p[f * n + x] += pp[i] * w * er;
					q[f * n + x] += pp[i] * w * ei;
				}
			}
		}
		[strans saveAsKOImage:@"IMG.str"];
	}

	return 0;
}
