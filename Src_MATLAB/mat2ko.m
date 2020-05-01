//
//
//

#import <RecKit/RecKit.h>

int
main(int ac, char *av[])
{
	char		cwd[256];
	NSString	*path;
	RecImage	*img;

	if (ac < 2) {
		printf("mat2ko <basename>\n");
	}
	if (getcwd(cwd, 256) != NULL) {
		path = [NSString stringWithFormat:@"%s/%s.mat", cwd, av[1]];
	}
	img = [RecImage imageWithMatfile:path];
	path = [NSString stringWithFormat:@"%s/%s.img", cwd, av[1]];
	[img saveAsKOImage:path];
	
	return 0;
}
