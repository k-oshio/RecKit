//
//	RecLoopControl
//

#import "RecLoopControl.h"
#import "RecLoop.h"
#import "RecLoopIndex.h"
#import "RecImage.h"

// ===== RecLoopControl ====
@implementation RecLoopControl

// new states are created
+ (RecLoopControl *)controlForImage:(RecImage *)image
{
	RecLoopControl		*lc;
	NSArray				*loops = [image loops];

	if (loops == nil) return nil;
	lc = [[RecLoopControl alloc] init];
	return [lc initWithLoopArray:loops];
}

// states: referenced (not copied)
// flags : copied
+ (RecLoopControl *)controlWithControl:(RecLoopControl *)control
{
	RecLoopControl	*lc;
	lc = [[RecLoopControl alloc] init];
    return [lc initWithControl:control];
}

// states: if exist in src control, referenced (not copied), otherwise created
// flags : if exist in src control, copied, otherwise set to YES
+ (RecLoopControl *)controlWithControl:(RecLoopControl *)control forImage:(RecImage *)image
{
	RecLoopControl		*lc;
	lc = [[RecLoopControl alloc] init];
	return [lc initWithControl:control forImage:image];
}

+ (RecLoopControl *)controlWithLoopArray:(NSArray *)loops
{
	RecLoopControl		*lc;
	lc = [[RecLoopControl alloc] init];
	return [lc initWithLoopArray:loops];
}

+ (RecLoopControl *)controlWithLoops:(RecLoop *)lp, ...;
{
	RecLoopControl  *lc = nil;
	NSMutableArray	*loops = [NSMutableArray array];
	va_list			varglist;

	if (lp) {
		[loops addObject:lp];
		va_start(varglist, lp);
		while ((lp = va_arg(varglist, RecLoop *))) {
			[loops addObject:lp];
			va_end(varglist);
		}
		lc = [RecLoopControl controlWithLoopArray:loops];
	}
    return lc;
}

- (id)initWithLoopArray:(NSArray *)loops
{
	NSMutableArray	*tmpArray = [NSMutableArray array];
	RecLoop			*lp;
	RecLoopIndex	*li;
	int				i, n = (int)[loops count];

	for (i = 0; i < n; i++) {
		lp = [loops objectAtIndex:i];
		li = [RecLoopIndex loopIndexWithLoop:lp];	// default is active
		[tmpArray addObject:li];
	}
	loopIndeces = [NSArray arrayWithArray:tmpArray];

	return self;
}

// this is shallow copy : (copyWithZone is deep copy)
// states: referenced (not copied)
// flags : copied
- (RecLoopControl *)initWithControl:(RecLoopControl *)control
{
	NSMutableArray	*tmpArray = [NSMutableArray array];
	RecLoopIndex	*li;
	int				i;
	int				n = [control dim];	// src dim

	for (i = 0; i < n; i++) {	// for src loops
		li = [control loopIndexAtIndex:i];
		[tmpArray addObject:[RecLoopIndex loopIndexAtIndex:li]];	// shallow copy
	}
	loopIndeces = [NSArray arrayWithArray:tmpArray];

	return self;
}

// states: if exist in src control, referenced (not copied), otherwise created
// flags : if exist in src control, copied, otherwise set to YES
- (RecLoopControl *)initWithControl:(RecLoopControl *)control forImage:(RecImage *)image
{
	NSMutableArray	*tmpArray = [NSMutableArray array];	// RecLoopState array
	RecLoop			*lp, *loop;
	NSArray			*loops = [image loops];
	RecLoopIndex	*li;
	int				i, j;
	int				n = [image dim];		// dst dim
	int				m = [control dim];	// src dim
	BOOL			found;

	for (i = 0; i < n; i++) {	// for dst loops
		loop = [loops objectAtIndex:i];
		found = NO;
		for (j = 0; j < m; j++) {	// for src states
			li = [control loopIndexAtIndex:j];
			lp = [li loop];
			if ([lp isEqual:loop]) {
				found = YES;
				break;
			}
		}
		if (found) {
			[tmpArray addObject:[RecLoopIndex loopIndexAtIndex:li]];	// shallow copy
		} else {
			[tmpArray addObject:[RecLoopIndex loopIndexWithLoop:loop]];
		}
	}
	loopIndeces = [NSArray arrayWithArray:tmpArray];

	return self;
}

