//
//  GCResource.m
//  page-ready
//
//  Created by Gianni Chiappetta on 2012-11-07.
//  Copyright (c) 2012 MetaLab. All rights reserved.
//

#import "GCResource.h"

@implementation GCResource

@synthesize contentLength, error, finish, id, request, start;

- (NSString *)humanReadableContentLength
{
  if (!contentLength)
    return @"null";

  char *units[] = {"", "KB", "MB", "GB", "TB", "PB"};
  int e = floor(log(contentLength) / log(1024));
  char amount[12];
  sprintf(amount, "%1.2f%s", contentLength / pow(1024, e), units[e]);
  
  return [NSString stringWithUTF8String:amount];
}

@end
