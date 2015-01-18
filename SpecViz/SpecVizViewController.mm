//
//  SpecVizViewController.m
//  SpecViz
//
//  Created by Matt Horton on 1/15/15.
//  Copyright (c) 2015 Matt Horton. All rights reserved.
//


#import "SpecVizViewController.h"
#import "MHCore.h"

@interface SpecVizViewController()

@property (strong, nonatomic) MHCore *core;
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

- (void)setupGL;
- (void)tearDownGL;
@end

@implementation SpecVizViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.core = [[MHCore alloc] initWithViewController:self];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
    
    // initialize
    [self.core coreInit];
}

- (void)viewDidLayoutSubviews
{
    [self.core coreSetDimsWithWidth:self.view.bounds.size.width andHeight: self.view.bounds.size.height ];
}

- (void)dealloc
{
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }
    
    // Dispose of any resources that can be recreated.
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    // glEnable( GL_DEPTH_TEST );
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    self.effect = nil;
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    //    glClearColor( 1.0f, 1.0f, 0.0f, 1.0f);
    //    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [self.core coreRender];
}

- (IBAction)modeChanged:(UIButton *)sender {
    [self.core changeMode];
}

- (IBAction)playPause:(id)sender{
    [self.core playPause];
}

- (IBAction)goBig:(id)sender {
    [self.core goBig];
}

@end
