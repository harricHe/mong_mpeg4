/* ///////////////////////////////////////////////////////////////////////// */
/*   File:  : bilinear8x8.c                                                  */
/*   Author : Chun-Jen Tsai                                                  */
/*   Date   : Feb/03/2003                                                    */
/* ------------------------------------------------------------------------- */
/*   MPEG-4 half-pel interpolation functions.                                */
/*   Copyright, 2003.                                                        */
/*   Multimedia Embedded Systems Lab.                                        */
/*   Department of Computer Science and Information engineering              */
/*   National Chiao Tung University, Hsinchu 300, Taiwan                     */
/* ///////////////////////////////////////////////////////////////////////// */

#include "metypes.h"
#include "bilinear8x8.h"

#define USE_HW_MC 1

#if USE_HW_MC
volatile int *reg_a  = (int *) 0xb0000000;
volatile int *reg_b  = (int *) 0xb0000004;
volatile int *reg_c  = (int *) 0xb0000008;
volatile int *reg_d  = (int *) 0xb000000c;
volatile int *reg_r  = (int *) 0xb0000010;
volatile int *mc_2pt = (int *) 0xb0000014;
volatile int *mc_4pt = (int *) 0xb0000018;
#endif

void
halfpel8x8_h(uint8 * dst, uint8 * src, xint stride, xint rounding)
{
    xint    row, col, idx;

    idx = 0;
    for (row = 0; row < (stride << 3); idx = (row += stride))
    {
        for (col = 0; col < 8; col++, idx++)
        {
#if USE_HW_MC
            *reg_a = (xint) src[idx];
            *reg_b = (xint) src[idx+1];
            *reg_r = (xint) rounding;
            dst[idx] = (uint8) (*mc_2pt);
#else
            xint sum = (xint) src[idx] + src[idx + 1] + 1 - rounding;
            dst[idx] = (uint8) (sum >> 1);
#endif
        }
    }
}

void
halfpel8x8_v(uint8 * dst, uint8 * src, xint stride, xint rounding)
{
    xint    row, col, idx;

    idx = 0;
    for (row = 0; row < (stride << 3); idx = (row += stride))
    {
        for (col = 0; col < 8; col++, idx++)
        {
#if HW_MC
            *reg_a = (xint) src[idx];
            *reg_b = (xint) src[idx+stride];
            *reg_r = (xint) rounding;
            dst[idx] = (uint8) (*mc_2pt);
#else
            xint sum = (xint) src[idx] + src[idx + stride] + 1 - rounding;
            dst[idx] = (uint8) (sum >> 1);
#endif
        }
    }
}

void
halfpel8x8_hv(uint8 * dst, uint8 * src, xint stride, xint rounding)
{
    xint    row, col, idx;

    idx = 0;
    for (row = 0; row < (stride << 3); idx = (row += stride))
    {
        for (col = 0; col < 8; col++, idx++)
        {
#if USE_HW_MC
            *reg_a = (xint) src[idx];
            *reg_b = (xint) src[idx+1];
            *reg_c = (xint) src[idx+stride];
            *reg_d = (xint) src[idx+stride+1];
            *reg_r = (xint) rounding;
            dst[idx] = (uint8) (*mc_4pt);
#else
            xint sum = (xint) src[idx] + (xint) src[idx + 1] +
                (xint) src[idx + stride] + (xint) src[idx + stride + 1];
            dst[idx] = (uint8) ((sum + 2 - rounding) >> 2);
#endif
        }
    }
}
