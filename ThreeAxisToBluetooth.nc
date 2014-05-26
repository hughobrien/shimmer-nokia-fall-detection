/* Hugh O'Brien, March 2009 */

configuration ThreeAxisToBluetooth {
}

implementation {
	components Main,
	ThreeAxisToBluetoothM,
	RovingNetworksC,
	TimerC,
	LedsC,
	DMA_M,
	MMA7260_AccelM;
	
	Main.StdControl -> ThreeAxisToBluetoothM;
	Main.StdControl -> TimerC;
	
	ThreeAxisToBluetoothM.samplingTimer -> TimerC.Timer[unique("Timer")];
	ThreeAxisToBluetoothM.Leds -> LedsC;
	ThreeAxisToBluetoothM.DMA0 -> DMA_M.DMA[0];
	
	ThreeAxisToBluetoothM.BTStdControl -> RovingNetworksC;
	ThreeAxisToBluetoothM.Bluetooth -> RovingNetworksC;
	
	ThreeAxisToBluetoothM.AccelStdControl -> MMA7260_AccelM;
	ThreeAxisToBluetoothM.Accel -> MMA7260_AccelM;
}