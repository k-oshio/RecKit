//
//  read DICOM files
//  first implementation uses c functions
//  repalace these with Dicom class later
//  tag dictionary should be placed in RecKit bundle (currently in $home/lib)
//

#import "Dicom.h"

// global flags etc
int         Rec_dcm_little_endian;	/* 0: no, 1:yes */
int         Rec_dcm_explicit_vr;	/* 0: no, 1:yes */
int         Rec_dcm_start;          /* end of file meta */
extern int  dbg;

NSDictionary    *vrDict = nil;
NSDictionary    *tagDict = nil;

@implementation RecImage (Dicom)

//
// === assumptions: ===
//  images have same dim
//  each file contains one slice
//
+ (void)initDicomDict  // bundle version
{
    NSBundle    *bundle = [NSBundle bundleForClass:[RecImage class]];
    NSString    *path;
    

    if (vrDict == nil) {
        if (bundle == nil) {
            printf("DICOM dictionary not found\n");
            return;
        }
        path = [bundle pathForResource:@"vrDictionary" ofType:@"plist"];
        vrDict = [NSDictionary dictionaryWithContentsOfFile:path];
    }
    if (tagDict == nil) {
        path = [bundle pathForResource:@"tagDictionary" ofType:@"plist"];
        tagDict = [NSDictionary dictionaryWithContentsOfFile:path];
    }
}

+ (RecImage *)imageWithDicomFile:(NSURL *)url
{
	NSArray		*paths = [NSArray arrayWithObject:url];
	return [RecImage imageWithDicomFiles:paths];
}

