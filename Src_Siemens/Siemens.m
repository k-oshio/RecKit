//
//	file I/O for Siemens
//	64bit version (not tested for 32bit)
//

#import "Siemens.h"

// ========================================
@implementation RecImage (Siemens)

// VA
+ (RecImage *)imageWithMeasAsc:(NSString *)asc andMeasData:(NSString *)data
{
    RecImage    *img = [RecImage imageWithMeasAsc:asc andMeasData:data lpDim:NULL];
    return img;
}

// VA
+ (RecImage *)imageWithMeasAsc:(NSString *)asc andMeasData:(NSString *)data lpDim:(LP_DIM *)dim
{
	RecImage	*img;
	LP_DIM		lp_dim = {0};
	FILE		*fp;

    if ((fp = fopen([asc UTF8String], "r")) == NULL) return nil;
    read_asc(fp, &lp_dim);
	fclose(fp);

    dump_dims_va(&lp_dim);

    if ((fp = fopen([data UTF8String], "r")) == NULL) return nil;
	fseek(fp, 32, SEEK_SET);	// header
	[RecLoop clearLoops];
	img = read_raw(fp, &lp_dim);
	fclose(fp);

    if (dim != NULL) {
        *dim = lp_dim;  // copy
    }

	return img;
}

+ (void)readMetaVD:(NSString *)meas lpDim:(LP_DIM *)dim
{
    FILE			*fp;
    if ((fp = fopen([meas UTF8String], "r")) == NULL) return;
	read_meta_vd(fp, dim);
}

// VB, VD
+ (RecImage *)imageWithMeasVD:(NSString *)meas lpDim:(LP_DIM *)dim	// not done yet (VB) ###
{
    FILE			*fp;
	LP_DIM			lp_dim;
	RecImage		*img;

    if ((fp = fopen([meas UTF8String], "r")) == NULL) return nil;

	read_meta_vd(fp, &lp_dim);
	

	[RecLoop clearLoops];
	switch (lp_dim.version) {
	default :
	case VERSION_VB :
		img = read_raw(fp, &lp_dim);
		break;
	case VERSION_VD :
		img = read_raw_vd(fp, &lp_dim);
		break;
	}

	fclose(fp);

	return img;
}

- (void)reorderSlice
{
    RecLoop         *lp;
    RecImage        *img;
    RecLoopControl  *srcLc, *dstLc;
    RecLoopIndex    *srcLi,*dstLi;
    int             i, nslice, j, ofs;

    img = [RecImage imageWithImage:self];

    lp = [RecLoop findLoop:@"kz"];
    if (lp == nil) return;

    nslice = [lp dataLength];

    srcLc = [self control];
    [srcLc deactivateLoop:lp];
    srcLi = [srcLc loopIndexForLoop:lp];
    dstLc = [img control];
    [dstLc deactivateLoop:lp];
    dstLi = [dstLc loopIndexForLoop:lp];

    ofs = 1 - nslice % 2;
    for (i = 0; i < nslice; i++) {
        if (i * 2 < nslice) {
            j = i * 2 + ofs;
        } else {
            j = i * 2 - nslice;
        }
        printf("slice: %d -> %d\n", i, j);
        [srcLi setCurrent:i];
        [dstLi setCurrent:j];
        [img copyImage:self dstControl:dstLc srcControl:srcLc];
    }
    [self copyIvarOf:img];
}

- (void)rotImage:(float)angle
{
    int     nang;

    nang = round(angle * 2 / M_PI);
    [self rotate:nang];
}

@end

// =============== C util =========================
void clear_ctr(LP_CTR *ctr)
{
    ctr->mask = 0;
    ctr->cLin = 0;
    ctr->cAcq = 0;
    ctr->cSlc = 0;
    ctr->cPar = 0;
    ctr->cEco = 0;
    ctr->cPha = 0;
    ctr->cRep = 0;
}

void
clear_lpdim(LP_DIM *lp_dim)
{
    int     i;
    lp_dim->nMDH = 0;
    lp_dim->nSamples = 0;
    lp_dim->nChannels = 0;
    lp_dim->nLin = 0;
    lp_dim->nSlc = 0;
    lp_dim->nAcq = 0;
    lp_dim->nRep = 0;
    lp_dim->nPar = 0;
    lp_dim->nPCorr = 0;
    lp_dim->nShot = 0;
    lp_dim->nImages = 0;
    lp_dim->epifactor = 0;
    lp_dim->turbofactor = 0;
    lp_dim->slThick = 0;
    lp_dim->phaseFOV = 0;
    lp_dim->readFOV = 0;
    lp_dim->normalCor = 0;
    lp_dim->normalTra = 0;
    lp_dim->normalSag = 0;
    lp_dim->inplaneRot = 0;
    for (i = 0; i < 16; i++) {
        lp_dim->wip[i] = 0;
    }
	lp_dim->repIsOuter = 0;
}

