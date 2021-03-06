/**************************************************************************
 *
 *	XVID MPEG-4 VIDEO CODEC
 *	8bit<->16bit transfer
 *
 *	This program is an implementation of a part of one or more MPEG-4
 *	Video tools as specified in ISO/IEC 14496-2 standard.  Those intending
 *	to use this software module in hardware or software products are
 *	advised that its use may infringe existing patents or copyrights, and
 *	any such use would be at such party's own risk.  The original
 *	developer of this software module and his/her company, and subsequent
 *	editors and their companies, will have no liability for use of this
 *	software or modifications or derivatives thereof.
 *
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; either version 2 of the License, or
 *	(at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program; if not, write to the Free Software
 *	Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 *************************************************************************/

/**************************************************************************
 *
 *	History:
 *
 *	07.01.2002	merge functions from compensate; rename functions
 *	22.12.2001	transfer_8to8add16 limit fix
 *	07.11.2001	initial version; (c)2001 peter ross <pross@cs.rmit.edu.au>
 *
 *************************************************************************/

#include "global.h"
#include "mem_transfer.h"

void
transfer_8to16copy(int16 * const dst, const uint8 * const src,
                   xint stride)
{
    uint32  i, j;

    for (j = 0; j < 8; j++)
    {
        for (i = 0; i < 8; i++)
        {
            dst[j * 8 + i] = (int16) src[j * stride + i];
        }
    }
}

void
transfer_16to8copy(uint8 * const dst, const int16 * const src,
                   xint stride)
{
    uint32  j;
	
    for (j = 0; j < 8; j++)
    {
		int16 pixel;
		int dstIdx = j * stride;
		int srcIdx = j * 8;

		pixel = src[srcIdx];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx] = (uint8) pixel;

		pixel = src[srcIdx+1];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx+1] = (uint8) pixel;

		pixel = src[srcIdx+2];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx+2] = (uint8) pixel;

		pixel = src[srcIdx+3];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx+3] = (uint8) pixel;

		pixel = src[srcIdx+4];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx+4] = (uint8) pixel;

		pixel = src[srcIdx+5];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx+5] = (uint8) pixel;

		pixel = src[srcIdx+6];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx+6] = (uint8) pixel;

		pixel = src[srcIdx+7];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx+7] = (uint8) pixel;
    }
}

/*
  perform motion compensation (and 8bit->16bit dct transfer)
*/
void
transfer_8to16sub(int16 * const dct,
                  uint8 * const cur, const uint8 * ref, xint stride)
{
    uint32  i, j;

    for (j = 0; j < 8; j++)
    {
        for (i = 0; i < 8; i++)
        {
            uint8   c = cur[j * stride + i];
            uint8   r = ref[j * stride + i];
            cur[j * stride + i] = r;
            dct[j * 8 + i] = (int16) c - (int16) r;
        }
    }
}

void
transfer_16to8add(uint8 * const dst, const int16 * const src,
                  xint stride)
{
    uint32 j;

    for (j = 0; j < 8; j++)
    {
		int dstIdx = j * stride;
		int srcIdx = j * 8;

		int16 pixel;
		pixel = (int16) dst[dstIdx] + src[srcIdx];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx] = (uint8) pixel;

		pixel = (int16) dst[dstIdx + 1] + src[srcIdx + 1];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx + 1] = (uint8) pixel;

		pixel = (int16) dst[dstIdx + 2] + src[srcIdx + 2];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx + 2] = (uint8) pixel;

		pixel = (int16) dst[dstIdx + 3] + src[srcIdx + 3];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx + 3] = (uint8) pixel;

		pixel = (int16) dst[dstIdx + 4] + src[srcIdx + 4];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx + 4] = (uint8) pixel;

		pixel = (int16) dst[dstIdx + 5] + src[srcIdx + 5];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx + 5] = (uint8) pixel;

		pixel = (int16) dst[dstIdx + 6] + src[srcIdx + 6];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx + 6] = (uint8) pixel;

		pixel = (int16) dst[dstIdx + 7] + src[srcIdx + 6];
		pixel = (pixel < 0 ? 0 : (pixel > 255 ? 255 : pixel));
        dst[dstIdx + 7] = (uint8) pixel;
    }
}
void
transfer8x8_copy(uint8 * const dst, const uint8 * const src,
                 xint stride)
{
    uint32 j;
    for (j = 0; j < 8; j++)
    {
		int idx = j * stride;
		dst[idx] = src[idx];
		dst[idx + 1] = src[idx + 1];
		dst[idx + 2] = src[idx + 2];
		dst[idx + 3] = src[idx + 3];
		dst[idx + 4] = src[idx + 4];
		dst[idx + 5] = src[idx + 5];
		dst[idx + 6] = src[idx + 6];
		dst[idx + 7] = src[idx + 7];
    }
}
