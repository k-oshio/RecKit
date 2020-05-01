//
//	file I/O for Siemens
//	64bit version (not tested for 32bit)
//

#import "mdh.h"	// ver ??? (VA ???)
#import "RecImage.h"
#import "RecLoop.h"
#import "RecLoopIndex.h"
#import "RecLoopControl.h"

#define	VERSION_VA	0
#define	VERSION_VB	1
#define	VERSION_VD	3

// mask (defined in pkg/MrServers/MrMeasSrv/SeqIF/MDH/MdhProxy.h)
#define MDH_MASK_PCOR   0x00200000
#define MDH_MASK_FLIP   0x01000000
#define MDH_MASK_EOFM   0x00000001

#define	MDH_SCALE	(1.0e5)


typedef struct {
    int         mask;
	int			counter;
	int			time;
	//
    int         cLin;	// ky
    int         cAcq;	// avg
    int         cSlc;	// slc
    int         cPar;	// par (3d)
    int         cEco;	// echo
    int         cPha;	// cardiac ?
    int         cRep;	// phase
	int			cCha;
	//
	int			cSet;	// repetition (dynamic)
	int			cSeg;	// epi flip
	int			cIda;	// not used
	int			cIdb;	// not used
	int			cIdc;	// not used
	int			cIdd;	// not used
	int			cIde;	// not used
	//
	int			nSamples;
	int			nChannels;
} LP_CTR;	// in each MDH

typedef struct {
//	software version
	int			version;	// 0:VA, 1:VB, 3:VD
// pulse sequence
    char        seq_name[256];
// copied from MDH
    int         nSamples;
    int         nChannels;
// calculated by reading all MDH's
    int         nLin;
    int         nSlc;
    int         nAcq;       // avg
    int         nRep;       // delay step (or stim on/off)
	int			nPar;
	int			nPCorr;
	int			nShot;
	int			nSet;
	int			nSeg;
	int			nImages;	// redundant.. total images
    int         nMDH;       // number of total MDH records in file
//	time sequence
	int			repIsOuter;	//	rep loop is outer to acq (in time)
// read from Meas.asc
	int			epifactor; 
	int			turbofactor;
    int         segments;
// slice dimension
    float       slThick;
    float       readFOV;
    float       phaseFOV;
// slice orientation
    float       normalCor;
    float       normalTra;
    float       normalSag;
    float       inplaneRot;
// Wip params
    float       wip[16];
} LP_DIM;

// c func
void        clear_ctr(LP_CTR *ctr);
void        clear_lpdim(LP_DIM *lp_dim);
void        get_seqname(char *buf, char *seq_nm);
void        get_param(char *buf, char *name, int *val_out, BOOL paren);
void        get_fparam(char *buf, char *name, float *val_out);
void        get_wip(char *buf, float *wp);
int         to_short(unsigned char *p);
float       to_float(unsigned char *p);
int         to_long(unsigned char *p);
BOOL        read_mdh(FILE *fp, LP_CTR *lp_ctr);
int         read_asc(FILE *fp, LP_DIM *lp_dim);
int         read_dims_va(FILE *fp, LP_DIM *lp_dim);
void        dump_dims_va(LP_DIM *lp_dim);
void        dump_dims_vd(LP_DIM *lp_dim);
void        read_line(float *re, float *im, float *buf, int n, int flip);
RecImage    *read_raw(FILE *fp, LP_DIM *lp_dim);

// vb, vd
int			get_str(char *p, int max_len, FILE *fp);
int			read_meta_vd(FILE *fp, LP_DIM *lp_dim);
BOOL		read_mdh_vd(FILE *fp, LP_CTR *lp_ctr);
BOOL		read_chh_vd(FILE *fp, LP_CTR *lp_ctr);
int			read_asc_vd(char *buf, LP_DIM *lp_dim);
RecImage *	read_raw_vd(FILE *fp, LP_DIM *lp_dim);
int			read_dims_vb(FILE *fp, LP_DIM *lp_dim);
int			read_dims_vd(FILE *fp, LP_DIM *lp_dim);
int			read_config_vd(char *buf, LP_DIM *lp_dim);
int			read_line_vd(float *p, float *q, float *buf, int len, int flip);

void		dump_meas_text(char *buf, int len, char *path);

//====================================
@interface	RecImage (Siemens)

// VA
+ (RecImage *)imageWithMeasAsc:(NSString *)asc andMeasData:(NSString *)data;
+ (RecImage *)imageWithMeasAsc:(NSString *)asc andMeasData:(NSString *)data lpDim:(LP_DIM *)dim;

// VB, VD
+ (RecImage *)imageWithMeasVD:(NSString *)meas lpDim:(LP_DIM *)dim;
+ (void)readMetaVD:(NSString *)meas lpDim:(LP_DIM *)dim;

- (void)reorderSlice;
- (void)rotImage:(float)angle;

@end

// ### not done yet