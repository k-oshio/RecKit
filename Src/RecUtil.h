//
//  RecUtil.h
//  utility functions
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import "RecImage.h"    // RecVector def

// util macro
#define Rec_max(x, y) ((x) > (y) ? (x) : (y))
#define Rec_min(x, y) ((x) < (y) ? (x) : (y))

typedef struct {
    int     dim;
    int     order;
    float   *cs;
} RecDctSetup;

typedef struct {
    int     dim;
    int     order;
    float   *Tk;
	float	*w;
	float	*nm;
} RecChebSetup;

typedef struct {
    int     dim;
	DSPSplitComplex	cs;
	DSPSplitComplex	wkcs;
	DSPSplitComplex	wk;
} RecDftSetup;

typedef struct {
    int				dim;		// n for Chirp-Z
	int				dim2;		// Po2 for FFT
	FFTSetup		fft_setup;	// FFT setup			(dim2)
	DSPSplitComplex	cp;			// chirp cos / sin		(dim)
	DSPSplitComplex	cpf;		// chirp zero-fill & FT (dim2)
	DSPSplitComplex	wk;			// work area			(dim2)
} RecCftSetup;

typedef struct {
    int     dim;
	int		kern_size;
	float	*sc;	// scaling function
	float	*wv;	// wavelet function
	float	*wk;	// work area
} RecWaveSetup;

typedef struct {
	cl_context			context;
	cl_command_queue	cmd_queue;
	cl_program			program;
	cl_kernel			kern;
	size_t				lWorkSize[2], gWorkSize[2];
	cl_device_id		*devices;
} Rec_GPU;

// power_of_2
int     Rec_po2(int n);	// up (for zero-fill
int		Rec_up2Po2(int n);
int		Rec_down2Po2(int n);

// complex mult (cpx1 *= cpx2, cpx1 *= cpx2*)
void	Rec_cpx_mul(float *dst_re, float *dst_im, int dst_skip,
					float *src_re, float *src_im, int src_skip, int len);
// complex conjugate mult
void	Rec_cpx_cmul(float *dst_re, float *dst_im, int dst_skip,
					float *src_re, float *src_im, int src_skip, int len);

// error est util
float	Rec_dotprod(float *p1, float *p2, int len);
float	Rec_L2_norm(float *p, int len);
float	Rec_L2_dist(float *p1, float *p2, int len);
void	Rec_normalize(float *p, int len);

// make orthogonal expantion later ###
// phase correction 1D
void	Rec_pcorr(float *re, float *im, int skip, int len, float *phs);	// p0 array
void    Rec_est_correl(float *re, float *im, int skip, int len, float *sumr, float *sumi);
float   Rec_est_1st(float *re, float *im, int skip, int len);
void    Rec_corr1st(float *re, float *im, int skip, int len, float p1);
// phase correction 1D / 2D
void    Rec_est_sum(float *re, float *im, int skip, int len, float *sumr, float *sumi);
float   Rec_est_0th(float *re, float *im, int skip, int len);
void    Rec_corr0th(float *re, float *im, int skip, int len, float p0);	// const p0

// EPI pcorr
void		Rec_epi_pcorr(float *p, float *q, int xDim, int yDim, BOOL se);
// 2nd order iterative pcorr (need to be square -> expand to rect later)
// probably 1d version should be used
void		Rec_pcorr_fine(float *p, float *q, int xDim, int yDim);
void		pcorr_line(float *p, float *q, int xDim, int yDim, int x);
void		sort_mg(float *p, int n);
// 1D phase est
void		Rec_est_poly_1d(float *coef, int order, float *re, float *im, int skip, int len);
void		Rec_corr_poly_1d(float *coef, int order, float *re, float *im, int skip, int len);
void		Rec_unwrap_1d(float *p, int n, int skip);
RecImage	*Rec_nyquist_seg(RecImage *sm, RecImage *df);
// 2D phase est
//void		Rec_est_poly_2d(float *coef, int ordx, int ordy, float *re, float *im, int xDim, int yDim); // moved to nciRec
void		Rec_corr_poly_2d(float *coef, int ordx, int ordy, float *re, float *im, int xDim, int yDim);
void		Rec_chk_phase(float *ph, float *mg, int xDim, int yDim, float mx);

