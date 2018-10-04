/*
  Copyright (C) 2018 by Roger E Critchlow Jr, Charlestown, MA, USA.

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
*/
#ifndef Config_h
#define Config_h 1

/*
  these defines specify values which must be supplied for the rest
  of the code to work.  If you don't want the values supplied here,
  then you should define different values before this header is included.
*/

/*
  this define controls whether the sketch flashes the LED while it runs.
*/
#ifndef FLASH_LED
#define FLASH_LED 0
#endif

/*
  this define specifies the number of averaging steps taken in hardware
  valid from 0 to 31, it takes repeated samples and adds them together so
  it increases the time taken to scan the set of touch pads.  It takes
  about 100usec to scan two pads with no averaging on a Teensy LC.
*/
#ifndef HARDWARE_AVERAGING
#define HARDWARE_AVERAGING 1
#endif

/*
  this defines the degree of exponential averaging applied to the raw touch
  measurements, this smooths
*/
#ifndef EXPONENTIAL_AVERAGING
#define EXPONENTIAL_AVERAGING 1
#endif

/*
  this define specifies the the normalized threshold used to distinguish touched
  and non-touched
*/
#ifndef TOUCH_THRESHOLD
#define TOUCH_THRESHOLD 0x40
#endif

/*
  these define the common touch pins for Teensy's with
  touch sense interfaces, 3.0, 3.1, 3.2, 3.6 and LC.
*/
#define COMMON_NPADS		9
#define COMMON_PADS		0, 1, 15, 16, 17, 18, 19, 22, 23

/*
  these define the common touch pins when I2S is required.
  i2s also uses pins 9 and 13.
*/
#define COMMON_NOI2S_NPADS	7
#define COMMON_NOI2S_PADS	0, 1, 15, 16, 17, 18, 19

/*
  these defines specify the maximum touch pads available
  on each Teensy 3 variant.  these should be overridden
  before Config.h is included to change the pads or their
  order.
*/
#ifndef PADS
#if defined(__MK20DX128__) || defined(__MK20DX256__)        // Teensy 3.0/3.1/3.2 touch pins
#define NPADS 12
#define PADS 0, 1, 15, 16, 17, 18, 19, 22, 23, 25, 32, 33
#elif defined(__MK66FX1M0__)                                // Teensy 3.6 touch pins
#define NPADS 11
#define PADS 0, 1, 15, 16, 17, 18, 19, 22, 23, 29, 30
#elif defined(__MKL26Z64__)                                 // Teensy LC touch pins
#define NPADS 11
#define PADS 0, 1, 3, 4, 15, 16, 17, 18, 19, 22, 23
#else
#error "no default Touch PADS definition for the current processor"
#endif
#endif

#endif // config_h

