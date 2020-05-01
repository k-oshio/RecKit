//
//	RecLoopControl
//	ver 02
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

@class RecLoop, RecLoopState, RecLoopIndex, RecImage;

// ===== RecLoopControl ====
@interface RecLoopControl : NSObject
{
	NSArray		*loopIndeces;				// array of LoopIndex (LoopState + active flag)
}

// ========== new def of control ====================
//	"withControl"	: has common states with "control"
//	"forImage"		: has same loops with "image"
// ========== new def of control ====================

// has same loop set with image (states are created)
+ (RecLoopControl *)controlForImage:(RecImage *)image;
// create control containing loops
+ (RecLoopControl *)controlWithLoopArray:(NSArray *)loops;
+ (RecLoopControl *)controlWithLoops:(RecLoop *)lp, ...;

// shallow copy (states are referenced, flags are copied)
+ (RecLoopControl *)controlWithControl:(RecLoopControl *)control;
// has same loop set with image (states in control are referenced)
+ (RecLoopControl *)controlWithControl:(RecLoopControl *)control forImage:(RecImage *)img;

//- (RecLoopControl *)commonControlForImage:(RecImage *)img;
// -> use [img controlWithControl:]

- (RecLoopControl *)controlByRemovingLoop:(RecLoop *)lp;

- (RecLoopControl *)copyWithZone:(NSZone *)zone;	// deep copy (states are copied)
- (RecLoopControl *)complementaryControl;

- (RecLoopControl *)initWithLoopArray:(NSArray *)loops;
- (RecLoopControl *)initWithControl:(RecLoopControl *)control;
- (RecLoopControl *)initWithControl:(RecLoopControl *)control forImage:(RecImage *)image;

// accessing loops -> probably not necessary
//	(RecImage has these methods, and RecLoop doesn't have state) ###
- (RecLoop *)xLoop;
- (RecLoop *)yLoop;
- (RecLoop *)zLoop;
// current position
- (int)zPosition;

// change loops
- (void)replaceLoop:(RecLoop *)lp withLoop:(RecLoop *)newLp;
- (void)insertLoop:(RecLoop *)lp atIndex:(int)ix;
- (void)insertLoop:(RecLoop *)newLp beforeLoop:(RecLoop *)lp;
- (void)removeLoop:(RecLoop *)lp;
- (RecLoop *)combineLoop:(RecLoop *)lp1 andLoop:(RecLoop *)lp2;	// return newly created loop

// active flag
// change id to void. (currently these returns self)
- (id)activateAll;
- (id)deactivateAll;
- (id)activateInner;    // innermost
- (id)deactivateInner;
- (id)activateTop; 
- (id)deactivateTop;
- (id)activateX;
- (id)deactivateX;
- (id)activateY;
- (id)deactivateY;
- (id)activateXY;
- (id)deactivateXY;
- (id)activateXYZ;
- (id)deactivateXYZ;
- (id)activateLoop:(RecLoop *)lp;
- (id)deactivateLoop:(RecLoop *)lp;
- (id)activateLoopAtIndex:(int)ix;
- (id)deactivateLoopAtIndex:(int)ix;
- (id)invertActive;
- (id)deactivateLoopsContainedIn:(RecLoopControl *)lc;
- (NSArray *)activeLoops;

// dimensions
- (int)dim;
- (int)loopLength;				// number of elements within range
- (NSArray *)loopIndeces;
- (void)setLoopIndeces:(NSArray *)indeces;
- (int)loopLengthOfLoop:(RecLoop *)lp;

// loop index
- (RecLoop *)loopAtIndex:(int)ix;
- (int)indexOfLoop:(RecLoop *)lp;
- (RecLoopIndex *)loopIndexAtIndex:(int)ix;
- (RecLoopIndex *)loopIndexForLoop:(RecLoop *)lp;
- (RecLoop *)innerLoop;             // innermost among active. for fast looping
- (RecLoopIndex *)innerLoopIndex;   // innermost among active. for fast looping
- (RecLoop *)topLoop;               // top among active. for real top, use loopAtIndex:
- (RecLoopIndex *)topLoopIndex;     // top among active. for real top, use loopIndexAtIndex:
- (BOOL)containsLoop:(RecLoop *)lp;

// action
- (id)rewind;		// rewind active
- (id)rewindAll;	// rewind all loops including inactive ones
- (id)resetRange;
- (id)setRange:(NSRange)range forLoop:(RecLoop *)lp;
- (id)setCurrent:(int)cur forLoop:(RecLoop *)lp;
- (id)resetRangeForLoop:(RecLoop *)lp;
- (int)current;
- (BOOL)increment;

- (NSArray *)subControls;	// returns array of LoopControls for top loop
- (NSArray *)subControlsForLoop:(RecLoop *)lp;

- (void)dumpLoops;

@end
