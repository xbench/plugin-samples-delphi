## ApSIC Xbench QA Plugin Sample for Delphi
This repository contains a sample for an ApSIC Xbench QA plugin developed in Embarcadero Delphi.

ApSIC Xbench plugins are 32-bit or 64-bit DLLs.  ApSIC Xbench 3.0 32-bit edition requires a 32-bit DLL and ApSIC Xbench 3.0 64-bit edition requires a 64-bit DLL.  This means that you must create both DLLs if you need to deploy your plugin to several users with various ApSIC Xbench 3.0 editions.

The documentation to develop and deploy ApSIC Xbench QA plugins is found [here](http://www.xbench.net/download/ApSIC.Xbench.3.0.QA.Plug-in.Reference.Guide.pdf).

This sample QA plugin has two functions:
* Show all segments that have a suspicious length (source text too long compared to target text or viceversa)
* Show the 3 longest target strings

This Delphi project has been developed with Delphi XE3 and it generates 32-bit and 64-bit DLLs.  Once compiled, the corresponding DLL must be copied to the same directory where xbench.exe resides, so that it is loaded at startup time.