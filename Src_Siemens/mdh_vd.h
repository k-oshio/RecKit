/*---------------------------------------------------------------------------*/
/*  Copyright (C) Siemens AG 1998  All Rights Reserved.  Confidential        */
/*---------------------------------------------------------------------------*/
/*
 * Project: NUMARIS/4
 *    File: \n4_servers1\pkg\MrServers\MrMeasSrv\SeqIF\MDH\mdh.h
 * Version:
 *  Author: CC_MEAS SCHOSTZF
 *    Date: n.a.
 *
 *    Lang: C
 *
 * Descrip: measurement data header
 *
 *---------------------------------------------------------------------------*/

/*--------------------------------------------------------------------------*/
/* Include control                                                          */
/*--------------------------------------------------------------------------*/
#ifndef MDH_H
#define MDH_H

/*--------------------------------------------------------------------------*/
/* Include MR basic type definitions                                        */
/*--------------------------------------------------------------------------*/
#include "MrCommon/MrGlobalDefinitions/MrBasicTypes.h"

/*--------------------------------------------------------------------------*/
/*  Definition of header parameters                                         */
/*--------------------------------------------------------------------------*/
#define MDH_NUMBEROFEVALINFOMASK   2
#define MDH_NUMBEROFICEPROGRAMPARA 24

/*--------------------------------------------------------------------------*/
/*  Definition of free header parameters (short)                            */
/*--------------------------------------------------------------------------*/
#define MDH_RESERVEDHDRPARA  (4)

/*--------------------------------------------------------------------------*/
/* Definition of time stamp tick interval/frequency                         */
/* (used for ulTimeStamp and ulPMUTimeStamp                                 */
/*--------------------------------------------------------------------------*/
#define RXU_TIMER_INTERVAL  (2500000)     /* data header timer interval [ns]*/
#define RXU_TIMER_FREQUENCY (400)         /* data header timer frequency[Hz]*/

/*--------------------------------------------------------------------------*/
/*  Definition of bit masks for ulFlagsAndDMALength field                   */
/*--------------------------------------------------------------------------*/
#define MDH_DMA_LENGTH_MASK   (0x01FFFFFFL)
#define MDH_PACK_BIT_MASK     (0x02000000L)
#define MDH_ENABLE_FLAGS_MASK (0xFC000000L)

/*--------------------------------------------------------------------------*/
/* Definition of loop counter structure                                     */
/* Note: any changes of this structure affect the corresponding swapping    */
/*       method of the measurement data header proxy class (MdhProxy)       */
/*--------------------------------------------------------------------------*/
#include "MrServers/MrVista/include/pack.h"

/// \ingroup MDH
/// \todo write documentation 
/// \brief Definition of loop counter structure
typedef struct
{
  PACKED_MEMBER( uint16_t,  ushLine         ); /**< line index                   */
  PACKED_MEMBER( uint16_t,  ushAcquisition  ); /**< acquisition index            */
  PACKED_MEMBER( uint16_t,  ushSlice        ); /**< slice index                  */
  PACKED_MEMBER( uint16_t,  ushPartition    ); /**< partition index              */
  PACKED_MEMBER( uint16_t,  ushEcho         ); /**< echo index                   */
  PACKED_MEMBER( uint16_t,  ushPhase        ); /**< phase index                  */
  PACKED_MEMBER( uint16_t,  ushRepetition   ); /**< measurement repeat index     */
  PACKED_MEMBER( uint16_t,  ushSet          ); /**< set index                    */
  PACKED_MEMBER( uint16_t,  ushSeg          ); /**< segment index  (for TSE)     */
  PACKED_MEMBER( uint16_t,  ushIda          ); /**< IceDimension a index         */
  PACKED_MEMBER( uint16_t,  ushIdb          ); /**< IceDimension b index         */
  PACKED_MEMBER( uint16_t,  ushIdc          ); /**< IceDimension c index         */
  PACKED_MEMBER( uint16_t,  ushIdd          ); /**< IceDimension d index         */
  PACKED_MEMBER( uint16_t,  ushIde          ); /**< IceDimension e index         */
} sLoopCounter;                                /* sizeof : 28 byte             */

