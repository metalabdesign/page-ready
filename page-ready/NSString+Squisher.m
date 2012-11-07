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
  if (self.length <= length)
    return self;
  else {
    NSUInteger size = (length - 3) / 2;
    NSString *start = [self substringToIndex:size];
    NSString *end = [self substringFromIndex:self.length - size];
    return [NSString stringWithFormat:@"%@...%@", start, end];
  }
}

@end
