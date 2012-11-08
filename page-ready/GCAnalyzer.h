//
//  GCAnalyzer.h
//  Page Ready
//
//  Created by Gianni Chiappetta on 2012-11-01.
//  Copyright (c) 2012 Gianni Chiappetta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <JavaScriptCore/JSObjectRefPrivate.h>
#import <WebKit/WebKit.h>
#import <WebKit/WebViewPrivate.h>
#import <WebKit/WebScriptDebugDelegate.h>
#import "common.h"
#import "GCCondition.h"
#import "GCException.h"
#import "GCResource.h"
#import "NSString+Squisher.h"

typedef enum {
  GC_verbosity_silent  = -1,
  GC_verbosity_normal  = 0,
  GC_verbosity_verbose = 1
} GC_verbosity;

typedef enum {
  GC_state_page_loaded         = 0x01,
  GC_state_resources_loaded    = 0x02,
  GC_state_conditions_finished = 0x04,
  GC_state_finished            = 0x08
} GC_state;

@interface GCAnalyzer : NSObject
{
  NSURL        *_url;
  NSNumber     *_timeout;
  NSArray      *_conditions;
  GC_verbosity  _verbose;
}

@property (readonly) NSURL        *url;
@property            NSNumber     *timeout;
@property            NSArray      *conditions;
@property            GC_verbosity  verbose;

- (id)initWithString:(NSString*)aUrl;

- (id)initWithURL:(NSURL*)aUrl;

- (void)analyze;

- (void)analyzeThen:(void (^)(void))block;

@end
