//
//  GCAnalyzer.m
//  Page Ready
//
//  Created by Gianni Chiappetta on 2012-11-01.
//  Copyright (c) 2012 Gianni Chiappetta. All rights reserved.
//

#import "GCAnalyzer.h"

Boolean GC_is_thruthy(const void *result)
{
  if (result == nil)
    return false;
  else if (result == (__bridge void *)([WebUndefined undefined]))
    return false;
  else if (CFGetTypeID(result) == CFStringGetTypeID())
    return !(CFStringGetIntValue(result) == 0);
  else if (CFGetTypeID(result) == CFBooleanGetTypeID() && result == kCFBooleanFalse)
    return false;
  else if (CFGetTypeID(result) == CFNumberGetTypeID()) {
    int value;
    CFNumberGetValue(result, kCFNumberIntType, &value);
    return !(value == 0);
  }
  else
    return true;
}

NSString* GC_to_string(const void *result)
{
  if (result == nil)
    return @"nil";
  else if (result == (__bridge void *)([WebUndefined undefined]))
    return @"undefined";
  else if (CFGetTypeID(result) == CFStringGetTypeID())
    return (__bridge NSString *)(result);
  else if (CFGetTypeID(result) == CFBooleanGetTypeID())
    return result == kCFBooleanTrue ? @"true" : @"false";
  else if (CFGetTypeID(result) == CFNumberGetTypeID())
    return [(__bridge NSNumber *)(result) stringValue];
  else
    return [(__bridge id)(result) stringValue]; // Hope for the best!
}

@interface GCAnalyzer ()
{
  int    conditionCount;
  int    conditionMet;
  int    exceptionCount;
  int    resourceID;
  int    resourceFailed;
  int    resourceLoaded;
  int    state;
  double webViewProgress;
  BOOL   jsDebugging;
  
  void (^finalBlock)(GCAnalyzer *);
  void (^updateBlock)(GCAnalyzer *);

  NSArray             *exceptions;
  NSMutableDictionary *resources;
  NSDate              *loadStart;
  NSDate              *loadEnd;
  WebView             *webView;
}
@end


@implementation GCAnalyzer

@synthesize timeout = _timeout;
@synthesize url     = _url;

- (id)initWithString:(NSString *)aUrl
{
  return [self initWithURL:[NSURL URLWithString:aUrl]];
}

- (id)initWithURL:(NSURL *)aUrl
{
  if ((self = [super init])) {
    conditionCount  = 0;
    conditionMet    = 0;
    exceptionCount  = 0;
    resourceID      = 0;
    resourceFailed  = 0;
    resourceLoaded  = 0;
    state           = 0;
    webViewProgress = 0.0;
    jsDebugging     = YES; // TODO Make this optional
    
    _conditions = [NSArray new];
    _timeout    = @(ANALYZER_TIMEOUT_DOUBLE);
    _url        = aUrl;
    
    exceptions = [NSArray new];
    resources  = [NSMutableDictionary dictionaryWithCapacity:0];
    webView    = [WebView new];
    webView.frameLoadDelegate    = self;
    webView.resourceLoadDelegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewProgressStarted:)
                                                 name:WebViewProgressStartedNotification
                                               object:webView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewProgressEstimate:)
                                                 name:WebViewProgressEstimateChangedNotification
                                               object:webView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewProgressFinished:)
                                                 name:WebViewProgressFinishedNotification
                                               object:webView];
  }
  
  return self;
}

- (void)setConditions:(NSArray *)conditions
{
  _conditions = conditions;
  conditionCount = (int)[_conditions count];
}

- (NSArray *)conditions
{
  return _conditions;
}

- (void)onUpdate
{
  if (updateBlock)
    updateBlock(self);
}


#pragma mark - Instance Methods

- (void)analyze
{
  [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:_url]];
}

- (void)analyzeAndThen:(void (^)(GCAnalyzer *))_block
{
  finalBlock = _block;
  [self analyze];
}

- (void)analyzeOnUpdate:(void (^)(GCAnalyzer *))_updateBlock andThen:(void (^)(GCAnalyzer *))_finalBlock
{
  updateBlock = _updateBlock;
  [self analyzeAndThen:_finalBlock];
}