// -> change to read text in buf
int
read_asc(FILE *fp, LP_DIM *lp_dim)
{
	char		buf[256];
    char        *sts;
//    FILE        *fp;
 
//    if ((fp = fopen([path UTF8String], "r")) == NULL) return -1;

    clear_lpdim(lp_dim);
    for (;;) {
        sts = fgets(buf, 256, fp);
        if (sts == NULL) break;
        get_seqname(buf, (char *)&lp_dim->seq_name);
        get_param(buf, "sSliceArray.lSize",         &lp_dim->nSlc,      NO);
        get_param(buf, "sFastImaging.lEPIFactor",   &lp_dim->epifactor, NO);
        get_param(buf, "sFastImaging.lTurboFactor", &lp_dim->turbofactor, NO);
        get_param(buf, "sFastImaging.lSegments",    &lp_dim->segments,  NO);
        get_param(buf, "lAverages",                 &lp_dim->nAcq,      NO);
    // read sSliceArray
        get_fparam(buf, "sSliceArray.asSlice[0].dThickness",   &lp_dim->slThick);
        get_fparam(buf, "sSliceArray.asSlice[0].dPhaseFOV",    &lp_dim->phaseFOV);
        get_fparam(buf, "sSliceArray.asSlice[0].dReadoutFOV",  &lp_dim->readFOV);
        get_fparam(buf, "sSliceArray.asSlice[0].sNormal.dCor", &lp_dim->normalCor);
        get_fparam(buf, "sSliceArray.asSlice[0].sNormal.dTra", &lp_dim->normalTra);
        get_fparam(buf, "sSliceArray.asSlice[0].sNormal.dSag", &lp_dim->normalSag);
        get_fparam(buf, "sSliceArray.asSlice[0].dInPlaneRot",  &lp_dim->inplaneRot);
	// not present in newer version
        get_param(buf, "lRepetitions",              &lp_dim->nRep,      NO);  // +1
        get_param(buf, "m_iMaxNoOfRxChannels",      &lp_dim->nChannels, YES);
        get_param(buf, "m_iNoOfFourierColumns",     &lp_dim->nSamples,  YES);
        get_param(buf, "m_iNoOfFourierLines",       &lp_dim->nLin,      YES);
        get_param(buf, "m_iNoOfFourierPartitions",  &lp_dim->nPar,      YES);
        get_param(buf, "m_lNoOfPhaseCorrScans",     &lp_dim->nPCorr,    YES); // +1
    // WiP param
        get_wip(buf, lp_dim->wip);
    }
// adjust index
    lp_dim->nRep += 1;
    lp_dim->nShot = lp_dim->nLin / lp_dim->epifactor;
	if (lp_dim->nShot == 0) lp_dim->nShot = 1;
    lp_dim->nImages = lp_dim->nSlc * lp_dim->nRep * lp_dim->nAcq * lp_dim->nPar;

    return 0;
}

// mainly for debug purpose...
// dimensions are read from meas.asc (except for pcorr, total mdh records etc)
int
read_dims_va(FILE *fp, LP_DIM *lp_dim)
{
//    FILE    *fp;
    BOOL    end_of_meas;
    int     bytelen;
    int		nlin, nslc, nacq, nrep, npar, nseg, npcorr, nmdh;
	LP_CTR	lp_ctr;

//    if ((fp = fopen([path UTF8String], "r")) == NULL) return -1;

//	if (lp_dim->epifactor == 0) {
//		printf("epifactor has to be set before calling read_dims()\n");
//		return -1;
//	}

	clear_ctr(&lp_ctr);
	
// find nslice, nacq, nrep
    nlin = nslc = nacq = nrep = npar = nseg = 0;
    npcorr = 0;
    nmdh = 0;
//    fseek(fp, 32, SEEK_SET);
    for (;;) {
        end_of_meas = read_mdh(fp, &lp_ctr);
//printf("lin/slc/asc/rep/par/ch = %d/%d/%d/%d/%d/%d/%d\n", lp_ctr.cLin, lp_ctr.cSlc, lp_ctr.cAcq, lp_ctr.cRep, lp_ctr.cPar, lp_ctr.cCha, lp_ctr.cSeg);
        if (end_of_meas) break;

        if (lp_ctr.mask & MDH_MASK_PCOR) {
			npcorr++;
        //    printf("pc line = %d\n", lp_ctr.cLin);
        } else {
			if (lp_ctr.cLin > nlin) nlin = lp_ctr.cLin;
			if (lp_ctr.cSlc > nslc) nslc = lp_ctr.cSlc;
			if (lp_ctr.cAcq > nacq) nacq = lp_ctr.cAcq;
			if (lp_ctr.cRep > nrep) nrep = lp_ctr.cRep;
			if (lp_ctr.cPar > npar) npar = lp_ctr.cPar;
			if (lp_ctr.cSeg > nseg) npar = lp_ctr.cSeg;
			
        }
		lp_dim->nSamples = lp_ctr.nSamples;
		lp_dim->nChannels = lp_ctr.nChannels;
        bytelen = lp_dim->nSamples * 2 * sizeof(float);
        if (fseek(fp, bytelen, SEEK_CUR) < 0) break;

        nmdh++; // number of successfully read mdh records
    }
// largest index -> number
    lp_dim->nLin = nlin + 1;
    lp_dim->nSlc = nslc + 1;
    lp_dim->nAcq = nacq + 1;
    lp_dim->nRep = nrep + 1;
    lp_dim->nPar = npar + 1;

    lp_dim->nMDH = nmdh;

//printf("lin/slc/acq/rep/par = %d/%d/%d/%d/%d/%d\n", nlin, nslc, nacq, nrep, npar, lp_ctr.cEco);

    return 0;
}