+ (RecImage *)imageWithDicomFiles:(NSArray *)URLs
{
    RecImage    *img;
    FILE        *fp;
    const char  *cPath;
    short       sVal;
    char        str[256];
    short       *buf;
    int         xdim, ydim, zdim;
    RecLoop     *xLoop, *yLoop, *zLoop;
    float       xpxs, ypxs, zpos1, zpos2;
	int			intercept, slope;			// for HU value (CT)
	int			maxPix, fullVal;			// pixel scaling (Canon)
	float		pixScale;
    int         i, j, dataLen;
    float       *p;
	int			sts;
	BOOL		ct = NO;

    if (tagDict == nil) [RecImage initDicomDict];

    zdim = (int)[URLs count];
// slice 1
    cPath = [[[URLs objectAtIndex:0] path] UTF8String];
    fp = fopen(cPath, "r");
    if (fp == NULL) return nil;
	sts = Rec_dcm_read_file_meta(fp); // results are saved in global var
	if (sts < 0) return nil;

    Rec_dcm_read_item(fp, 0x8, 0x60, REC_DCM_STRING, str, 256);	//
//printf("mod = %s\n", str);
	ct = (strncmp(str, "CT", 2) == 0);

    Rec_dcm_read_item(fp, 0x28, 0x10, REC_DCM_SHORT, (char *)&sVal, 2);	// yDim
    ydim = sVal;
    Rec_dcm_read_item(fp, 0x28, 0x11, REC_DCM_SHORT, (char *)&sVal, 2);	// xDim
    xdim = sVal;
    Rec_dcm_read_item(fp, 0x28, 0x30, REC_DCM_STRING, str, 256);	//
    sscanf(str, "%f\\%f", &xpxs, &ypxs);

    Rec_dcm_read_item(fp, 0x28, 0x1052, REC_DCM_STRING, str, 256);	// Intercept
    sscanf(str, "%d", &intercept);
    Rec_dcm_read_item(fp, 0x28, 0x1053, REC_DCM_STRING, str, 256);	// Slope
     sscanf(str, "%d", &slope);
//printf("inter = %d, slope = %d\n", intercept, slope);
    Rec_dcm_read_item(fp, 0x20, 0x1041, REC_DCM_STRING, str, 256);
    sscanf(str, "%f", &zpos1);
    fclose(fp);
// slice 2
    if (zdim > 1) {
        cPath = [[[URLs objectAtIndex:1] path] UTF8String];
    //    cPath = [[paths objectAtIndex:1] UTF8String];
        fp = fopen(cPath, "r");
        Rec_dcm_read_item(fp, 0x20, 0x1041, REC_DCM_STRING, str, 256);
        sscanf(str, "%f", &zpos2);
        fclose(fp);
        zpos1 = fabs(zpos1 - zpos2);    // slice interval
    }
// dim
    xLoop = [RecLoop loopWithDataLength:xdim];
    yLoop = [RecLoop loopWithDataLength:ydim];
    zLoop = [RecLoop loopWithDataLength:zdim];
// fov
    [xLoop setFov:xpxs * xdim];
    [yLoop setFov:ypxs * ydim];
    [zLoop setFov:zpos1 * zdim];
// alloc image
    img = [RecImage imageOfType:RECIMAGE_REAL withLoops:zLoop, yLoop, xLoop, nil];
// unit
    [img setUnit:REC_POS forLoop:xLoop];
    [img setUnit:REC_POS forLoop:yLoop];
    [img setUnit:REC_POS forLoop:zLoop];
// read image data
    p = [img data];
    dataLen = xdim * ydim;  // image data len in bytes
    buf = (short *)malloc(dataLen * sizeof(short));
    for (i = 0; i < zdim; i++) {
        cPath = [[[URLs objectAtIndex:i] path] UTF8String];
    //    cPath = [[paths objectAtIndex:i] UTF8String];
        fp = fopen(cPath, "r");
        Rec_dcm_read_file_meta(fp);
// pixel scaling (Canon CT)
		if (ct) {
			printf("CT file\n");
			Rec_dcm_read_item(fp, 0x28, 0x107, REC_DCM_SHORT, (char *)&sVal, 2);	// largest pixel value
			maxPix = sVal;
	//	printf("maxPix = %d, ct = %d, slope = %d, inter = %d\n", maxPix, ct, slope, intercept);
			Rec_dcm_read_item(fp, 0x7fe0, 0x10, REC_DCM_SARRAY, (char *)buf, dataLen * sizeof(short));
			fclose(fp);
			// scaling
			fullVal = 0;
			for (j = 0; j < dataLen; j++) {
				if (fullVal < buf[j]) {
					fullVal = buf[j];
				}
			}
			pixScale = (float)maxPix / fullVal;
	//printf("maxPix = %f, fullVal = %f\n", maxPix, fullVal);
			if (maxPix == 0) {	// Canon MR
			//	pixScale = 1.0;
				
			}
			// convert to float (& scale to HU)
			for (j = 0; j < dataLen; j++) {
				p[dataLen * i + j] = (float)buf[j] * slope + intercept;
			}
		} else {	// canon MR
			pixScale = 0;
			Rec_dcm_read_item(fp, 0x700d, 0x1000, REC_DCM_STRING, str, 256);
			sscanf(str, "%f", &pixScale);
			if (pixScale > 0) {
	//	printf("pixScale (MR) = %f\n", pixScale);
			Rec_dcm_read_item(fp, 0x7fe0, 0x10, REC_DCM_SARRAY, (char *)buf, dataLen * sizeof(short));
				for (j = 0; j < dataLen; j++) {
					p[dataLen * i + j] = (float)buf[j] / pixScale;
				}
			}
		}
    }
    free(buf);

    return img;
}

@end

