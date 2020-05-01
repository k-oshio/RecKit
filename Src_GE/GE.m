//
//	file I/O for GE P-file
//

#import "GE.h"

// global
int		hdr_rev;
int		lo_byte_first;

//======== category ===========
@implementation RecImage (GE)

+ (RecImage *)imageWithPfile:(NSString *)path RECCTL:(RECCTL *)ctl
{
	const char		*cPath = [path UTF8String];
	RecImage		*im;
	POOL_HEADER		hdr;
	FILE			*fp;
	RecLoop			*l_sl, *l_ch, *l_rd, *l_pe, *l_ec;
	RecLoopControl	*lc;
	int				sl, ch, ec, pe, rd;
	int				nslice, nchan, xdim, ydim, necho, pt_size, step;
	int				dataLength;
	float			*p, *q;
	short			*buf;	// one line
	int				ix;

	fp = fopen(cPath, "r");
	if (fp == NULL) return nil;

	read_pool_hdr(fp, &hdr, ctl);

// Loops
    nslice  = ctl->nslices;		// Slice
    nchan   = ctl->nrecs;       // Channel
    xdim    = ctl->da_xres;		// Read
	ydim    = ctl->da_yres;		// Phase
	necho   = ctl->nechoes;
	pt_size = ctl->pt_size;
	step = pt_size / 2;

	l_sl = [RecLoop loopWithName:@"Slice"	dataLength:nslice];
	l_ch = [RecLoop loopWithName:@"Channel"	dataLength:nchan];
	l_rd = [RecLoop loopWithName:@"Read"	dataLength:xdim];
	l_pe = [RecLoop loopWithName:@"Phase"	dataLength:ydim];
	l_ec = [RecLoop loopWithName:@"Echo"	dataLength:necho];

// alloc image
	im = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:l_ch, l_sl, l_ec, l_pe, l_rd, nil];
// unit
    [im setUnit:REC_POS  forLoop:l_sl];   // after real time FT
    [im setUnit:REC_FREQ forLoop:l_rd];
    [im setUnit:REC_FREQ forLoop:l_pe];
// geom
    [l_rd setFov:ctl->fov]; // mm
    [l_pe setFov:ctl->fov]; // mm
    [l_sl setFov:10.0];     // not defined in hder

    lc = [im control];
	dataLength = [im dataLength];
	buf = (short *)malloc(xdim * sizeof(short) * 2);

	[lc deactivateInner];
	[lc rewind];

	for (ch = 0; ch < nchan; ch++) {
		for (sl = 0; sl < nslice; sl++) {
			for (ec = 0; ec < necho; ec++) {
				// skip base data
				fread(buf, xdim, pt_size * 2, fp);
				for (pe = 0; pe < ydim; pe++) {
					// read one line
					fread(buf, xdim, pt_size * 2, fp);
					p = [im currentDataWithControl:lc];
					q = p + dataLength;
					ix = 0;
					for (rd = 0; rd < xdim; rd++) {
						p[rd] = read_short((unsigned char *)&buf[ix]); ix += step;
						q[rd] = read_short((unsigned char *)&buf[ix]); ix += step;
					}
					[lc increment];
				}
			}
		}
	}
	free(buf);

    [im conjugate];

	return im;
}

- (void)pfSwap:(BOOL)sw rot:(int)code
{
	if (sw) {
		[self trans];
	}
	if (code) {
		[self rotate:code];
	}
}

@end

//======== util func ... move to RecUtil ===========
int
read_int(unsigned char *buf)
{
	int     i;
    unsigned long val;

	val = 0;
    if (lo_byte_first) {
        for (i = 3; i >= 0; i--) {
            val <<= 8;
            val += buf[i];
        }
    } else {
        for (i = 0; i < 4; i++) {
            val <<= 8;
            val += buf[i];
        }
    }
    return (int)val;
}

float
read_float(unsigned char *buf)
{
	int		ival;
    float   val;

	ival = read_int(buf);
	bcopy(&ival, &val, 4);
    return val;
}

int
read_short(unsigned char *buf)
{
	int     i;
    short   val;

	val = 0;
    if (lo_byte_first) {
        for (i = 1; i >= 0; i--) {
            val <<= 8;
            val += buf[i];
        }
    } else {
        for (i = 0; i < 2; i++) {
            val <<= 8;
            val += buf[i];
        }
    }
	return (int)val;
}

