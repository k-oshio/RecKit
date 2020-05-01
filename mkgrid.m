//
//
// === plans ====
// make this a filter (stdin, stdout), and take string name as arg

#import <Reckit/RecKit.h>

int
main(int ac, char *av[])
{
	RecImage	*img;
	RecLoop		*kx, *ky;
	int			i, j;
	float		*p;

	kx = [RecLoop loopWithName:@"kx" dataLength:256];
	ky = [RecLoop loopWithName:@"ky" dataLength:256];
	img = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:ky, kx, nil];
	p = [img data];

	for (i = 0; i < 256 * 256; i++) {
		p[i] = 0.3;
	}
	for (i = 0; i < 256; i += 8) {
		for (j = 0; j < 256; j++) {
			p[i * 256 + j] = 1.0;
		}
	}
	for (j = 0; j < 256; j++) {
		p[255 * 256 + j] = 1.0;
	}
	for (i = 0; i < 256; i++) {
		for (j = 0; j < 256; j += 8) {
			p[i * 256 + j] = 1.0;
		}
		p[i * 256 + 255] = 1.0;
	}
	[img saveAsKOImage:@"test_warp_grid.img"];

	return 0;
}
