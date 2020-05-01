//
//  move to other Rec_XXX header
//

#import <sys/time.h>

struct		timeval	timer_st0, timer_st, timer_ed;
float		tint;

#define		TIMER_ST	gettimeofday(&timer_st, NULL); timer_st0 = timer_st;
#define		TIMER_END(str) gettimeofday(&timer_ed, NULL); \
				tint = (timer_ed.tv_sec - timer_st.tv_sec) * 1000000 + timer_ed.tv_usec - timer_st.tv_usec; \
				timer_st = timer_ed; \
				printf(" time: %f (sec) ", tint * 1.0e-6); \
				printf(str); \
				printf("\n");
#define		TIMER_TOTAL gettimeofday(&timer_ed, NULL); \
				tint = (timer_ed.tv_sec - timer_st0.tv_sec) * 1000000 + timer_ed.tv_usec - timer_st.tv_usec; \
				printf(" time: %f (sec) ", tint * 1.0e-6); \
				printf("TOTAL\n");