int
read_pool_hdr(FILE *fp, POOL_HEADER *poolhdr, RECCTL *ctl)
{
	int				hdrsize;
    int				runno, testrunno;
	RDB_HEADER_REC	*hdr;
	float			hdr_rev_f;

	fread(poolhdr, sizeof(POOL_HEADER), 1, fp); // entire header
	hdr = (RDB_HEADER_REC *)poolhdr;

    runno = atoi(hdr->rdb_hdr_run_char);
	lo_byte_first = 0;
	testrunno = read_int((unsigned char *)&hdr->rdb_hdr_run_int);
    if (runno == testrunno) {
        lo_byte_first = 0;
        printf("MSB first\n");
    } else {
        lo_byte_first = 1;
        printf("LSB first\n");
    }

// size is rev dependent ... diff is only in exam/ser/im part
    hdr_rev_f = read_float((unsigned char *)(&hdr->rdb_hdr_rdbm_rev));
	hdr_rev = (int)hdr_rev_f;
	printf("RDBM header version = %4.2f\n", hdr_rev_f);

    switch (hdr_rev) {
    case 5 :
		hdrsize = 39940;
        break;
    case 7 :
		hdrsize = 39984;
        break;
    case 8 :
		hdrsize = 60464;
        break;
    case 9 :
	//	hdrsize = 39984;	// rdbm.h is not correct
		hdrsize = 61464;
        break;
    case 11 :
    default :
//		hdrsize = 66072;	// rdbm.h (ver 11) says it's 65560
		hdrsize = read_int((unsigned char *)&hdr->rdb_hdr_off_data);
		break;
    }
//	printf("header size = %d\n", hdrsize);
	fseek(fp, hdrsize, SEEK_SET);	// skip rest of header

    set_ctl(poolhdr, ctl);

    return 0;
}

void
set_ctl(POOL_HEADER	*poolhdr, RECCTL *ctl)
{
	int			bit;
	int			i;
	RDB_HEADER_REC		*hdr;
	RDB_SLICE_INFO_ENTRY	*acqtab;

// image dim
	hdr = (RDB_HEADER_REC *)poolhdr;
	ctl->da_xres = read_short((unsigned char *)&hdr->rdb_hdr_da_xres);
	ctl->da_yres = read_short((unsigned char *)&hdr->rdb_hdr_da_yres) - 1;
	ctl->rc_xres = read_short((unsigned char *)&hdr->rdb_hdr_rc_xres);
	ctl->rc_yres = read_short((unsigned char *)&hdr->rdb_hdr_rc_yres);
	ctl->rc_zres = read_short((unsigned char *)&hdr->rdb_hdr_rc_zres);
	ctl->frsize = read_short((unsigned char *)&hdr->rdb_hdr_frame_size);
	ctl->nframes = read_short((unsigned char *)&hdr->rdb_hdr_nframes) - 1;
	ctl->pfov = read_float((unsigned char *)&hdr->rdb_hdr_phase_scale);
	ctl->pt_size = read_short((unsigned char *)&hdr->rdb_hdr_point_size);
// slice order
	ctl->nslices = read_short((unsigned char *)&hdr->rdb_hdr_nslices);
	ctl->nechoes = read_short((unsigned char *)&hdr->rdb_hdr_nechoes);
	ctl->npasses = read_short((unsigned char *)&hdr->rdb_hdr_npasses);
	ctl->nrecs = read_short((unsigned char *)&hdr->rdb_hdr_dab[0].stop_rcv)
		- read_short((unsigned char *)&hdr->rdb_hdr_dab[0].start_rcv) + 1;
	ctl->cheart = read_short((unsigned char *)&hdr->rdb_hdr_cheart);
// rhtype
	bit = read_short((unsigned char *)&hdr->rdb_hdr_data_collect_type);
//	ctl->chop = ((bit & RDB_CHOPPER) != RDB_CHOPPER);
	ctl->cine = (bit & RDB_CINE);
	ctl->hnex = (bit & RDB_HNEX);
	ctl->hecho = (bit & RDB_HECHO);
	ctl->nop = (bit & RDB_NO_PHASE_WRAP);
	ctl->ft3d = (bit & RDB_3DFFT);
	ctl->pomp = (bit & RDB_POMP);
// rhformat
	bit = read_short((unsigned char *)&hdr->rdb_hdr_data_format);
	ctl->chop = (bit & RDB_YCHOP);
// rhdaqctrl
	bit = read_short((unsigned char *)&hdr->rdb_hdr_dacq_ctrl);
	ctl->eepf = (bit & RDB_FLIP_PHASE_EVEN);
	ctl->oepf = (bit & RDB_FLIP_PHASE_ODD);
	ctl->eeff = (bit & RDB_FLIP_FREQ_EVEN);
	ctl->oeff = (bit & RDB_FLIP_FREQ_ODD);
// image orientation
	ctl->trans = read_short((unsigned char *)&hdr->rdb_hdr_transpose);
	if (ctl->trans != 0) {
		ctl->trans = 0;
	} else {
		ctl->trans = 1;
	}
	ctl->rot = read_short((unsigned char *)&hdr->rdb_hdr_rotation);

	ctl->coilno = read_int((unsigned char *)&hdr->rdb_hdr_coilno);

// data_acq_tab
	acqtab = (RDB_SLICE_INFO_ENTRY *) poolhdr->rdb_hdr_data_acq_tab;
	for (i = 0; i < ctl->nslices; i++) {
		ctl->slpass[i] = read_short((unsigned char *)&acqtab[i].pass_number);
		ctl->slc[i] = read_short((unsigned char *)&acqtab[i].slice_in_pass);
	}
// rhuser
	ctl->rhuser[ 0] = read_float((unsigned char *)&hdr->rdb_hdr_user0);
	ctl->rhuser[ 1] = read_float((unsigned char *)&hdr->rdb_hdr_user1);
	ctl->rhuser[ 2] = read_float((unsigned char *)&hdr->rdb_hdr_user2);
	ctl->rhuser[ 3] = read_float((unsigned char *)&hdr->rdb_hdr_user3);
	ctl->rhuser[ 4] = read_float((unsigned char *)&hdr->rdb_hdr_user4);
	ctl->rhuser[ 5] = read_float((unsigned char *)&hdr->rdb_hdr_user5);
	ctl->rhuser[ 6] = read_float((unsigned char *)&hdr->rdb_hdr_user6);
	ctl->rhuser[ 7] = read_float((unsigned char *)&hdr->rdb_hdr_user7);
	ctl->rhuser[ 8] = read_float((unsigned char *)&hdr->rdb_hdr_user8);
	ctl->rhuser[ 9] = read_float((unsigned char *)&hdr->rdb_hdr_user9);
	ctl->rhuser[10] = read_float((unsigned char *)&hdr->rdb_hdr_user10);
	ctl->rhuser[11] = read_float((unsigned char *)&hdr->rdb_hdr_user11);
	ctl->rhuser[12] = read_float((unsigned char *)&hdr->rdb_hdr_user12);
	ctl->rhuser[13] = read_float((unsigned char *)&hdr->rdb_hdr_user13);
	ctl->rhuser[14] = read_float((unsigned char *)&hdr->rdb_hdr_user14);
	ctl->rhuser[15] = read_float((unsigned char *)&hdr->rdb_hdr_user15);
	ctl->rhuser[16] = read_float((unsigned char *)&hdr->rdb_hdr_user16);
	ctl->rhuser[17] = read_float((unsigned char *)&hdr->rdb_hdr_user17);
	ctl->rhuser[18] = read_float((unsigned char *)&hdr->rdb_hdr_user18);
	ctl->rhuser[19] = read_float((unsigned char *)&hdr->rdb_hdr_user19);
// image param
    ctl->tr = read_short((unsigned char *)&hdr->rdb_hdr_fd_tr); // X
    ctl->te = read_int((unsigned char *)&hdr->rdb_hdr_te); // ok
    ctl->flip = 0;
    ctl->fov = read_float((unsigned char *)&hdr->rdb_hdr_fov); // ok
}