// === C functions ===
int
Rec_dcm_read_file_meta(FILE *fp)
{
	int             len;
	char            buf[512];
	char            magic[4];
    REC_DCM_DEL     del;

	if (dbg) {
		printf("Rec_dcm_read_file_meta()\n");
	}

// skip preamble
	fseek(fp, 128, SEEK_SET);

// dicom prefix "DICM"
	fread(magic, 4, 1, fp);
	if (strncmp(magic, "DICM", 4) != 0) {
		if (dbg) printf("no file meta group\n");
		Rec_dcm_explicit_vr = 0;
		Rec_dcm_little_endian = 1;
        Rec_dcm_start = 0;
		return -1;
	}
// explicitVR / little endian within file meta
	Rec_dcm_explicit_vr = 1;
	Rec_dcm_little_endian = 1;

// transfer syntax
    if (Rec_dcm_read_tag(fp, &del) < 0) return -1;
	// group/type = 0x0002 0x0000
	if (del.tag_gr != 0x2 || del.tag_num != 0x0) {
		if (dbg) printf("no file meta group len\n");
        return -1;
    }
    Rec_dcm_get_int(fp, &len);
	if (dbg) printf("meta len = %d\n", len);

    Rec_dcm_start = (int)ftell(fp) + len; // if eFilm, add 4
    while (ftell(fp) < Rec_dcm_start) {
        if (Rec_dcm_read_tag(fp, &del) < 0) return -1;
        if (del.tag_gr == 0x0002 && del.tag_num == 0x0010) {
            break;
        }
        fseek(fp, del.len, SEEK_CUR);
    }
	fread(buf, del.len, 1, fp);

    buf[del.len] = 0;
    if (strncmp(buf, "1.2.840.10008.1.2", 17) == 0) {
        if (buf[17] == 0) {
            // implicit VR little endian, x.10008.1.2
            Rec_dcm_explicit_vr = 0;
            Rec_dcm_little_endian = 1;
        } else
        if (buf[18] == '1') {
            // explicit VR little endian, x.10008.1.2.1
            Rec_dcm_explicit_vr = 1;
            Rec_dcm_little_endian = 1;
        } else
        if (buf[18] == '2') {
            // explicit VR big endian, x.10008.1.2.2
            Rec_dcm_explicit_vr = 1;
            Rec_dcm_little_endian = 0;
        } else {
            Rec_dcm_explicit_vr = 1;
            printf("tfr syntax not implemented. (%s)\n", buf);
            return -1;
        }
        if (dbg) {
            printf("tfr syntax found\n");
            printf("explicit VR = %d\n", Rec_dcm_explicit_vr);
            printf("litte endian = %d\n", Rec_dcm_little_endian);
        }
    }

    return 0;
}

    
/*

//=======old

// file meta group
	fread(buf, del.len, 1, fp);
// eFilm/UCDavisLib patch
	{
		int 	eFilm = 0;
		for (p = buf; p < buf + len; p++) {
			if (*p != 'e') continue;
			if ((eFilm = (int)strstr(p, "eFilm"))) break;
		}
		if (eFilm) {
			printf("Header created by eFilm... file meta len adjusted\n");
			fseek(fp, 4, SEEK_CUR);
		}
	}
    Rec_dcm_start = (int)ftell(fp); // current position

// ******** rewrite this using read_tag
	p = buf;
	while (p < buf + 512) { // buf len
		group = Rec_dcm_buf_to_short((unsigned char *)p);
		type = Rec_dcm_buf_to_short((unsigned char *)p + 2);
		p += 4;
		if (group != 2) return -1;
		if (type == 16) {	// tfr syntax
			p += 4;
			if (strncmp(p, "1.2.840.10008.1.2", 17) == 0) {
				if (*(p + 17) == 0) {
                    // implicit VR little endian, x.10008.1.2
					Rec_dcm_explicit_vr = 0;
					Rec_dcm_little_endian = 1;
				} else
				if (*(p + 18) == '1') {
                    // explicit VR little endian, x.10008.1.2.1
					Rec_dcm_explicit_vr = 1;
					Rec_dcm_little_endian = 1;
				} else
				if (*(p + 18) == '2') {
                    // explicit VR big endian, x.10008.1.2.2
					Rec_dcm_explicit_vr = 1;
					Rec_dcm_little_endian = 0;
				} else {
					Rec_dcm_explicit_vr = 1;
                    printf("tfr syntax not implemented. (%s)\n", p);
                    return -1;
                }
                if (dbg) {
                    printf("tfr syntax found\n");
                    printf("explicit VR = %d\n", Rec_dcm_explicit_vr);
                    printf("litte endian = %d\n", Rec_dcm_little_endian);
                }
			} else {
				return -1;
			}
			break;
		} else {	// skip if not tfr syntax
            Rec_dcm_vr(p, &sz, &type);
			switch (sz) {
			case -1 :
				return -1;
			case 2 :
				len = Rec_dcm_buf_to_short((unsigned char *)p + 2);
				p += 4;
				break;
			case 4 :
				len = Rec_dcm_buf_to_long((unsigned char *)p + 4);
				p += 8;
				break;
			}
            if (dbg) {
                printf("file meta : skipping %d bytes, gr=%d, tp=%d\n", len, group, type);
            }
			p += len;
		}
	}

	return 0;
}
*/

