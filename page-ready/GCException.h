//
//  GCException.h
//  page-ready
//
//  Created by Gianni Chiappetta on 2012-11-07.
//  Copyright (c) 2012 MetaLab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebScriptDebugDelegate.h>

@interface GCException : NSObject
{
  WebScriptCallFrame *caller;
  id                  exception;
  NSString           *functionName;
  BOOL                hasHandler;
  int                 lineno;
  WebSourceId         sid;
}

@property (retain) WebScriptCallFrame *caller;
@property          id                  exception;
@property (retain) NSString           *functionName;
@property          BOOL                hasHandler;
@property          int                 lineno;
@property          WebSourceId         sid;

@end
