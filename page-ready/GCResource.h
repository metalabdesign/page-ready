//
//  GCResource.h
//  page-ready
//
//  Created by Gianni Chiappetta on 2012-11-07.
//  Copyright (c) 2012 MetaLab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GCResource : NSObject
{
  NSUInteger    contentLength;
  NSError      *error;
  NSDate       *finish;
  NSNumber     *id;
  NSURLRequest *request;
  NSDate       *start;
}

@property          NSUInteger    contentLength;
@property (retain) NSNumber     *id;
@property (retain) NSError      *error;
@property (retain) NSDate       *finish;
@property (retain) NSURLRequest *request;
@property (retain) NSDate       *start;

- (NSArray *)humanReadableContentLength;

@end
