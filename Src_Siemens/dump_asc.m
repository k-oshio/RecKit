//
//
// memo: nSet is missing from Meas.YAPS
//				and only available in Config (pseudo JASON)
//			proceed using read_dims(), and update JASON part later
//

#import "RecKit.h"

int
main(int ac, char *av[])
{
@autoreleasepool {
	LP_DIM		lp_dim;
	RecImage	*img;

	if (ac < 2) {
		printf("dump_asc <meas_file>\n");
		exit(0);
	}
	
	img = [RecImage imageWithMeasVD:[NSString stringWithUTF8String:av[1]] lpDim:&lp_dim];
	if (!img) {
		printf("Meas read error\n");
		exit(0);
	}
	[img saveAsKOImage:@"IMG_dump_asc.raw"];
	[img fft2d:REC_FORWARD];
	[img freqCrop];
	[img epiPcorr];
	[img saveAsKOImage:@"IMG_dump_asc.img"];

    return 0;

	} // autorelease pool
}
