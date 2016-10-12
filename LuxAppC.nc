#include "antitheft.h"

configuration LuxAppC
{
}

implementation
{
  components MainC, LuxC,LedsC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  components new HamamatsuS10871TsrC();
  
  /**Provides the Sender interface to the module*/
  components new SerialAMSenderC(AM_RADIO_STOLEN_MSG);
  
  /**Provides the Radio Driver intitialization interface to our program..*/
  components SerialActiveMessageC;

  LuxC -> MainC.Boot;
  LuxC.Timer0 -> Timer0;
  LuxC.Timer1 -> Timer1;
  LuxC.Timer2 -> Timer2;
  LuxC.Leds -> LedsC;
  
  /**Our receive interface depends on is provided by AMReceiverC*/
  LuxC.AMSend -> SerialAMSenderC;
  LuxC.AMControl -> SerialActiveMessageC;
  LuxC.Read -> HamamatsuS10871TsrC;
  
  LuxC.Packet -> SerialAMSenderC;
}