// probably difference is in single vs mult, not VA vs VB #####
int
read_dims_vb(FILE *fp, LP_DIM *lp_dim)
{
//    FILE    *fp;
    BOOL    end_of_meas;
    int     bytelen;
    int		nlin, nslc, nacq, nrep, npar, nseg, npcorr, nmdh;
	LP_CTR	lp_ctr;

	clear_ctr(&lp_ctr);

if (0) {
	int		*buf;
	long long	i, len = 10000;
	buf = (int *)malloc(sizeof(float) * len);

	fgetpos(fp, &i);
	printf("pos = %lx\n", i);
	fread(buf, sizeof(int), len, fp);
	fclose(fp);
	fp = fopen("raw.dat", "w");
	fwrite(buf, sizeof(int), len, fp);
	fclose(fp);
	exit(0);
}

/* from YAPS ####
sKSpace.lBaseResolution		= 	256
sKSpace.lPhaseEncodingLines	= 	256
sKSpace.lPartitions			= 	208
sKSpace.lImagesPerSlab		= 	176
*/
	
// find nslice, nacq, nrep
    nlin = nslc = nacq = nrep = npar = nseg = 0;
    npcorr = 0;
    nmdh = 0;
    for (;;) {
        end_of_meas = read_mdh(fp, &lp_ctr);
printf("lin/slc/acq/rep/par/ch/seg = %d/%d/%d/%d/%d/%d/%d\n", lp_ctr.cLin, lp_ctr.cSlc, lp_ctr.cAcq, lp_ctr.cRep, lp_ctr.cPar, lp_ctr.cCha, lp_ctr.cSeg);
        if (end_of_meas) break;

        if (lp_ctr.mask & MDH_MASK_PCOR) {
			npcorr++;
        //    printf("pc line = %d\n", lp_ctr.cLin);
        } else {
			if (lp_ctr.cLin > nlin) nlin = lp_ctr.cLin;
			if (lp_ctr.cSlc > nslc) nslc = lp_ctr.cSlc;
			if (lp_ctr.cAcq > nacq) nacq = lp_ctr.cAcq;
			if (lp_ctr.cRep > nrep) nrep = lp_ctr.cRep;
			if (lp_ctr.cPar > npar) npar = lp_ctr.cPar;
			if (lp_ctr.cSeg > nseg) npar = lp_ctr.cSeg;
			
        }
		lp_dim->nSamples = lp_ctr.nSamples;
		lp_dim->nChannels = lp_ctr.nChannels;
        bytelen = lp_dim->nSamples * 2 * sizeof(float);
        if (fseek(fp, bytelen, SEEK_CUR) < 0) break;

        nmdh++; // number of successfully read mdh records
    }
// largest index -> number
    lp_dim->nLin = nlin + 1;
    lp_dim->nSlc = nslc + 1;
    lp_dim->nAcq = nacq + 1;
    lp_dim->nRep = nrep + 1;
    lp_dim->nPar = npar + 1;

    lp_dim->nMDH = nmdh;

//printf("lin/slc/acq/rep/par = %d/%d/%d/%d/%d/%d\n", nlin, nslc, nacq, nrep, npar, lp_ctr.cEco);

    return 0;
}

void
get_seqname(char *buf, char *str_out)
{
    char    tmp[256];

//    if (strncmp(buf, "tProtocolName", 13) == 0) {
	if ((buf = strstr(buf, "tProtocolName")) != NULL) {
        sscanf(buf, "tProtocolName = %s", tmp);
        strcpy(str_out, tmp);
    }
}

void
get_param(char *buf, char *name, int *val_out, BOOL paren)
{
//    int     len = (int)strlen(name);
    int     val;
    char    tmp[256];

//    if (strncmp(buf, name, len) == 0) {
		if ((buf = strstr(buf, name)) != NULL) {
        if (paren) {
            sscanf(buf, "%s = [%d]", tmp, &val);
        } else {
            sscanf(buf, "%s = %d", tmp, &val);
        }
    //    printf("[%s] = %d\n", name, val);
		*val_out = val;
    }
}

void
get_fparam(char *buf, char *name, float *val_out)
{
//    int     len = (int)strlen(name);
    float   val;
    char    tmp[256];

//    if (strncmp(buf, name, len) == 0) {
		if ((buf = strstr(buf, name)) != NULL) {
        sscanf(buf, "%s = %f", tmp, &val);
     //   printf("[%s] = %f\n", name, val);
		*val_out = val;
    }
}

void
get_wip(char *buf, float *wp)
{
    int     i, len;
    char    varName[256];
    float   val;
    char    tmp[256];

    for (i = 0; i < 16; i++) {
        sprintf(varName, "sWiPMemBlock.alFree[%d]", i);
        len = (int)strlen(varName);
        if (strncmp(buf, varName, len) == 0) {
            sscanf(buf, "%s = %f", tmp, &val);
            wp[i] = val;
            break;
        }
        sprintf(varName, "sWiPMemBlock.adFree[%d]", i);
        if (strncmp(buf, varName, len) == 0) {
            sscanf(buf, "%s = %f", tmp, &val);
            wp[i] = val;
            break;
        }
    }
}

int
to_short(unsigned char *p)
{
	int				i;
    int				tmp;
	int				val = 0;

    for (i = 0; i < 2; i++) {
        tmp = p[i];
		tmp <<= (8 * i);
		val += tmp;
    }

    return val;
}

float
to_float(unsigned char *p)
{
	int				i;
    unsigned int	tmp;
	unsigned int	val = 0;
	float			fval;

    for (i = 0; i < 4; i++) {
        tmp = p[i];
		tmp <<= (8 * i);
		val += tmp;
    }
	bcopy(&val, &fval, 4);

    return fval;
}

int
to_long(unsigned char *p)
{
	int				i;
    int				tmp;
	int				val = 0;

    for (i = 0; i < 4; i++) {
        tmp = p[i];
		tmp <<= (8 * i);
		val += tmp;
    }

    return val;
}

