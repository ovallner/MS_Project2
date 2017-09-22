//
//  DopplerViewController.m
//  Lab2
//
//  Created by Oscar on 9/21/17.
//  Copyright © 2017 SMU.cse5323. All rights reserved.
//

#import "DopplerViewController.h"
#import "FrequencyViewController.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "FFTHelper.h"
#import "math.h"
#import "SMUGraphHelper.h"

#define BUFFER_SIZE 8192

@interface DopplerViewController ()
@property (strong, nonatomic) Novocaine *audioManager;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (weak, nonatomic) IBOutlet UILabel *motionLabel;
@property (weak, nonatomic) IBOutlet UISlider *freqSlider;
@property (weak, nonatomic) IBOutlet UILabel *freqLabel;
@property (nonatomic) float frequency;
@property (nonatomic) float phaseIncrement;
@end

@implementation DopplerViewController

-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}

-(CircularBuffer*)buffer{
    if(!_buffer){
        _buffer = [[CircularBuffer alloc]initWithNumChannels:1 andBufferSize:BUFFER_SIZE];
    }
    return _buffer;
}

-(SMUGraphHelper*)graphHelper{
    if(!_graphHelper){
        _graphHelper = [[SMUGraphHelper alloc]initWithController:self
                                        preferredFramesPerSecond:15
                                                       numGraphs:1
                                                       plotStyle:PlotStyleSeparated
                                               maxPointsPerGraph:BUFFER_SIZE];
    }
    return _graphHelper;
}

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc]initWithFFTSize:BUFFER_SIZE];
    }
    
    return _fftHelper;
}

-(float)frequency{
    if(!_frequency){
        _frequency = 18000;
    }
    return _frequency;
}

- (IBAction)changeFreq:(UISlider *)sender {
    [self updateFreq:sender.value];
}

- (void) updateFreq: (float)freqInHz {
    self.frequency = freqInHz;
    self.freqLabel.text = [NSString stringWithFormat:@"%.0f Hz",freqInHz];
    self.phaseIncrement = 2*M_PI*self.frequency/self.audioManager.samplingRate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Setting Slider values
    self.freqSlider.value = 18000;
    self.freqSlider.minimumValue = 15000;
    self.freqSlider.maximumValue = 20000;
    self.freqLabel.text = [NSString stringWithFormat:@"%.0f Hz", self.frequency];
    
    
    __block float phase = 0.0;
    [self.graphHelper setScreenBoundsBottomHalf];
    
    __block DopplerViewController * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    
    
    [self.audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        double sineWaveRepeatMax = 2*M_PI;
        for(int i = 0; i < numFrames; i++)
        {
            data[i] = sin(phase);
            
            phase += self.phaseIncrement;
            
            if(phase >= sineWaveRepeatMax)
            {
                phase -= sineWaveRepeatMax;
            }
        }
    }];
    
    [self.audioManager play];
    
}

-(void) viewDidDisappear:(BOOL)animated {
    [self.audioManager pause];
}

#pragma mark GLK Inherited Functions
//  override the GLKViewController update function, from OpenGLES
- (void)update{
    // just plot the audio stream
    
    // get audio stream data
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    // graph the FFT Data
    [self.graphHelper setGraphData:fftMagnitude
                    withDataLength:BUFFER_SIZE/2
                     forGraphIndex:0
                 withNormalization:128.0
                     withZeroValue:-64];
    
    [self.graphHelper update]; // update the graph
    [self determineMovement: fftMagnitude];
    free(arrayData);
    free(fftMagnitude);
}

- (void)determineMovement: (float*) fftMagnitude {
    
    //int playedFreqIndex = (int)self.frequency / (self.audioManager.samplingRate/(BUFFER_SIZE));
    
    float maxVal = 0;
    vDSP_Length maxIndex = 10000000;
    
    //vDSP_maxvi(fftMagnitude, 1, &maxVal, &maxIndex, BUFFER_SIZE/2);
    
    for(int i = 1; i < BUFFER_SIZE/2; i++) {
        if(fftMagnitude[i] > maxVal ) {
            maxVal = fftMagnitude[i];
            maxIndex = i;
        }
    }
    
    float maxVal2 = 0;
    vDSP_Length maxIndex2 = 10000000;
    for(int i = 1; i < BUFFER_SIZE/2; i++){
        if( (fabs(maxIndex - i) * self.audioManager.samplingRate/(BUFFER_SIZE)) <= 1){
            i += 2;
            continue;
        }
        if(fftMagnitude[i] > maxVal2) {
            maxVal2 = fftMagnitude[i];
            maxIndex2 = i;
        }
    }
    
    
    if( fabs(self.frequency - (maxIndex2 * self.audioManager.samplingRate/(BUFFER_SIZE))) < 3) {
        self.motionLabel.text = @"No Motion";
    }
    else if(self.frequency > (maxIndex2 * self.audioManager.samplingRate/(BUFFER_SIZE))) {
        self.motionLabel.text = @"Moving away";
    }
    else if(self.frequency < (maxIndex2 * self.audioManager.samplingRate/(BUFFER_SIZE))) {
        self.motionLabel.text = @"Moving towards";
    }
    
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
