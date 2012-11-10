//
//  main.m
//  page-ready
//
//  Created by Gianni Chiappetta on 2012-11-01.
//  Copyright (c) 2012 Gianni Chiappetta. All rights reserved.
//

#import <stdio.h>
#import <string.h>
#import <getopt.h>
#import <libgen.h>
#import <sysexits.h>
#import <Foundation/Foundation.h>
#import "GCAnalyzer.h"


// Init
const char *prog;
static GC_output output = GC_output_normal;
static struct option longOptions[] = {
  {"verbose",   no_argument,       &output,  1},
  {"silent",    no_argument,       &output, -1},
  {"json",      no_argument,       &output,  2},
  {"cache",     no_argument,       0, 'p'},
  {"help",      no_argument,       0, 'h'},
  {"condition", required_argument, 0, 'c'},
  {"timeout",   required_argument, 0, 't'},
  {"version",   no_argument,       0, 0},
  {0, 0, 0, 0}
};
BOOL shouldKeepRunning = YES;


// Forward Declarations
void usage();

void next(NSEnumerator *e, NSArray *conditions, NSNumber *timeout, NSArray *analyzers, GC_output output, BOOL pageCache);


// Main
int main(int argc, const char **argv)
{
  BOOL pageCache = NO;
  char *timeoutString = strdup(ANALYZER_TIMEOUT);
  prog = basename((char *)argv[0]);
  NSMutableArray *conditions = [NSMutableArray new];
  NSMutableArray *urls = [NSMutableArray new];

  // Option Parsing
  while (1) {
    int optionIndex = 0;
    int c = getopt_long(argc, (char *const*)argv, "hjpc:t:", longOptions, &optionIndex);
    GCCondition *cond;

    if (c == -1)
      break;

    switch (c) {
      case 0:
        if (longOptions[optionIndex].flag != 0)
          break;

        if (strcasecmp("version", longOptions[optionIndex].name) == 0) {
          printf("%s %s\n", prog, PAGE_READY_VERSION);
          exit(EXIT_SUCCESS);
        }

        break;

      case 'c':
        cond = [GCCondition new];
        cond.attempts = @0;
        cond.expr     = @(optarg);
        cond.interval = 0.0;
        cond.met      = NO;
        [conditions addObject:cond];
        break;

      case 'h':
        usage();
        break;


      case 'j':
        output = GC_output_json;
        break;
      
      case 'p':
        pageCache = YES;
        break;

      case 't':
        free(timeoutString);
        timeoutString = strdup(optarg);
        break;

      case '?':
        usage();
        break;

      default:
        abort();
    }
  }

  if (!(optind < argc))
    usage();

  while (optind < argc)
    [urls addObject:@(argv[optind++])];

  // Do we have a pipe?
  if (!isatty(fileno(stdin))) {
    NSFileHandle *input = [NSFileHandle fileHandleWithStandardInput];
    NSData *inputData = [NSData dataWithData:[input readDataToEndOfFile]];
    NSString *inputString = [[NSString alloc] initWithData:inputData encoding:NSUTF8StringEncoding];
    GCCondition *condition = [GCCondition new];
    condition.attempts = @0;
    condition.expr = inputString;
    condition.interval = 0.0;
    condition.met = NO;
    [conditions addObject:condition];
  }

  // Go
  @autoreleasepool {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];

    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber *timeout = [f numberFromString:@(timeoutString)];
    free(timeoutString);

    NSEnumerator *urlEnumerator = [urls objectEnumerator];
    next(urlEnumerator, conditions, timeout, [NSArray new], output, pageCache);

    while (shouldKeepRunning && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
  }
  
  return 0;
}


void next(NSEnumerator *e, NSArray *conditions, NSNumber *timeout, NSArray *analyzers, GC_output output, BOOL pageCache)
{
  NSString *url;
  BOOL canOutput = !(output == GC_output_silent || output == GC_output_json);

  if (url = [e nextObject]) {
    if (canOutput)
      printf(BOLD_ON "%s" BOLD_OFF "\n", [url UTF8String]);

    GCAnalyzer *an = [[GCAnalyzer alloc] initWithString:url];
    an.conditions   = conditions;
    an.timeout      = timeout;
    an.usePageCache = pageCache;

    [an analyzeOnUpdate:^(GCAnalyzer *analyzer){ if (canOutput) [analyzer printStatus]; }
                andThen:^(GCAnalyzer *analyzer){
                  if (canOutput) {
                    if (output == GC_output_normal)
                      [analyzer printSummary];
                    else
                      [analyzer printSummaryVerbose];
                  }
                  next(e, conditions, timeout, [analyzers arrayByAddingObject:analyzer], output, pageCache);
                }];
  }
  else {
    if (output == GC_output_json) {
      NSMutableArray *json = [NSMutableArray new];
      for (GCAnalyzer *analyzer in analyzers) {
        [json addObject:[analyzer toJSON]];
      }
      NSString *jsonString = [json componentsJoinedByString:@",\n"];
      printf("[%s]", [jsonString UTF8String]);
    }
    exit(EXIT_SUCCESS);
  }
}


void usage()
{
  fprintf(stderr, "Usage: %s [-hjp] [--silent | --verbose | --json] [-t seconds] [-c expr] url ...\n\n", prog);
  fprintf(stderr, "    Options:\n");
  fprintf(stderr, "        -c expr, --condition=expr\n");
  fprintf(stderr, "            Javascript expression to be used as a test condition. Multiple expressions may be included.\n\n");
  fprintf(stderr, "        -h, --help\n");
  fprintf(stderr, "            Display this help message.\n\n");
  fprintf(stderr, "        -j, --json\n");
  fprintf(stderr, "            Instead of a text report, return the analysis as JSON.\n\n");
  fprintf(stderr, "        -p, --cache\n");
  fprintf(stderr, "            Enable the page cache. Disabled by default.\n\n");
  fprintf(stderr, "        -t seconds, --timeout=seconds\n");
  fprintf(stderr, "            Timeout in seconds for condition to be met within. Default: %s\n\n", ANALYZER_TIMEOUT);
  fprintf(stderr, "        --silent\n");
  fprintf(stderr, "            No output.\n\n");
  fprintf(stderr, "        --verbose\n");
  fprintf(stderr, "            More detailed output.\n\n");
  fprintf(stderr, "        --version\n");
  fprintf(stderr, "            Show version number and quit.\n\n");
  fprintf(stderr, "    Examples:\n");
  fprintf(stderr, "        %s http://google.com\n\n", prog);
  fprintf(stderr, "        %s -c \"someFunc()\" -c \"anotherFunc()\" -c \"thirdFunc()\" http://wesbos.com http://darcyclarke.me\n\n", prog);
  fprintf(stderr, "        %s -c \"document.readyState == 'complete'\" -t 2.5 http://gf3.ca\n\n", prog);
  fprintf(stderr, "        %s --verbose http://metalabdesign.com < cat your_file.js\n", prog);

  exit(EX_USAGE);
}
