Page Ready
==========

Web page performance analyzer. This tool was built to help determine the real-world load times of client-side applications.

Not only does it track resource requests and exceptions, but it also allows you to execute javascript expressions against the pages in question to determine when they're true. This would allow you, for instance, to determine when a specific view is loaded and in the DOM, or when dynamically-fetched content is actually visible to the user, &c…


Prerequisites
-------------

This tool depends on the frameworks in [WebKit Nightly](http://nightly.webkit.org), so be sure to have it downloaded and installed before use.


Compiling
---------

Compiling `page-ready` is as simply as opening the project in XCode and clicking Product → Build (⌘B).


Usage
-----

Usage instructions are included with the tool

```sh
./page-ready -h
```