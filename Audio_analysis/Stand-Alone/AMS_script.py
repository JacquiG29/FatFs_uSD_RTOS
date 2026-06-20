#!/usr/bin/env python3

""" 
****************************************************************************************************
*	           				Acoustic Measurement System - Standalone Operation  							   *
****************************************************************************************************

The following code describes the behaviour of the Raspberry Pi based AMS in standalone mode.
It works independenlty as both playback and acquisition node. If you want distributed 
operation, set up both the master node and the slave node with the RFM9x LoRa transceivers.

This code requires the use of a Hifiberry DAC + ADC board and the AMS Phantom Power HAT that was
designed for condenser microphone polarization and pre-amplification.
		 
NOTE: Make sure that all python libraries are installed in the Raspberry Pi. 
	  Use Pip to install libraries.

Code running on: 

- Python 3.5.3
- OS: Raspbian GNU/Linux 9 (stretch)
- Kernel: Linux raspberrypi 4.19.23-v7+

*****************************************************************************************************
"""


''' Libraries associated with the queues and threading'''
import contextlib
import queue
import sys
import threading

''' Libraries associated with audio signal processing '''
import numpy as np
import math
import matplotlib.pyplot as plt
import sounddevice as sd
import time
import utils_master as utils
from collections import deque
from scipy.io import wavfile


''' **************************** Definition of Audio Callback ************************************************* '''

def audio_callback(indata, outdata, frames, time, status):

	global rec_flag
	global rec_done
	global data
	assert frames == blocksize 
	if status.input_overflow:
	# NB: This increment operation is not atomic, but this doesn't
	#     matter since no other thread is writing to the attribute.
		print('Input underflow: increase blocksize?', file=sys.stderr)
		input_overflows += 1
	assert not status 

	# NB: reproducing is accessed from different threads.
	#     This is safe because here we are only accessing it once (with a
	#     single bytecode instruction).
	if rec_flag:
		try:
			data = play_queue.get_nowait()
			rec_queue.put_nowait(indata.copy())

		except queue.Empty:
			print('Recording complete.', file=sys.stderr)
			rec_flag = False
			rec_done = True

		if len(data) < len(outdata):
			outdata[:len(data)] = self.data[:,None]
			outdata[len(data):] = b'\x00' * (len(outdata) - len(data))

		else:
			outdata[:] = data[:,None]
	else:
		outdata[:] = 0


''' ***************************** Configuration of the audio stream ******************************************* '''
rec_flag = False
rec_done = False
fs = 44100
blocksize = 384
device = 2 
flow = 31
fhigh = 16000
dur = 4
sil = 3
target_inr = 20
audio_channels = 1
stream = sd.Stream(samplerate = fs, blocksize = blocksize, device = device, channels = audio_channels, latency = 'low', callback = audio_callback)
stream.start()


''' ******************************************* Main Program ************************************************** '''
print('#' * 80)
print('				AMS - Standalone Mode')
print('#' * 80)

sinesweep = utils.get_sine_sweep(flow,fhigh,dur,sil,fs)
inverse_filter = utils.get_inverse_filter(flow,fhigh,dur,sil,fs)
play_queue = queue.Queue()
play_queue = utils.fill_queue(play_queue, sinesweep, blocksize)
rec_queue = queue.Queue(maxsize = int((fs * (dur + sil)) / blocksize))
rec_flag = True

while True:

	time.sleep(0.1)

	if (rec_done == True):
		stream.stop()
		rec_done = False
		recorded_sweep = utils.get_all_queue_result(rec_queue)
		processed_sweep = np.asarray(recorded_sweep)
		processed_sweep = processed_sweep.flatten()
		processed_sweep = (processed_sweep / np.max(processed_sweep))
		ir = utils.fast_conv_vect(processed_sweep, inverse_filter)
		peak = utils.find_peak(ir)
		ir = ir[(peak - 11025):] 		
		inr = utils.get_INR(ir,fs)

		print("The measured INR is: {:.2f}.\n".format(inr))

		if (inr < target_inr):
	
			dur = dur * 2
			print("Updated sinesweep duration to: " + str(dur) + " [s]")
			sinesweep = utils.get_sine_sweep(flow,fhigh,dur,sil,fs)
			inverse_filter = utils.get_inverse_filter(flow,fhigh,dur,sil,fs)

			with play_queue.mutex:
				play_queue.queue.clear()
			play_queue = utils.fill_queue(play_queue, sinesweep, blocksize)
			
			rec_queue = queue.Queue(maxsize = int((fs * (dur + sil)) / blocksize))
			with rec_queue.mutex: 
				rec_queue.queue.clear()

			stream.start()
			rec_flag = True

		else:

			file_name = "Measured_IR(" + time.strftime("%Y-%m-%d-%H-%M-%S", time.gmtime()) + ").wav"
			scaled_signal = np.int16(ir.real/np.max(np.abs(ir.real))* 32767)
			wavfile.write(file_name, fs,scaled_signal)
			print("IR has been exported with file name: " + file_name)
			break
