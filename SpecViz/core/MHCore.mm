//
//  MHCore.m
//  SpecViz
//
//  Created by Matthew Horton on 1/16/15.
//  Copyright (c) 2015 Matt Horton. All rights reserved.
//

#import "MHCore.h"
#import "AEBlockAudioReceiver.h"
#import "AEAudioFilePlayer.h"
#import "mo-gfx.h"
#import "mo-touch.h"
#import "mo-fft.h"

#define SRATE 24000
#define FRAMESIZE 512
#define NUM_CHANNELS 2


// global variables
GLfloat g_waveformWidth = 300;
GLfloat g_waveformHeight = 420;
GLfloat g_gfxWidth = 320;
GLfloat g_gfxHeight = 568;
GLint g_numBigBars = 20;

// buffer
float * g_vertices = NULL;
UInt32 g_numFrames;
float * g_buffer = NULL;
float * g_freq_buffer = NULL;
complex * g_cbuff = NULL;
// window
float * g_window = NULL;
float * g_spectrum = NULL;
float * g_bars = NULL;
float * g_big_bars = NULL;
GLshort * g_specIndeces = NULL;
GLshort * g_bigIndeces = NULL;
float * g_big_bar_heights = NULL;


@implementation MHCore {
    long framesize;
    AEBlockAudioReceiver *audioRec;
    AEBlockAudioReceiver *audioOut;
    AEAudioFilePlayer *player;
}

-(instancetype)initWithViewController:(SpecVizViewController *) viewController {
    self.vc = viewController;
    self.isSpectrum = NO;
    self.isBigBars = NO;
    self.fromFile = NO;
    return self;
}

-(instancetype)init {
    return [[MHCore alloc] initWithViewController:nil];
}

