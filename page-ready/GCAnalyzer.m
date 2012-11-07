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
  
  void (^block)(void);

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
@synthesize verbose = _verbose;

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
    _verbose    = GC_verbosity_normal;
    
    exceptions = [NSArray new];
    resources  = [NSMutableDictionary dictionaryWithCapacity:0];
    webView    = [WebView new];
    webView.frameLoadDelegate = self;
    webView.resourceLoadDelegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webViewProgressStarted:) name:WebViewProgressStartedNotification object:webView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webViewProgressEstimate:) name:WebViewProgressEstimateChangedNotification object:webView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webViewProgressFinished:) name:WebViewProgressFinishedNotification object:webView];
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


#pragma mark -
#pragma mark Instance Methods

- (void)analyze
{
  if (_verbose != GC_verbosity_silent)
    printf(BOLD_ON "%s" BOLD_OFF "\n", [[_url absoluteString] UTF8String]);
  [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:_url]];
}

- (void)analyzeThen:(void (^)(void))aBlock
{
  block = aBlock;
  [self analyze];
}


#pragma mark -
#pragma mark Output Helpers

- (void)maybeFinish
{
  if (state & GC_state_finished)
    return;
  
  if ((state & GC_state_page_loaded) &&
      (state & GC_state_resources_loaded) &&
      (state & GC_state_conditions_finished)) {
    state |= GC_state_finished;
    [self printSummary];
    if (block)
      block();
  }
}

- (void)printStatus:(double)progress
{
  if (_verbose == GC_verbosity_silent)
    return;
  
  int i;
  int progressInt = round(progress * 20.0);
  
  printf("Page Load: %i%% [" COLOR_GREEN, progressInt * 5);
  for (i = 0; i < progressInt; i++)
    printf("▮");
  printf(COLOR_RESET);
  for (i = 0; i < 20 - progressInt; i++)
    printf("▮");
  printf("] Resources: %i/%i loaded - Exceptions: %i - Conditions: %d/%d met\r",
         resourceID, resourceLoaded, exceptionCount, conditionMet, conditionCount);
  
  fflush(stdout);
}

- (void)printSummary
{
  if (_verbose == GC_verbosity_silent)
    return;
  
  printf("\33[2K\r");
  fflush(stdout);
  
  if (_verbose == GC_verbosity_normal) {
    printf(UNDERLINE_ON "Page Load"  UNDERLINE_OFF "\t%fsec\n", [loadEnd timeIntervalSinceDate:loadStart]);
    printf(UNDERLINE_ON "Resources"  UNDERLINE_OFF "\t%i requested, %i loaded\n", resourceID, resourceLoaded);
    printf(UNDERLINE_ON "Exceptions" UNDERLINE_OFF "\t%i raised\n", exceptionCount);
    printf(UNDERLINE_ON "Conditions" UNDERLINE_OFF "\t%d specified, %d met\n", conditionCount, conditionMet);
  }
  else {
    printf(UNDERLINE_ON "Page Load"  UNDERLINE_OFF "\n");
    printf("\t" COLOR_GREEN STRING_SUCCESS COLOR_RESET " %f sec\n", [loadEnd timeIntervalSinceDate:loadStart]);
    
    printf(UNDERLINE_ON "Resources"  UNDERLINE_OFF "\n");
    if ([resources count]) {
      for (id key in resources) {
        NSDictionary *resource = [resources objectForKey:key];
        NSTimeInterval interval = [[resource objectForKey:@"finish"] timeIntervalSinceDate:[resource objectForKey:@"start"]];
        NSString *url = ((NSURLRequest *)[resource objectForKey:@"request"]).URL.absoluteString;
        printf("\t" COLOR_GREEN STRING_SUCCESS COLOR_RESET " %f sec\t%s\n",
               interval, [[url squishToLength:63] UTF8String]);
      }
    }
    else
      printf("\t" COLOR_BLUE STRING_INFO COLOR_RESET " No resources\n");
    
    printf(UNDERLINE_ON "Exceptions" UNDERLINE_OFF "\n");
    if ([exceptions count]) {
      for (NSDictionary *exception in exceptions) {
        printf("\t" COLOR_RED STRING_FAIL COLOR_RESET " %s %s:%d\tWas%s caught\n",
               [[exception objectForKey:@"exception"] UTF8String],
               [[exception objectForKey:@"functionName"] UTF8String],
               [[exception objectForKey:@"lineno"] intValue],
               [[exception objectForKey:@"hasHandler"] boolValue] ? "" : " not");
      }
    }
    else
      printf("\t" COLOR_BLUE STRING_INFO COLOR_RESET " No exceptions\n");
    
    printf(UNDERLINE_ON "Conditions" UNDERLINE_OFF "\n");
    if ([_conditions count]) {
      for (GCCondition *condition in _conditions) {
        char *met = condition.met ? COLOR_GREEN STRING_SUCCESS : COLOR_RED STRING_FAIL;
        printf("\t%s" COLOR_RESET " %f sec\t%s\n", met, condition.interval, [[[condition expr] squishToLength:63] UTF8String]);
      }
    }
    else
      printf("\t" COLOR_BLUE STRING_INFO COLOR_RESET " No conditions\n");
  }
  printf("\n");
}