// this is deep copy
// states are copied
// flags are copied
- (id)copyWithZone:(NSZone *)zone
{
	NSMutableArray	*tmpLoops = [NSMutableArray array];
	RecLoopIndex	*li;
	RecLoopControl	*lc = [[[self class] alloc] init];
	int				i, n = (int)[loopIndeces count];

	if (lc) {
		for (i = 0; i < n; i++) {
			li = [[loopIndeces objectAtIndex:i] copy];	// copy each LoopState
			[tmpLoops addObject:li];
		}
		lc->loopIndeces = [NSArray arrayWithArray:tmpLoops];
	}
	return lc;
}

- (RecLoop *)xLoop
{
	return [[loopIndeces lastObject] loop];
}

- (RecLoop *)yLoop
{
	int		loopIx = (int)[loopIndeces count] - 2;
	if (loopIx < 0) {
		return [RecLoop pointLoop];
	} else {
		return [[loopIndeces objectAtIndex:loopIx] loop];
	}
}

- (RecLoop *)zLoop
{
	int		loopIx = (int)[loopIndeces count] - 3;
	if (loopIx < 0) {
		return [RecLoop pointLoop];
	} else {
		return [[loopIndeces objectAtIndex:loopIx] loop];
	}
}

- (int)zPosition
{
	int		loopIx = (int)[loopIndeces count] - 3;

	if (loopIx < 0) {
		return 0;
	}
	return [[loopIndeces objectAtIndex:loopIx] current];
}

- (RecLoopControl *)controlByRemovingLoop:(RecLoop *)lp
{
    RecLoopControl  *lc;
    RecLoopIndex    *li;
    NSMutableArray  *tmpArray;

    lc = [RecLoopControl controlWithControl:self];
    li = [lc loopIndexForLoop:lp];
    tmpArray = [NSMutableArray arrayWithArray:[lc loopIndeces]];
    [tmpArray removeObject:li];
    [lc setLoopIndeces:[NSArray arrayWithArray:tmpArray]];

    return lc;
}

- (void)replaceLoop:(RecLoop *)lp withLoop:(RecLoop *)newLp;
{
    RecLoopIndex    *li, *newLi;
    NSMutableArray  *tmpArray;
    int             ix;

    li = [self loopIndexForLoop:lp];
    newLi = [RecLoopIndex loopIndexWithLoop:newLp];
    ix = (int)[loopIndeces indexOfObject:li];
    tmpArray = [NSMutableArray arrayWithArray:[self loopIndeces]];
    [tmpArray replaceObjectAtIndex:ix withObject:newLi];
    loopIndeces = [NSArray arrayWithArray:tmpArray];
}

- (void)removeLoop:(RecLoop *)lp
{
    RecLoopIndex    *li, *newLi;
    NSMutableArray  *tmpArray;
    int             ix;

    li = [self loopIndexForLoop:lp];
    newLi = [RecLoopIndex loopIndexWithLoop:lp];
    ix = (int)[loopIndeces indexOfObject:li];
    tmpArray = [NSMutableArray arrayWithArray:[self loopIndeces]];
    [tmpArray removeObjectAtIndex:ix];
    loopIndeces = [NSArray arrayWithArray:tmpArray];
}

- (RecLoop *)combineLoop:(RecLoop *)lp1 andLoop:(RecLoop *)lp2	// return newly created loop
{
	RecLoop		*newLp = [RecLoop loopWithDataLength:[lp1 dataLength] * [lp2 dataLength]];
	[self removeLoop:lp2];
	[self replaceLoop:lp1 withLoop:newLp];
	return newLp;
}

