//
//	file I/O for Toshiba
//
//	== plans ==
//	create "header" data structure
//

#import "RecImage.h"
#import "RecLoop.h"
#import "RecLoopIndex.h"
#import "RecLoopControl.h"

@class ToshibaXMLDelegate;

@interface	RecImage (Toshiba)
+ (RecImage *)imageWithToshibaRunNo:(int)n1 siteNo:(int)n2 protoNo:(int)n3;
+ (RecImage *)imageWithToshibaFile:(NSString *)path;
+ (RecImage *)imageWithToshibaFile:(NSString *)path vorder:(RecImage **)vorder;
+ (RecImage *)imageWithToshibaFile:(NSString *)path vorder:(RecImage **)vorder fov:(RecVector *)fov;
+ (NSArray *)readLoops:(ToshibaXMLDelegate *)del;
- (void)readData:(NSString *)path;
- (RecImage *)sortPe:(ToshibaXMLDelegate *)del;	// returns traj, if non-cartesian trajectory
- (void)sortBlock:(ToshibaXMLDelegate *)del;
- (RecImage *)readVOrder:(ToshibaXMLDelegate *)del;

@end

//== NSXMLParser delegate
@interface ToshibaXMLDelegate:NSObject
{
	int				*intParam;
	int				**intArrayParam;
	float			*floatParam;
	float			**arrayParam;
	int				*arrayLen;
	int				currentType;	// 0:int, 1:float, 2:array, 3:string, -1:not within param
}

@property int		channels;

@property int		depth;		// raw data zdim
@property int		height;		// raw data ydim
@property int		width;		// raw data xdim

@property int		k_depth;	// recon zdim
@property int		k_height;	// recon ydim
@property int		k_width;	// recon xdim

@property float		fov_depth;	// z fov
@property float		fov_height;	// y fov
@property float		fov_width;	// x fov

@property int		*se_sort_tab;		// 3D slice
@property int		se_sort_tab_len;
@property int		*pe_sort_tab;		// phase encode
@property int		pe_sort_tab_len;
@property int		*block_sort_tab;	//
@property int		block_sort_tab_len;
@property float		*traj_coordinates;	//
@property int		traj_coordinates_len;

// === NSXMLParser delegate methods ===
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
	namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
	attributes:(NSDictionary *)attributeDict;
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string;
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
	namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName;

@end