short
Rec_dcm_read_short(FILE *fp, int gr, int ty)
{
    short   sVal = 0;
    int     found = 0;

    found = Rec_dcm_read_item(fp, gr, ty, REC_DCM_SHORT, (char *)&sVal, 2);
    return sVal;
}

float
Rec_dcm_read_float(FILE *fp, int gr, int ty)
{
    char    buf[256];
    float   fVal = 0;

    Rec_dcm_read_item(fp, gr, ty, REC_DCM_STRING, buf, 256);
printf("%s\n", buf);
	sscanf(buf, "%f", &fVal);
    return fVal;
}

/* reads one data element from file */
/* 0: no error, -1: error return */
int
Rec_dcm_read_tag(FILE *fp, REC_DCM_DEL *del)
{
	int             len, seq, type = REC_DCM_UNK;
	unsigned short  sval;
	char            vr[3];

/* current posision */
    if (Rec_dcm_get_short(fp, &sval) < 0) return -1;
    del->tag_gr = sval;
    if (Rec_dcm_get_short(fp, &sval) < 0) return -1;
    del->tag_num = sval;
    /* special case... delimiter */
    if (del->tag_gr == 0xfffe) {
        Rec_dcm_get_int(fp, &len);
        strcpy(vr, "dd");
        len = 0;
    } else
    if (Rec_dcm_explicit_vr) {  // Explicit VR
        fread(vr, 2, 1, fp);
        vr[2] = 0;
        Rec_dcm_vr(vr, &seq, &type);
        if (seq) {   // OB, OW, SQ or UN
            fseek(fp, 2, SEEK_CUR); // skip 00000
            Rec_dcm_get_int(fp, &len);
        } else {
            Rec_dcm_get_short(fp, &sval);
            len = sval;
        }
    } else {    // Implicit VR
        strcpy(vr, "--");
        if (Rec_dcm_get_int(fp, &len) < 0) return -1;
    }
    del->type = type;
    del->len = len;
    del->ofs = (int)ftell(fp);  // debug

    if (dbg) printf("st = %x, vr = %2s, gr/ty = 0x%x/0x%x, len = %d, type = %d\n",
        del->ofs, vr, del->tag_gr, del->tag_num, del->len, type);

    return 0;
}

/* return value: 1:found, 0:not found */
int
Rec_dcm_read_item(FILE *fp, int gr, int ty, int data_type, char *p, int maxlen)
{
	int         i;
	unsigned short       sval;
	int         ival;
    REC_DCM_DEL     del;

    fseek(fp, Rec_dcm_start, SEEK_SET);
	while (1) {
        if (Rec_dcm_read_tag(fp, &del) < 0) break;
        if (del.tag_gr != gr || del.tag_num != ty) {    /* not this one */
			if (del.len > 0) fseek(fp, del.len, SEEK_CUR);
            continue;
        }
		if (del.len > maxlen) {
            if (dbg) printf("data too long\n");
        } else {
			switch (data_type) {
			case REC_DCM_SHORT : /* short */
				Rec_dcm_get_short(fp, &sval);
				bcopy(&sval, p, 2);
				break;
			case REC_DCM_INT : /* int */
				Rec_dcm_get_int(fp, &ival);
				bcopy(&ival, p, 4);
				break;
			case REC_DCM_STRING : /* string */
				fread(p, del.len, 1, fp);
				p[del.len] = 0;
				break;
			case REC_DCM_SARRAY : /* short array */
				for (i = 0; i < del.len/2; i++) {
					Rec_dcm_get_short(fp, &sval);
					bcopy(&sval, p + i*2, 2);
				}
				break;
			case REC_DCM_LARRAY : /* int array */
				for (i = 0; i < del.len/4; i++) {
					Rec_dcm_get_int(fp, &ival);
					bcopy(&ival, p + i*4, 4);
				}
				break;
			}
			return 1;	/* found */
		}
	}
	rewind(fp);
	return 0;	/* not found */
}

