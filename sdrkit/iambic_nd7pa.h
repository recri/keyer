/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.

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

#ifndef IAMBIC_ND7PA_H
/*
* newkeyer.c  an electronic keyer with programmable outputs 
* Copyright (C) 2012 Roger L. Traylor   
* 
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
* 
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
* 
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// newkeyer.c    
// R. Traylor
// 3.19.2012
// iambic keyer      

//#define F_CPU 8000000UL     //8Mhz clock
//#include <util/delay.h>
//#include <avr/io.h>
//#include <avr/interrupt.h>
//#include <avr/eeprom.h>

class iambic_nd7pa {
  //main keyer state machine states
  static const int IDLE =     0;  //waiting for a paddle closure 
  static const int DIT =      1;  //making a dit 
  static const int DAH =      2;  //making a dah  
  static const int DIT_DLY =  3;  //intersymbol delay, one dot time
  static const int DAH_DLY =  4;  //intersymbol delay, one dot time
  static const int TUNE =     5;  //tune state...added after article to allow tuning
  //
  static const int FALSE =    0;
  static const int TRUE =     1;
  //

  //define EEPROM storage areas
  // uint8_t EEMEM eeprom_wds_per_min = 20;    //this value only assigned during programming

  int keyer_state   = IDLE;   //the keyer state 
  int timer_ena     = 0;      //the timer enable 
  int dit_pending   = FALSE;  //memory for dits  
  int dah_pending   = FALSE;  //memory for dahs  
  int timeout       ;         //one dot interval  
  int half_timeout  ;         //one half dot interval 
  int key           = FALSE;  //internal keyer output 
  int ee_wait_cnt   = -1;     //countdown to save new setting to eeprom
  int wds_per_min   = 20;     //words per minute (still need to intalize if in EEPROM?)

  //output state machine states 
  // static const int IDLE =   0;  // redefines the previous definition of IDLE
  static const int A =      1;  //
  static const int B =      2;  //
  static const int C =      3;  //
  static const int D =      4;  //
  static const int E =      5;  //
  static const int F =      6;  //
  static const int G =      7;  //
  static const int H =      8;  //
  static const int I =      9;  //

  //output state machine variables
  int output_state     = IDLE;
  int tx_dly           = 0x00;
  int mute1_timeout    =    4;			//500uS for audio mute to engage
  int relay_timeout    =   31;			//4mS for relay to actuate
  int tx_decay         =   65;			//5mS for xmit envelope to decay

  int key_in	       =    0;
  int key_out	       =    0;

  static const int DIT_BIT = 1;
  static const int DAH_BIT = 2;

  //functions
  void    tx_on()  { key_out = 1;}		//asserts key output (active high)
  void    tx_off() { key_out = 0;}		//deasserts key output
  int dit_on() { return(key_in&DIT_BIT); }	//returns non-zero if dit paddle on 
  int dah_on() { return(key_in&DAH_BIT); }	//returns non-zero if dah paddle on 


  /*****************************  mute1  ****************************************/
  int mute1_state = 0;
  //mute 1 is active low
  void mute1(state) { mute1_state = state; }

  /******************************************************************************/

  /****************************  mute2  *****************************************/
  
  int mute2_state = 0;
  void mute2(state) { mute2_state = state; }

  /******************************************************************************/

  //*****************************************************************************/
  //                  Interrupt service routine for timer 0 
  //worst case is about 18uS to run ISR

  int clock(int raw_dit_on, int raw_dah_on, int ticks) {

    static uint16_t timer;

    timer--;  //decrement clock 

    //keyer main state machine   
    switch(keyer_state){ //see if user changed the minutes setting
    case (IDLE) : 
      key = FALSE;
      if      (bit_is_clear(PINC,5)){       keyer_state = TUNE;}
      else if (dit_on()){timer = timeout;   keyer_state = DIT; }
      else if (dah_on()){timer = timeout*3; keyer_state = DAH; }       
      break;
    case (TUNE):  //this state added to allow for a transmitter tuning state
      key = TRUE;
      if(bit_is_set(PINC,5)){keyer_state = IDLE;}
      break;
    case (DIT) :
      key = TRUE; 
      if(!timer){timer = timeout; keyer_state = DIT_DLY;}  
      break;
    case (DAH) : 
      key = TRUE; 
      if(!timer){timer = timeout; keyer_state = DAH_DLY;}  
      break;
    case (DIT_DLY) :
      key = FALSE;  
      if(!timer){
        if(dah_pending == TRUE) {timer=timeout*3; keyer_state = DAH;}
        else                    {keyer_state = IDLE;}
      }
      break; 
    case (DAH_DLY) : 
      key = FALSE; 
      if(!timer){
        if(dit_pending == TRUE) {timer=timeout; keyer_state = DIT;}
        else                    {keyer_state = IDLE;}
      }
      break; 
    }//switch keyer state

    //*****************  dit pending main state machine   *********************
    switch(dit_pending){ //see if a dot is pending 
    case (FALSE) : 
      if( (dit_on() && (keyer_state == DAH)     & (timer < timeout / 3))   ||
          (dit_on() && (keyer_state == DAH_DLY) & (timer > half_timeout))) 
        { dit_pending = TRUE;}
      break;
    case (TRUE) : 
      if(keyer_state == DIT){dit_pending = FALSE;}
      break;
    }//switch dit_pending
         
    //******************  dah pending main state machine   *********************
    switch(dah_pending){ //see if a dah is pending 
    case (FALSE) : 
      if( (dah_on() && (keyer_state == DIT)     & (timer < half_timeout))  ||
          (dah_on() && (keyer_state == DIT_DLY) & (timer > half_timeout)))
	{dah_pending = TRUE;}
      break;
    case (TRUE) : 
      if(keyer_state == DAH){dah_pending = FALSE;}
      break;
    }//switch dah_pending


    //****************** state machine for the output sequencer *********
    tx_dly--;  //decrement the delay counter for the output sequencer
    switch(output_state){ 
    case (IDLE) : 
      if(key==TRUE){ tx_dly = mute1_timeout; output_state=A;} //delay from mute1 to relay on
      break; 
    case (A) : mute1(TRUE); 
      if(!tx_dly){tx_dly=relay_timeout; output_state=B;} //delay from mute2 to relay on
      break; 
    case (B) : mute2(TRUE); 
      if(!tx_dly){output_state=C;} //wait for relay
      break; 
    case (C) : if(key==FALSE){tx_dly=mute1_timeout+relay_timeout+1; output_state=D;} //equalize key low 
      else{tx_on(); TCCR2B = (1<<CS22) | (1<<CS20);}  //tx_on and sidetone on 
      break;
    case (D) : if(!tx_dly){tx_dly=tx_decay; output_state=E;}  
      break;
    case (E) : tx_off(); TCCR2B = 0x00;  //tx off and sidetone off 
      if(!tx_dly){tx_dly=mute1_timeout; output_state = F;}
      break; 
    case (F) : mute2(FALSE);
      if(!tx_dly){output_state=G;}//let transmitter die out 
      break;
    case (G) : mute1(FALSE); 
      output_state = IDLE;   //unmute audio
      break; 
    }//switch output state  

  }


  //****************************  main code loop  ********************************
  int main(void) { 
    setup();   //do setup of timers, ports interrupts
    tx_off();  //make sure xmitter is off
    while(1){  //spin forever and update dot period blindly
      timeout = (9375/wds_per_min); //1 dot time = ((1200/wds_per_min)*1000)/128
      half_timeout = (timeout >> 1);
    } //do forever
  }//main
};

