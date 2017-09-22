//
//  FrequencyViewController.m
//  Lab2
//
//  Created by Oscar on 9/20/17.
//  Copyright © 2017 SMU.cse5323. All rights reserved.
//

#import "FrequencyViewController.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "FFTHelper.h"
#import "math.h"

#define BUFFER_SIZE 8192

@interface FrequencyViewController ()
@property (strong, nonatomic) Novocaine *audioManager;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property (weak, nonatomic) IBOutlet UILabel *freqLabel1;
@property (weak, nonatomic) IBOutlet UILabel *freqLabel2;
@end

@implementation FrequencyViewController

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

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc]initWithFFTSize:BUFFER_SIZE];
    }
    
    return _fftHelper;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSLog(@"View Loaded!");
    
    __block FrequencyViewController * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
        
        
    }];
    
    [self.audioManager play];
    
    
    [NSTimer scheduledTimerWithTimeInterval:0.1
                                     target:self
                                   selector:@selector(update)
                                   userInfo:nil
                                    repeats:YES];
}

- (void) update {
    // just plot the audio stream
    
    // get audio stream data
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    float maxVal = 0;
    vDSP_Length maxIndex = 10000000;
    
    //vDSP_maxvi(fftMagnitude, 1, &maxVal, &maxIndex, BUFFER_SIZE/2);
    
    for(int i = 1; i < BUFFER_SIZE/2; i++) {
        if(fftMagnitude[i] > maxVal && 20*log(fftMagnitude[i]) > 60) {
            maxVal = fftMagnitude[i];
            maxIndex = i;
        }
    }
    
    float maxVal2 = 0;
    vDSP_Length maxIndex2 = 10000000;
    for(int i = 1; i < BUFFER_SIZE/2; i++){
        if( (abs(maxIndex - i) * self.audioManager.samplingRate/(BUFFER_SIZE)) <= 30){
            i += 60;
            continue;
        }
        if(fftMagnitude[i] > maxVal2 && 20*log(fftMagnitude[i]) > 60) {
            maxVal2 = fftMagnitude[i];
            maxIndex2 = i;
        }
    }
    
    
    if(maxIndex != 10000000) {
        self.freqLabel1.text = [NSString stringWithFormat:@"%.1f Hz", ((float)maxIndex * self.audioManager.samplingRate/(BUFFER_SIZE))];
    }
    if(maxIndex2 != 10000000) {
        self.freqLabel2.text = [NSString stringWithFormat:@"%.1f Hz", ((float)maxIndex2 * self.audioManager.samplingRate/(BUFFER_SIZE))];
    }
    
    free(arrayData);
    free(fftMagnitude);
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