- (RecLoopControl *)complementaryControl
{
	RecLoopControl	*control = [RecLoopControl controlWithControl:self]; // shallow copy
	[control invertActive];
	return control;
}

- (void)insertLoop:(RecLoop *)lp atIndex:(int)ix
{
	NSMutableArray	*tmpArray = [NSMutableArray arrayWithArray:loopIndeces];
	RecLoopIndex	*li = [RecLoopIndex loopIndexWithLoop:lp];

	[tmpArray insertObject:li atIndex:ix];
	loopIndeces = [NSArray arrayWithArray:tmpArray];
}

- (void)insertLoop:(RecLoop *)newLp beforeLoop:(RecLoop *)lp
{
	int		ix = [self indexOfLoop:lp];
	[self insertLoop:newLp atIndex:ix];
}

- (id)activateAll
{
	int				i, n = [self dim];

	for (i = 0; i < n; i++) {
        [[self loopIndexAtIndex:i] setActive:YES];
	}
	return self;
}

- (id)deactivateAll
{
	int				i, n = [self dim];

	for (i = 0; i < n; i++) {
        [[self loopIndexAtIndex:i] setActive:NO];
	}
	return self;
}

- (id)invertActive
{
	int				i, n = [self dim];
	RecLoopIndex	*li;

	for (i = 0; i < n; i++) {
		li = [self loopIndexAtIndex:i];
		if ([li active]) {
			[li setActive:NO];
		} else {
			[li setActive:YES];
		}
	}
	return self;
}

- (id)deactivateInner
{
	int		n = [self dim];
	if (n > 0) [[self loopIndexAtIndex:n - 1] setActive:NO];
	return self;
}

- (id)activateInner
{
	int		n = [self dim];
	if (n > 0) [[self loopIndexAtIndex:n - 1] setActive:YES];
	return self;
}

- (id)deactivateTop
{
	int		n = [self dim];
	if (n > 0) [[self loopIndexAtIndex:0] setActive:NO];
    return self;
}

- (id)activateTop
{
	int		n = [self dim];
	if (n > 0) [[self loopIndexAtIndex:0] setActive:YES];
    return self;
}

- (id)activateX
{
    return [self activateInner];
}

- (id)deactivateX
{
    return [self deactivateInner];
}

- (id)activateY
{
    int dim = [self dim];
    if (dim > 1) [self activateLoopAtIndex:dim - 2];
    return self;
}

- (id)deactivateY
{
    int dim = [self dim];
    if (dim > 1) [self deactivateLoopAtIndex:dim - 2];
    return self;
}

- (id)activateXY
{
	int		dim = [self dim];

	if (dim > 0) [[self loopIndexAtIndex:dim - 1] setActive:YES];
	if (dim > 1) [[self loopIndexAtIndex:dim - 2] setActive:YES];
	return self;
}

- (id)deactivateXY
{
	int		dim = [self dim];

	if (dim > 0) [[self loopIndexAtIndex:dim - 1] setActive:NO];
	if (dim > 1) [[self loopIndexAtIndex:dim - 2] setActive:NO];
	return self;
}

- (id)activateXYZ
{
	int		dim = [self dim];

	if (dim > 0) [[self loopIndexAtIndex:dim - 1] setActive:YES];
	if (dim > 1) [[self loopIndexAtIndex:dim - 2] setActive:YES];
	if (dim > 2) [[self loopIndexAtIndex:dim - 3] setActive:YES];
	return self;
}

- (id)deactivateXYZ
{
	int		dim = [self dim];

	if (dim > 0) [[self loopIndexAtIndex:dim - 1] setActive:NO];
	if (dim > 1) [[self loopIndexAtIndex:dim - 2] setActive:NO];
	if (dim > 2) [[self loopIndexAtIndex:dim - 3] setActive:NO];
	return self;
}

