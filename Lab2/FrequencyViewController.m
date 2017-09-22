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
@property (weak, nonatomic) IBOutlet UILabel *noteLabel;
@property (weak, nonatomic) IBOutlet UILabel *noteLabel2;
@property (nonatomic) int *noteFreqs;
@property (nonatomic) NSMutableArray *halfstepArray;
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

-(int*) noteFreqs {
    if(!_noteFreqs) {
        _noteFreqs = malloc(sizeof(int)*7);
        _noteFreqs[0] = 110;
        _noteFreqs[1] = 220;
        _noteFreqs[2] = 440;
        _noteFreqs[3] = 880;
        _noteFreqs[4] = 1760;
        _noteFreqs[5] = 3520;
        _noteFreqs[6] = 7040;
    }
    return _noteFreqs;
}

-(NSMutableArray*) halfstepArray {
    if(!_halfstepArray) {
        _halfstepArray = [[NSMutableArray alloc] init];
        _halfstepArray[0] = @"A";
        _halfstepArray[1] = @"A#";
        _halfstepArray[2] = @"B";
        _halfstepArray[3] = @"C";
        _halfstepArray[4] = @"C#";
        _halfstepArray[5] = @"D";
        _halfstepArray[6] = @"D#";
        _halfstepArray[7] = @"E";
        _halfstepArray[8] = @"F";
        _halfstepArray[9] = @"F#";
        _halfstepArray[10] = @"G";
        _halfstepArray[11] = @"G#";
        _halfstepArray[12] = @"A";
    }
    return _halfstepArray;
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
    //float* fftMag = malloc(sizeof(float)*BUFFER_SIZE/2);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    //[self fftAverage: fftMagnitude: fftMag];
    
    float maxVal = 0;
    vDSP_Length maxIndex = 10000000;
    
    //vDSP_maxvi(fftMagnitude, 1, &maxVal, &maxIndex, BUFFER_SIZE/2);
    
    for(int i = 1; i < BUFFER_SIZE/8; i++) {
        if(fftMagnitude[i] > maxVal && 20*log(fftMagnitude[i]) > 20) {
            maxVal = fftMagnitude[i];
            maxIndex = i;
        }
    }
    
    float maxVal2 = 0;
    vDSP_Length maxIndex2 = 10000000;
    for(int i = 1; i < BUFFER_SIZE/8; i++){
        if( (fabs(maxIndex - i) * self.audioManager.samplingRate/(BUFFER_SIZE)) <= 30){
            i += 60;
            continue;
        }
        if(fftMagnitude[i] > maxVal2 && 20*log(fftMagnitude[i]) > 20) {
            maxVal2 = fftMagnitude[i];
            maxIndex2 = i;
        }
    }
    
    float freq1 = (float)maxIndex * self.audioManager.samplingRate/(BUFFER_SIZE);
    float freq2 = (float)maxIndex2 * self.audioManager.samplingRate/(BUFFER_SIZE);
    
    if(maxIndex != 10000000) {
        
        int octave = 0;
        
        for(int i = 2; i < 9; i++) {
            if(self.noteFreqs[i - 2] > (int)freq1) {
                octave = i - 1;
                break;
            }
        }
        float a = 1.059463094359295;
        int halfstep = 0;
        for(int i = 0; i < 13; i++) {
            if(freq1 > self.noteFreqs[octave -2] * pow(a, i)) {
                if(freq1 - (self.noteFreqs[octave -2] * pow(a, i-1)) < freq1 - (self.noteFreqs[octave -2] * pow(a, i))) {
                    halfstep = i-1;
                }
                else {
                    halfstep = i;
                }
            }
        }
        //NSLog(@"note: %@", self.halfstepArray[halfstep]);
        
        NSLog(@"ocatave: %d", octave);
        NSString* noteName = [NSString stringWithFormat: @"%@%d", self.halfstepArray[halfstep], octave];
        self.noteLabel.text = noteName;
        
        self.freqLabel1.text = [NSString stringWithFormat:@"%.1f Hz", (freq1)];
        
        
        
    }
    if(maxIndex2 != 10000000) {
        
        int octave = 0;
        
        for(int i = 2; i < 9; i++) {
            if(self.noteFreqs[i - 2] > (int)freq2) {
                octave = i - 1;
                break;
            }
        }
        float a = 1.059463094359295;
        int halfstep = 0;
        for(int i = 0; i < 13; i++) {
            if(freq2 > self.noteFreqs[octave -2] * pow(a, i)) {
                if(freq2 - (self.noteFreqs[octave -2] * pow(a, i-1)) < freq2 - (self.noteFreqs[octave -2] * pow(a, i))) {
                    halfstep = i-1;
                }
                else {
                    halfstep = i;
                }
            }
        }
        NSLog(@"note: %@", self.halfstepArray[halfstep]);
        
        NSLog(@"ocatave: %d", octave);
        NSString* noteName = [NSString stringWithFormat: @"%@%d", self.halfstepArray[halfstep], octave];
        self.noteLabel2.text = noteName;
        self.freqLabel2.text = [NSString stringWithFormat:@"%.1f Hz", (freq2)];
    }
    
    free(arrayData);
    free(fftMagnitude);
    
    //free(fftMag);
}

-(void) fftAverage: (float *) fftMagnitude
                  : (float*) fftMag {
    
    float bucketAvg;
    for(int i = 0; i < BUFFER_SIZE/2; i++) {
        bucketAvg = 0;
        for(int j = 0; j < 4 && i < BUFFER_SIZE/2; j++) {
            bucketAvg += fftMag[i];
            i++;
        }
        bucketAvg /= 4;
        fftMagnitude[i/4] = bucketAvg;
    }

}

-(void) viewDidDisappear:(BOOL)animated {
    free(self.noteFreqs);
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
