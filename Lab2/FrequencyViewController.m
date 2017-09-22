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
@property (nonatomic) NSMutableDictionary *noteTableA;
@property (nonatomic) NSMutableDictionary *halfstepLookup;
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

-(NSMutableDictionary *)noteTableA {
    if(!_noteTableA) {
        _noteTableA = [[NSMutableDictionary alloc] init];
        [_noteTableA setValue:@110 forKey:@"2"];
        [_noteTableA setValue:@220 forKey:@"3"];
        [_noteTableA setValue:@440 forKey:@"4"];
        [_noteTableA setValue:@880 forKey:@"5"];
        [_noteTableA setValue:@1760 forKey:@"6"];
        [_noteTableA setValue:@3520 forKey:@"7"];
        [_noteTableA setValue:@7040 forKey:@"8"];
    }
    return _noteTableA;
}

-(NSMutableDictionary *) halfstepLookup {
    if(!_halfstepLookup) {
        _halfstepLookup = [[NSMutableDictionary alloc] init];
        [_halfstepLookup setValue:@"A#" forKey:@"1"];
        [_halfstepLookup setValue:@"B" forKey:@"2"];
        [_halfstepLookup setValue:@"B#" forKey:@"3"];
        [_halfstepLookup setValue:@"C" forKey:@"4"];
        [_halfstepLookup setValue:@"C#" forKey:@"5"];
        [_halfstepLookup setValue:@"D" forKey:@"6"];
        [_halfstepLookup setValue:@"D#" forKey:@"7"];
        [_halfstepLookup setValue:@"E" forKey:@"8"];
        [_halfstepLookup setValue:@"F" forKey:@"9"];
        [_halfstepLookup setValue:@"F#" forKey:@"10"];
        [_halfstepLookup setValue:@"G" forKey:@"11"];
        [_halfstepLookup setValue:@"G#" forKey:@"12"];
    }
    return _halfstepLookup;
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
    float* fftMag = malloc(sizeof(float)*BUFFER_SIZE/2);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/8);
    
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMag];
    
    [self fftAverage: fftMagnitude
                    : fftMag];
    
    float maxVal = 0;
    vDSP_Length maxIndex = 10000000;
    
    //vDSP_maxvi(fftMagnitude, 1, &maxVal, &maxIndex, BUFFER_SIZE/2);
    
    for(int i = 1; i < BUFFER_SIZE/8; i++) {
        if(fftMagnitude[i] > maxVal && 20*log(fftMagnitude[i]) > 60) {
            maxVal = fftMagnitude[i];
            maxIndex = i;
        }
    }
    
    float maxVal2 = 0;
    vDSP_Length maxIndex2 = 10000000;
    for(int i = 1; i < BUFFER_SIZE/8; i++){
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
        self.freqLabel1.text = [NSString stringWithFormat:@"%.1f Hz", ((float)maxIndex * 4 * self.audioManager.samplingRate/(BUFFER_SIZE))];
    }
    if(maxIndex2 != 10000000) {
        self.freqLabel2.text = [NSString stringWithFormat:@"%.1f Hz", ((float)maxIndex2 * 4 * self.audioManager.samplingRate/(BUFFER_SIZE))];
    }
    
    free(arrayData);
    free(fftMagnitude);
    free(fftMag);
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