- (id)activateLoop:(RecLoop *)lp
{
	RecLoopIndex	*li = [self loopIndexForLoop:lp];
	[li setActive:YES];
	return self;
}

- (id)deactivateLoop:(RecLoop *)lp
{
	RecLoopIndex	*li = [self loopIndexForLoop:lp];
	[li setActive:NO];
	return self;
}

- (id)activateLoopAtIndex:(int)ix
{
    RecLoopIndex    *li = [self loopIndexAtIndex:ix];
    [li setActive:YES];
    return self;
}

- (id)deactivateLoopAtIndex:(int)ix
{
    RecLoopIndex    *li = [self loopIndexAtIndex:ix];
    [li setActive:NO];
    return self;
}

- (NSArray *)activeLoops
{
    int             i, n = [self dim];
    NSMutableArray  *tmpArray = [NSMutableArray array];

    for (i = 0; i < n; i++) {
        if ([[self loopIndexAtIndex:i] active]) {
            [tmpArray addObject:[self loopAtIndex:i]];
        }
    }
    return [NSArray arrayWithArray:tmpArray];
}

- (id)deactivateLoopsContainedIn:(RecLoopControl *)lc
{
    int             i, n = [self dim];
    RecLoopIndex    *li;

    for (i = 0; i < n; i++) {
        li = [self loopIndexAtIndex:i];
        if ([lc containsLoop:[li loop]]) {
            [li deactivate];
        }
    }
    return self;
}

- (int)dim
{
	return (int)[loopIndeces count];
}

- (int)loopLength
{
	int				i;
	int				n = (int)[loopIndeces count];
	int				len = 1;
	RecLoopIndex	*li;

	for (i = 0; i < n; i++) {
		li = [loopIndeces objectAtIndex:i];
		len *= [li loopLength];
	}
	return len;
}

- (int)loopLengthOfLoop:(RecLoop *)lp
{
    RecLoopIndex    *li = [self loopIndexForLoop:lp];
    return [li loopLength];
}

- (NSArray *)loopIndeces
{
	return loopIndeces;
}

- (void)setLoopIndeces:(NSArray *)indeces
{
	loopIndeces = indeces;
}

- (RecLoopIndex *)loopIndexForLoop:(RecLoop *)lp
{
	int				i, n = (int)[loopIndeces count];
	RecLoopIndex	*li;

	for (i = 0; i < n; i++) {
		li = [loopIndeces objectAtIndex:i];
		if ([[li loop] isEqual:lp]) return li;
	}
	return nil;	// not found
}

- (RecLoopIndex *)loopIndexAtIndex:(int)ix;
{
	return [loopIndeces objectAtIndex:ix];
}

- (RecLoop *)loopAtIndex:(int)ix
{
	return [[loopIndeces objectAtIndex:ix] loop];
}

- (int)indexOfLoop:(RecLoop *)lp
{
    return (int)[loopIndeces indexOfObject:[self loopIndexForLoop:lp]];
}

- (RecLoop *)innerLoop
{
	return [[self innerLoopIndex] loop];
}

// innermost among active (for fast looping)
- (RecLoopIndex *)innerLoopIndex
{
    int             i, n = (int)[loopIndeces count];
    RecLoopIndex    *li;

    for (i = n - 1; i >= 0; i--) {
        li = [loopIndeces objectAtIndex:i];
        if ([li active]) return li;
    }
    return nil;
}

//- (RecLoopIndex *)topLoopIndex
//{
//    return [loopIndeces objectAtIndex:0];
//}

- (RecLoop *)topLoop
{   
    return [[self topLoopIndex] loop];
}

// top among active
- (RecLoopIndex *)topLoopIndex
{
    int             i, n = (int)[loopIndeces count];
    RecLoopIndex    *li;

    for (i = 0; i < n; i++) {
        li = [loopIndeces objectAtIndex:i];
        if ([li active]) return li;
    }
    return nil;
}

