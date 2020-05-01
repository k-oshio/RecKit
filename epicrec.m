//
//  simple recon
//  supports:
//      xres/yres up to 512
//      pfov
//      nop
//      orientation based on header info

#import <RecKit/RecKit.h>

int
main(int ac, char *av[])
{
    @autoreleasepool {
        char		fname[256];
        NSString	*path;
        int			pnum;
        RecLoop		*rd, *pe;
        RecLoop		*ky, *kx;
        int			xdim, ydim;
        RecImage	*raw;
        RECCTL		ctl;
        BOOL        verbose = NO;

        if (ac > 1 && av[1][0] == '-' && av[1][1] == 'v') {
            verbose = YES;
            printf("verbose mode\n");
        }
        printf("Raw data file ? ");
        fgets(fname, 256, stdin);
        fname[strlen(fname)-1] = 0;
        path = [NSString stringWithUTF8String:fname];
        raw = [RecImage imageWithPfile:path RECCTL:&ctl];
        if (raw == nil) {
            printf("Couldn't open image file [%s]\n", fname);
            exit(0);
        }
        if (sscanf(fname, "P%d.7", &pnum) == 0) {
            pnum = 0;
        }
        if (verbose) {
            dump_ctl(&ctl);
            exit(0);
        }

    //	sprintf(fname, "I%05d.raw", pnum);
        path = [NSString stringWithFormat:@"I%05d.raw", pnum];
        [raw saveAsKOImage:path];

        rd = [RecLoop findLoop:@"Read"];
        pe = [RecLoop findLoop:@"Phase"];

        xdim = [rd dataLength];
        if (xdim > 512) {
            printf("Read dim > 512\n");
            exit(0);
        }
        if (xdim > 256) {
            xdim = 512;
        } else {
            xdim = 256;
        }
        kx = [RecLoop loopWithName:@"kx" dataLength:xdim];

        ydim = [pe dataLength];
        if (ydim > 512) {
            printf("Phase dim > 512\n");
            exit(0);
        }
        if (ydim > 256) {
            ydim = 512;
        } else {
            ydim = 256;
        }
        ky = [RecLoop loopWithName:@"ky" dataLength:ydim];

    // 2D FT
        // hnex
        if (ctl.hnex) {
            [raw replaceLoop:rd withLoop:kx];
            [raw fft1d:kx direction:REC_FORWARD];
            [raw halfFT:pe];
            ky = [raw yLoop];
        } else
        // hecho
        if (ctl.hecho) {
            [raw replaceLoop:pe withLoop:ky];
            [raw fft1d:ky direction:REC_FORWARD];
            [raw halfFT:rd];
            kx = [raw xLoop];
        // default (zero-fill)
        } else {
            [raw replaceLoop:rd withLoop:kx];
            [raw fft1d:kx direction:REC_FORWARD];
            [raw replaceLoop:pe withLoop:ky];
            [raw fft1d:ky direction:REC_FORWARD];
        }

        // pfov
        if (ctl.pfov != 1.0) {
            [raw pFOV:ctl.pfov];
        }
        // nop
        if (ctl.nop) {
            path = [NSString stringWithFormat:@"I%05d_nop.img", pnum];
            [raw saveAsKOImage:path];
            [raw nopCrop];
        }
        // image orientation
        [raw pfSwap:ctl.trans rot:ctl.rot];

        path = [NSString stringWithFormat:@"I%05d.img", pnum];
        [raw saveAsKOImage:path];
    }
	return 0;
}
