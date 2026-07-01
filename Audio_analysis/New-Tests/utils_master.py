import numpy as np
import math
import matplotlib.pyplot as plt
import queue


from scipy import stats
from scipy import signal
from scipy.signal import butter
from scipy.fftpack import fft, ifft
from scipy.ndimage.filters import gaussian_filter1d # To smooth FFT plot


def get_sine_sweep(f1,f2,Ti,sil,fs):
	'''
	Generates an exponential Sine Sweep with frequency range (f1,f2), duration Ti 
	and sampling frequency fs.
	
	:param f1: Start frequency for the sinesweep.
	:param f2: Stop frequency for the sinesweep.
	:param Ti: Duration in seconds of the sinesweep.
	:param sil: Duration in seconds of the silence after the sinesweep.
	:param fs: Sampling frequency
	:return: Numpy array that represents the sinesweep.
	
	'''
	f_in = f_out = 0.1
	t = np.arange(0, Ti*fs)/fs
	L = round(Ti*f1/math.log(f2/f1))
	Li = (1/f1)*L 
	sweep = np.sin(((2*np.pi)*L)*np.exp((f1*t)/L)-1)
	fade_in = np.linspace(0,1, num = int(f_in * fs))
	fade_out = np.linspace(1,0, num = int(f_out * fs))
	sweep[0:int(f_in * fs)] = sweep[0:int(f_in * fs)] * fade_in	
	sweep[len(sweep) - int(f_out * fs):len(sweep)] = sweep[len(sweep) - int(f_out * fs):len(sweep)] * fade_out
	sweep = np.pad(sweep,(0,int(sil*fs)), 'constant')

	return(sweep)

def get_inverse_filter(f1,f2,Ti,sil,fs):
	'''
	Generates the inverse filter necessary to perform the deconvolution.
	
	:param f1: Start frequency for the sinesweep.
	:param f2: Stop frequency for the sinesweep.
	:param Ti: Duration in seconds of the sinesweep.
	:param sil: Duration in seconds of the silence after the sinesweep.
	:param fs: Sampling frequency
	:return: Numpy array that represents the inverse filter.
	
	'''
	f_in = f_out = 0.1
	t = np.arange(0, Ti*fs)/fs
	L = round(Ti*f1/math.log(f2/f1))
	Li = (1/f1)*L 
	sweep = np.sin(((2*np.pi)*L)*np.exp((f1*t)/L)-1)
	fade_in = np.linspace(0,1, num = int(f_in * fs))
	fade_out = np.linspace(1,0, num = int(f_out * fs))
	sweep[0:int(f_in * fs)] = sweep[0:int(f_in * fs)] * fade_in	
	sweep[len(sweep) - int(f_out * fs):len(sweep)] = sweep[len(sweep) - int(f_out * fs):len(sweep)] * fade_out
	inverse_sweep = (f1/Li)*np.exp(-1*(t/Li))*(sweep[::-1])
	inverse_sweep = np.pad(inverse_sweep,(int(sil*fs),0), 'constant')

	return inverse_sweep

def timeplot(ts, fs, title = "Time plot"):

	'''
	Timeplot with correct axis.
	
	:param ts: Numpy array with signal to be plotted.
	:param fs: Sampling frequency.
	:param title: Optional parameter for the title of plot.
	
	'''
	plt.figure(figsize=(10,3))
	plt.plot(ts)
	plt.xticks(np.arange(0,len(ts),fs), np.arange(0,len(ts)/fs,1))
	plt.ylabel("Amplitude")
	plt.xlabel("Samples")
	plt.title(title)
	#plt.title("Time Series".format(len(ts)/fs, fs))
	plt.grid(True)


def plot_specgram(data, title='', x_label='', y_label='', fig_size=None):
	'''
	Plot Spectrogram
	
	:param data: Numpy array with signal to be plotted.
	:param title: Optional parameter for the title of plot.

	'''
	fig = plt.figure()
	if fig_size != None:
		fig.set_size_inches(fig_size[0], fig_size[1])
	ax = fig.add_subplot(111)
	ax.set_title(title)
	ax.set_xlabel(x_label)
	ax.set_ylabel(y_label)
	pxx,  freq, t, cax = plt.specgram(data, Fs=44100, cmap=plt.cm.Spectral_r,)
	fig.colorbar(cax).set_label('Amplitude [dB]')
	
 
