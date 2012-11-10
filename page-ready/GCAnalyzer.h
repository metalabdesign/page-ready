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
  GC_state_page_loaded         = 0x01,
  GC_state_resources_loaded    = 0x02,
  GC_state_conditions_finished = 0x04,
  GC_state_finished            = 0x08
} GC_state;

@interface GCAnalyzer : NSObject
{
  NSArray  *_conditions;
  NSNumber *_timeout;
  NSURL    *_url;
  BOOL      _usePageCache;
}

@property            NSArray  *conditions;
@property            NSNumber *timeout;
@property (readonly) NSURL    *url;
@property            BOOL      usePageCache;

- (id)initWithString:(NSString*)aUrl;

- (id)initWithURL:(NSURL*)aUrl;

- (void)analyze;

- (void)analyzeAndThen:(void (^)(GCAnalyzer *))block;

- (void)analyzeOnUpdate:(void (^)(GCAnalyzer *))updateBlock andThen:(void (^)(GCAnalyzer *))finalBlock;

- (NSString *)toJSON;

- (void)printStatus;

- (void)printSummary;

- (void)printSummaryVerbose;

@end
