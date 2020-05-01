//
//	RecLoop.h
//	ver 02	9-10-2009
//		state is separated from dim
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

// ======= unit,  fov ===
// DICOM    o       o
// GE       o       o (z scale not in hdr -> set fov manually to zloop)
// Siemens  o       o

// normal vec, fov -> loop
// unit -> image

// ===== RecLoop (1d Loop) ====
@interface RecLoop : NSObject <NSCoding, NSCopying>
{
	NSString	*name;		// loop id
	int			dataLength;
	int			center;		// echo center etc
    // geom
	float		fov;        // does not change with zero-fill etc
}

+ (void)dumpLoops;
+ (void)clearLoops;
+ (RecLoop *)loopWithDataLength:(int)d;
+ (RecLoop *)loopWithDim:(int)d;		//same as above
+ (RecLoop *)loopWithName:(NSString *)aName dataLength:(int)d;
+ (RecLoop *)pointLoop;
+ (RecLoop *)findLoop:(NSString *)name;
+ (RecLoop *)replaceLoopNamed:(NSString *)name withLoop:(RecLoop *)newLp;

- (id)initWithName:(NSString *)aName dataLength:(int)d;
- (void)setName:(NSString *)aName;
- (NSString *)name;
- (BOOL)isPointLoop;
- (void)setDataLength:(int)len;
- (int)dataLength;
- (void)setCenter:(int)ct;
- (int)center;

// geom
- (void)setFov:(float)f;
- (float)fov;

// debug
- (void)dump;

@end