def get_fft(ts,Fs,N):
	'''
	Calculate FFT for plot

	:param ts: Numpy array with signal to be plotted.
	:param Fs: Sampling frequency.
	:param N: Length for the FFT	
	:return Pxx: Array which contains the FFT
	'''
	Y_k = np.fft.fft(ts)[0:int(N/2)]/N # FFT function from numpy of signal ts with lenght N
	Y_k[1:] = 2*Y_k[1:] # need to take the single-sided spectrum only
	Pxx = np.abs(Y_k) # be sure to get rid of imaginary part
	Pxx = 20 * np.log10(Pxx)
	return Pxx


def draw_fft(Pxx, Fs, N, smooth = False, title = "Frequency Spectrum"):
	'''
	Plot FFT 

	:param Pxx: Numpy array with signal to be plotted.
	:param Fs: Sampling frequency.
	:param N: Length for the FFT.
	:param smooth: Boolean variable used to smooth the plot.
	:param title: Optional parameter for the title.	
	'''
	f = Fs*np.arange((N/2))/N; # frequency vector
	freq_octaves = [31, 63, 125, 250]

	if smooth == True:

		Pxx_smooth = gaussian_filter1d(Pxx, sigma=30)
		plt.figure(figsize=(10,3))
		plt.plot(f,Pxx_smooth,linewidth=1)
		plt.xscale('log')
		plt.xlim(31, 16000)
		plt.title(title)
		plt.ylabel('Amplitude [dB]')
		plt.xticks([31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000], ["31 Hz", "63 Hz", "125 Hz", "250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"])
		plt.xlabel('Frequency [Hz]')
		plt.grid(True)
	else:
		plt.figure(figsize=(10,3))
		plt.plot(f,Pxx,linewidth=1)
		plt.xscale('log')
		plt.xlim(31, 16000)
		plt.title(title)
		plt.ylabel('Amplitude [dB]')
		plt.xticks([31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000], ["31 Hz", "63 Hz", "125 Hz", "250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"])
		plt.xlabel('Frequency [Hz]')
		plt.grid(True)

def find_peak(ts):
	'''
	Obtains the sample with the highest value.
	
	:param ts: Numpy array with signal.
	'''
	return np.argmax(np.abs(ts))

def nextpow2(L):
	'''
	Simple function to calculate the next power of two.
	:param L: Input value.
	:return N: Next power of two of L. 
	
	'''
	N = 2
	while N < L: N = N * 2
	return N
	
def fast_conv_vect(x,h):
	'''
	Fast convolution done using the FFT.
	Use as: y1 = fast_conv_vect( x1, h1 ).real  
	Takes the real part to avoid a too small complex part (around e-18)
	
	:param x: Array corresponding to the first signal in the time domain.
	:param h: Array corresponding to the second signal in the time domain.
	:return y: Array corresponding to the output after the convolution in the time domain.
	
	'''
	# searches for the amount of points required to perform the FFT
	L = len(h) + len(x) - 1 # linear convolution length
	N = nextpow2(L)
	# Note: N>=L is needed because the IDFT of the multiplication is the circular convolution and to match it to the
	# common one, N>=L is required (where L=N1+N2-1;N1=length(x);N2=length(h))

	# FFT(X,N) is the N points FFT, with zero padding if X has less than N points and truncated if has more.
	H = fft(h,N) # Fourier transform of the impulse
	X = fft(x,N) # Fourier transform of the input signal
	
	Y = H * X # spectral multiplication
	y = ifft(Y) # time domain again
	return y

