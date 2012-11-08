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


#pragma mark - Instance Methods

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


#pragma mark - Output Helpers

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
         resourceLoaded, resourceID, exceptionCount, conditionMet, conditionCount);
  
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
    
    // Resources
    printf(UNDERLINE_ON "Resources"  UNDERLINE_OFF "\n");
    if ([resources count]) {
      for (id key in resources) {
        GCResource *resource = [resources objectForKey:key];
        NSString *url = resource.request.URL.absoluteString;
        NSError *error = resource.error;
        
        if (error != nil)
          printf("\t" COLOR_RED STRING_FAIL " %s" COLOR_RESET "\t%s\t%s\n",
                 [[error domain] UTF8String], [[url squishToLength:SQUISH_LENGTH] UTF8String], [[error localizedDescription] UTF8String]);
        else {
          NSTimeInterval interval = [resource.finish timeIntervalSinceDate:resource.start];
          printf("\t" COLOR_GREEN STRING_SUCCESS COLOR_RESET " %f sec [%s]\t%s\n",
                 interval,
                 [[resource humanReadableContentLength] UTF8String],
                 [[url squishToLength:SQUISH_LENGTH] UTF8String]);
        }
      }
    }
    else
      printf("\t" COLOR_BLUE STRING_INFO COLOR_RESET " No resources\n");
    
    // Exceptions
    printf(UNDERLINE_ON "Exceptions" UNDERLINE_OFF "\n");
    if ([exceptions count]) {
      for (GCException *exception in exceptions) {
        printf("\t" COLOR_RED STRING_FAIL COLOR_RESET " %s %s:%d\tWas%s caught\n",
               [exception.exception UTF8String],
               [exception.functionName UTF8String],
               exception.lineno,
               exception.hasHandler ? "" : " not");
      }
    }
    else
      printf("\t" COLOR_BLUE STRING_INFO COLOR_RESET " No exceptions\n");
    
    // Conditions
    printf(UNDERLINE_ON "Conditions" UNDERLINE_OFF "\n");
    if ([_conditions count]) {
      for (GCCondition *condition in _conditions) {
        char *met = condition.met ? COLOR_GREEN STRING_SUCCESS : COLOR_RED STRING_FAIL;
        printf("\t%s" COLOR_RESET " ", met);
        if (condition.met)
          printf("%f sec", condition.interval);
        else
          printf(COLOR_RED "TIMEOUT" COLOR_RESET);
        printf("\t%s\n", [[[condition expr] squishToLength:SQUISH_LENGTH] UTF8String]);
      }
    }
    else
      printf("\t" COLOR_BLUE STRING_INFO COLOR_RESET " No conditions\n");
  }
  printf("\n");
}


#pragma mark - WebView Notifications

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
  
  [self printStatus:webViewProgress];
  
  return request;
}

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource
{
  GCResource *resource = [resources objectForKey:identifier];
  resource.finish = [NSDate date];
  resourceLoaded++;
  
  [self printStatus:webViewProgress];
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
  
  [self printStatus:webViewProgress];
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