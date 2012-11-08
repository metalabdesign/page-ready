//
//  NSString+Squisher.m
//  page-ready
//
//  Created by Gianni Chiappetta on 2012-11-05.
//  Copyright (c) 2012 Gianni Chiappetta. All rights reserved.
//

#import "NSString+Squisher.h"

@implementation NSString (Squisher)

- (NSString *)squishToLength:(NSUInteger)length
{
  NSString *stripped = [self stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
  
  if (stripped.length <= length)
    return stripped;
  else {
    NSUInteger size = (length - 3) / 2;
    NSString *start = [stripped substringToIndex:size];
    NSString *end   = [stripped substringFromIndex:stripped.length - size];
    return [NSString stringWithFormat:@"%@...%@", start, end];
  }
}

@end