#pragma mark - JSON Encoder

- (NSString *)toJSON
{
  NSMutableArray *conditionDictionaries = [NSMutableArray new];
  NSMutableArray *exceptionDictionaries = [NSMutableArray new];
  NSMutableArray *resourceDictionaries  = [NSMutableArray new];
  
  // Conditions
  for (GCCondition *condition in _conditions) {
    [conditionDictionaries addObject:@{
     @"attempts":   condition.attempts,
     @"expr":       condition.expr,
     @"interval":   @(condition.interval),
     @"met":        [NSNumber numberWithBool:condition.met]
     }];
  }
  
  // Exceptions
  for (GCException *exception in exceptions) {
    [exceptionDictionaries addObject:@{
      /*@"caller": exception.caller,*/
     @"exception":    GC_to_string((__bridge const void *)(exception.exception)),
     @"functionName": exception.functionName ?: @"(null)",
     @"hasHandler":   [NSNumber numberWithBool:exception.hasHandler],
     @"lineno":       @(exception.lineno)
    }];
  }
 
  // Resources
  for (id key in resources) {
    GCResource *resource = resources[key];
    NSMutableDictionary *dicks = [NSMutableDictionary dictionaryWithDictionary:@{
     @"contentLength": @(resource.contentLength),
     @"id":            resource.id,
     @"finish":        @([resource.finish timeIntervalSince1970]),
     @"interval":      @([resource.finish timeIntervalSinceDate:resource.start]),
     @"url":           resource.request.URL.absoluteString,
     @"start":         @([resource.start timeIntervalSince1970])
     }];
    
    if (resource.error != nil)
      dicks[@"error"] = @{@"domain": resource.error.domain, @"localizedDescription": resource.error.localizedDescription};
    
    [resourceDictionaries addObject:dicks];
  }

  NSDictionary *json = [NSDictionary dictionaryWithObjectsAndKeys:
                        conditionDictionaries,                          @"conditions",
                        exceptionDictionaries,                          @"exceptions",
                        resourceDictionaries,                           @"resources",
                        @([loadStart timeIntervalSince1970]),           @"loadStart",
                        @([loadEnd   timeIntervalSince1970]),           @"loadEnd",
                        @([loadEnd   timeIntervalSinceDate:loadStart]), @"interval",
                        _timeout,                                       @"timeout",
                        _url.absoluteString,                            @"url",
                        nil];
  
  return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:json
                                                                        options:NSJSONWritingPrettyPrinted
                                                                          error:NULL]
                               encoding:NSUTF8StringEncoding];
}


#pragma mark - Output Methods

- (void)maybeFinish
{
  if (state & GC_state_finished)
    return;
  
  if ((state & GC_state_page_loaded) &&
      (state & GC_state_resources_loaded) &&
      (state & GC_state_conditions_finished)) {
    state |= GC_state_finished;
    
    if (finalBlock)
      finalBlock(self);
  }
}

- (void)printStatus
{
  int i;
  int progressInt = round(webViewProgress * 20.0);
  
  printf("Page Load: %i%% [" COLOR_GREEN, progressInt * 5);
  for (i = 0; i < progressInt; i++)
    printf("▮");
  printf(COLOR_RESET);
  for (i = 0; i < 20 - progressInt; i++)
    printf("▮");
  printf("] Resources: %i/%i loaded - Exceptions: %i - Conditions: %d/%d met\r",
         resourceLoaded, resourceID, exceptionCount, conditionMet, conditionCount);
  
  fflush(stdout);
}

- (void)printSummary
{
  printf("\33[2K\r");
  fflush(stdout);
  
  printf(UNDERLINE_ON "Page Load"  UNDERLINE_OFF "\t%fsec\n", [loadEnd timeIntervalSinceDate:loadStart]);
  printf(UNDERLINE_ON "Resources"  UNDERLINE_OFF "\t%i requested, %i loaded\n", resourceID, resourceLoaded);
  printf(UNDERLINE_ON "Exceptions" UNDERLINE_OFF "\t%i raised\n", exceptionCount);
  printf(UNDERLINE_ON "Conditions" UNDERLINE_OFF "\t%d specified, %d met\n", conditionCount, conditionMet);
  
  printf("\n");
}

