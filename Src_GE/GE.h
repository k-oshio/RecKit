//
//	file I/O for GE P-file
//

//#include <stdio.h>
//#include <math.h>
#define RECON_FLAG	/* used in rdbm.h */
#import "rdbm.11.0.h"
#import "RecImage.h"
#import "RecLoop.h"
#import "RecLoopControl.h"

/* ========== recutil ============= */
typedef struct RECCTL {
/* dimentions */
	int		da_xres;
	int		da_yres;
	int		rc_xres;
	int		rc_yres;
	int		rc_zres;
	float	pfov;
	int		frsize;
	int		nframes;
	int		nslices;
	int		nechoes;
	int		npasses;
	int		nrecs;
	int		cheart;
    int		pt_size;
/* rhtype */
	int		chop;
	int		cine;
	int		hnex;
	int		hecho;
	int		nop;
	int		ft3d;
	int		pomp;
/* rhdaqctrl */
	int		eepf;
	int		oepf;
	int		eeff;
	int		oeff;
/* image orientation */
	int		trans;
	int		rot;
/* slice order */
	int		slpass[512];
	int		slc[512];
/* rhuser */
	float	rhuser[20];
/* image param */
    float   tr;
    float   te;
    float   flip;
    float   fov;
/* testing... */
	int		coilno;
} RECCTL;

int		read_int(unsigned char *buf);
float	read_float(unsigned char *buf);
int		read_short(unsigned char *buf);
int		read_pool_hdr(FILE *fp, POOL_HEADER *poolhdr, RECCTL *ctl);
void	set_ctl(POOL_HEADER *poolhdr, RECCTL *ctl);
void    dump_ctl(RECCTL *ctl);

@interface	RecImage (GE)

+ (RecImage *)imageWithPfile:(NSString *)path RECCTL:(RECCTL *)ctl;
- (void)pfSwap:(BOOL)sw rot:(int)code;		// GE specific

@end