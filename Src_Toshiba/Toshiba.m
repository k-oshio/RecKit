//
//	file I/O for Toshiba
//	q&d version ok	6-11
//

#import <Foundation/Foundation.h>

#import "Toshiba.h"

@implementation	RecImage (Toshiba)

+ (RecImage *)imageWithToshibaRunNo:(int)n1 siteNo:(int)n2 protoNo:(int)n3
{
	NSString		*path;
	char			cwd[256];

	getcwd(cwd, 256);
	path = [NSString stringWithFormat:@"%s/Run%05d.%04d.%02d", cwd, n1, n2, n3];
	return [RecImage imageWithToshibaFile:path];
}

+ (RecImage *)imageWithToshibaFile:(NSString *)path
{
    RecVector   fov;
	return [RecImage imageWithToshibaFile:path vorder:nil fov:&fov];
}

+ (RecImage *)imageWithToshibaFile:(NSString *)path vorder:(RecImage **)vorder fov:(RecVector *)fov
{
	NSXMLParser			*parser;
	ToshibaXMLDelegate	*del;
	BOOL				sts = NO;
	RecImage			*img;
	NSString			*filePath;
	NSArray				*loops;

// read loops
	filePath = [NSString stringWithFormat:@"%@.raw.xml", path];
	parser = [[NSXMLParser alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filePath]];
	del = [[ToshibaXMLDelegate alloc] init];
	[parser setDelegate:(id)del];
	sts = [parser parse];
	if (sts == NO) return nil;

	loops = [self readLoops:del];
	img = [RecImage imageOfType:RECIMAGE_COMPLEX withLoopArray:loops];

// read image data
	filePath = [NSString stringWithFormat:@"%@.raw.bin", path];
	[img readData:filePath];
[img dumpLoops];

//	*vorder = [img sortPe:del];
	*vorder = [img readVOrder:del];
if (*vorder == nil) {
	printf("sortPe failed\n");
}
[*vorder saveAsKOImage:@"IMG_traj"];
//exit(0);
	[img sortBlock:del];

// read FOV / pixel size
	fov->x = [del fov_width];
	fov->y = [del fov_height];
	fov->z = [del fov_depth];

// unit
    [img setUnit:REC_FREQ forLoop:[img zLoop]];
    [img setUnit:REC_FREQ forLoop:[img yLoop]];
    [img setUnit:REC_FREQ forLoop:[img xLoop]];
//[img dumpInfo];

	return img;
}

+ (NSArray *)readLoops:(ToshibaXMLDelegate *)del
{
	RecLoop		*ch, *kz, *ky, *kx;
	int			n_ch, kz_dim, ky_dim, kx_dim;

	n_ch	= [del channels];
	kz_dim	= [del depth];
	ky_dim	= [del height];
//	kz_dim	= [del height];	// ??
//	ky_dim	= [del depth];	// ??
	kx_dim	= [del width];

	printf("ch/z/y/x = %d/%d/%d/%d\n", n_ch, kz_dim, ky_dim, kx_dim);

	ch = [RecLoop loopWithName:@"Channel"	dataLength:n_ch];
	kz = [RecLoop loopWithName:@"Slice"		dataLength:kz_dim];
	ky = [RecLoop loopWithName:@"Phase"		dataLength:ky_dim];
	kx = [RecLoop loopWithName:@"Read"		dataLength:kx_dim];

	return [NSArray arrayWithObjects:ch, kz, ky, kx, nil];
}

- (void)readData:(NSString *)path
{
	int			i, len, ix;
	int			actLen;
	float		*p, *q;
	int			*pp;
	FILE		*fp;

	len = [self dataLength];
	p = [self data];
	q = p + len;

//	32bit int, lsb first, interleaved complex
	pp = (int *)malloc(sizeof(int) * len * 2);

	fp = fopen([path UTF8String], "r");
	actLen = (int)fread(pp, sizeof(int) * 2, len, fp);
	fclose(fp);
	if (actLen != len) {
		printf("actLen(%d) shorter than len (%d)\n", actLen, len);
	}
	for (i = ix = 0; i < len; i++) {
		p[i] = pp[ix++] / (float)0xffff;
		q[i] = pp[ix++] / (float)0xffff;
	}
	free(pp);
}

