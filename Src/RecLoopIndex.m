//
//	New Recon Lib
//	image data objects
//

#import "RecLoopIndex.h"
#import "RecLoop.h"

NSMutableDictionary	*loopDict;

// ===== RecLoopState ====

@implementation RecLoopState

+ (RecLoopState *)stateWithLoop:(RecLoop *)lp
{
    return [[RecLoopState alloc] initWithLoop:lp];
}

+ (RecLoopState *)pointState
{
	RecLoop			*lp = [RecLoop pointLoop];
	return [RecLoopState stateWithLoop:lp];
}

// designated initializer
- (id)initWithLoop:(RecLoop *)lp
{
    self = [super init];
    if (!self) return nil;

	loop = lp;
	range = NSMakeRange(0, [lp dataLength]);
	current = 0;
	return self;
}

// deep copy
- (id)copyWithZone:(NSZone *)zone
{
	id	ls = [[[self class] alloc] initWithLoop:[self loop]];
	[ls setRange:[self range]];
	[ls setCurrent:[self current]];
	return ls;
}

- (int)loopStart
{
	return (int)range.location;
}

- (int)loopLength
{
	return (int)range.length;
}

- (int)dataLength
{
	return [loop dataLength];
}

- (void)setLoop:(RecLoop *)lp;
{
	loop = lp;
}

- (RecLoop *)loop
{
	return loop;
}

- (id)setRange:(NSRange)r
{
	range = r;
    [self rewind];
	return self;
}

- (id)resetRange
{
	range = NSMakeRange(0, [loop dataLength]);
	[self rewind];
	return self;
}

- (NSRange)range
{
	return range;
}

- (id)rewind
{
	current = (int)range.location;
	return self;
}

- (BOOL)increment
{
	current++;
	if (current >= range.location + range.length) {
		current = (int)range.location;
		return NO;	// not in range
	}
	return YES;		// in range
}

- (void)setCurrent:(int)cur
{
	if (cur != current &&
		cur >= range.location &&
		cur < range.location + range.length)
	current = cur;
}

- (int)current
{
	return current;
}

@end


// ===== RecLoopIndex ====

@implementation RecLoopIndex

+ (RecLoopIndex *)loopIndexWithLoop:(RecLoop *)lp
{
	return [[RecLoopIndex alloc] initWithLoop:lp];
}

+ (RecLoopIndex *)loopIndexWithState:(RecLoopState *)st
{
	RecLoopIndex *li = [[RecLoopIndex alloc] initWithState:st];
    return li;
}

// this is shaloow copy (copyWithZone is deep copy)
+ (RecLoopIndex *)loopIndexAtIndex:(RecLoopIndex *)index
{
	RecLoopIndex    *li = [[RecLoopIndex alloc] init];
	[li setState:[index state]];	// reference
	[li setActive:[index active]];	// value
	return li;
}

+ (RecLoopIndex *)pointLoopIndex
{
	RecLoop			*lp = [RecLoop pointLoop];

	return [RecLoopIndex loopIndexWithLoop:lp];
}

// designated initializer
- (RecLoopIndex *)initWithLoop:(RecLoop *)lp
{
    self = [super init];
    if (!self) return nil;

	[self setState:[RecLoopState stateWithLoop:lp]];
	active = YES;
	return self;
}

- (RecLoopIndex *)initWithState:(RecLoopState *)st
{
	[self setState:st];
	[self setActive:YES];
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	RecLoopIndex    *li = [[[self class] alloc] init];
	[li setState:[state copy]];	// reference
	[li setActive:active];	// value
	return li;
}

- (BOOL)active
{
	return active;
}

- (void)setActive:(BOOL)flg
{
	active = flg;
}

- (void)activate;
{
	active = YES;
}

- (void)deactivate
{
	active = NO;
}

- (RecLoopState *)state
{
	return state;
}

- (void)setState:(RecLoopState *)st
{
	state = st;
}

- (RecLoop *)loop
{
	return [state loop];
}

- (int)loopStart
{
    return [state loopStart];
}

- (int)loopLength
{
	if (active) {
		return [state loopLength];
	} else {
		return 1;
	}
}

- (int)dataLength
{
	return [state dataLength];
}

- (id)setRange:(NSRange)range
{
    [state setRange:range];
    return self;
}

- (id)resetRange
{
    [state resetRange];
    return self;
}

- (NSRange)range
{
    return [state range];
}

- (void)rewind
{
	if (active) {
		[state rewind];
	}
}

- (void)forceRewind
{
	[state rewind];
}

- (BOOL)increment
{
	if (active) {
		return [state increment];
	} else {
		return NO;
	}
}

- (void)setCurrent:(int)cur
{
	[state setCurrent:cur];
}

- (int)current
{
	return [state current];
}

@end