-(void) coreInit {
    GLoilerInit();
    
    self.vc.audioController = [[AEAudioController alloc]
                            initWithAudioDescription:[AEAudioController nonInterleavedFloatStereoAudioDescription]
                            inputEnabled:YES];
    
    NSError *errorAudioSetup = NULL;
    BOOL result = [[self.vc audioController] start:&errorAudioSetup];
    if ( !result ) {
        NSLog(@"Error starting audio engine: %@", errorAudioSetup.localizedDescription);
    }
    
    NSTimeInterval dur = self.vc.audioController.currentBufferDuration;
    
    framesize = AEConvertSecondsToFrames(self.vc.audioController, dur);
    
    g_vertices = new float[framesize*2]; //2d
    g_spectrum = new float[framesize]; //2d and half the size
    g_bars = new float [framesize/2*8];
    g_big_bar_heights = new float[g_numBigBars];
    g_big_bars = new float[g_numBigBars*8];
    g_window = new float[framesize]; //1d
    g_buffer = new float[framesize]; //1d
    g_freq_buffer = new float[framesize]; //1d
    g_cbuff = new complex[framesize/2];
    g_specIndeces = new GLshort[framesize/2*6];
    g_bigIndeces = new GLshort[g_numBigBars*6];
    
    NSURL *file = [[NSBundle mainBundle] URLForResource:@"Loop" withExtension:@"m4a"];
    player = [AEAudioFilePlayer audioFilePlayerWithURL:file
                                          audioController:self.vc.audioController
                                                    error:NULL];
    [player setLoop:YES];
    [player setCurrentTime:0];
    [player setVolume:0];
    
    audioRec = [AEBlockAudioReceiver audioReceiverWithBlock:^(void *source, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio) {
        if(!self.fromFile) {
            // our x
            float x = 0;
            // increment
            float inc = g_waveformWidth / frames;
            
            // zero!!!
            memset( g_vertices, 0, sizeof(float)*framesize*2);
            memset( g_buffer, 0, sizeof(float)*framesize);
            memset( g_cbuff, 0, sizeof(complex)*(framesize/2));
            memset( g_specIndeces, 0, sizeof(GLshort)*(framesize/2*6));
            
            for( int i = 0; i < frames; i++ )
            {
                // set to current x value
                g_vertices[2*i] = x;
                // increment x
                x += inc;
                // set the y coordinate (with scaling)
                
                g_vertices[2*i+1] = ((float*)audio->mBuffers[0].mData)[i] * g_gfxHeight;
                g_buffer[i] = ((float*)audio->mBuffers[0].mData)[i] * g_gfxHeight;
            }
            
            if(self.isSpectrum) {
                //get window
                hanning(g_window, (unsigned long)frames);
                
                // apply window
                apply_window(g_buffer, g_window, (unsigned long) frames);
                
                // copy g_buffer to g_freq_buffer
                memcpy( g_freq_buffer, g_buffer, sizeof(float)*frames);
                
                // fft
                rfft(g_freq_buffer, frames, FFT_FORWARD);
                
                // Get the complex buffer for this round set up
                g_cbuff = (complex *) g_freq_buffer;
                
                float y = 0;
                float bar_width = .95*inc;
                float big_bar_width = g_waveformWidth/g_numBigBars;
                int big_bar_idx = 0;
                int new_bar_idx = 0;
                int current_num_to_avg = 0;
                double current_sum = 0.0;
                
                for (int i = 0; i < frames/2; i++){
                    // set to current x value
                    g_spectrum[2*i] = y;
                    
                    // increment x
                    y += inc*2;
                    // set the y coordinate (with scaling)
                    g_spectrum[2*i+1] = cmp_abs(g_cbuff[i]) * 4;
                    
                    if(!self.isBigBars) {
                    
                        g_bars[8*i] = g_bars[8*i+2] = y - bar_width/2;
                        g_bars[8*i+4] = g_bars[8*i+6] = y + bar_width/2;
                        g_bars[8*i+1] = g_bars[8*i+5] = 0;
                        g_bars[8*i+3] = g_bars[8*i+7] = g_spectrum[2*i+1]*4;
                        
                        g_specIndeces[6*i] = 4*i;
                        g_specIndeces[6*i+1] = 4*i+1;
                        g_specIndeces[6*i+2] = 4*i+3;
                        g_specIndeces[6*i+3] = 4*i+3;
                        g_specIndeces[6*i+4] = 4*i+2j;
                        g_specIndeces[6*i+5] = 4*i;

                    } else {
                        new_bar_idx = (int)(y/big_bar_width);
                        if (new_bar_idx > big_bar_idx) {
                            //do things
                            current_sum += g_spectrum[2*i+1];
                            g_big_bar_heights[big_bar_idx] = (float)(current_sum/current_num_to_avg);
                            big_bar_idx = new_bar_idx;
                            current_num_to_avg = 0;
                            current_sum = 0.0;
                        } else {
                            current_sum += g_spectrum[2*i+1];
                            current_num_to_avg++;
                        }
                    }
                }
                
                if(self.isBigBars) {
                    float big_bar_width = g_waveformWidth/g_numBigBars;
                    
                    for(int i = 0; i < g_numBigBars; i++) {
                        g_big_bars[8*i] = g_big_bars[8*i+2] = i*big_bar_width + big_bar_width*.05;
                        g_big_bars[8*i+4] = g_big_bars[8*i+6] = (i+1)*big_bar_width - big_bar_width*.05;
                        g_big_bars[8*i+1] = g_big_bars[8*i+5] = 0;
                        g_big_bars[8*i+3] = g_big_bars[8*i+7] = g_big_bar_heights[i]*6;
                        
                        g_bigIndeces[6*i] = 4*i;
                        g_bigIndeces[6*i+1] = 4*i+1;
                        g_bigIndeces[6*i+2] = 4*i+3;
                        g_bigIndeces[6*i+3] = 4*i+3;
                        g_bigIndeces[6*i+4] = 4*i+2;
                        g_bigIndeces[6*i+5] = 4*i;
                    }
                    
                }
            }
            
            
            // save the num frames
            if (!self.isSpectrum) {
                g_numFrames = frames;
            } else {
                g_numFrames = frames/2;
            }
        }
        
    }];
    
    audioOut = [AEBlockAudioReceiver audioReceiverWithBlock:^(void *source, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio) {
        if(self.fromFile) {
            // our x
            float x = 0;
            // increment
            float inc = g_waveformWidth / frames;
            
            // zero!!!
            memset( g_vertices, 0, sizeof(float)*framesize*2);
            memset( g_buffer, 0, sizeof(float)*framesize);
            memset( g_cbuff, 0, sizeof(complex)*(framesize/2));
            memset( g_specIndeces, 0, sizeof(GLshort)*(framesize/2*6));
            
            for( int i = 0; i < frames; i++ )
            {
                // set to current x value
                g_vertices[2*i] = x;
                // increment x
                x += inc;
                // set the y coordinate (with scaling)
                
                g_vertices[2*i+1] = ((float*)audio->mBuffers[0].mData)[i] * g_gfxHeight;
                g_buffer[i] = ((float*)audio->mBuffers[0].mData)[i] * g_gfxHeight;
            }
            
            if(self.isSpectrum) {
                //get window
                hanning(g_window, (unsigned long)frames);
                
                // apply window
                apply_window(g_buffer, g_window, (unsigned long) frames);
                
                // copy g_buffer to g_freq_buffer
                memcpy( g_freq_buffer, g_buffer, sizeof(float)*frames);
                
                // fft
                rfft(g_freq_buffer, frames, FFT_FORWARD);
                
                // Get the complex buffer for this round set up
                g_cbuff = (complex *) g_freq_buffer;
                
                float y = 0;
                float bar_width = .95*inc;
                float big_bar_width = g_waveformWidth/g_numBigBars;
                int big_bar_idx = 0;
                int new_bar_idx = 0;
                int current_num_to_avg = 0;
                double current_sum = 0.0;
                
                for (int i = 0; i < frames/2; i++){
                    // set to current x value
                    g_spectrum[2*i] = y;
                    
                    // increment x
                    y += inc*2;
                    // set the y coordinate (with scaling)
                    
                    g_spectrum[2*i+1] = cmp_abs(g_cbuff[i]) * 4;
                    
                    if(!self.isBigBars) {
                        
                        g_bars[8*i] = g_bars[8*i+2] = y - bar_width/2;
                        g_bars[8*i+4] = g_bars[8*i+6] = y + bar_width/2;
                        g_bars[8*i+1] = g_bars[8*i+5] = 0;
                        g_bars[8*i+3] = g_bars[8*i+7] = g_spectrum[2*i+1]*4;
                        
                        g_specIndeces[6*i] = 4*i;
                        g_specIndeces[6*i+1] = 4*i+1;
                        g_specIndeces[6*i+2] = 4*i+3;
                        g_specIndeces[6*i+3] = 4*i+3;
                        g_specIndeces[6*i+4] = 4*i+2;
                        g_specIndeces[6*i+5] = 4*i;
                        
                    } else {
                        new_bar_idx = (int)(y/big_bar_width);
                        if (new_bar_idx > big_bar_idx) {
                            //do things
                            current_sum += g_spectrum[2*i+1];
                            g_big_bar_heights[big_bar_idx] = (float)(current_sum/current_num_to_avg);
                            big_bar_idx = new_bar_idx;
                            current_num_to_avg = 0;
                            current_sum = 0.0;
                        } else {
                            current_sum += g_spectrum[2*i+1];
                            current_num_to_avg++;
                        }
                    }
                }
                
                if(self.isBigBars) {
                    float big_bar_width = g_waveformWidth/g_numBigBars;
                    
                    for(int i = 0; i < g_numBigBars; i++) {
                        g_big_bars[8*i] = g_big_bars[8*i+2] = i*big_bar_width + big_bar_width*.05;
                        g_big_bars[8*i+4] = g_big_bars[8*i+6] = (i+1)*big_bar_width - big_bar_width*.05;
                        g_big_bars[8*i+1] = g_big_bars[8*i+5] = 0;
                        g_big_bars[8*i+3] = g_big_bars[8*i+7] = g_big_bar_heights[i]*6;
                        
                        g_bigIndeces[6*i] = 4*i;
                        g_bigIndeces[6*i+1] = 4*i+1;
                        g_bigIndeces[6*i+2] = 4*i+3;
                        g_bigIndeces[6*i+3] = 4*i+3;
                        g_bigIndeces[6*i+4] = 4*i+2;
                        g_bigIndeces[6*i+5] = 4*i;
                    }
                    
                }
            }
            
            
            // save the num frames
            if (!self.isSpectrum) {
                g_numFrames = frames;
            } else {
                g_numFrames = frames/2;
            }
        }
    }];
    
    [self.vc.audioController addInputReceiver:audioRec];
    [self.vc.audioController addOutputReceiver:audioOut];
    [self.vc.audioController addChannels: @[player]];
}