// ## not finished yet
int
Rec_dcm_dump_itemsX(FILE *fp)
{
	int             i, j, len;
    int             maxLen = 60;
    int             maxItems = 1000;
    char            buf[61];
	unsigned short  sval;
    REC_DCM_DEL     del;

    fseek(fp, Rec_dcm_start, SEEK_SET);
	for (i = 0; i < maxItems; i++) {
        if (Rec_dcm_read_tag(fp, &del) < 0) break;
        if (del.len < 0) continue;
        if (del.len < maxLen) {
            len = del.len;
            fread(buf,len, 1, fp);
        } else {
            len = maxLen;
            fread(buf, maxLen, 1, fp);
            fseek(fp, del.len - maxLen, SEEK_CUR);
        }
        if (del.tag_num != 0) { // slip group length
            sval = Rec_dcm_buf_to_short((unsigned char *)buf);
            for (j = 0; j < len; j++) {
                if (buf[j] < 0x20) buf[j] = 0x20;
            }
            buf[len] = 0;
            printf("%02d:[%04x,%04x]:len=%d:%d:[%s]\n", i, del.tag_gr, del.tag_num, del.len, sval, buf);
        }
    }
	rewind(fp);
	return 0;	/* not found */
}
// tagDictinary version
int
Rec_dcm_dump_items(FILE *fp)
{
	int             i, len;
    int             maxLen = 60;
    int             maxItems = 1000;
    char            buf[61];
	int             intVal;
    REC_DCM_DEL     del;
    NSString        *tag_key, *vr_key;
    NSDictionary    *tag, *vr;
    const char      *desc;
    int             type;

    fseek(fp, Rec_dcm_start, SEEK_SET);
	for (i = 0; i < maxItems; i++) {
        if (Rec_dcm_read_tag(fp, &del) < 0) break;  // error
        if (del.len < 0) continue;  // undefined length (0xFFFFFFFF)
        tag_key = [NSString stringWithFormat:@"%04X,%04X", del.tag_gr, del.tag_num];
        tag = [tagDict objectForKey:tag_key];
        if (tag) {
            vr_key = [tag objectForKey:@"VR"];
            vr = [vrDict objectForKey:vr_key];
        } else {
            vr_key = @"--";
            vr = nil;
        }
        if (del.len < maxLen) {
            len = del.len;
            fread(buf,len, 1, fp);
            buf[len] = 0;
        } else {
            len = maxLen;
            fread(buf, maxLen, 1, fp);
            fseek(fp, del.len - maxLen, SEEK_CUR);
        }
        // dump one item
        if (del.tag_num != 0) { // skip group length
            desc = [[tag objectForKey:@"Description"] UTF8String];
            if (desc == nil) desc = "(???)";
        //    printf("[%04X,%04X]:len=%2d:%s:", del.tag_gr, del.tag_num, del.len, desc);       
            printf("[%04X,%04X]:%2s:%s:", del.tag_gr, del.tag_num, [vr_key UTF8String], desc);  
            if (!tag) {
                intVal = Rec_dcm_buf_to_short((unsigned char *)buf);
                printf("%d:[%10s]\n", intVal, buf);
            } else {
                type = [[vr objectForKey:@"Type"] intValue];
                switch (type) {
                case REC_DCM_SHORT :
                    intVal = Rec_dcm_buf_to_short((unsigned char *)buf);
                    printf("%d\n", intVal);
                    break;
                case REC_DCM_INT :
                    intVal = Rec_dcm_buf_to_long((unsigned char *)buf);
                    printf("%d\n", intVal);
                    break;
                case REC_DCM_STRING :
                    printf("[%s]\n", buf);
                    break;
                default :
                    printf("??\n");
                    break;
                }
            }
        }
    }
	rewind(fp);
	return 0;	/* not found */
}