#pragma mark -
#pragma mark WebView Notifications

- (void)webViewProgressStarted:(NSNotification *)notification
{
  loadStart = [NSDate date];
  [self printStatus:webViewProgress];
  [self testAllConditionsUntilDone];
}

- (void)webViewProgressEstimate:(NSNotification *)notification
{
  webViewProgress = [notification.object estimatedProgress];
  [self printStatus:webViewProgress];
}

- (void)webViewProgressFinished:(NSNotification *)notification
{
  loadEnd = [NSDate date];
  [self printStatus:webViewProgress];
}


#pragma mark -
#pragma mark Frame Load Delegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
  state |= GC_state_page_loaded;
  [self maybeFinish];
}


#pragma mark -
#pragma mark Resource Load Delegate

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource
{
  return [NSNumber numberWithInt:resourceID++];
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
  NSMutableDictionary *dict = [NSMutableDictionary
                               dictionaryWithObjects:@[request,    [NSDate date]]
                                             forKeys:@[@"request", @"start"]];
  [resources setObject:dict forKey:identifier];
  
  [self printStatus:webViewProgress];
  
  return request;
}

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource
{
  NSMutableDictionary *res = [resources objectForKey:identifier];
  [res setObject:[NSDate date] forKey:@"finish"];
  resourceLoaded++;
  
  [self printStatus:webViewProgress];
  [self performSelector:@selector(resourcesMaybeFinishedLoading:) withObject:nil afterDelay:0.5];
}

- (void)resourcesMaybeFinishedLoading:(NSNumber *)obj
{
  if (resourceLoaded != resourceID && (obj == nil || [obj intValue] < 10)) // XXX Retry for up to 5 seconds
    [self performSelector:@selector(resourcesMaybeFinishedLoading:) withObject:[NSNumber numberWithInt:0] afterDelay:0.5];
  else {
    state |= GC_state_resources_loaded;
    [self maybeFinish];
  }
}


#pragma mark -
#pragma mark JavaScript Debugging

- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame
{
//  if (jsDebugging)
  [sender setScriptDebugDelegate:self];
}

- (void)webView:(WebView *)webView exceptionWasRaised:(WebScriptCallFrame *)frame hasHandler:(BOOL)hasHandler sourceId:(WebSourceId)sid line:(int)lineno forWebFrame:(WebFrame *)webFrame
{
  NSMutableDictionary *exception = [NSMutableDictionary dictionaryWithCapacity:6];
  if ([frame caller])
    [exception setObject:[frame caller] forKey:@"caller"];
  if ([frame exception]) {
    [[webFrame windowObject] setValue:[frame exception] forKey:@"__GC_frame_exception"];
    id objectRef = [[webFrame windowObject] evaluateWebScript:@"__GC_frame_exception.constructor.name"];
    [[webFrame windowObject] setValue:nil forKey:@"__GC_frame_exception"];
    [exception setObject:objectRef forKey:@"exception"];
  }
  if([frame functionName])
    [exception setObject:[frame functionName] forKey:@"functionName"];
  [exception setObject:[NSNumber numberWithBool:hasHandler] forKey:@"hasHandler"];
  [exception setObject:@(lineno) forKey:@"lineno"];
  [exception setObject:@(sid) forKey:@"sid"];

  exceptionCount++;
  exceptions = [exceptions arrayByAddingObject:exception];
  
  [self printStatus:webViewProgress];
}


#pragma mark -
#pragma mark Condition Testing

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

#pragma mark - WebScriptObject Iterators

+ (NSArray *)arrayWithWebScriptObject:(WebScriptObject *)obj
{
  NSMutableArray *ret = [NSMutableArray array];
  NSUInteger count = [[obj valueForKey:@"length"] integerValue]; //exception occurs if it is associative array.
  unsigned i;
  for (i = 0; i < count; i++) {
    [ret addObject:[obj webScriptValueAtIndex:i]];
  }
  return ret;
}

+ (NSDictionary *)dictionaryWithWebScriptObject:(WebScriptObject *)obj
                                webScriptObject:(WebScriptObject *)scriptObj
{
  NSMutableDictionary *ret= [NSMutableDictionary dictionary];
  id keys= [scriptObj callWebScriptMethod:@"_f0_"
                            withArguments:[NSArray arrayWithObjects:obj, nil]];
  NSArray *keyAry= [self arrayWithWebScriptObject:keys];
  unsigned i;
  for(i= 0; i<[keyAry count]; i++) {
    NSString *key= [keyAry objectAtIndex:i];
    [ret setObject:[obj valueForKey:key] forKey:key];
  }
  return ret;
}

@end