// y phase encoding
- (RecImage *)sortPe:(ToshibaXMLDelegate *)del
{
	int				i, j, n = [del pe_sort_tab_len];
	int				ix, skip;
	int				tabix;
	int				*tab = [del pe_sort_tab];
	float			*traj_coord = [del traj_coordinates];
	float			traj_full, ref_full;
	int				traj_steps, ref_steps;
	RecImage		*traj = nil;
	RecLoop			*lp;
	RecLoopControl	*lc;
	int				loopLen;
	float			*buf, *p;

	// make traj (view angle table)
	if (traj_coord) {
		traj_full  = traj_coord[0];
		ref_full   = traj_coord[2];
		traj_steps = traj_coord[1];
		ref_steps  = traj_coord[3];
		
		
		printf("=== traj coord === \n");
		printf("%2.1f %3d %3.1f %3d\n", traj_full, traj_steps, ref_full, ref_steps);
		traj = [RecImage imageOfType:RECIMAGE_REAL xDim:n];
		p = [traj data];
		for (i = 0; i < n; i++) {
			tabix = tab[i];
			if (tabix >= 0x1000000) {
				p[i] = -2.0 * M_PI * ref_full * i / ref_steps;
			} else {
				p[i] = -2.0 * M_PI * traj_full * tabix / traj_steps;
			}
//			printf("%d %f\n", i, p[i]);
		}
	} else {
	// sort
		buf = (float *)malloc(sizeof(float) * n);
		lp = [self yLoop];
		skip = [self skipSizeForLoop:lp];
		lc = [self control];
		[lc deactivateLoop:lp];
		loopLen = [lc loopLength];
		[lc rewind];
		[lc dumpLoops];
		for (i = 0; i < loopLen; i++) {
			// real
			p = [self currentDataWithControl:lc];
			for (j = ix = 0; j < n; j++, ix += skip) {
				tabix = tab[j];
//printf("%d %d\n", j, tab[j]);
		//	tabix = j;
				if (tabix >= 0x1000000) {
				//	ref views ... ignore
				//	printf("tabx(top 4 bits) = %d, %d\n", tabix / 0x10000000, tabix % 0x10000000);
					tabix = 0;
				}
			//	buf[tabix] = p[ix];
//	printf("%d %d\n", j, tabix);
			}
			for (j = ix = 0; j < n; j++, ix += skip) {
				p[ix] = buf[j];
			}
			// imag
			p += dataLength;
			for (j = ix = 0; j < n; j++, ix += skip) {
				tabix = tab[j];
		//	tabix = j;
				if (tabix >= n) tabix = 0;
				buf[tabix] = p[ix];
			}
			for (j = ix = 0; j < n; j++, ix += skip) {
				p[ix] = buf[j];
			}
			[lc increment];
		}
		free(buf);
	}
	return traj;
}

- (RecImage *)readVOrder:(ToshibaXMLDelegate *)del
{
	int				i, n = [del pe_sort_tab_len];
	int				tabix;
	int				*tab = [del pe_sort_tab];
	float			*traj_coord = [del traj_coordinates];
	RecImage		*vorder = [RecImage imageOfType:RECIMAGE_REAL xDim:n];
	float			*p = [vorder data];
	float			traj_full, ref_full;
	int				traj_steps, ref_steps;

	if (traj_coord) {
		traj_full  = traj_coord[0];
		ref_full   = traj_coord[2];
		traj_steps = traj_coord[1];
		ref_steps  = traj_coord[3];
	} else {
		traj_full  = 1;
		ref_full   = 1;
		traj_steps = 729;
		ref_steps  = 8;
	}

	printf("=== traj coord === \n");
	printf("%2.1f %3d %3.1f %3d\n", traj_full, traj_steps, ref_full, ref_steps);
	vorder = [RecImage imageOfType:RECIMAGE_REAL xDim:n];
	p = [vorder data];
	for (i = 0; i < n; i++) {
		tabix = tab[i];
		if (tabix >= 0x1000000) {
			p[i] = -2.0 * M_PI * ref_full * i / ref_steps;
		} else {
			p[i] = -2.0 * M_PI * traj_full * tabix / traj_steps;
		}
//			printf("%d %f\n", i, p[i]);
	}

	return vorder;
}

// 3D slice encoding
- (void)sortBlock:(ToshibaXMLDelegate *)del
{
	int				i, j; // n = [del block_sort_tab_len];
	int				n = [del depth];
	int				ix, skip, tabix;
	int				*tab = [del block_sort_tab];
	RecLoop			*lp;
	RecLoopControl	*lc;
	int				loopLen;
	float			*buf, *p;

	buf = (float *)malloc(sizeof(float) * n);
	lp = [self zLoop];	// check
	skip = [self skipSizeForLoop:lp];
	lc = [self control];
	[lc deactivateLoop:lp];
	loopLen = [lc loopLength];
	for (i = 0; i < loopLen; i++) {
		// real
		p = [self currentDataWithControl:lc];
		for (j = ix = 0; j < n; j++, ix += skip) {
		//	buf[tab[j]] = p[ix];
			buf[j] = p[ix];
		}
		for (j = ix = 0; j < n; j++, ix += skip) {
			tabix = tab[j];
			p[ix] = buf[tabix];
		}
		// imag
		p += dataLength;
		for (j = ix = 0; j < n; j++, ix += skip) {
		//	buf[tab[j]] = p[ix];
			buf[j] = p[ix];
		}
		for (j = ix = 0; j < n; j++, ix += skip) {
			tabix = tab[j];
			p[ix] = buf[tabix];
		}
		[lc increment];
	}
	free(buf);
}