- (void)printSummaryVerbose
{
  printf("\33[2K\r");
  fflush(stdout);
  
  printf(UNDERLINE_ON "Page Load"  UNDERLINE_OFF "\n");
  printf(STRING_INDENT COLOR_GREEN STRING_SUCCESS COLOR_RESET " %.5f" COLOR_GREY "sec" COLOR_RESET "\n",
         [loadEnd timeIntervalSinceDate:loadStart]);
  
  // Resources
  printf("\n" UNDERLINE_ON "Resources"  UNDERLINE_OFF "\n");
  if ([resources count]) {
    for (id key in resources) {
      GCResource *resource = [resources objectForKey:key];
      NSString   *url      = resource.request.URL.absoluteString;
      NSError    *error    = resource.error;
      
      if (error != nil)
        printf(STRING_INDENT COLOR_RED STRING_FAIL COLOR_RESET " %-16s %10s %-*s %s\n",
               [[error domain] UTF8String],
               " ",
               SQUISH_LENGTH + 3,
               [[url squishToLength:SQUISH_LENGTH] UTF8String],
               [[error localizedDescription] UTF8String]);
      else {
        char interval[24];
        sprintf(interval, "%.5f" COLOR_GREY "sec" COLOR_RESET, [resource.finish timeIntervalSinceDate:resource.start]);
        NSArray *size = [resource humanReadableContentLength];
        printf(STRING_INDENT COLOR_GREEN STRING_SUCCESS COLOR_RESET " %-26s %7s" COLOR_GREY "%-2s" COLOR_RESET " %-*s\n",
               interval,
               [[size objectAtIndex:0] UTF8String],
               [[size objectAtIndex:1] UTF8String],
               SQUISH_LENGTH + 3,
               [[url squishToLength:SQUISH_LENGTH] UTF8String]);
      }
    }
  }
  else
    printf(STRING_INDENT COLOR_BLUE STRING_INFO COLOR_RESET " No resources\n");
  
  // Exceptions
  printf("\n" UNDERLINE_ON "Exceptions" UNDERLINE_OFF "\n");
  if ([exceptions count]) {
    for (GCException *exception in exceptions) {
      printf(STRING_INDENT COLOR_RED STRING_FAIL COLOR_RESET " %-18s %8s %s:%d\n",
             [GC_to_string((__bridge const void *)(exception.exception)) UTF8String],
             exception.hasHandler ? "caught" : "uncaught",
             [exception.functionName UTF8String],
             exception.lineno);
    }
  }
  else
    printf(STRING_INDENT COLOR_BLUE STRING_INFO COLOR_RESET " No exceptions\n");
  
  // Conditions
  printf("\n" UNDERLINE_ON "Conditions" UNDERLINE_OFF "\n");
  if ([_conditions count]) {
    for (GCCondition *condition in _conditions) {
      char *met = condition.met ? COLOR_GREEN STRING_SUCCESS : COLOR_RED STRING_FAIL;
      printf(STRING_INDENT "%s" COLOR_RESET " ", met);
      if (condition.met) {
        char interval[24];
        sprintf(interval,  "%.5f" COLOR_GREY "sec" COLOR_RESET, condition.interval);
        printf("%-26s", interval);
      }
      else
        printf(COLOR_RED "%-17s" COLOR_RESET, "TIMEOUT");
      printf("  %s\n", [[[condition expr] squishToLength:SQUISH_LENGTH] UTF8String]);
    }
  }
  else
    printf(STRING_INDENT COLOR_BLUE STRING_INFO COLOR_RESET " No conditions\n");
  
  printf("\n");
}


#pragma mark - WebView Notifications

- (void)webViewProgressStarted:(NSNotification *)notification
{
  loadStart = [NSDate date];
  [self onUpdate];
  [self testAllConditionsUntilDone];
}

- (void)webViewProgressEstimate:(NSNotification *)notification
{
  webViewProgress = [notification.object estimatedProgress];
  [self onUpdate];
}

- (void)webViewProgressFinished:(NSNotification *)notification
{
  loadEnd = [NSDate date];
  [self onUpdate];
}