/*--------------------------------------------------------------------------*/
/*  Definition of slice vectors                                             */
/*--------------------------------------------------------------------------*/

/// \ingroup MDH
/// \todo write documentation 
/// \brief Definition of slice vectors 
typedef struct
{
  PACKED_MEMBER( float,  flSag          );
  PACKED_MEMBER( float,  flCor          );
  PACKED_MEMBER( float,  flTra          );
} sVector; /* 12 bytes */

/// \ingroup MDH
/// \todo write documentation 
/// \brief Definition of slice data structure
typedef struct
{
  PACKED_STRUCT( sVector,         sSlicePosVec     ); /**< slice position vector        */
  PACKED_MEMBER( float,           aflQuaternion[4] ); /**< rotation matrix as quaternion*/
} sSliceData;                                         /* sizeof : 28 byte             */

/*--------------------------------------------------------------------------*/
/*  Definition of cut-off data                                              */
/*--------------------------------------------------------------------------*/
/// \ingroup MDH
/// \todo write documentation 
/// \brief Definition of cut-off data
typedef struct
{
  PACKED_MEMBER( uint16_t,  ushPre          );    /**< write ushPre zeros at line start */
  PACKED_MEMBER( uint16_t,  ushPost         );    /**< write ushPost zeros at line end  */
} sCutOffData; /* 4 bytes */


/*--------------------------------------------------------------------------*/
/*  Definition of measurement data header                                   */
/*--------------------------------------------------------------------------*/
/// \ingroup MDH
/// \todo write documentation 
/// \brief Definition of the scan header structure
typedef struct sScanHeader
{
  PACKED_MEMBER( uint32_t,     ulFlagsAndDMALength           );                 ///<  0: ( 4) bit  0..24: DMA length [bytes]
                                                                                ///<          bit     25: pack bit
                                                                                ///<          bit 26..31: pci_rx enable flags
  PACKED_MEMBER( int32_t,      lMeasUID                      );                 ///<  4: ( 4) measurement user ID
  PACKED_MEMBER( uint32_t,     ulScanCounter                 );                 ///<  8: ( 4) scan counter [1...]
  PACKED_MEMBER( uint32_t,     ulTimeStamp                   );                 ///< 12: ( 4) time stamp [2.5 ms ticks since 00:00]
  PACKED_MEMBER( uint32_t,     ulPMUTimeStamp                );                 ///< 16: ( 4) PMU time stamp [2.5 ms ticks since last trigger]
  PACKED_MEMBER( uint16_t,     ushSystemType                 );                 ///< 20: ( 2) System type (todo: values?? ####)
  PACKED_MEMBER( uint16_t,     ulPTABPosDelay                );                 ///< 22: ( 2) PTAb delay ??? TODO: How do we handle this ####
  PACKED_MEMBER( int32_t,	     lPTABPosX                     );                 ///< 24: ( 4) absolute PTAB position in [µm]
  PACKED_MEMBER( int32_t,	     lPTABPosY                     );                 ///< 28: ( 4) absolute PTAB position in [µm]
  PACKED_MEMBER( int32_t,	     lPTABPosZ                     );                 ///< 32: ( 4) absolute PTAB position in [µm]
  PACKED_MEMBER( uint32_t,	   ulReserved1                   );                 ///< 36: ( 4) reserved for future hardware signals
  PACKED_MEMBER( uint32_t,     aulEvalInfoMask[MDH_NUMBEROFEVALINFOMASK]);      ///< 40: ( 8) evaluation info mask field
  PACKED_MEMBER( uint16_t,     ushSamplesInScan              );                 ///< 48: ( 2) # of samples acquired in scan
  PACKED_MEMBER( uint16_t,     ushUsedChannels               );                 ///< 50: ( 2) # of channels used in scan
  PACKED_STRUCT( sLoopCounter, sLC                           );                 ///< 52: (28) loop counters
  PACKED_STRUCT( sCutOffData,  sCutOff                       );                 ///< 80: ( 4) cut-off values
  PACKED_MEMBER( uint16_t,     ushKSpaceCentreColumn         );                 ///< 84: ( 2) centre of echo
  PACKED_MEMBER( uint16_t,     ushCoilSelect                 );                 ///< 86: ( 2) Bit 0..3: CoilSelect
  PACKED_MEMBER( float,        fReadOutOffcentre             );                 ///< 88: ( 4) ReadOut offcenter value
  PACKED_MEMBER( uint32_t,     ulTimeSinceLastRF             );                 ///< 92: ( 4) Sequence time stamp since last RF pulse
  PACKED_MEMBER( uint16_t,     ushKSpaceCentreLineNo         );                 ///< 96: ( 2) number of K-space centre line
  PACKED_MEMBER( uint16_t,     ushKSpaceCentrePartitionNo    );                 ///< 98: ( 2) number of K-space centre partition
  PACKED_STRUCT( sSliceData,   sSD                           );                 ///< 100:(28) Slice Data
  PACKED_MEMBER( uint16_t,     aushIceProgramPara[MDH_NUMBEROFICEPROGRAMPARA] );///< 128:(48) free parameter for IceProgram
  PACKED_MEMBER( uint16_t,     aushReservedPara[MDH_RESERVEDHDRPARA] );         ///< 176:( 8) unused parameter (padding to next 192byte alignment )
                                                                                ///<          NOTE: These parameters MUST NOT be used by any application (for future use)
  PACKED_MEMBER( uint16_t,     ushApplicationCounter         );                 ///< 184 ( 2)
  PACKED_MEMBER( uint16_t,     ushApplicationMask            );                 ///< 186 ( 2)
  PACKED_MEMBER( uint32_t,     ulCRC                         );                 ///< 188:( 4) CRC 32 checksum
} sScanHeader;                                                                  // total length: 6 x 32 Byte (192 Byte)