BOOL
read_mdh(FILE *fp, LP_CTR *lp_ctr)
{
    sMDH			mdh;
    sLoopCounter    *lc;
    sSliceData      *sd;
    int             n = 0;

    n = (int)fread(&mdh, sizeof(sMDH), 1, fp);
    if (n < 1) {
		printf("fread error\n");
		return YES;
	}

    lc = (sLoopCounter *)&mdh.sLC;
    sd = (sSliceData *)&mdh.sSD;

if (0) {
printf("%d/%d/%d/%d/%d/%d/%d/%d/%d\n",
	lc->ushLine,                  /* line index                   */
	lc->ushAcquisition,           /* acquisition index            */
	lc->ushSlice,                 /* slice index                  */
	lc->ushPartition,             /* partition index              */
	lc->ushEcho,                 /* echo index                   */	
	lc->ushPhase,                 /* phase index                  */
	lc->ushRepetition,            /* measurement repeat index     */
	lc->ushSet,                   /* set index                    */
	lc->ushSeg);                   /* segment index  (for TSE)     */
}
if (0) {
	if (lc->ushLine == 1) {
		printf("%d/s:%f c:%f t:%f\n",
			lc->ushSlice, sd->sSlicePosVec.flSag, sd->sSlicePosVec.flCor, sd->sSlicePosVec.flTra);
	}
}
    lp_ctr->mask = to_long((unsigned char *)&mdh.aulEvalInfoMask);
    if (lp_ctr->mask & MDH_MASK_EOFM) {
		printf("END_OF_MEAS flag\n");
		return YES; // meas end
	}

	lp_ctr->counter = to_short((unsigned char *)&mdh.ulScanCounter);
	lp_ctr->time	= to_short((unsigned char *)&mdh.ulTimeStamp);
    lp_ctr->nSamples = to_short((unsigned char *)&mdh.ushSamplesInScan);
    lp_ctr->nChannels = to_short((unsigned char *)&mdh.ushUsedChannels);

    lp_ctr->cLin = to_short((unsigned char *)&lc->ushLine);
    lp_ctr->cAcq = to_short((unsigned char *)&lc->ushAcquisition);
    lp_ctr->cSlc = to_short((unsigned char *)&lc->ushSlice);
    lp_ctr->cPar = to_short((unsigned char *)&lc->ushPartition);
    lp_ctr->cEco = to_short((unsigned char *)&lc->ushEcho);
    lp_ctr->cPha = to_short((unsigned char *)&lc->ushPhase);
    lp_ctr->cRep = to_short((unsigned char *)&lc->ushRepetition);
	lp_ctr->cCha = to_long((unsigned char *)&mdh.ulChannelId);
	lp_ctr->cSeg = to_short((unsigned char *)&lc->ushSeg);
	lp_ctr->cCha &= 0x00ff;	// don't know what higher bits means (maybe coil ID)

    return NO;  // not meas end yet
}

void
dump_dims_va(LP_DIM *lp_dim)
{
    int     i;
    printf("=====\n");
    printf("sequence = %s\n", lp_dim->seq_name);
    printf("=====\n");
    printf("nSamples    = %d\n", lp_dim->nSamples);
    printf("nChannels   = %d\n", lp_dim->nChannels);
    printf("nLin        = %d\n", lp_dim->nLin);
    printf("nSlc        = %d\n", lp_dim->nSlc);
    printf("nAcq        = %d\n", lp_dim->nAcq);
    printf("nRep        = %d\n", lp_dim->nRep);
    printf("nPar        = %d\n", lp_dim->nPar);
    printf("nPCorr      = %d\n", lp_dim->nPCorr);
    printf("nShot       = %d\n", lp_dim->nShot);
    printf("nImages     = %d\n", lp_dim->nImages);
    printf("epifactor   = %d\n", lp_dim->epifactor);
    printf("turbofactor = %d\n", lp_dim->turbofactor);
    printf("nSeg		= %d\n", lp_dim->segments);
    printf("=====\n");
    printf("sliceThick  = %5.1f\n", lp_dim->slThick);
    printf("phaseFOV    = %5.1f\n", lp_dim->phaseFOV);
    printf("read FOV    = %5.1f\n", lp_dim->readFOV);
    printf("=====\n");
    printf("normal Cor  = %5.1f\n", lp_dim->normalCor);
    printf("normal Tra  = %5.1f\n", lp_dim->normalTra);
    printf("normal Sag  = %5.1f\n", lp_dim->normalSag);
    printf("inplane Rot = %5.1f\n", lp_dim->inplaneRot);
    printf("=====\n");
    for (i = 0; i < 16; i++) {
        if (lp_dim->wip[i] != 0) {
             printf("WiP[%d]      = %5.1f\n", i, lp_dim->wip[i]);
        }
    }
    printf("=====\n");
}

void
dump_dims_vd(LP_DIM *lp_dim)
{
    int     i;
    printf("=====\n");
    printf("sequence = %s\n", lp_dim->seq_name);
    printf("=====\n");
    printf("nSamples    = %d\n", lp_dim->nSamples);
    printf("nChannels   = %d\n", lp_dim->nChannels);
    printf("nLin        = %d\n", lp_dim->nLin);
    printf("nSlc        = %d\n", lp_dim->nSlc);
    printf("nAcq        = %d\n", lp_dim->nAcq);
    printf("nRep        = %d\n", lp_dim->nRep);
    printf("nPar        = %d\n", lp_dim->nPar);
    printf("nPCorr      = %d\n", lp_dim->nPCorr);
    printf("nShot       = %d\n", lp_dim->nShot);
    printf("nImages     = %d\n", lp_dim->nImages);
    printf("epifactor   = %d\n", lp_dim->epifactor);
    printf("turbofactor = %d\n", lp_dim->turbofactor);
    printf("nSeg		= %d\n", lp_dim->segments);
    printf("=====\n");
    printf("sliceThick  = %5.1f\n", lp_dim->slThick);
    printf("phaseFOV    = %5.1f\n", lp_dim->phaseFOV);
    printf("read FOV    = %5.1f\n", lp_dim->readFOV);
    printf("=====\n");
    printf("normal Cor  = %5.1f\n", lp_dim->normalCor);
    printf("normal Tra  = %5.1f\n", lp_dim->normalTra);
    printf("normal Sag  = %5.1f\n", lp_dim->normalSag);
    printf("inplane Rot = %5.1f\n", lp_dim->inplaneRot);
    printf("=====\n");
    for (i = 0; i < 16; i++) {
        if (lp_dim->wip[i] != 0) {
             printf("WiP[%d]      = %5.1f\n", i, lp_dim->wip[i]);
        }
    }
    printf("=====\n");
}

