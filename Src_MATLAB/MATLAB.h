//
//	file I/O for MATLAB  "mat" file (level 5)
//

#import "RecImage.h"
#import "RecLoop.h"
#import "RecLoopControl.h"

#define	miINT8			1
#define	miUINT8			2
#define	miINT16			3
#define	miUINT16		4
#define	miINT32			5
#define	miUINT32		6
#define	miSINGLE		7
#define	miDOUBLE		9
#define	miINT64			12
#define	miUINT64		13
#define	miMATRIX		14
#define	miCOMPRESSED	15
#define	miUTF8			16
#define	miCUTF16		17
#define	miCUTF32		18


typedef struct
{
	char	desc[116];	// description
	char	subsys[8];
	short	version;
	char	endian[2];
} miHeader;	// 128 bytes

typedef struct
{
	int		type;
	int		bytes;
} miTag;	// 8 bytes

@interface	RecImage (MATLAB)

+ (RecImage *)imageWithMatfile:(NSString *)path;

@end