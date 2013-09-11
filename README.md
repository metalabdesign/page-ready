Page Ready
==========

Web page performance analyzer. This tool was built to help determine the
real-world load times of client-side applications.

Not only does it track resource requests and exceptions, but it also allows you
to execute javascript expressions against the pages in question to determine
when they're true. This would allow you, for instance, to determine when
a specific view is loaded and in the DOM, or when dynamically-fetched content
is actually visible to the user, &c…

![example run](http://f.cl.ly/items/1X3r470U2D0K080P453J/page_ready.PNG)


Prerequisites
-------------

This tool depends on the frameworks in [WebKit
Nightly](http://nightly.webkit.org), so be sure to have it downloaded and
installed before use.


Downloading
-----------

With each release a new binary compiled for OS X 10.8 is uploaded and can be
found in the [downloads section](https://github.com/metalabdesign/page-ready/downloads).


Compiling
---------

Compiling `page-ready` is as simple as opening the project in XCode and
clicking Product → Build (⌘B).


Usage
-----

```
Usage: page-ready [-hjp] [--silent | --verbose | --json] [-t seconds] [-c expr] url ...

    Options:
        -c expr, --condition=expr
            Javascript expression to be used as a test condition. Multiple expressions may be included.

        -h, --help
            Display this help message.

        -j, --json
            Instead of a text report, return the analysis as JSON.

        -p, --cache
            Enable the page cache. Disabled by default.

        -t seconds, --timeout=seconds
            Timeout in seconds for condition to be met within. Default: 60.0

        --silent
            No output.

        --verbose
            More detailed output.

        --version
            Show version number and quit.

    Examples:
        page-ready http://google.com

        page-ready -c "someFunc()" -c "anotherFunc()" -c "thirdFunc()" http://wesbos.com http://darcyclarke.me

        page-ready -c "document.readyState == 'complete'" -t 2.5 http://gf3.ca

        page-ready --verbose http://metalabdesign.com < cat your_file.js
```

Usage instructions can also be viewed with the tool:

```sh
./page-ready -h
```
