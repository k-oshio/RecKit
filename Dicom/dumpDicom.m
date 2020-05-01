//
//
//

#import <RecKit/RecKit.h>

extern int dbg, Rec_dcm_explicit_vr;

int
main(int ac, char *av[])
{
    @autoreleasepool {
        FILE        *fp;
        int         sts;
//        int         i;

        dbg = 0;

        [RecImage initDicomDict];

        if (ac < 2) {
            printf("dumpDicom <file>\n");
            exit(0);
        }
        fp = fopen(av[1], "r");
        sts = Rec_dcm_read_file_meta(fp); // results are saved in global var
        if (Rec_dcm_explicit_vr) {      //0: no, 1:yes
            printf("Explicit VR\n");
        }

        sts = Rec_dcm_dump_items(fp);


        fclose(fp);
    }
    return 0;
}
