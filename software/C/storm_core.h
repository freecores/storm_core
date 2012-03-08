#ifndef storm_core_h
#define storm_core_h

////////////////////////////////////////////////////////////////////////////////
// storm_core.h - STORM Core internal definitions
//
// Created by Stephan Nolting (stnolting@googlemail.com)
// http://www.opencores.com/project,storm_core
// Last modified 08. Mar. 2012
////////////////////////////////////////////////////////////////////////////////

/* Internal System Coprocessor Register Set */
#define SYS_CP     15 // system coprocessor #
#define ID_REG_0    0 // ID register 0
#define ID_REG_1    1 // ID register 1
#define ID_REG_2    2 // ID register 2
#define SYS_CTRL_0  6 // system control register 0
#define CSTAT       8 // cache statistics register
#define ADR_FB      9 // adr feedback from bus unit -> for exception handling
#define LFSR_POLY  11 // Internal LFSR, polynomial
#define LFSR_DATA  12 // Internal LFSR, shift register
#define SYS_IO     13 // System IO ports

/* CP_SYS_CTRL_0 */
#define DC_FLUSH   0 // flush d-cache
#define DC_CLEAR   1 // clear d-cache
#define IC_CLEAR   2 // flush i-cache
#define DC_WTHRU   3 // cache write-thru enable
#define DC_AUTOPR  4 // auto pre-reload d-cache page
#define IC_AUTOPR  5 // auto pre-reload i-cache page
#define LFSR_EN   13 // enable lfsr
#define LFSR_M    14 // lfsr update mode
#define LFSR_D    15 // lfsr shift direction
#define MBC_0     16 // max bus cycle length bit 0
#define MBC_LSB   16
#define MBC_15    31 // max bus cycle length bit 15
#define MBC_MSB   31

#endif // storm_core_h
