---
layout: post
title: "Deploying Xamarin Android Project to x86 emulator"
date: 2017-05-17
categories: article
comments: true
---

At the time of this writing, there is no easy way to build an x86 APK from a Xamarin Android project from Visual Studio 2017.

I discovered this recently after coming across the need to deploy my application to an emulator running a [x86](https://en.wikipedia.org/wiki/X86) image. In fact, Visual Studio 2017 assumes that the used emulator runs an [ARM](https://en.wikipedia.org/wiki/ARM_architecture) image.

After some searching, I found the ["Build ABI Specific APKs"](https://developer.xamarin.com/guides/android/advanced_topics/build-abi-specific-apks/) document in the official Xamarin documentation that describes the multiple steps necessary to build a x86 apk.

After trying out the steps manually with success, it made sense to automate the process in a [Powershell](https://technet.microsoft.com/en-us/library/bb978526.aspx) script.

The script is a available as a [Github Gist](https://gist.github.com/MissaouiChedy/ac4772c11993a72fc1ed13d7fc59c69b) and you can use it without restrictions.


In the following post, we will take a look at: 
- Where to place the script and What environment does it expect?
- How to use the script?
- What steps does it performs?

<a id="download-button" href="https://gist.github.com/MissaouiChedy/ac4772c11993a72fc1ed13d7fc59c69b/archive/dade72345034c883743bbc64748c7216a8d5e07c.zip"><i class="fa fa-cloud-download" aria-hidden="true"></i>
DOWNLOAD SCRIPT</a>
<style>
#download-button
{
display: inline-block;
padding: 0.5em;
font-weight: bold;
text-decoration: none;
font-family: Helvetica;
background-color: black;
color: white;
}
</style>

## Installation

It is recommended to place this script somewhere under the solution folder, for example, under a *"tools"* folder as in the following directory tree:
```
MySolution
|-src
  |-MyAndroidProject
|-tools
  |-Deploy-X86App.ps1
```

The script assumes, of course, that the following *"components"* are properly installed and configured:
- [Visual Studio 2017](https://docs.microsoft.com/en-us/visualstudio/install/install-visual-studio)
- [Xamarin](https://developer.xamarin.com/guides/android/getting_started/installation/windows/)
- [Android SDK](https://developer.xamarin.com/guides/android/getting_started/installation/windows/manual_installation/)

Furthermore, the script relies on the following programs [to be reachable via the system's (or user's) `PATH` variable](https://www.computerhope.com/issues/ch000549.htm), here they are along with there common location: 

- [msbuild](https://github.com/Microsoft/msbuild#microsoftbuild-msbuild) <i class="fa fa-folder" aria-hidden="true"></i>
 `C:\Program Files (x86)\Microsoft Visual Studio\201X\Community\MSBuild\xx.x\Bin`
- [jarsigner](http://docs.oracle.com/javase/7/docs/technotes/tools/windows/jarsigner.html) <i class="fa fa-folder" aria-hidden="true"></i>
 `C:\Program Files\Java\jdk1.x.x_xxx\bin`
- [zipalign](https://developer.android.com/studio/command-line/zipalign.html) <i class="fa fa-folder" aria-hidden="true"></i>
 `~\AppData\Local\Android\sdk\build-tools\xx.x.x\`
- [adb](https://developer.android.com/studio/command-line/adb.html) <i class="fa fa-folder" aria-hidden="true"></i>
 `~\AppData\Local\Android\sdk\platform-tools`

 
## usage

First off, it is possible to view the documentation of the utility by using the [`Get-Help` commandlet](https://msdn.microsoft.com/en-us/powershell/reference/5.1/microsoft.powershell.core/get-help). The documentation contains details and usage examples.

The utility is used by providing a running emulator Id and a Xamarin Android project location:

`.\Deploy-X86App.ps1 emulator-ID -ProjectPath src\MyApp`

The scripts would normally accept a lot of arguments that can be tedious to type each time, fortunately most of them are initialized with nice defaults or are gathered from project files (such as the `AndroidManifest.xml`).

In addition it is possible to provide default values for any script parameter [by modifying the script's `param` statement](http://windowsitpro.com/blog/making-powershell-params).

## functioning

The `Deploy-X86App.ps1` utility script first builds a x86 apk by using `msbuild`, then it signs and zipaligns the generated apk by using respectively `jarsigner` and `zipalign` which is finally deployed in the target emulator via the `adb` utility.

These steps are described in detail in the [Build ABI Specific APKs](https://developer.xamarin.com/guides/android/advanced_topics/build-abi-specific-apks/) document.

## Closing thoughts

*PowerShell* is, in my opinion, the best scripting platform available today. It has been helpful many times more than once to perform and automate repeatable tasks.











