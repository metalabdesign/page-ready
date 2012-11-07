//
//  GCContainer.h
//  Page Ready
//
//  Created by Gianni Chiappetta on 2012-11-04.
//  Copyright (c) 2012 Gianni Chiappetta. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GCCondition : NSObject
{
  NSNumber       *attempts;
  NSString       *expr;
  NSTimeInterval  interval;
  BOOL            met;
}

@property (retain) NSNumber       *attempts;
@property (retain) NSString       *expr;
@property          NSTimeInterval  interval;
@property          BOOL            met;

@end