// ==== moved to vrDictionary
/*
typedef struct {
    int		seq;        // seq type:1, other:0
    char	code[3];    // "AE" etc
    int     type;       // REC_DCM_SHORT etc
}   VRMAP;

static VRMAP vrMap[] = {
	{2, "AE", 2},	// Aplication Entity
	{2, "AS", 2},	// Age String
	{2, "AT", 5},	// Attribute Tag
	{2, "CS", 2},	// Code String
	{2, "DA", 2},	// Date
	{2, "DS", 2},	// Decimal String
	{2, "DT", 2},	// Date Time
	{2, "FL", 3},	// Float
	{2, "FD", 4},	// Floating Double
	{2, "IS", 2},	// Integer String (char string)
	{2, "LO", 2},	// Long string (max 64 char)
	{2, "LT", 2},	// Long Text (max 10240 char)
	{4, "OB", 2},	// Other byte string
	{4, "OW", 0},	// Other, Word String
	{2, "PN", 2},	// Person Name
	{2, "SH", 5},	// Short string (max 16 char)
	{2, "SL", 1},	// Signed Long
	{4, "SQ", 2},	// Sequence of items (Data Element Array)
	{2, "SS", 0},	// Signed Short
	{2, "ST", 2},	// Short Text (max 1024 char)
	{2, "TM", 2},	// Time
	{2, "UI", 2},	// Unique Identifier
	{2, "UL", 1},	// Unsigned Long
	{4, "UN", 2},	// Unknown (byte string)
	{2, "US", 0},	// Unsigned Short
	{2, "RT", 2},	// Retired
	{-1, "", -1}	// End of table
};
#define VR_TAB_LEN 26
*/
/*
int
Rec_dcm_vrX(char *code, int *len_sz, int *type)
{
	int	i;

	for (i = 0; i < VR_TAB_LEN; i++) {
		if (vrMap[i].sz < 0) break;
		if (strncmp(code, vrMap[i].code, 2) == 0) {
            *len_sz = vrMap[i].sz;
            *type = vrMap[i].type;
            return 0;
        }
	}
	return -1;
}
*/

// =====

int
Rec_dcm_vr(char *code, int *seq, int *type)
{
    char        vr[3];
    NSString    *codeString;

    vr[0] = code[0]; vr[1] = code[1]; vr[2] = 0;
    codeString = [NSString stringWithUTF8String:vr];

    NSDictionary    *vrItem = [vrDict objectForKey:[NSString stringWithUTF8String:vr]];
    if (vrItem == nil) return -1;

    *seq = [[vrItem objectForKey:@"Seq"] intValue];
    *type = [[vrItem objectForKey:@"Type"] intValue];

    return 0;
}

int
Rec_dcm_get_short(FILE *fp, unsigned short *val)
{
	unsigned short	ival;
	if (fread(&ival, sizeof(short), 1, fp) != 1) return -1;
	ival = Rec_dcm_buf_to_short((unsigned char *)&ival);
	*val = ival;
	return 0;
}

int
Rec_dcm_get_int(FILE *fp, int *val)
{
    int		ival;
	if (fread(&ival, sizeof(int), 1, fp) != 1) return -1;
	ival = Rec_dcm_buf_to_long((unsigned char *)&ival);
	*val = ival;
	return 0;
}

int
Rec_dcm_buf_to_short(unsigned char *buf)	/* little endian */
{
	unsigned short	ival = 0;
	int		i;

	if (Rec_dcm_little_endian) {
		for (i = 0; i < 2; i++) {
			ival <<= 8;
			ival += buf[1 - i];
		}
	} else {
		for (i = 0; i < 2; i++) {
			ival <<= 8;
			ival += buf[i];
		}
	}
	return ival;
}

int
Rec_dcm_buf_to_long(unsigned char *buf)	/* little endian */
{
	int		ival = 0;
	int		i;

	if (Rec_dcm_little_endian) {
		for (i = 0; i < 4; i++) {
			ival <<= 8;
			ival += buf[3 - i];
		}
	} else {
		for (i = 0; i < 4; i++) {
			ival <<= 8;
			ival += buf[i];
		}
	}
	return ival;
}