#pragma mark - Frame Load Delegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
  state |= GC_state_page_loaded;
  [self maybeFinish];
}


#pragma mark - Resource Load Delegate

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource
{
  return [NSNumber numberWithInt:resourceID++];
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
  GCResource *resource = [GCResource new];
  resource.id      = identifier;
  resource.request = request;
  resource.start   = [NSDate date];
  [resources setObject:resource forKey:identifier];
  
  [self onUpdate];
  
  return request;
}

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource
{
  GCResource *resource = [resources objectForKey:identifier];
  resource.finish = [NSDate date];
  resourceLoaded++;
  
  [self onUpdate];
  [self performSelector:@selector(resourcesMaybeFinishedLoading) withObject:nil afterDelay:0.5];
}

- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource
{
  GCResource *resource = [resources objectForKey:identifier];
  resource.error = error;
  resourceFailed++;
}

- (void)webView:(WebView *)sender resource:(id)identifier didReceiveContentLength:(NSUInteger)length fromDataSource:(WebDataSource *)dataSource
{
  GCResource *resource = [resources objectForKey:identifier];
  resource.contentLength = (resource.contentLength || 0) + length;
}

- (void)resourcesMaybeFinishedLoading
{
  if ((resourceLoaded + resourceFailed) != resourceID)
    [self performSelector:@selector(resourcesMaybeFinishedLoading) withObject:nil afterDelay:0.5];
  else {
    state |= GC_state_resources_loaded;
    [self maybeFinish];
  }
}


#pragma mark - JavaScript Debugging

- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame
{
  if (jsDebugging)
    [sender setScriptDebugDelegate:self];
}

- (void)webView:(WebView *)webView exceptionWasRaised:(WebScriptCallFrame *)frame hasHandler:(BOOL)hasHandler sourceId:(WebSourceId)sid line:(int)lineno forWebFrame:(WebFrame *)webFrame
{
  GCException *exception = [GCException new];
  exception.caller       = [frame caller];
  exception.functionName = [frame functionName];
  exception.hasHandler   = hasHandler;
  exception.lineno       = lineno;
  exception.sid          = sid;
  
  if (JSValueIsObject(JSGlobalContextCreate(NULL), [[frame exception] JSObject])) {
    [[webFrame windowObject] setValue:[frame exception] forKey:@"__GC_frame_exception"];
    id objectRef = [[webFrame windowObject] evaluateWebScript:@"__GC_frame_exception.constructor.name"];
    [[webFrame windowObject] setValue:nil forKey:@"__GC_frame_exception"];
    exception.exception = objectRef;
  }
  else {
    exception.exception = [frame exception];
  }

  exceptionCount++;
  exceptions = [exceptions arrayByAddingObject:exception];
  
  [self onUpdate];
}


#pragma mark - Condition Testing

-(void)testAllConditionsUntilDone
{
  if ([[NSDate date] timeIntervalSinceDate:loadStart] >= [_timeout doubleValue]) {
    state |= GC_state_conditions_finished;
    [self maybeFinish];
    return;
  }
  
  conditionMet = 0;
  Boolean done = true;
  GCCondition *condition;
  NSEnumerator *e = [_conditions objectEnumerator];
  while (condition = [e nextObject]) {
    if (!condition.met)
      [self testCondition:condition];
    
    if (condition.met)
      conditionMet++;
    else
      done = false;
  }
  
  if (done) {
    state |= GC_state_conditions_finished;
    [self maybeFinish];
    return;
  }
  
  [self performSelector:@selector(testAllConditionsUntilDone) withObject:nil afterDelay:0.1];
}

-(void)testCondition:(GCCondition *)condition
{
  if (condition.met)
    return;
    
  id result = [[webView windowScriptObject] evaluateWebScript:condition.expr];
  Boolean truthy = GC_is_thruthy((__bridge const void *)(result));
  
  condition.attempts = [NSNumber numberWithInt:[condition.attempts intValue] + 1];
  condition.interval = [[NSDate date] timeIntervalSinceDate:loadStart];
  if (truthy)
    condition.met = YES;
}

@end