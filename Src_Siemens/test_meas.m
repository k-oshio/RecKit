//
//
// memo: nSet is missing from Meas.YAPS
//				and only available in Config (pseudo JASON)
//			proceed using read_dims(), and update JASON part later
//
//

#import "RecKit.h"

int			read_meas_vd(NSString *path);

int
main()
{
@autoreleasepool {
	LP_DIM		lp_dim;
	RecImage	*img;

	system("rm IMG_*.*");
	
	if (0) {
		printf("===== VA check ======\n");
		img = [RecImage imageWithMeasAsc:@"meas0.asc" andMeasData:@"meas0.out" lpDim:&lp_dim];
		if (!img) {
			printf("VA read error\n");
			exit(0);
		}
		[img saveAsKOImage:@"IMG_VA.raw"];
		[img fft2d:REC_FORWARD];
		[img freqCrop];
		[img epiPcorr];
		[img saveAsKOImage:@"IMG_VA.img"];
		printf("===== VA ok ======\n");
	}

	if (0) {
		printf("===== VB check ======\n");
	//	img = [RecImage imageWithMeasVD:@"meas1.dat" lpDim:&lp_dim];
	//	img = [RecImage imageWithMeasVD:@"meas1_mult.dat" lpDim:&lp_dim];	// probably PROPELLER + SENSE -> don't bother
		img = [RecImage imageWithMeasVD:@"meas2_mult.dat" lpDim:&lp_dim];
		if (!img) {
			printf("VB read error\n");
			exit(0);
		}
		[img saveAsKOImage:@"IMG_VB.raw"];
		[img fft2d:REC_FORWARD];
		[img freqCrop];
		[img epiPcorr];
		[img saveAsKOImage:@"IMG_VB.img"];
		printf("===== VB ok ======\n");
	}

	if (0) {
		printf("===== VD check ======\n");
		img = [RecImage imageWithMeasVD:@"meas3.dat" lpDim:&lp_dim];
		if (!img) {
			printf("VD read error\n");
			exit(0);
		}
		[img dumpLoops];
		[img saveAsKOImage:@"IMG_VD.raw"];


		[img fft2d:REC_FORWARD];
		[img freqCrop];
		[img epiPcorr];

		[img saveAsKOImage:@"IMG_VD.img"];

		printf("===== VD ok ======\n");
    }

	if (1) {
		printf("===== VD check (32ch coil) ======\n");
		img = [RecImage imageWithMeasVD:
			@"/Volumes/Data/images/NIRS/2018-11-26/meas_MID00025_FID19258_MPRAGE_sag_p2_iso.dat"
			lpDim:&lp_dim];
		if (!img) {
			printf("VD read error\n");
			exit(0);
		}
		[img dumpLoops];
		[img saveAsKOImage:@"IMG_VD.raw"];
		[img fft2d:REC_FORWARD];
		[img saveAsKOImage:@"IMG_VD.img"];
	}
    return 0;

	} // autorelease pool
}

// replace with -imageWithMeasVD: when finished ###
int
read_meas_vd(NSString *path)
{
    FILE			*fp;
	LP_DIM			lp_dim;
	RecImage		*img;

    if ((fp = fopen([path UTF8String], "r")) == NULL) return -1;

	read_meta_vd(fp, &lp_dim);
	img = read_raw_vd(fp, &lp_dim);
	[img saveAsKOImage:@"Meas.raw.img"];

	[img fft2d:REC_FORWARD];
	[img saveAsKOImage:@"Meas.img.img"];

	fclose(fp);

	return 0;
}