-(void) coreRender {
    // NSLog( @"render..." );
    
    // projection
    glMatrixMode( GL_PROJECTION );
    // reset
    glLoadIdentity();
    // alternate
    // GLfloat ratio = g_gfxHeight / g_gfxWidth;
    // glOrthof( -1, 1, -ratio, ratio, -1, 1 );
    // orthographic
    glOrthof( -g_gfxWidth/2, g_gfxWidth/2, -g_gfxHeight/2, g_gfxHeight/2, -1.0f, 1.0f );
    // modelview
    glMatrixMode( GL_MODELVIEW );
    // reset
    // glLoadIdentity();
    
    glClearColor( 0, 0, 0, 1 );
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    
    // push
    glPushMatrix();
    
    // center it
    glTranslatef( -g_waveformWidth / 2, 0, 0 );
    
    if(self.isSpectrum) glTranslatef(0, -g_waveformHeight/2,0);
    
    // set the vertex array pointer
    if(!self.isSpectrum){
        glVertexPointer( 2, GL_FLOAT, 0, g_vertices );
        glEnableClientState( GL_VERTEX_ARRAY );
        
        // color
        glColor4f( 1, 0, 1, 1 );
        // draw the thing
        glDrawArrays( GL_LINE_STRIP, 0, g_numFrames/2 );
        
        // color
        glColor4f( 1, 0, 0, 1 );
        // draw the thing
        glDrawArrays( GL_LINE_STRIP, g_numFrames/2-1, g_numFrames/2 );
    } else {
        //glVertexPointer( 2, GL_FLOAT, 0, g_spectrum );
        if(!self.isBigBars) {
            glVertexPointer( 2, GL_FLOAT, 0, g_bars );
        } else {
            glVertexPointer( 2, GL_FLOAT, 0, g_big_bars );
        }
        

        glEnableClientState( GL_VERTEX_ARRAY );
        
        // color
        glColor4f( 1, .1, .5, 1 );
        // draw the thing
        if(!self.isBigBars) {
            glDrawElements(GL_TRIANGLES, g_numFrames*6, GL_UNSIGNED_SHORT, g_specIndeces);
        } else {
            glDrawElements(GL_TRIANGLES, g_numBigBars*6, GL_UNSIGNED_SHORT, g_bigIndeces);
        }
//        glDrawArrays( GL_TRIANGLE_STRIP, 0, g_numFrames*4 );

    }
    
    // pop
    glPopMatrix();
}

