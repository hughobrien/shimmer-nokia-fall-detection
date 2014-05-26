/*  Three Axis Accelerometer to Bluetooth Console for TinyOS 1.x
	Hugh O'Brien, March 2009. This code is released into the Public Domain.

	Samples are taken once every 20ms, once ten samples have been collected
	the results are averaged and sent over the Bluetooth radio, this results
	in an update frequency of 5Hz which should compromise between battery
	life and the loss of short lived readings.
*/
	
/* LED Legend:
	Green = Device is On
	Red = Bluetooth Connection Open
	Yellow On = DMA Buffer completed
	Yellow Off = Bluetooth Write Completed
	Orange  = DMA sample completed (toggles so blink rate = 1/2 sample rate)
	All On = Error State
*/

/* number of channels being sampled */
#define NUM_ADC_CHAN 3

/* take a sample every 'sample rate' miliseconds */
#define BASE_SAMPLE_RATE 50

/* how many samples to average before broadcast */
#define NUM_SAMPLES_TO_AVG 10 

/*sum of the characters being sent */
#define CHAR_BUF_SIZE 16

/* 	sensitivity is defined in the StdControl.init() function
	as 2G - it is itself a macro so could not be included here */


includes DMA;

module ThreeAxisToBluetoothM {
	provides {
		interface StdControl;
	}
	
	uses {
		interface Leds;
		interface Timer as samplingTimer;
		interface StdControl as BTStdControl;
		interface Bluetooth;
		interface StdControl as AccelStdControl;
		interface MMA7260_Accel as Accel;
		interface DMA as DMA0;
	}
}

