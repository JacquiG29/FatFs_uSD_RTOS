/**
 * =============================================================================
 * SIMPLIFIED AUDIO PLAYBACK FOR STM32H735G-DK
 * =============================================================================
 * 
 * This file demonstrates the MINIMUM code needed to play audio from a buffer
 * through the headphone output at 48kHz using the BSP library.
 * 
 * Key concepts:
 *   1. Double-buffering: DMA plays from one half while you fill the other
 *   2. Callbacks: BSP calls your functions when half/full buffer is played
 *   3. Continuous loop: Keep feeding data or the audio will glitch
 * 
 * Hardware: SAI (Serial Audio Interface) -> WM8994 codec -> Headphone jack
 * 
 * =============================================================================
 */

#include "main.h"
#include "audio_play.h"

/* -----------------------------------------------------------------------------
 * CONFIGURATION
 * -------------------------------------------------------------------------- */

/* Audio parameters - change these as needed */
#define AUDIO_SAMPLE_RATE       48000   /* Hz - also try 44100, 96000 */
#define AUDIO_VOLUME            70      /* 0-100 */
#define AUDIO_CHANNELS          2       /* Stereo */
#define AUDIO_BITS              16      /* 16-bit samples */

/* Buffer size: larger = more latency but safer, smaller = lower latency
 * Must be multiple of 4 for DMA alignment
 * At 48kHz stereo: 4096 samples = 4096/(48000*2) = ~42ms of audio */
#define AUDIO_BUFFER_SIZE       2048

/* Audio instance: 0 = SAI (headphone/line out), 1 = other peripherals */
#define AUDIO_OUT_INSTANCE      0

/* -----------------------------------------------------------------------------
 * DATA STRUCTURES
 * -------------------------------------------------------------------------- */

/* Buffer states - tells us which half needs refilling */
typedef enum {
    BUFFER_IDLE = 0,        /* Nothing happening */
    BUFFER_HALF_COMPLETE,   /* First half done playing - refill it */
    BUFFER_FULL_COMPLETE    /* Second half done playing - refill it */
} BufferState_t;

/* 
 * Audio buffer - MUST be in D3 SRAM (0x38000000) for DMA to access it!
 * The compiler attribute places it there automatically.
 */
#if defined(__GNUC__)
__attribute__((section(".RAM_D3"))) 
#endif
static uint16_t PlayBuffer[AUDIO_BUFFER_SIZE];

/* Playback control */
static volatile BufferState_t BufferState = BUFFER_IDLE;
static volatile uint8_t IsPlaying = 0;

/* Your audio source data - replace with your actual audio */
extern const uint16_t AudioSourceData[];  /* Your audio samples */
extern const uint32_t AudioSourceSize;    /* Number of samples */
static uint32_t AudioReadPointer = 0;     /* Current position in source */

/* -----------------------------------------------------------------------------
 * PRIVATE FUNCTION PROTOTYPES
 * -------------------------------------------------------------------------- */
static void Audio_FillBuffer(uint8_t* pBuffer, uint32_t Size);

/* -----------------------------------------------------------------------------
 * CORE FUNCTIONS
 * -------------------------------------------------------------------------- */

/**
 * @brief Initialize audio output hardware
 * @return 0 on success, non-zero on failure
 * 
 * This sets up:
 *   - WM8994 codec via I2C
 *   - SAI peripheral for I2S audio
 *   - DMA for automatic data transfer
 */
int Audio_Init(void)
{
    BSP_AUDIO_Init_t AudioInit;
    
    /* Configure audio parameters */
    AudioInit.Device        = AUDIO_OUT_DEVICE_HEADPHONE;
    AudioInit.ChannelsNbr   = AUDIO_CHANNELS;
    AudioInit.SampleRate    = AUDIO_SAMPLE_RATE;
    AudioInit.BitsPerSample = AUDIO_RESOLUTION_16B;
    AudioInit.Volume        = AUDIO_VOLUME;
    
    /* Initialize - this configures codec + SAI + DMA */
    if (BSP_AUDIO_OUT_Init(AUDIO_OUT_INSTANCE, &AudioInit) != BSP_ERROR_NONE)
    {
        return -1;  /* Failed - check I2C connection to codec */
    }
    
    return 0;
}

/**
 * @brief Start audio playback
 * 
 * Fills the buffer initially and starts DMA circular transfer.
 * After this, callbacks handle continuous playback.
 */
void Audio_StartPlayback(void)
{
    /* Reset read position */
    AudioReadPointer = 0;
    
    /* Fill entire buffer with initial audio data */
    Audio_FillBuffer((uint8_t*)&PlayBuffer[0], AUDIO_BUFFER_SIZE * sizeof(uint16_t));
    
    /* 
     * Start DMA playback in circular mode
     * Parameters:
     *   - Instance: which audio output (0 = SAI)
     *   - Buffer: pointer to audio data
     *   - Size: total buffer size in BYTES
     * 
     * The DMA will automatically loop and trigger callbacks at half/full
     */
    BSP_AUDIO_OUT_Play(AUDIO_OUT_INSTANCE, (uint8_t*)PlayBuffer, 
                       AUDIO_BUFFER_SIZE * sizeof(uint16_t));
    
    IsPlaying = 1;
}

/**
 * @brief Stop audio playback
 */
void Audio_StopPlayback(void)
{
    BSP_AUDIO_OUT_Stop(AUDIO_OUT_INSTANCE);
    IsPlaying = 0;
    BufferState = BUFFER_IDLE;
}

