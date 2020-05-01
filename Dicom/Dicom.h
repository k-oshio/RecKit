//
//

#import "RecImage.h"
#import "RecLoop.h"

#define     REC_DCM_UNK     -1
#define		REC_DCM_SHORT	0
#define		REC_DCM_INT		1
#define		REC_DCM_STRING	2
#define		REC_DCM_FLOAT	3
#define		REC_DCM_DOUBLE	4
#define		REC_DCM_SARRAY	5
#define		REC_DCM_LARRAY	6

/* data element */
typedef struct REC_DCM_DEL {
    int     tag_gr;     /* tag, group number */
    int     tag_num;    /* tag, element number */
    int     type;       /* type, REC_DCM_SHORT etc */
    int     len;        /* byte length of data part */
    int     ofs;       /* starting byte offset of data part */
} REC_DCM_DEL;

// c functions
// top level
int         Rec_dcm_read_file_meta(FILE *);
int         Rec_dcm_read_item(FILE *, int, int, int, char *, int);
int         Rec_dcm_dump_items(FILE *);

// lower level
short       Rec_dcm_read_short(FILE *, int, int);   // short val
float       Rec_dcm_read_float(FILE *, int, int);   // float val in string
int         Rec_dcm_buf_to_short(unsigned char *);
int         Rec_dcm_buf_to_long(unsigned char *);
int         Rec_dcm_get_short(FILE *, unsigned short *);
int         Rec_dcm_get_int(FILE *, int *);
int         Rec_dcm_read_tag(FILE *, REC_DCM_DEL *);
int         Rec_dcm_vr(char *, int *, int *);

// === obj c ===
@interface	RecImage (Dicom)

+ (RecImage *)imageWithDicomFile:(NSString *)path;
+ (RecImage *)imageWithDicomFiles:(NSArray *)paths;
+ (void)initDicomDict;

@end
