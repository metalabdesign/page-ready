//
//  main.m
//  page-ready
//
//  Created by Gianni Chiappetta on 2012-11-01.
//  Copyright (c) 2012 Gianni Chiappetta. All rights reserved.
//

#import <string.h>
#import <getopt.h>
#import <libgen.h>
#import <sysexits.h>
#import <Foundation/Foundation.h>
#import "GCAnalyzer.h"


// Init
const char *prog;
static GC_verbosity verbose = GC_verbosity_normal;
static struct option longOptions[] = {
  {"verbose",   no_argument,       &verbose,  1},
  {"silent",    no_argument,       &verbose, -1},
  {"help",      no_argument,       0, 'h'},
  {"condition", required_argument, 0, 'c'},
  {"timeout",   required_argument, 0, 't'},
  {0, 0, 0, 0}
};
BOOL shouldKeepRunning = YES;


// Forward Declarations
void usage();

void next(NSEnumerator *e, NSArray *conditions, NSNumber *timeout, GC_verbosity verbose);


// Main
int main(int argc, const char **argv)
{
  char *timeoutString = strdup(ANALYZER_TIMEOUT);
  prog = basename((char *)argv[0]);
  NSMutableArray *conditions = [NSMutableArray new];
  NSMutableArray *urls = [NSMutableArray new];
  
  // Option Parsing
  while (1) {
    int optionIndex = 0;
    int c = getopt_long(argc, (char *const*)argv, "hc:t:", longOptions, &optionIndex);
    GCCondition *cond;
    
    if (c == -1)
      break;
    
    switch (c) {
      case 0:
        // All long options have short counterparts
        break;
        
      case 'h':
        usage();
        break;
        
      case 'c':
        cond = [GCCondition new];
        cond.attempts = @0;
        cond.expr     = @(optarg);
        cond.interval = 0.0;
        cond.met      = NO;
        [conditions addObject:cond];
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
  
  // Go
  @autoreleasepool {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber *timeout = [f numberFromString:@(timeoutString)];
    free(timeoutString);
    
    NSEnumerator *urlEnumerator = [urls objectEnumerator];
    next(urlEnumerator, conditions, timeout, verbose);
    
    while (shouldKeepRunning && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
  }
  return 0;
}


void next(NSEnumerator *e, NSArray *conditions, NSNumber *timeout, GC_verbosity verbose)
{
  NSString *url;
  if (url = [e nextObject]) {
    GCAnalyzer *an = [[GCAnalyzer alloc] initWithString:url];
    an.timeout = timeout;
    an.conditions = conditions;
    an.verbose = verbose;
    [an analyzeThen:^(){
      next(e, conditions, timeout, verbose);
    }];
  }
  else
    exit(EXIT_SUCCESS);
}


void usage()
{
  fprintf(stderr, "Usage: %s [-h] [--silent | --verbose] [-t seconds] [-c expr] url ...\n\n", prog);
  fprintf(stderr, "    Options:\n");
  fprintf(stderr, "        -c expr, --condition=expr\n");
  fprintf(stderr, "            Javascript expression to be used as a test condition. Multiple expressions may be included.\n\n");
  fprintf(stderr, "        -h, --help\n");
  fprintf(stderr, "            Display this help message.\n\n");
  fprintf(stderr, "        -t seconds, --timeout=seconds\n");
  fprintf(stderr, "            Timeout in seconds for condition to be met within. Default: %s\n\n", ANALYZER_TIMEOUT);
  fprintf(stderr, "        --silent\n");
  fprintf(stderr, "            No output.\n\n");
  fprintf(stderr, "        --verbose\n");
  fprintf(stderr, "            More detailed output.\n\n");
  fprintf(stderr, "    Examples:\n");
  fprintf(stderr, "        %s http://google.com\n\n", prog);
  fprintf(stderr, "        %s -c \"document.readyState == 'complete'\" -t 2.5 http://gf3.ca\n\n", prog);
  fprintf(stderr, "        %s --verbose -c \"`cat ./yourFile.js`\" http://metalabdesign.com\n", prog);
  
  exit(EX_USAGE);
}