/**
 * @brief Fill buffer with audio data from source
 * @param pBuffer Pointer to buffer to fill
 * @param Size    Number of BYTES to fill
 * 
 * This is where you put YOUR audio data into the playback buffer.
 * For your project, this might read from:
 *   - A WAV file in flash
 *   - Generated sine wave for sweep
 *   - Recorded data for loopback
 */
static void Audio_FillBuffer(uint8_t* pBuffer, uint32_t Size)
{
    uint16_t* dst = (uint16_t*)pBuffer;
    uint32_t samplesToWrite = Size / sizeof(uint16_t);
    
    for (uint32_t i = 0; i < samplesToWrite; i++)
    {
        /* Get sample from source, loop if at end */
        if (AudioReadPointer >= AudioSourceSize)
        {
            AudioReadPointer = 0;  /* Loop playback */
        }
        
        dst[i] = AudioSourceData[AudioReadPointer++];
    }
    
    /* 
     * IMPORTANT: Clean D-Cache so DMA sees the new data!
     * Without this, DMA may read stale data from cache.
     */
    SCB_CleanDCache_by_Addr((uint32_t*)pBuffer, Size);
}

/**
 * @brief Main audio processing - CALL THIS IN YOUR MAIN LOOP!
 * 
 * Checks if either buffer half needs refilling and handles it.
 * Must be called frequently enough to keep up with playback.
 * At 48kHz with 4096 sample buffer, you have ~42ms per half.
 */
void Audio_Process(void)
{
    if (!IsPlaying)
        return;
    
    if (BufferState == BUFFER_HALF_COMPLETE)
    {
        /* First half finished playing - refill it while second half plays */
        Audio_FillBuffer((uint8_t*)&PlayBuffer[0], 
                        (AUDIO_BUFFER_SIZE / 2) * sizeof(uint16_t));
        BufferState = BUFFER_IDLE;
    }
    else if (BufferState == BUFFER_FULL_COMPLETE)
    {
        /* Second half finished - refill it while first half plays */
        Audio_FillBuffer((uint8_t*)&PlayBuffer[AUDIO_BUFFER_SIZE / 2], 
                        (AUDIO_BUFFER_SIZE / 2) * sizeof(uint16_t));
        BufferState = BUFFER_IDLE;
    }
}

/* -----------------------------------------------------------------------------
 * BSP CALLBACKS - Called by DMA interrupt handler
 * -------------------------------------------------------------------------- */

/**
 * @brief Called when DMA finishes first half of buffer
 * 
 * At this point:
 *   - First half has been sent to codec
 *   - DMA is now sending second half
 *   - You need to refill first half before DMA loops back
 */
void BSP_AUDIO_OUT_HalfTransfer_CallBack(uint32_t Instance)
{
    if (Instance == AUDIO_OUT_INSTANCE)
    {
        BufferState = BUFFER_HALF_COMPLETE;
    }
}

/**
 * @brief Called when DMA finishes entire buffer (second half)
 * 
 * At this point:
 *   - Second half has been sent to codec  
 *   - DMA is looping back to first half
 *   - You need to refill second half before DMA gets there
 */
void BSP_AUDIO_OUT_TransferComplete_CallBack(uint32_t Instance)
{
    if (Instance == AUDIO_OUT_INSTANCE)
    {
        BufferState = BUFFER_FULL_COMPLETE;
    }
}

/**
 * @brief Called on DMA error
 */
void BSP_AUDIO_OUT_Error_CallBack(uint32_t Instance)
{
    /* Handle error - maybe stop and restart? */
    IsPlaying = 0;
}



/* -----------------------------------------------------------------------------
 * UTILITY: Generate test tone (optional)
 * -------------------------------------------------------------------------- */

#include <math.h>

/* Pre-computed sine table for efficiency */
#define SINE_TABLE_SIZE 256
static int16_t SineTable[SINE_TABLE_SIZE];
static uint8_t SineTableInitialized = 0;

/**
 * @brief Generate a sine wave buffer for testing
 * @param buffer     Output buffer
 * @param numSamples Number of samples to generate
 * @param frequency  Frequency in Hz
 * @param amplitude  Amplitude 0-32767
 */
void Audio_GenerateSineWave(int16_t* buffer, uint32_t numSamples, 
                            float frequency, int16_t amplitude)
{
    /* Initialize sine table once */
    if (!SineTableInitialized)
    {
        for (int i = 0; i < SINE_TABLE_SIZE; i++)
        {
            SineTable[i] = (int16_t)(32767.0f * sinf(2.0f * 3.14159f * i / SINE_TABLE_SIZE));
        }
        SineTableInitialized = 1;
    }
    
    /* Phase accumulator for continuous waveform */
    static float phase = 0;
    float phaseIncrement = frequency * SINE_TABLE_SIZE / AUDIO_SAMPLE_RATE;
    
    for (uint32_t i = 0; i < numSamples; i += 2)
    {
        int tableIndex = (int)phase % SINE_TABLE_SIZE;
        int16_t sample = (SineTable[tableIndex] * amplitude) / 32767;
        
        /* Stereo: same sample on both channels */
        buffer[i]     = sample;  /* Left */
        buffer[i + 1] = sample;  /* Right */
        
        phase += phaseIncrement;
        if (phase >= SINE_TABLE_SIZE)
            phase -= SINE_TABLE_SIZE;
    }
}