-(void) coreSetDimsWithWidth:(CGFloat)w andHeight:(CGFloat)h {
    GLoilerSetDims(w, h);
}

-(void) changeMode {
    self.isSpectrum = !self.isSpectrum;
    if (self.isSpectrum) {
        [self.vc.pressMe setHidden:NO];
    } else {
        [self.vc.pressMe setHidden:YES];
    }
}

-(void) playPause {
    if (self.fromFile) {
        [player setCurrentTime:0];
        [player setVolume:0];
        [self.vc.playButton setTitle:@"Play" forState:UIControlStateNormal];
    } else {
        [player setCurrentTime:0];
        [player setVolume:1.0];
        [self.vc.playButton setTitle:@"Mic" forState:UIControlStateNormal];
    }
    
    self.fromFile = !self.fromFile;
}

-(void) goBig {
    self.isBigBars = !self.isBigBars;
}

@end








//  From file:
//  renderer.mm
//  GLoiler
//
//  Created by Ge Wang on 1/15/15.
//  Copyright (c) 2014 Ge Wang. All rights reserved.
//


//-----------------------------------------------------------------------------
// name: touch_callback()
// desc: the touch call back
//-----------------------------------------------------------------------------
void touch_callback( NSSet * touches, UIView * view,
                    std::vector<MoTouchTrack> & tracks,
                    void * data)
{
    // points
    CGPoint pt;
    CGPoint prev;
    
    // number of touches in set
    NSUInteger n = [touches count];
    NSLog( @"total number of touches: %d", (int)n );
    
    // iterate over all touch events
    for( UITouch * touch in touches )
    {
        // get the location (in window)
        pt = [touch locationInView:view];
        prev = [touch previousLocationInView:view];
        
        // check the touch phase
        switch( touch.phase )
        {
                // begin
            case UITouchPhaseBegan:
            {
                NSLog( @"touch began... %f %f", pt.x, pt.y );
                break;
            }
            case UITouchPhaseStationary:
            {
                NSLog( @"touch stationary... %f %f", pt.x, pt.y );
                break;
            }
            case UITouchPhaseMoved:
            {
                NSLog( @"touch moved... %f %f", pt.x, pt.y );
                break;
            }
                // ended or cancelled
            case UITouchPhaseEnded:
            {
                NSLog( @"touch ended... %f %f", pt.x, pt.y );
                break;
            }
            case UITouchPhaseCancelled:
            {
                NSLog( @"touch cancelled... %f %f", pt.x, pt.y );
                break;
            }
                // should not get here
            default:
                break;
        }
    }
}


// initialize the engine (audio, grx, interaction)
void GLoilerInit()
{
    NSLog( @"init..." );
    
    // set touch callback
    MoTouch::addCallback( touch_callback, NULL );
}


// set graphics dimensions
void GLoilerSetDims( float width, float height )
{
    NSLog( @"set dims: %f %f", width, height );
}