- (BOOL)containsLoop:(RecLoop *)loop
{
    int     i, n = [self dim];
    BOOL    found = NO;
    RecLoop *lp;

    for (i = 0; i < n; i++) {
        lp = [[loopIndeces objectAtIndex:i] loop];
        if ([lp isEqual:loop]) {
            found = YES;
            break;
        }
    }
	return found;
}

- (id)rewind
{
	int		i, n = [self dim];

	for (i = 0; i < n; i++) {
		[[self loopIndexAtIndex:i] rewind];	// state rewinds only if active
	}
	return self;
}

- (id)rewindAll
{
	int		i, n = [self dim];

	for (i = 0; i < n; i++) {
		[[self loopIndexAtIndex:i] forceRewind];	// rewind state
	}
	return self;
}

- (id)resetRange
{
	int		i, n = (int)[loopIndeces count];

	for (i = 0; i < n; i++) {
		[[loopIndeces objectAtIndex:i] resetRange];	// reset active or non-active
	}
	return self;
}

- (id)setRange:(NSRange)range forLoop:(RecLoop *)lp
{
	RecLoopIndex	*li;
	li = [self loopIndexForLoop:lp];
	[li setRange:range];
	return self;
}

- (id)resetRangeForLoop:(RecLoop *)lp
{
	RecLoopIndex	*li;
	li = [self loopIndexForLoop:lp];
	[li resetRange];
	return self;
}

- (id)setCurrent:(int)cur forLoop:(RecLoop *)lp
{
	RecLoopIndex	*li;
	li = [self loopIndexForLoop:lp];
	[li setCurrent:cur];
	return self;
}

// increment inner-most (active) loop
- (BOOL)increment
{
	int				i, n = [self dim];
	BOOL			inRange = NO;
	RecLoopIndex	*li;

	for (i = n - 1; i >= 0; i--) {
		li = [self loopIndexAtIndex:i];
		inRange = [li increment];			// increment only if active
		if (inRange) break;
	}
	return inRange;
}

- (int)current
{
	int				i, n = [self dim];
	int				current;
	int				size = 1;
	RecLoopIndex	*li;
	RecLoop			*lp;

	current = 0;
	for (i = n - 1; i >= 0; i--) {
		li = [self loopIndexAtIndex:i];
		lp = [li loop];
		current += [li current] * size;
		size *= [lp dataLength];
	}
	return current;
}

// returns array of LoopControls for top loop
// mainly for NSOperation
- (NSArray *)subControls
{
//	RecLoop *lp = [self activeTopLoop]; // top may not be active
	RecLoop *lp = [self topLoop];       // topLoop is topmost active loop
    return [self subControlsForLoop:lp];
}

// private
- (NSArray *)subControlsForLoop:(RecLoop *)lp
{
    int             i, n;
    NSMutableArray  *tmpArray = [NSMutableArray array];
	RecLoopIndex    *li = [self loopIndexForLoop:lp];

	n = [li dataLength];
	[li setActive:NO];
	for (i = 0; i < n; i++) {
		[li setCurrent:i];
		[tmpArray addObject:[self copy]];
	}
	return [NSArray arrayWithArray:tmpArray];
}

// === methods for debugging
- (void)dumpLoops
{
	RecLoop			*lp;
	RecLoopIndex	*li;
	RecLoopState	*st;
	int				i;

	printf("===== Loops (RecLoopControl) =======\n");
	for (i = 0; i < [loopIndeces count]; i++) {
		li = [loopIndeces objectAtIndex:i];
		st = [li state];
		lp = [st loop];
		printf("RecLoop:[%s] %d:%d [%ld %ld] active:%d state:0x%0lx\n", [[lp name] UTF8String],
			[lp dataLength],
			[st current],
			(long)[st range].location,
			(long)[st range].length,
			[li active],
			(unsigned long)st);
	}
	printf("===================\n");
}

@end

