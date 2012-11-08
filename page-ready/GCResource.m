//
//  GCResource.m
//  page-ready
//
//  Created by Gianni Chiappetta on 2012-11-07.
//  Copyright (c) 2012 MetaLab. All rights reserved.
//

#import "common.h"
#import "GCResource.h"

@implementation GCResource

@synthesize contentLength, error, finish, id, request, start;

- (NSArray *)humanReadableContentLength
{
  if (!contentLength)
    return @[@"0.00", @"B"];

  char *units[] = {"B", "KB", "MB", "GB", "TB", "PB"};
  int e = floor(log(contentLength) / log(1024));
  char amount[12];
  sprintf(amount, "%1.2f", contentLength / pow(1024, e));
  
  return [NSArray arrayWithObjects:@(amount), @(units[e]), nil];
}

@end
