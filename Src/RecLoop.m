//
//	New Recon Lib
//	image data objects
//

#import "RecLoop.h"

NSMutableDictionary	*loopDict;

// ===== RecLoop ====
@implementation RecLoop

+ (void)initialize
{
	if (self == [RecLoop class]) {	// if this is RecLoop class itself, and not its subclass
		loopDict = [NSMutableDictionary dictionary];
	}
}

+ (RecLoop *)loopWithDataLength:(int)d
{
	return [RecLoop loopWithName:@"" dataLength:d];
}

+ (RecLoop *)loopWithDim:(int)d		//same as above
{
	return [RecLoop loopWithName:@"" dataLength:d];
}

+ (RecLoop *)loopWithName:(NSString *)aName dataLength:(int)d
{
	RecLoop	*lp;

    if ((lp = [RecLoop findLoop:aName]) != nil) {
        return lp;
    }
    lp = [[RecLoop alloc] init];
    if (aName == nil)  aName = @"";
	lp = [lp initWithName:aName dataLength:d];
	return lp;
}

+ (RecLoop *)pointLoop
{
	// PoitLoop is anonymous
	return [RecLoop loopWithName:@"" dataLength:1];
}

+ (void)dumpLoops
{
	NSArray	*loops = [loopDict allValues];
	RecLoop	*lp;
	int		i;

	printf("===== Loops (RecLoop:loopDict) =======\n");
	for (i = 0; i < [loops count]; i++) {
		lp = [loops objectAtIndex:i];
		printf("RecLoop:[%s] %d\n", [[lp name] UTF8String], [lp dataLength]);
	}
	printf("===================\n");
}

+ (void)clearLoops
{
	[loopDict removeAllObjects];
}

+ (RecLoop *)findLoop:(NSString *)name
{
	RecLoop	*lp;
	if ([name isEqualTo:@""]) return nil;
	lp = [loopDict objectForKey:name];
	return lp;
}

+ (RecLoop *)replaceLoopNamed:(NSString *)name withLoop:(RecLoop *)newLp
{
	if ([name isEqualTo:@""]) return nil;
	[loopDict removeObjectForKey:name];
	[loopDict setObject:newLp forKey:name];
	return newLp;
}

// updated (8-5-2013)
// - names are unique within dictionary
// - nil name not allowed
// - if name is a null string, not put in dictionary
// - all Loops with no name are distinct
//
- (id)initWithName:(NSString *)aName dataLength:(int)d
{
    RecLoop *lp;

    self = [super init];    // NSObject

    if (aName == nil) aName = @"";
	name = aName;
	dataLength = d;
	center = d / 2;
    fov = 200.0;

	if (name && ![name isEqualToString: @""]) {
		if ((lp = [RecLoop findLoop:name])) {
			NSLog(@"Loop [%@] already exists.", name);
		//	exit(0);
            return lp;
		}
		[loopDict setObject:self forKey:name];
	}

	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	RecLoop	*lp = [[self class] alloc];

	lp = [lp initWithName:@"" dataLength:[self dataLength]];
    if (lp) {
        [lp setCenter:[self center]];
        [lp setFov:[self fov]];
    }

	return lp;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:	name		forKey:@"RecLpName"];
	[coder encodeInt:		dataLength	forKey:@"RecLpDLen"];
	[coder encodeInt:		center		forKey:@"RecLpCenter"];
	[coder encodeFloat:		fov         forKey:@"RecLpFov"];
}

// check duplicats: don't add to dict if already exists
- (id)initWithCoder:(NSCoder *)coder
{
	RecLoop		*lp;
//	BOOL		loopExists = NO;

    self = [super init];    // NSObject
    if (!self) {
        printf("???\n");
        return nil;
    }

	name = [coder decodeObjectForKey:@"RecLpName"];

// this is necessary (apart from NSCoder)
	if (name && ![name isEqualToString: @""]) { // isEqual: is in NSObject protocol
		if ((lp = [RecLoop findLoop:name])) {	// loop already exists
//printf("Loop [%s] exists\n", [name UTF8String]);
			return lp;
        }
	}
    [loopDict setObject:self forKey:name];

	dataLength	=  [coder decodeIntForKey:		@"RecLpDLen"];
	center		=  [coder decodeIntForKey:		@"RecLpCenter"];
	fov         =  [coder decodeFloatForKey:	@"RecLpFov"];

    return self;
}

- (void)setName:(NSString *)aName
{
    if (aName == nil) aName = @"";
    name = aName;
}

- (NSString *)name
{
	return name;
}

- (BOOL)isPointLoop
{
	return (dataLength == 1);
}

- (void)setDataLength:(int)len
{
	dataLength = len;
}

- (int)dataLength
{
	return dataLength;
}

- (void)setCenterPos:(int)ct
{
	center = ct;
}

- (int)center
{
	return center;
}

- (void)setFov:(float)f
{
    fov = f;
}

- (float)fov
{
    return fov;
}

//=== debug ===
- (void)dump
{
    printf("RecLoop:[%s] %d\n", [[self name] UTF8String], [self dataLength]);
}

@end
