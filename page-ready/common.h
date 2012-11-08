//
//  common.h
//  Page Ready
//
//  Created by Gianni Chiappetta on 2012-11-02.
//  Copyright (c) 2012 Gianni Chiappetta. All rights reserved.
//

#ifndef Page_Ready_common_h
#define Page_Ready_common_h

#define PAGE_READY_VERSION "0.1.3"

#define PAGE_READY_BUF_SIZE 4096

#define COLOR_RED     "\x1b[31m"
#define COLOR_GREEN   "\x1b[32m"
#define COLOR_YELLOW  "\x1b[33m"
#define COLOR_BLUE    "\x1b[34m"
#define COLOR_MAGENTA "\x1b[35m"
#define COLOR_CYAN    "\x1b[36m"
#define COLOR_WHITE   "\x1b[37m"
#define COLOR_RESET   "\x1b[0m"

#define BOLD_ON  "\x1b[1m"
#define BOLD_OFF "\x1b[22m"

#define UNDERLINE_ON  "\x1b[4m"
#define UNDERLINE_OFF "\x1b[24m"

#define STRING_FAIL    "✖"
#define STRING_INFO    "ℹ"
#define STRING_SUCCESS "✔"

#define SQUISH_LENGTH  80

#define VAL(x) #x
#define STRINGIFY(x) VAL(x)

#define ANALYZER_TIMEOUT_DOUBLE 60.0
#define ANALYZER_TIMEOUT        STRINGIFY(ANALYZER_TIMEOUT_DOUBLE)

#endif
