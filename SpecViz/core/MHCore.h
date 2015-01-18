//
//  MHCore.h
//  SpecViz
//
//  Created by Matthew Horton on 1/16/15.
//  Copyright (c) 2015 Matt Horton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SpecVizViewController.h"

#ifndef __GLoiler__renderer__
#define __GLoiler__renderer__

// initialize the engine (audio, grx, interaction)
void GLoilerInit();
// TODO: cleanup
// set graphics dimensions
void GLoilerSetDims( float width, float height );


#endif /* defined(__GLoiler__renderer__) */

@interface MHCore : NSObject

@property (nonatomic) SpecVizViewController* vc;
@property (nonatomic) BOOL isSpectrum;
@property (nonatomic) BOOL isBigBars;
@property (nonatomic) BOOL fromFile;

-(instancetype)initWithViewController:(SpecVizViewController *)vc;

-(void) coreInit;
-(void) coreRender;
-(void) coreSetDimsWithWidth:(CGFloat)w andHeight:(CGFloat)h;

-(void) changeMode;
-(void) playPause;
-(void) goBig;

@end
