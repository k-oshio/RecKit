//
//	file I/O for MATLAB  "mat" file (level 5)
//	reads only image files (matlab matrix format)
//

// === plans ===
// *phase, magnitude ok
// *BrainMask : automatic compression (double -> char)
// CLFA : 4-D, data ?? (error in reading name)
// GRE_Multi_Contrast : size ?


#import "MATLAB.h"
#include <zlib.h>	// image data compression
#include <strings.h>

//======== category ===========
@implementation RecImage (MATLAB)

+ (RecImage *)imageWithMatfile:(NSString *)path
{
	const char		*cPath = [path UTF8String];
	FILE			*fp;
	miHeader		hdr;
	miTag			tag;
	int				i, sts;
	long			len, actlen = 0;
	int				tagsize = sizeof(miTag);
	RecImage		*im;
	unsigned char	*buf = NULL, *tmpbuf = NULL, *p;
	double			*dbuf;
	float			*imgData;
	unsigned char	flags[8];
	BOOL			complex;
	int				type;
	int				dims;
	int				dim[4];	// max 4dim
	char			name[256];

	fp = fopen(cPath, "r");
	if (fp == NULL) return nil;

// header
	fread(&hdr, sizeof(miHeader), 1, fp);
	if (strncmp(hdr.endian, "IM", 2) != 0) {	// Little endian only, for the moment
		printf("Big endian file\n");
		fclose(fp);
		exit(0);
	}
// read data, if compressed, uncompress
	fread(&tag, tagsize, 1, fp);
	len = tag.bytes;
	buf = (unsigned char *)malloc(len);
	fread(buf, len, 1, fp);
	fclose(fp);

	if (tag.type == miCOMPRESSED) {
		// read and uncompress
	printf("compressed\n");
		actlen = len * 2;
		for (i = 0; i < 10; i++) { // 2^10 == 1024
			tmpbuf = (unsigned char *)malloc(actlen);
			sts = uncompress((unsigned char *)tmpbuf, (unsigned long *)&actlen,
				(const unsigned char *)buf, (long)len);
			if (sts == Z_OK) break;
			free(tmpbuf);
			actlen *= 2;
		}
		free(buf);
		bcopy(tmpbuf, &tag, tagsize);
		if (tag.type != miMATRIX) {
			printf("Not a matlab matrix file\n");
			free(tmpbuf);
			exit(0);
		}
		actlen = tag.bytes;
		buf = (unsigned char *)malloc(actlen);
		bcopy(tmpbuf + tagsize, buf, actlen);
		free(tmpbuf);
	} else
	if (tag.type == miMATRIX) {
	printf("uncompressed matrix\n");
		// read matrix to memory
		actlen = tag.bytes;
		buf = (unsigned char *)malloc(actlen);
		fread(buf, actlen, 1, fp);
	}

if (0) {
	fclose(fp);
	fp = fopen("../test_img/MATLAB.tmp", "w");
	fwrite(buf, actlen, 1, fp);
	fclose(fp);
	exit(0);
}

// read matrix content (fixed format !!!)
	p = buf;
	// array flags
	bcopy(p, &tag, tagsize);
	p += tagsize;

	bcopy(p, flags, tag.bytes);
	printf("flags");
	for (i = 0; i < 8; i++) {
		printf(":%02x", flags[i]);
	}
	printf("\n");

	complex = (flags[1] & 0x10);
	printf("Class:%d, Flags:%02x\n", flags[0], flags[1]);	// class is always 6 (double)
	
	actlen = ceil(tag.bytes / 8.0) * 8;
	p += actlen;

	// probably doc is not correct (chk with other files ###)
	if (complex) {
		type = RECIMAGE_COMPLEX;
	} else {
		type = RECIMAGE_REAL;
	}

	// dim array
	bcopy(p, &tag, tagsize);
	p += tagsize;
	dims = tag.bytes / 4;
	printf("dim");
	for (i = 0; i < dims; i++) {
		bcopy(p + 4 * i, dim + i, 4);
		printf(": %d", dim[i]);
	}
	printf("\n");
	actlen = ceil(tag.bytes / 8.0) * 8;
	p += actlen;

	// dims is 2 or 3 ### CLFA is 4 dim
	switch (dims) {
	case 2:
	default:
		im = [RecImage imageOfType:type xDim:dim[0] yDim:dim[1]];
		break;
	case 3:
		im = [RecImage imageOfType:type xDim:dim[0] yDim:dim[1] zDim:dim[2]];
		break;
	case 4:	// not working yet ### (CLFA.mat)
		im = [RecImage imageOfType:type xDim:dim[0] yDim:dim[1] zDim:dim[2] * dim[3]];
		break;
	}
	// name
	bcopy(p, &tag, tagsize);
	p += tagsize;
	bcopy(p, name, tag.bytes);
	actlen = ceil(tag.bytes / 8.0) * 8;
	p += actlen;
	printf("Name:[%s]\n", name);
	// image data (real part)
	bcopy(p, &tag, tagsize);
	p += tagsize;
printf("data type:%d, len:%d\n", tag.type, tag.bytes);

	imgData = [im data];
	switch (tag.type) {
	case miDOUBLE :		// default
	default :
		dbuf = (double *)malloc(tag.bytes);
		len = tag.bytes / 8;
		bcopy(p, dbuf, tag.bytes);
		for (i = 0; i < len; i++) {
			imgData[i] = dbuf[i];
		}
		break;
	case miINT8 :	// char
	case miUINT8 :	// char
		len = tag.bytes;
		for (i = 0; i < len; i++) {
			imgData[i] = p[i];
		}
		break;
	}
	// image data (imag part)
	if (type == RECIMAGE_COMPLEX) {
		// read tag for imag
		bcopy(p, &tag, tagsize);
		p += tagsize;
printf("data type:%d, len:%d\n", tag.type, tag.bytes);
		
		imgData = [im data] + [im dataLength];
		bcopy(p, dbuf, tag.bytes);
		for (i = 0; i < len; i++) {
			imgData[i] = dbuf[i];
		}
	}
	free(buf);
	return im;
}

@end