// dbg
void
dump_ctl(RECCTL *ctl)
{
    int     i;
// dimentions
	printf("da_xres = %d\n", ctl->da_xres);
    printf("da_yres = %d\n", ctl->da_yres);
    printf("rc_xres = %d\n", ctl->rc_xres);
    printf("rc_yres = %d\n", ctl->rc_yres);
    printf("rc_zres = %d\n", ctl->rc_zres);
    printf("pfov    = %4.2f\n", ctl->pfov);
    printf("frsize  = %d\n", ctl->frsize);
    printf("nframes = %d\n", ctl->nframes);
    printf("nslices = %d\n", ctl->nslices);
    printf("nechoes = %d\n", ctl->nechoes);
    printf("npasses = %d\n", ctl->npasses);
    printf("nrecs   = %d\n", ctl->nrecs);
    printf("cheart  = %d\n", ctl->cheart);
    printf("pt_size = %d\n", ctl->pt_size);
// rhtype
    printf("chop    = %d\n", ctl->chop);
    printf("cine    = %d\n", ctl->cine);
    printf("hnex    = %d\n", ctl->hnex);
    printf("hecho   = %d\n", ctl->hecho);
    printf("nop     = %d\n", ctl->nop);
    printf("ft3d    = %d\n", ctl->ft3d);
    printf("pomp    = %d\n", ctl->pomp);
// rhdaqctrl
    printf("eepf    = %d\n", ctl->eepf);
    printf("oepf    = %d\n", ctl->oepf);
    printf("eeff    = %d\n", ctl->eeff);
    printf("oeff    = %d\n", ctl->oeff);
// image orientation
    printf("trans   = %d\n", ctl->trans);
    printf("rot     = %d\n", ctl->rot);
// slice order
//	int		slpass[512];
//	int		slc[512];
// rhuser
    printf("rhuser\n");
    for (i = 0; i < 10; i++) {
        printf("%4.2f ", ctl->rhuser[i]);
    }
    printf("\n");
    for (i = 10; i < 20; i++) {
        printf("%4.2f ", ctl->rhuser[i]);
    }
    printf("\n");
// testing...
    printf("coilno  = %d\n", ctl->coilno);
    printf("TE  = %5.1f\n", ctl->te / 1000);
    printf("FOV = %5.1f\n", ctl->fov / 10);
//    printf("TR  = %5.1f\n", ctl->tr);
//    printf("flip  = %5.1f\n", ctl->flip);
}
