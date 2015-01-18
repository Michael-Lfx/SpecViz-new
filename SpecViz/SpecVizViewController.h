//
//  SpecVizViewController.h
//  SpecViz
//
//  Created by Matt Horton on 1/15/15.
//  Copyright (c) 2015 Matt Horton. All rights reserved.
//
@class AEAudioController;

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "AEAudioController.h"

@interface SpecVizViewController : GLKViewController;

@property (nonatomic) AEAudioController *audioController;
@property (weak, nonatomic) IBOutlet UIButton *pressMe;
@property (weak, nonatomic) IBOutlet UIButton *playButton;

- (IBAction)modeChanged:(UIButton *)sender;
- (IBAction)playPause:(id)sender;
- (IBAction)goBig:(id)sender;

@end