implementation {
	
	/* define sprintf as a C type call */
	extern int sprintf(char *str, const char *format, ... )
	__attribute__ ((C));
	
	/* storage for DMA'd accelerometer data */
	uint16_t buf1[NUM_ADC_CHAN * NUM_SAMPLES_TO_AVG];
	uint16_t buf2[NUM_ADC_CHAN * NUM_SAMPLES_TO_AVG];
	
	/* keeps track of which buffer is being used by DMA */
	bool buf2_active = FALSE;
	
	/* keeps track of whether the alternate buffer is ready to use again */
	bool alt_buf_in_use = FALSE; 
	
	/* counter for how many entries to the buffer have been made */
	uint8_t dma_blocks = 0; 
	
	/* storage for ASCII output */
	uint8_t charbuf[CHAR_BUF_SIZE];
	
	/* on-the-fly modifiable sample rate */
	uint16_t sampleRate = BASE_SAMPLE_RATE;
	
	
	/* This is the first function called after the system 'boots' */
	
	command result_t StdControl.init() {
		call Leds.init();
		call AccelStdControl.init();
		call Accel.setSensitivity(RANGE_2_0G);
		call DMA0.ADCinit();
		call BTStdControl.init();

		/* Set up the flags for the ADC, code from BioMobius examples*/
		atomic{ 

			SET_FLAG(ADC12CTL1, ADC12DIV_7);
			
			/* sample and hold time 4 adc12clk cycles */
			SET_FLAG(ADC12CTL0, SHT0_0);
			
			/* set reference voltage to 2.5v */
			SET_FLAG(ADC12CTL0, REF2_5V);
			
			/* conversion start address */
			SET_FLAG(ADC12CTL1, CSTARTADD_0);
		
			SET_FLAG(ADC12MCTL0, INCH_5);  /* accel x */
			SET_FLAG(ADC12MCTL1, INCH_4);  /* accel y */
			SET_FLAG(ADC12MCTL2, INCH_3);  /* accel z */
			SET_FLAG(ADC12MCTL2, EOS);     /* end of sequence */
			SET_FLAG(ADC12MCTL0, SREF_1);	/* Vref = Vref+ and Vr- */
			SET_FLAG(ADC12MCTL1, SREF_1);	/* Vref = Vref+ and Vr- */
			SET_FLAG(ADC12MCTL2, SREF_1);	/* Vref = Vref+ and Vr- */
			
			/* set up for three adc channels -> three adcmem regs -> three dma
			channels in round-robin */
			
			/* clear init defaults first */
			CLR_FLAG(ADC12CTL1, CONSEQ_2); /* clear repeat single channel */
			SET_FLAG(ADC12CTL1, CONSEQ_1); /* single sequence of channels */
		}
		
		/* initialise DMA, begin writing to buf1 */
		call DMA0.init();
		call DMA0.setSourceAddress((uint16_t)ADC12MEM0_);
		call DMA0.setDestinationAddress((uint16_t)buf1);
		call DMA0.setBlockSize(NUM_ADC_CHAN);

		/* these are flags specific to the MSP430 uC */
		DMA0CTL = DMADT_1 + DMADSTINCR_3 + DMASRCINCR_3;
		
		return SUCCESS;
	}


	/* this block executes after StdControl.init() */
	command result_t StdControl.start() {
		call Leds.greenOn();
		call BTStdControl.start();
		return SUCCESS;
		/* System idles here until a BT connection is made */
	}
	
	/* this is only called in case of a (detected) system fault */
	command result_t StdControl.stop() {
		call Leds.yellowOff();
		call samplingTimer.stop();
		call AccelStdControl.stop();
		call BTStdControl.stop();
		return SUCCESS;
	}
	
	
	/* 	every time the sampling timer fires this is executed
		I suspect this might benefit from being atomic if the sample rate
		became very high but the examples do not show that thinking
		so I left it pre-emptable */
		
	event result_t samplingTimer.fired() {
		call DMA0.beginTransfer();
		call DMA0.ADCbeginConversion();
		return SUCCESS;
	  }
	
	  
	/* 	simple task to remove the long running calls from
		Bluetooth.connectionMade, as it is called async it would otherwise
		run to completion */
	
	task void postConnectionSetup() {
		call AccelStdControl.start();
		call samplingTimer.start(TIMER_REPEAT, sampleRate);
	}
		
	async event void Bluetooth.connectionMade(uint8_t status) {
		call Leds.redOn();
		post postConnectionSetup();
	}
	
	async event void Bluetooth.commandModeEnded() {
		/* we're required to handle this event but for this project we don't
		have to do anything meaningful */
	}
	
	/* long running async command is okay here as the system won't
		be doing anything else */
	async event void Bluetooth.connectionClosed(uint8_t reason) {
		call samplingTimer.stop();
		call Leds.redOff();
		call Leds.yellowOff();
		call Leds.orangeOn();
		call AccelStdControl.stop();
	}
	
	async event void Bluetooth.dataAvailable(uint8_t data) {
		/* code to allow the receiver device to modify the sample rate,
		disabled as it's buggy */
		
		/*call Leds.orangeToggle();
		atomic switch (data) {
			
			case 'S':
				sampleRate = BASE_SAMPLE_RATE / 2;
			case 'M':
				sampleRate = BASE_SAMPLE_RATE;
			case 'F':
				sampleRate = BASE_SAMPLE_RATE * 2;
		}
		
		call samplingTimer.stop();
		call samplingTimer.start(TIMER_REPEAT, sampleRate);*/
	}
	
	event void Bluetooth.writeDone() {
		call Leds.yellowOff();
	}
	
	
	/* this task is the CPU hotspot of my contributions however
		I may be calling OS provided functions that outweigh it */
	
	task void averageData() {
		uint16_t X=0,Y=0,Z=0;
		uint8_t i;
		
		/* 	this doubled up code could be compacted by using
			a buf pointer but as space isn't currently an issue
			I left it verbose for clarity */
		
		/*if buf2 is being used by DMA, read from buf1 */
		if ( buf2_active) { 
			for ( i=0; i <NUM_SAMPLES_TO_AVG ; i++ ) {
				X += buf1[NUM_ADC_CHAN * i ];
				Y += buf1[NUM_ADC_CHAN * i + 1 ];
				Z += buf1[NUM_ADC_CHAN * i + 2];
				}
			}
		else {
			for ( i=0; i <NUM_SAMPLES_TO_AVG ; i++ ) {
				X += buf2[NUM_ADC_CHAN * i ];
				Y += buf2[NUM_ADC_CHAN * i + 1 ];
				Z += buf2[NUM_ADC_CHAN * i + 2];
			}
		}
		
		/* we're finished with the buffer so allow DMA to use it */
		atomic alt_buf_in_use = FALSE;
		
		
		/* find the average values */
		X /= NUM_SAMPLES_TO_AVG;
		Y /= NUM_SAMPLES_TO_AVG;
		Z /= NUM_SAMPLES_TO_AVG;
		
		/* convert the values to fixed prescision strings */
		sprintf(charbuf, "%.4u %.4u %.4u\r\n",X,Y,Z);
		call Bluetooth.write(charbuf, CHAR_BUF_SIZE);
		
	}

	/* 	This is called when the data from the ADC has
		been written to memory */
		
	async event void DMA0.transferComplete() {
		
		call Leds.orangeToggle();
		dma_blocks ++;
		
		/* move the DMA destination pointer along in the buffer */
		DMA0DA += (NUM_ADC_CHAN * 2);
		
		atomic {
			if (dma_blocks == NUM_SAMPLES_TO_AVG ) { /* if buffer is full */
				
				/*if the other buf is still in use, reuse the current one */
				if (alt_buf_in_use) { 
					if (buf2_active) {
						DMA0DA = (uint16_t) buf2;
						dma_blocks = 0;
					}
					else {
						DMA0DA = (uint16_t) buf1;
						dma_blocks =0;
					}
				}
				/* if it's not active then switch buffers */
				else { 
					if (buf2_active) {
						DMA0DA = (uint16_t)buf1;
						buf2_active = FALSE;
						dma_blocks = 0;
					}
					else {
						DMA0DA = (uint16_t)buf2;
						buf2_active = TRUE;
						dma_blocks = 0;
						}
						
					atomic alt_buf_in_use = TRUE;
					post averageData();
				}
				call Leds.yellowOn();
				}	
			}
		}

			
	async event void DMA0.ADCInterrupt(uint8_t regnum) {
		call StdControl.stop();
		call Leds.greenOn();
		call Leds.redOn();
		call Leds.orangeOn();
		call Leds.yellowOn();
	}
}