RecImage *
read_raw(FILE *fp, LP_DIM *lp_dim)
{
	RecImage		*img;
    int             dataLength;
    float           *p, *q;
    RecLoop         *yLp, *xLp;
    RecLoop         *slcLp, *acqLp, *repLp, *chLp;
    RecLoopIndex    *srcLi, *acqLi, *repLi, *yLi, *chLi;
    RecLoopControl  *lc;
    LP_CTR          lp_ctr;
    float           *buf = NULL;
    int             bytelen;
    BOOL            end_of_data;
	BOOL			rep_found = NO;
    int             line;

    xLp     = [RecLoop loopWithName:@"kx"  dataLength:lp_dim->nSamples];
    yLp     = [RecLoop loopWithName:@"ky"  dataLength:lp_dim->nLin];
    slcLp   = [RecLoop loopWithName:@"kz"  dataLength:lp_dim->nSlc];
    acqLp   = [RecLoop loopWithName:@"avg" dataLength:lp_dim->nAcq];
    repLp   = [RecLoop loopWithName:@"phs" dataLength:lp_dim->nRep];
	chLp	= [RecLoop loopWithName:@"ch"  dataLength:lp_dim->nChannels];
// make image
    img = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:chLp, repLp, acqLp, slcLp, yLp, xLp, nil];
// unit
    [img setUnit:REC_FREQ forLoop:xLp];
    [img setUnit:REC_FREQ forLoop:yLp];
    [img setUnit:REC_POS  forLoop:slcLp];    // 2D only, for the moment
// fov
    [xLp   setFov:lp_dim->readFOV];
    [yLp   setFov:lp_dim->phaseFOV];
    [slcLp setFov:lp_dim->slThick * [slcLp dataLength]];

    lc = [img control];
    dataLength = [img dataLength];
    repLi = [lc loopIndexForLoop:repLp];
    acqLi = [lc loopIndexForLoop:acqLp];
    srcLi = [lc loopIndexForLoop:slcLp];
    yLi   = [lc loopIndexForLoop:yLp];
	chLi  = [lc loopIndexForLoop:chLp];

// read data
    bytelen = lp_dim->nSamples * sizeof(float) * 2;
    buf = (float *)malloc(bytelen);
 
    [lc rewind];
    for (;;) {
        end_of_data = read_mdh(fp, &lp_ctr);
        if (end_of_data) break;
		if (!rep_found) {
			if (lp_ctr.cRep > 0 || lp_ctr.cAcq > 0) {
				if (lp_ctr.cAcq > 0) {
					lp_dim->repIsOuter = 1;
				}
				rep_found = YES;
			}
			//printf("r:%d a:%d counter:%d\n", lp_ctr.cRep, lp_ctr.cAcq, lp_ctr.counter);
			//printf("r:%d a:%d counter:%d\n", lp_ctr.cRep, lp_ctr.cAcq, lp_ctr.time);
		}
        if (fread(buf, bytelen, 1, fp) != 1) break;

        if (lp_ctr.mask & MDH_MASK_PCOR) {
            continue;   // ignore pcorr lines
        }

        line = lp_ctr.cLin;
//printf("clin = %03d, cSeg = %02d\n", lp_ctr.cLin, lp_ctr.cSeg);
        if (line < 0 || line >= [yLp dataLength]) {
            printf("line number out of range (%d)\n", line);
            continue;
        }
        [repLi setCurrent:lp_ctr.cRep];
        [acqLi setCurrent:lp_ctr.cAcq];
        [srcLi setCurrent:lp_ctr.cSlc];
        [yLi   setCurrent:line];
		[chLi	setCurrent:lp_ctr.cCha];
//	if (line == 1 || line == 2) {
//		printf("slc:%d, rep:%d, ch:%d, par = %d\n", lp_ctr.cSlc, lp_ctr.cRep, lp_ctr.cCha, lp_ctr.cPar);
//	}
        p = [img currentDataWithControl:lc];
        q = p + dataLength;
        read_line(p, q, buf, lp_dim->nSamples, lp_ctr.mask & MDH_MASK_FLIP);
	}
	free(buf);

    return img;
}

void
read_line(float *re, float *im, float *buf, int n, int flip)
{
    int				j;

    if (flip == 0) {
        for (j = n-1; j >= 0; j--) {
            re[j] += to_float((void *)buf++) * MDH_SCALE;
            im[j] += to_float((void *)buf++) * MDH_SCALE;
        }
    } else {
        for (j = 0; j < n; j++) {
            re[j] += to_float((void *)buf++) * MDH_SCALE;
            im[j] += to_float((void *)buf++) * MDH_SCALE;
        }
    }
}

// === VD version
int
get_str(char *p, int max_len, FILE *fp)
{
	int		i, c;

	for (i = 0; i < max_len; i++) {
		c = fgetc(fp);
		p[i] = c;
		if (c == 0) break;
	}
	return 0;
}