// func version -> use RecImage ##
FFTSetup	Rec_fft_setup(int dim);
void		Rec_free_fft_setup(FFTSetup setup);
void		Rec_fft_1d(float *re, float *im, int dim, int direction, FFTSetup setup);
void		Rec_fft_2d(float *re, float *im, int xDim, int yDim, int direction);
void		Rec_fft_x(float *re, float *im, int xDim, int yDim, int direction);
void		Rec_fft_y(float *re, float *im, int xDim, int yDim, int direction);

// digital cosine transform (p -> q)
// design API first...
// 2d is limited to symmetric img / coef
RecDctSetup *Rec_dct_setup(int dimImg, int dimCoef);
void		Rec_free_dct_setup(RecDctSetup *setup);
void		Rec_dct_1d(float *img, int i_skip, float *coef, int c_skip, RecDctSetup *setup, int direction);
void		Rec_dct_2d(float *img, float *coef, RecDctSetup *setup, int direction);
void		Rec_dct_2d_corr(float *p, float *q, float *coef, RecDctSetup *setup);

RecChebSetup *Rec_cheb_setup(int dimImg, int dimCoef);
void		Rec_free_cheb_setup(RecChebSetup *setup);
void		Rec_cheb_1d(float *img, int i_skip, float *coef, int c_skip, RecChebSetup *setup, int direction);
void		Rec_cheb_2d(float *img, float *coef, RecChebSetup *setup, int direction);
void		Rec_cheb_2d_corr(float *p, float *q, float *coef, RecChebSetup *setup);
RecImage	*Rec_cheb_mk_2d_kern(int xDim, int yDim, int ordx, int ordy);
void		Rec_cheb_2d_expansion(float *p, float *cp, RecImage *kern);

// Wavelet
RecWaveSetup *Rec_wave_setup(int dim);
void		Rec_free_wave_setup(RecWaveSetup *setup);
void		Rec_wvt(float *x, int lev, RecWaveSetup *setup);
void		Rec_iwvt(float *x, int lev, RecWaveSetup *setup);

// Pinwheel
void		Rec_pinwheel(int k, int l, int n, RecImage *img);
RecImage	*Rec_pinwheel_param(int n);		// k, l
//RecImage	*Rec_pinwheel_kernel(RecImage *param, int len);
RecImage	*Rec_pinwheel_kernel(RecImage *img, RecImage *param);
RecImage	*Rec_pinwheel_dump_kernel(int n);
RecImage	*Rec_pinwheel_decomp(RecImage *img, RecImage *knl);
RecImage	*Rec_pinwheel_synth(RecImage *img, RecImage *knl);


// filter
void    Rec_smooth(float *p, int n, int ks);

// find peak position of phase correlation image (with gaussian window)
float       Rec_find_peak_frac(float *p, int skip, int n);
// 
float       Rec_find_peak(float *p, int skip, int n);
NSPoint     Rec_find_peak2(float *p, int xDim, int yDim);
RecVector   Rec_find_peak3(float *p, int xDim, int yDim, int zDim);
// with max value
float       Rec_find_peak_mx(float *p, int skip, int n, float *mx);
NSPoint     Rec_find_peak2_mx(float *p, int xDim, int yDim, float *mx);
RecVector   Rec_find_peak3_mx(float *p, int xDim, int yDim, int zDim, float *mx);
//
NSPoint		Rec_find_peak2_phs(float *p, float *q, int xDim, int yDim, float *phs);

// OpenCL utility
void        clCheckError(int err, char *where);
void        initGPU(Rec_GPU *gp, NSString *fileName);
void        freeGPU(Rec_GPU *gp);

// golden angle
float		Rec_golden_angle(int i);
float		Rec_golden_angle_t(int i);

// convolution util (2D or 3D, depending on dst image)
void		Rec_take_ROI(RecImage *src, RecImage *dst, int xc, int yc, int zc);

// RecImage (Warp) : conversion from pixel to fracFOV
RecImage	*dispToMap(RecImage *disp);

// DFT
RecDftSetup	*Rec_dftsetup(int len);
void		Rec_dft(RecDftSetup *setup, DSPSplitComplex *src, int src_skip, int direction);
void		Rec_destroy_dftsetup(RecDftSetup *setup);

// Chirp-Z
RecCftSetup	*Rec_cftsetup(int len);
void		Rec_cft(RecCftSetup *setup, DSPSplitComplex *src, int src_skip, int direction);
void		Rec_destroy_cftsetup(RecCftSetup *setup);

//============

