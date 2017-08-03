---
layout: post
title: "make sure to start with a Xamarin forms project"
date: 2017-08-03
categories: article
comments: true
---

I am currently working on a Xamarin project that we started as a [Xamarin Android](https://developer.xamarin.com/guides/android/getting_started/) application. We recently tried to migrate the application to a [Xamarin Forms](https://www.xamarin.com/forms) project but it turned out [to be pretty non trivial](https://forums.xamarin.com/discussion/comment/200380/#Comment_200380).

Xamarin is a cross platform solution for building mobile apps that run on Android, iOS and Windows Phone, but Xamarin is not quite cross platform as are Html 5 based solutions such as [Cordova](https://cordova.apache.org) and [PhoneGap](https://phonegap.com) in which a single application is built for all mobile platforms.


Xamarin allows developers to leverage native APIs as well as to get a strong native look and feel while sharing as much code as possible.

A Xamarin.Forms solution (in Visual Studio) contains usually the following projects which contains the artifacts shared between all platforms:

- The core logic project that is usually a [PCL](https://docs.microsoft.com/en-us/dotnet/standard/cross-platform/cross-platform-development-with-the-portable-class-library) or a [netstandard](https://blogs.msdn.microsoft.com/dotnet/2016/09/26/introducing-net-standard/) library
- A Xamarin.Forms project containing [XAML](https://msdn.microsoft.com/en-us/library/cc295302.aspx) shared views that can be used in all the supported mobile platforms. Interfaces abstracting platform specific APIs can be defined here as well

The visual studio solution contains also a project for each targeted platform, these platform specific projects contains the following elements:

- Concrete implementation of abstract interfaces using the platform specific APIs
- Complex views that require high coupling with the native SDK (displaying a [Google Maps map](https://developers.google.com/maps/documentation/android-api/) for example)
- *"Style sheets"* (usually xml) specifying how the shared XAML views should be rendered in the specific platform 

## recommendation

When deployment on multiple platforms is needed always start with a Xamarin.Forms project even when you are focusing on a single platform in the early stages and make sure to place the core logic in *PCL* or *netstandard* library project.

We thought that it would be easy to migrate a project initially started as Xamarin.Android but it turned out to require the creation of a new project and to move the code to the new project which we cannot afford in the present moment and which forces us to support only [Android]() for our current release scope <i class="fa fa-frown-o" aria-hidden="true"></i>. 