/*

ご質問の件ですが、データはMPRAGEでサイズは
256*256*176
のようです。これで矛盾しないでしょうか。
nch = 32

*/
/* read from YAPS ...
sequence = "MPRAGE_sag_p2_iso"
=====
nSamples    = 0
nChannels   = 0
nLin        = 256
nSlc        = 1
nAcq        = 1
nRep        = 65
nPar        = 208
nPCorr      = 0
nShot       = 256
nImages     = 65
epifactor   = 1
turbofactor = 16
nSeg		= 1
=====
sliceThick  = 176.0
phaseFOV    = 250.0
read FOV    = 250.0
=====
normal Cor  =   0.0
normal Tra  =   0.0
normal Sag  =   1.0
inplane Rot =   0.0
=====
*/

int
read_meta_vd(FILE *fp, LP_DIM *lp_dim)
{
	char	*buf;
	char	block_name[256];
	int		i;
	int		intVal;
	long	pos, start_pos, total_len;
	int		header_len, len, n_items;
	LP_CTR	lp_ctr;

//printf("mdh size = %ld\n", sizeof(sScanHeader));
//printf("chh size = %ld\n", sizeof(sChannelHeader));

// meta-header
	fread(&intVal, sizeof(int), 1, fp);		// 0		(?)
	if (intVal == 0) {
	//	buf = (char *)malloc(256);
		lp_dim->version = VERSION_VD;
		fread(&intVal, sizeof(int), 1, fp);		// 1		(?)
		fread(&intVal, sizeof(int), 1, fp);		// 0x00ae	(?)
		fread(&intVal, sizeof(int), 1, fp);		// 0x1ebd	(?)

		fread(&start_pos, sizeof(long), 1, fp);	
		fread(&total_len, sizeof(long), 1, fp);
		fseek(fp, 0x60, SEEK_SET);		// ?????
		get_str(block_name, 256, fp);			// protocol name
	//	printf("st = %lx, len = %lx, [%s]\n", start_pos, total_len, buf);
		fseek(fp, start_pos, SEEK_SET);
		fread(&header_len, sizeof(int), 1, fp);
	//	free(buf);
	} else {
		lp_dim->version = VERSION_VB;
		start_pos = 0;
		header_len = intVal;
	}

//printf("header_len = %0x\n", header_len);

//	fread(&header_len, sizeof(int), 1, fp);
	fread(&n_items, sizeof(int), 1, fp);
//	printf("header_len = %x, n_items = %d\n", header_len, n_items);

	for (i = 0; i < n_items; i++) {
		// read header item
		get_str(block_name, 256, fp);
		fread(&len, sizeof(int), 1, fp);
	//	printf("block name = [%s], len = %x\n", block_name, len);
		if (strncmp(block_name, "Config", 256) == 0) {	// Config found
			buf = (char *)malloc(len + 1);
			fread(buf, 1, len, fp);
			buf[len] = 0;
		//	read_config_vd(buf, lp_dim);
			free(buf);
		} else
		if (strncmp(block_name, "Meas", 256) == 0) {	// Meas found
			buf = (char *)malloc(len + 1);
			fread(buf, 1, len, fp);
			buf[len] = 0;
		//	read_meas_text_vd(buf, lp_dim);
			free(buf);
		} else
		if (strncmp(block_name, "MeasYaps", 256) == 0) {	// MeasYaps found
			buf = (char *)malloc(len + 1);
			fread(buf, 1, len, fp);
			buf[len] = 0;
			read_asc_vd(buf, lp_dim);
			dump_meas_text(buf, len, "MeasYaps.txt");
			free(buf);
		} else {
			pos = ftell(fp);
			fseek(fp, pos + len, SEEK_SET);
		}
	}

	pos = start_pos + header_len;
    fseek(fp, pos, SEEK_SET);
printf("start pos = %lx, header_len = %x, current pos = %lx\n", start_pos, header_len, pos);

//printf("after read_asc()\n");
//dump_dims_vd(lp_dim);

read_mdh_vd(fp, &lp_ctr);
lp_dim->nSamples = lp_ctr.nSamples;
printf("after read_mdh()\n");
dump_dims_vd(lp_dim);

//exit(0);

/*
// change below to read from YAPS, instead of mdh ##### 12-11-2018  ####
	switch (lp_dim->version) {
	default :
	case VERSION_VB :
		read_dims_vb(fp, lp_dim);	// read image dims from mdh
		break;
	case VERSION_VD :
		read_dims_vd(fp, lp_dim);
		break;
	}
printf("after read_dims()\n");
dump_dims_vd(lp_dim);

exit(0);
*/
    fseek(fp, pos, SEEK_SET);

	return 0;
}