def buffer(signal, blocksize):
	'''
	Create a buffer that takes a numpy array and a buffersize. The function returns the buffer and an updated version of the input. 
	When the numpy array comes to an end and the lenght of the input is less than the length of the output, the buffer is padded with 
	zeros and returns a flag indicating that there is no longer any values in the array. 

	:param signal: Numpy array of the signal.
	:param blocksize: Size in samples of the buffer.
	:return signal_n: Signal piece with blocksize
	:return signal: Signal that remains without signal_n  
	:return flag: Flag used to indicate when the signal has been fully fed to the buffer.
	'''
	if len(signal) > blocksize:
		signal_n = signal[:blocksize]
		signal = signal[blocksize:]
		flag = True
	else:
		signal = np.pad(signal, (0, blocksize-len(signal)), 'constant')
		signal_n = signal
		flag = False

	return signal_n, signal, flag

def fill_queue(signal_q, signal, blocksize):
	'''
	Uses the buffer function to fill a queue of elements.
	
	:param signal_q: Queue where signal will be put.
	:param signal: Signal that will be put on the queue.
	:param blocksize: Size in samples of the buffer.
	:return: Queue after the signal has been put.
	'''
	signal_cp = signal
	for _ in range(round((len(signal_cp)/ blocksize) + 1)): 
	    data, signal_cp, flag = buffer(signal_cp, blocksize)
	    if not flag:
	        break
	    signal_q.put_nowait(data) # Pre-fill queue

	return signal_q


def get_all_queue_result(queue):
	'''
	Gets the data from a queue.
	
	:param queue: The queue that has the data.
	:return result_list: Array which has the extracted data.
	'''
	result_list = []
	while not queue.empty():
		result_list.append(queue.get())

	return result_list

def get_INR(ir, fs, rt='t30'):
	"""
	Calculation of the INR accoring to technical note TN007 (Impulse Response To Noise Ratio) from Acustics Engineering (Dirac Software)
	
	:param signal: Numpy array containing the impulse response.
	:param rt: Reverberation time estimator. It accepts `'t30'`, `'t20'`, `'t10'` and `'edt'`.
	:returns: Impulse Response to Noise Ratio (INR) in dB.
	"""
	if rt == 't30':
		init = -5.0
		end = -35.0
		factor = 2.0
	elif rt == 't20':
		init = -5.0
		end = -25.0
		factor = 3.0
	elif rt == 't10':
		init = -5.0
		end = -15.0
		factor = 6.0
	elif rt == 'edt':
		init = 0.0
		end = -10.0
		factor = 6.0

	ir = ir.real
	ir = ir / np.max(np.abs(ir))

	# Schroeder integration
	abs_ir = np.abs(ir)/np.max(np.abs(ir))
	sch = np.cumsum(abs_ir[::-1]**2)[::-1]
	sch_db = 10.0 * np.log10(sch / np.max(sch))

	# Linear regression
	sch_init = sch_db[np.abs(sch_db - init).argmin()]
	sch_end = sch_db[np.abs(sch_db - end).argmin()]
	init_sample = np.where(sch_db == sch_init)[0][0]
	end_sample = np.where(sch_db == sch_end)[0][0]
	x = np.arange(init_sample, end_sample + 1) / fs
	y = sch_db[init_sample:end_sample + 1]
	slope, intercept = stats.linregress(x, y)[0:2]

	# Reverberation time (T30, T20, T10 or EDT)
	db_regress_init = (init - intercept) / slope
	db_regress_end = (end - intercept) / slope
	t60 = factor * (db_regress_end - db_regress_init)
	print(t60)
	# Calculation of Ln (Noise Level) from the initial part of the IR where the energy level is essentially constant in time.
	noise_segment = ir[0:3000]
	ir_power = np.sum(noise_segment.real*noise_segment.real)/noise_segment.size
	Ln = 10 * np.log10(1/ir_power)

	# Calculation of S(0) and Li
	peak = find_peak(ir)
	S0 = 10.0 * np.log10((t60/(6*np.log(10)))*(ir[peak] * ir[peak]))
	Li = S0 + 10*np.log10((6*np.log(10))/t60)

	# Calculation of INR
	INR = abs(Li - Ln)

	return INR
