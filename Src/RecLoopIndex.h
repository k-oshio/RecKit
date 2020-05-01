//
//	RecLoopState.h
//		state is separated from dim
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

@class	RecLoop;

// ===== RecLoopState (private) ====
@interface RecLoopState : NSObject
{
	RecLoop		*loop;
	int			current;
	NSRange		range;	// int:location, int:length
}

+ (RecLoopState *)stateWithLoop:(RecLoop *)lp;
+ (RecLoopState *)pointState;
- (id)initWithLoop:(RecLoop *)lp;
- (id)copyWithZone:(NSZone *)zone;
- (int)loopStart;
- (int)loopLength;
- (int)dataLength;
- (void)setLoop:(RecLoop *)lp;
- (RecLoop *)loop;

- (id)setRange:(NSRange)range;
- (id)resetRange;
- (NSRange)range;
- (id)rewind;
- (BOOL)increment;
- (void)setCurrent:(int)cur;
- (int)current;

@end

// ===== RecLoopIndex ====
@interface RecLoopIndex : NSObject
{
	RecLoopState	*state;
	BOOL			active;
}

+ (RecLoopIndex *)loopIndexWithLoop:(RecLoop *)lp;
+ (RecLoopIndex *)loopIndexWithState:(RecLoopState *)st;
+ (RecLoopIndex *)loopIndexAtIndex:(RecLoopIndex *)li;
+ (RecLoopIndex *)pointLoopIndex;
- (RecLoopIndex *)initWithLoop:(RecLoop *)lp;
- (RecLoopIndex *)initWithState:(RecLoopState *)st;
- (BOOL)active;
- (void)setActive:(BOOL)flg;
- (void)activate;
- (void)deactivate;
- (RecLoopState *)state;
- (void)setState:(RecLoopState *)st;

// methods to control underlying state
- (RecLoop *)loop;
- (int)loopStart;
- (int)loopLength;
- (int)dataLength;
- (id)setRange:(NSRange)range;
- (id)resetRange;
- (NSRange)range;
- (void)rewind;
- (void)forceRewind;
- (BOOL)increment;
- (void)setCurrent:(int)cur;
- (int)current;

@end