int
read_asc_vd(char *buf, LP_DIM *lp_dim)
{
    clear_lpdim(lp_dim);

	get_seqname(buf, (char *)&lp_dim->seq_name);
	get_param(buf, "sSliceArray.lSize",         &lp_dim->nSlc,      NO);
	get_param(buf, "sFastImaging.lEPIFactor",   &lp_dim->epifactor, NO);
	get_param(buf, "sFastImaging.lTurboFactor", &lp_dim->turbofactor, NO);
	get_param(buf, "sFastImaging.lSegments",    &lp_dim->segments,  NO);
	get_param(buf, "lAverages",                 &lp_dim->nAcq,      NO);
	get_param(buf, "lRepetitions",				&lp_dim->nRep,      NO);
// read sSliceArray
	get_fparam(buf, "sSliceArray.asSlice[0].dThickness",   &lp_dim->slThick);
	get_fparam(buf, "sSliceArray.asSlice[0].dPhaseFOV",    &lp_dim->phaseFOV);
	get_fparam(buf, "sSliceArray.asSlice[0].dReadoutFOV",  &lp_dim->readFOV);
	get_fparam(buf, "sSliceArray.asSlice[0].sNormal.dCor", &lp_dim->normalCor);
	get_fparam(buf, "sSliceArray.asSlice[0].sNormal.dTra", &lp_dim->normalTra);
	get_fparam(buf, "sSliceArray.asSlice[0].sNormal.dSag", &lp_dim->normalSag);
	get_fparam(buf, "sSliceArray.asSlice[0].dInPlaneRot",  &lp_dim->inplaneRot);
// WiP param
//	get_wip(buf, lp_dim->wip);

// VD/VB
	get_param(buf, "sKSpace.lBaseResolution",		&lp_dim->nSamples,	NO);
	get_param(buf, "sKSpace.lPhaseEncodingLines",	&lp_dim->nLin,	NO);
	get_param(buf, "sKSpace.lPartitions",			&lp_dim->nPar,	NO);
	get_param(buf, "sCoilSelectMeas.aRxCoilSelectData[0].asList.__attribute__.size",
													&lp_dim->nChannels,	NO);  // 
//sKSpace.lBaseResolution	 = 	256
//sKSpace.lPhaseEncodingLines	 = 	256
//sKSpace.lPartitions	 = 	208
//sKSpace.lImagesPerSlab	 = 	176

// adjust index
	lp_dim->nSet = 1;
    lp_dim->nRep += 1;
    lp_dim->nShot = lp_dim->nLin / lp_dim->epifactor;
	if (lp_dim->nShot == 0) lp_dim->nShot = 1;
    lp_dim->nImages = lp_dim->nSlc * lp_dim->nRep * lp_dim->nAcq;

    return 0;
}

BOOL
read_mdh_vd(FILE *fp, LP_CTR *lp_ctr)
{
    sScanHeader		mdh;
    sLoopCounter    *lc;
    int             n = 0;

    n = (int)fread(&mdh, sizeof(sScanHeader), 1, fp);
    if (n < 1) {
		printf("mdh read error\n");
		return YES;
	}

    lc = (sLoopCounter *)&mdh.sLC;

    lp_ctr->mask = mdh.aulEvalInfoMask[0];
    if (lp_ctr->mask & MDH_MASK_EOFM) {
		printf("END_OF_MEAS flag\n");
		return YES; // meas end
	}

    lp_ctr->nSamples  = mdh.ushSamplesInScan;
    lp_ctr->nChannels = mdh.ushUsedChannels;

    lp_ctr->cLin = lc->ushLine;
    lp_ctr->cAcq = lc->ushAcquisition;
    lp_ctr->cSlc = lc->ushSlice;
    lp_ctr->cPar = lc->ushPartition;
    lp_ctr->cEco = lc->ushEcho;
    lp_ctr->cPha = lc->ushPhase;
    lp_ctr->cRep = lc->ushRepetition;
	//
    lp_ctr->cSet = lc->ushSet;
    lp_ctr->cSeg = lc->ushSeg;
    lp_ctr->cIda = lc->ushIda;
    lp_ctr->cIdb = lc->ushIdb;
    lp_ctr->cIdc = lc->ushIdc;
    lp_ctr->cIdd = lc->ushIdd;
    lp_ctr->cIde = lc->ushIde;

    return NO;  // not meas end yet
}

BOOL
read_chh_vd(FILE *fp, LP_CTR *lp_ctr)
{
	sChannelHeader	chh;
	int				n = 0;

    n = (int)fread(&chh, sizeof(sChannelHeader), 1, fp);
    if (n < 1) {
		printf("fread error\n");
		return YES;
	}
//	lp_ctr->cCha = (int)chh.ulChannelId;

	return NO;
}

RecImage *
read_raw_vd(FILE *fp, LP_DIM *lp_dim)
{
	RecImage		*img;
	int				dataLength;
	float			*p, *q;
	RecLoop			*xLp, *yLp, *slcLp, *acqLp, *setLp, *chLp, *repLp;
	RecLoopControl	*lc;

    LP_CTR          lp_ctr;
    float           *buf = NULL;
    int             bytelen;
    int             line, nsample, nchan;
	int				i;
    BOOL            end_of_data;
	BOOL			threeD = NO;

	nsample = lp_dim->nSamples;
	nchan   = lp_dim->nChannels;
	bytelen = nsample * 8;
	buf = (float *)malloc(bytelen);

	// 3D data uses partition (no 3D flag ?)
//	if (lp_dim->nPar > 1) threeD = YES;		// nPar is always > 1 -> find other param
	
    chLp    = [RecLoop loopWithName:@"ch"  dataLength:nchan];
    xLp     = [RecLoop loopWithName:@"kx"  dataLength:nsample];
    yLp     = [RecLoop loopWithName:@"ky"  dataLength:lp_dim->nLin];
	if (threeD) {
		slcLp   = [RecLoop loopWithName:@"kz"  dataLength:lp_dim->nPar];
	} else {
		slcLp   = [RecLoop loopWithName:@"kz"  dataLength:lp_dim->nSlc];
	}
	acqLp   = [RecLoop loopWithName:@"avg" dataLength:lp_dim->nAcq];
    repLp   = [RecLoop loopWithName:@"rep" dataLength:lp_dim->nRep];
    setLp   = [RecLoop loopWithName:@"set" dataLength:lp_dim->nSet];
// make image
	img = [RecImage imageOfType:RECIMAGE_COMPLEX withLoops:yLp, setLp, repLp, acqLp, slcLp, chLp, xLp, nil];
	lc = [img control];
    dataLength = [img dataLength];
// unit
    [img setUnit:REC_FREQ forLoop:xLp];
    [img setUnit:REC_FREQ forLoop:yLp];
    [img setUnit:REC_POS  forLoop:slcLp];    // 2D only, for the moment
// fov
    [xLp   setFov:lp_dim->readFOV];
    [yLp   setFov:lp_dim->phaseFOV];
    [slcLp setFov:lp_dim->slThick * [slcLp dataLength]];

// first line ok (32 ch)
// frame error for second line on ... ####

    [lc rewind];
    for (;;) {
		// VD only
        end_of_data = read_mdh_vd(fp, &lp_ctr);
        if (end_of_data) break;

		for (i = 0; i < nchan; i++) {
			end_of_data = read_chh_vd(fp, &lp_ctr);
			lp_ctr.cCha = i;
			if (fread(buf, bytelen, 1, fp) != 1) break;

			if (lp_ctr.mask & MDH_MASK_PCOR) {
				continue;   // ignore pcorr lines
			}

			line = lp_ctr.cLin;
			if (line < 0 || line >= [yLp dataLength]) {
				printf("line number out of range (%d)\n", line);
				continue;
			}
			[lc setCurrent:lp_ctr.cLin forLoop:yLp];
			if (threeD) {
				[lc setCurrent:lp_ctr.cPar forLoop:slcLp];
			} else {
				[lc setCurrent:lp_ctr.cSlc forLoop:slcLp];
			}
			[lc setCurrent:lp_ctr.cSet forLoop:setLp];
			[lc setCurrent:lp_ctr.cAcq forLoop:acqLp];
			[lc setCurrent:lp_ctr.cRep forLoop:repLp];
			[lc setCurrent:lp_ctr.cCha forLoop:chLp];

			p = [img currentDataWithControl:lc];
			q = p + dataLength;
			// common for VA, VB, VD
			read_line(p, q, buf, nsample, lp_ctr.mask & MDH_MASK_FLIP);
		}
	}
	free(buf);

	[img swapLoop:chLp withLoop:yLp];

    return img;
}