@end

//== NSXMLParser delegate
@implementation ToshibaXMLDelegate

@synthesize	channels;

@synthesize	depth;		// raw data zdim
@synthesize	height;		// raw data ydim
@synthesize	width;		// raw data xdim

@synthesize	k_depth;	// recon zdim
@synthesize	k_height;	// recon ydim
@synthesize	k_width;	// recon xdim

@synthesize	fov_depth;	// z fov
@synthesize	fov_height;	// y fov
@synthesize	fov_width;	// x fov

@synthesize	se_sort_tab;
@synthesize se_sort_tab_len;
@synthesize	pe_sort_tab;
@synthesize pe_sort_tab_len;
@synthesize	block_sort_tab;
@synthesize	block_sort_tab_len;
@synthesize traj_coordinates;
@synthesize traj_coordinates_len;

- (id)init
{
	self = [super init];
	if (self == nil) return nil;

	currentType = -1;
	se_sort_tab = pe_sort_tab = block_sort_tab = NULL;
	se_sort_tab_len = pe_sort_tab_len = block_sort_tab_len = 0;

	return self;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
	namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
	attributes:(NSDictionary *)attributeDict
{
	// set param to current
//	printf("<%s> start\n", [elementName UTF8String]);
	if ([elementName isEqualToString:@"channels"]) {
		intParam = &channels;
		currentType = 0;	// int
	} else
	if ([elementName isEqualToString:@"depth"]) {
		intParam = &depth;
		currentType = 0;	// int
	} else
	if ([elementName isEqualToString:@"height"]) {
		intParam = &height;
		currentType = 0;	// int
	} else
	if ([elementName isEqualToString:@"width"]) {
		intParam = &width;
		currentType = 0;	// int
	} else
	if ([elementName isEqualToString:@"k_depth"]) {
		intParam = &k_depth;
		currentType = 0;	// int
	} else
	if ([elementName isEqualToString:@"k_height"]) {
		intParam = &k_height;
		currentType = 0;	// int
	} else
	if ([elementName isEqualToString:@"k_width"]) {
		intParam = &k_width;
		currentType = 0;	// int
	} else
	if ([elementName isEqualToString:@"fov_depth"]) {
		floatParam = &fov_depth;
		currentType = 1;	// float
	} else
	if ([elementName isEqualToString:@"fov_width"]) {
		floatParam = &fov_width;
		currentType = 1;	// float
	} else
	if ([elementName isEqualToString:@"fov_height"]) {
		floatParam = &fov_height;
		currentType = 1;	// float
	} else
	if ([elementName isEqualToString:@"se_sort_tbl"]) {
		intArrayParam = &se_sort_tab;
		arrayLen = &se_sort_tab_len;
		currentType = 3;	// int array
	} else
	if ([elementName isEqualToString:@"pe_sort_tbl"] ||
		[elementName isEqualToString:@"kspace_traj_sort_tbl"]) {
		intArrayParam = &pe_sort_tab;
		arrayLen = &pe_sort_tab_len;
		currentType = 3;	// int array
	} else
	if ([elementName isEqualToString:@"block_sort_tbl"]) {
		intArrayParam = &block_sort_tab;
		arrayLen = &block_sort_tab_len;
		currentType = 3;	// int array
	} else
	if ([elementName isEqualToString:@"traj_coordinates"]) {
		arrayParam = &traj_coordinates;
		arrayLen = &traj_coordinates_len;
		currentType = 2;	// float array
	} else {	// ignore others
		currentType = -1;
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	NSArray		*subStr;
	float		*p;
	int			*ip;
	int			i, len;

	switch (currentType) {
	case 0 :	// int
		*intParam = [string intValue];
		break;
	case 1 :	// float
		*floatParam = [string floatValue];
		break;
	case 2 :	// float array
		subStr = [string componentsSeparatedByString:@","];
		len = (int)[subStr count];
		p = (float *)malloc(sizeof(float) * len);
		*arrayParam = p;
		for (i = 0; i < len; i++) {
			p[i] = [[subStr objectAtIndex:i] floatValue];
		}
		*arrayLen = len;
		break;
	case 3 :	// int array
		subStr = [string componentsSeparatedByString:@","];
		len = (int)[subStr count];
		ip = (int *)malloc(sizeof(int) * len);
		*intArrayParam = ip;
		for (i = 0; i < len; i++) {
			ip[i] = [[subStr objectAtIndex:i] intValue];
		}
		*arrayLen = len;
		break;
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
	namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	currentType = -1;
}

- (void)dealloc
{
	if (se_sort_tab)		free(se_sort_tab);
	if (pe_sort_tab)		free(pe_sort_tab);
	if (block_sort_tab)		free(block_sort_tab);
	if (traj_coordinates)	free(traj_coordinates);
}

@end