/*--------------------------------------------------------------------------*/
/*  Definition of channel data header                                   */
/*--------------------------------------------------------------------------*/
/// \ingroup MDH
/// \todo write documentation 
/// \brief Definition of the scan header structure
typedef struct sChannelHeader
{
  PACKED_MEMBER( uint32_t,     ulTypeAndChannelLength        );    ///< 0: (4) bit  0.. 7: type (0x02 => ChannelHeader)
                                                                   ///<        bit  8..31: channel length (header+data) in byte
                                                                   ///<        type   := ulTypeAndChannelLength & 0x000000FF
                                                                   ///<        length := ulTypeAndChannelLength >> 8
  PACKED_MEMBER( int32_t,      lMeasUID                      );    ///< 4: (4) measurement user ID
  PACKED_MEMBER( uint32_t,     ulScanCounter                 );    ///< 8: (4) scan counter [1...]
  PACKED_MEMBER( uint32_t,     ulReserved1                   );    ///< 12:(4) reserved
  PACKED_MEMBER( uint32_t,     ulSequenceTime                );    ///< 16:(4) Sequence readout starting time bit 31..9 time in [10us]
                                                                   ///<                                       bit  8..0 time in [25ns]
  PACKED_MEMBER( uint32_t,     ulUnused2                     );    ///< 20:(4) unused
  PACKED_MEMBER( uint16_t,     ulChannelId                   );    ///< 24:(4) unused
  PACKED_MEMBER( uint16_t,     ulUnused3                     );    ///< 26:(2) unused
  PACKED_MEMBER( uint32_t,     ulCRC                         );    ///< 28:(4) CRC32 checksum of channel header
} sChannelHeader;                                                  // total length:  32 byte

#include "MrServers/MrVista/include/unpack.h"

#endif   /* MDH_H */

/*---------------------------------------------------------------------------*/
/*  Copyright (C) Siemens AG 1998  All Rights Reserved.  Confidential        */
/*---------------------------------------------------------------------------*/