int
read_dims_vd(FILE *fp, LP_DIM *lp_dim)
{
    BOOL    end_of_meas;
    int     bytelen;
    int		nlin, nslc, nacq, nrep, npar, npcorr, nset, nseg, nmdh;
	LP_CTR	lp_ctr;

// find nslice, nacq, nrep
    nlin = nslc = nacq = nrep = npar = 0;
    npcorr = nset = nseg = 0;
    nmdh = 0;

// ### find other way to get this info... too slow for large files
    for (;;) {
        end_of_meas = read_mdh_vd(fp, &lp_ctr);
//printf("lin/slc/acq/rep/par = %d/%d/%d/%d/%d/%d\n", nlin, nslc, nacq, nrep, npar, lp_ctr.cEco);
printf("lin/slc/acq/rep/par/set/seg/nsmp = %d/%d/%d/%d/%d/%d/%d/%d\n",
		lp_ctr.cLin, lp_ctr.cSlc, lp_ctr.cAcq, lp_ctr.cRep, lp_ctr.cPar, lp_ctr.cSet, lp_ctr.cSeg, lp_ctr.nSamples);
        if (end_of_meas) break;

        if (lp_ctr.mask & MDH_MASK_PCOR) {
			npcorr++;
        //    printf("pc line = %d\n", lp_ctr.cLin);
        } else {
			if (lp_ctr.cLin > nlin) nlin = lp_ctr.cLin;
			if (lp_ctr.cSlc > nslc) nslc = lp_ctr.cSlc;
			if (lp_ctr.cAcq > nacq) nacq = lp_ctr.cAcq;
			if (lp_ctr.cRep > nrep) nrep = lp_ctr.cRep;
			if (lp_ctr.cPar > npar) npar = lp_ctr.cPar;
			if (lp_ctr.cSet > npar) nset = lp_ctr.cSet;
			if (lp_ctr.cSeg > npar) nseg = lp_ctr.cSeg;
        }
		lp_dim->nSamples = lp_ctr.nSamples;
		lp_dim->nChannels = lp_ctr.nChannels;

		bytelen = (lp_ctr.nSamples * lp_ctr.nChannels) * 8 + lp_ctr.nChannels * sizeof(sChannelHeader);
        if (fseek(fp, bytelen, SEEK_CUR) < 0) break;

        nmdh++; // number of successfully read mdh records
    }
// largest index -> number
    lp_dim->nLin = nlin + 1;	// sKSpace.lPhaseEncodingLines = 64
    lp_dim->nSlc = nslc + 1;	// sSliceArray.lSize = 1
    lp_dim->nAcq = nacq + 1;	// ??
    lp_dim->nRep = nrep + 1;	// lRepetitions = 3900
    lp_dim->nPar = npar + 1;	// sKSpace.lPartitions = 64 !!!
    lp_dim->nSet = nset + 1;	// ???
    lp_dim->nSeg = nseg + 1;	// sFastImaging.lSegments = 1


    lp_dim->nMDH = nmdh;

// dump
	printf("nLin = %d\n", lp_dim->nLin);
	printf("nSlc = %d\n", lp_dim->nSlc);
	printf("nAcq = %d\n", lp_dim->nAcq);
	printf("nRep = %d\n", lp_dim->nRep);
	printf("nPar = %d\n", lp_dim->nPar);
	printf("nSet = %d\n", lp_dim->nSet);
	printf("nSeg = %d\n", lp_dim->nSeg);

    return 0;
}

// not done yet... just dump
int
read_config_vd(char *buf, LP_DIM *lp_dim)
{
	FILE	*fp;
	int		n = (int)strlen(buf);

	fp = fopen("Meas.Config.txt", "w");
	fwrite(buf, n, 1, fp);
	fclose(fp);

	return 0;
}

void
dump_meas_text(char *buf, int len, char *path)
{
	FILE	*fp;

	fp = fopen(path, "w");
	fwrite(buf, len, 1, fp);
	fclose(fp);
}

