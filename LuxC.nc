#include "Timer.h"
#include "antitheft.h"
#include "Serial.h"

module LuxC @safe()
{
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as Timer1;
  uses interface Timer<TMilli> as Timer2;
  uses interface Read<uint16_t>;
  uses interface Leds;
  uses interface Boot;
  uses interface SplitControl as AMControl;
  uses interface Packet;
  uses interface AMSend;
}

implementation
{
  
  int theft=0;
  uint16_t hr_counter = 0;
  
  /**We declare a radio buffer variable*/
  message_t packet;
  
  bool locked; /**acts like a MUTEX*/
  
  uint16_t sensor_val;
  uint16_t lux;
  uint8_t lux_hi[12];
  uint8_t lux_low[12];
  
  event void Boot.booted()
  {
    call Timer0.startPeriodic(100);
    call Timer1.startPeriodic(500);
    call Timer2.startPeriodic(1000);
    call AMControl.start();
  }
  
  /**Once the radio is initialized, an event is triggered indicating the success
   or failure of the action*/
  event void AMControl.startDone(error_t err) {
    /**if the radio was successfully initialized err==SUCCESS*/
    if (err == SUCCESS) {
      /** Do nothing */
    }
    else {
      /**Else, we try again to initialize the radio*/
      call AMControl.start();
    }
  }
  
  /**THis event is called when the radio is stopped*/
  event void AMControl.stopDone(error_t err) {
    // do nothing
  }

  
  event void Timer2.fired()
  {
    hr_counter += 1;
  }
  
  /** Check value of sensor */
  event void Timer0.fired()
  {
    call  Read.read();
  }

  /** Convert sensor value to Lux */
  event void Read.readDone(error_t error, uint16_t value)
  {
    sensor_val = value;
    lux = ((float)sensor_val/4069.0*1.5)* 0.769*1000*148.41315910257660342111558;
    //lux = 13877;
    //lux_hi = ((lux >> 8) & 0xff);
    //lux_low = ((lux >> 0) & 0xff);
    
    if (hr_counter % 60 == 0 && hr_counter <= 720) {
      lux_hi[(hr_counter/60) - 1] = ((lux >> 8) & 0xff);
      lux_low[(hr_counter/60) - 1] = ((lux >> 0) & 0xff);
    }
    
    if(error==SUCCESS)
    {
      call Leds.led2On();
      }
    else
      {
	call Leds.led2Off();
	
	}
  }

  
  /** Sends Lux value to serial */
  event void Timer1.fired()
  {
     if (hr_counter > 720) {
       call Leds.led1Toggle();
      dbg("AntitheftC", "AntitheftC: Stolen.\n", theft);
      /**if we are locked, i.e message being transmitted, we do nothing*/
      if (locked) {
	return;
      }
      else { /**else, we send a packet via serial*/
	/**First we acquire the network/radio buffer to write the contents of our message*/
	radio_stolen_msg_t* rcm = (radio_stolen_msg_t*)call Packet.getPayload(&packet, sizeof(radio_stolen_msg_t));
	/**if the reserved region of memory is not valid we return (abort the operation)*/
	if (rcm == NULL) {
	  return;
	}
	/**Otherwise, we write our message to the buffer*/
	strcpy((char*)rcm->first, "444");
	strcpy((char*)rcm->lux_hi, lux_hi);
	strcpy((char*)rcm->lux_low, lux_low);
	//rcm->lux_hi = lux_hi;
	//rcm->lux_low = lux_low;
	strcpy((char*)rcm->last, "555");
      
	/**Here we can the radio driver to send the message wirelessly*/
	if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_stolen_msg_t)) == SUCCESS) {
	  dbg("AntitheftC", "AntitheftC: Packet sent.\n", theft);
	  /**If the operation succeeded, we lock the MUTEX variable, to wait for a message completion
	  event*/
	  locked = TRUE;
	}
      }
     }
  }
  
//   /**This interface receives a packet that was transmitted to the node wirelessly.*/
//   event message_t* Receive.receive(message_t* bufPtr, 
// 				   void* payload, uint8_t len) {
//     dbg("RadioStolenToLedsC", "Received packet of length %hhu.\n", len);
//     /**If the size of the message received is not the one we are expecting,
//      we ignore the message*/
//     if (len != sizeof(radio_stolen_msg_t)) {
//       return bufPtr;
//       
//     } /**Otherwise, we process the message*/
//     else {
//       /**Here we do a TYPECAST, i.e, re-acquire the contents of the packets to map to our message structure*/
//       radio_stolen_msg_t* rcm = (radio_stolen_msg_t*)payload;
//       
//       /** We have received a "stolen" message from another node */
//       if (rcm->stolen == 1) {
// 	//call Leds.led2On();
// 	
//       /** No nodes have been stolen */
//       } else {
// 	//call Leds.led2Off();
//       }
//       return bufPtr;
//     }
//   }
  
  /**This event is signaled upon completion of the send packet operation*/
  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&packet == bufPtr) {
      /**Since the packet transmitted pointer is pointing to the same region to the 
       succeeded event, we can unlock the MUTEX.*/
      locked = FALSE;
    }
  }
}
