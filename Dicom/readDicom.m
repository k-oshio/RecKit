//
//
//

#import <RecKit/RecKit.h>

int
main()
{
    @autoreleasepool {

    NSFileManager   *manager = [NSFileManager defaultManager];
    NSString        *current, *path;
    NSArray         *paths;
    NSError         *err;
    RecImage        *img;

    int             i;

    current = [manager currentDirectoryPath];
    paths = [manager contentsOfDirectoryAtPath:current error:&err];
//    printf("%s\n", [current UTF8String]);

    for (i = 0; i < [paths count]; i++) {
        path = [paths objectAtIndex:i];
        printf("%s\n", [path UTF8String]);
    }

    img = [RecImage imageWithDicomFiles:paths];
    [img saveAsKOImage:@"dicom.img"];

    return 0;
    }
}
