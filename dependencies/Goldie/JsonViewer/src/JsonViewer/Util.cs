/*
This file is licensed under The zlib/libpng License:
-----------------------------------------------------

Copyright (c) 2009 Nick Sabalausky

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
    claim that you wrote the original software. If you use this software
    in a product, an acknowledgment in the product documentation would be
    appreciated but is not required.

    2. Altered source versions must be plainly marked as such, and must not be
    misrepresented as being the original software.

    3. This notice may not be removed or altered from any source
    distribution.
*/

using System;

namespace SemiTwist.Util
{
    static class Util
    {
        public static double Lerp(double fromVal,
                                  double fromA, double fromB,
                                  double toA, double toB)
        {
            return toA + (fromVal - fromA) * ((toB-toA) / (fromB-fromA));
        }

        public static double DeNormalize(double fromVal, double toA, double toB)
        {
            return Lerp(fromVal, 0, 1, toA, toB);
        }

        public static double Normalize(double fromVal, double fromA, double fromB)
        {
            return Lerp(fromVal, fromA, fromB, 0, 1);
        }

        public static void ClampRange(ref int start, ref int length, int min, int max)
        {
            if(start < 0)
            {
                length -= 0-start;
                start = 0;
            }

            if(start > max)
                start = max;

            if(start+length > max)
                length = (max+1) - start;

            if(length < 0)
                length = 0;
        }

        public static int CountCrNl(string str, int start, int length)
        {
            int count=0; // Number of "\r\n"
            char prevChar='X'; // Doesn't really matter, anything but \r
            for(int i=start; i<str.Length && i<(start+length); i++)
            {
                if(str[i]=='\n' && prevChar=='\r')
                    count++;

                prevChar = str[i];
            }
            return count;
        }

        public static int CountMissingCrNl(string rawText, string bakedText, int bakedPos)
        {
            int rawIndex=0;
            int bakedIndex=0;
            while(bakedIndex < bakedPos)
            {
                if(bakedText[bakedIndex] != rawText[rawIndex])
                {
                    if((bakedText[bakedIndex] != '\n')           ||
                        ("\r\n".IndexOf(rawText[rawIndex]) == -1))
                    {
                        throw new ArgumentException("rawText and bakedText differ in more than just newlines");
                    }

                    if(rawText[rawIndex] == '\r')
                        rawIndex++;
                }
                rawIndex++;
                bakedIndex++;
            }
            return rawIndex - bakedIndex;
        }
    }
}
