---
layout: post
title: "React<br/> a library for building tags"
date: 2017-10-25
categories: article
comments: true
---

Recently, I was doing client work on a web application built with [React](https://reactjs.org/) and server-side rendered by using [next js.](https://github.com/zeit/next.js)

When getting up to speed with React, I was surprised to discover that it is a very simple library that allows you to basically create components which can be thought of as html tags. Compared to [Angular 4](https://angular.io/) which I had the chance to play around with, react is much simpler, more focused on a single concern and very unopinionated.

In this post, I would like to outline what I discovered about React so far.

## Creating tags

React allows you to basically create components which can be defined as ES 6 classes or as a plain old functions, let's consider a very simple html tag that we may wish to create:

```html
<Greeter name="James Johnson" />
```

We would like the `Greeter` component to be rendered as in the following screenshot:

<div class="img-container">
![Greeeter component displayed]({{ site.url }}/imgs/Greeter.PNG)
</div>

So, we define it as follows:

{% highlight Javascript %}
import React from 'react';
class Greeter extends React.Component {
    
    constructor(props) {
        super(props);
        
        this.handleClick = this.handleClick.bind(this);
    }
    
    handleClick(event) {
        alert(`Hi again ${this.props.name}!`);
    }
    
    render() {
        return (<div className="greeter" onClick={this.handleClick}> 
                 <p>Hello {this.props.name}!</p>
                 <style jsx>
                    {`
                        div.greeter p {
                            color: blue;
                        }
                    `}
                 </style>
               </div>);
    }
}
{% endhighlight %}

The `Greeter` component is a class that extends the `React.Component` super class provided by React, by defining the `render` method we can specify the structure (html) of the component. 

React uses by default [jsx](https://reactjs.org/docs/jsx-in-depth.html) as a templating facility, jsx code looks very similar to html but it is actually going to be subsequently compiled to JavaScript, notice how some html attribute names have been changed and camelCased; `class` becomes `className` and `onclick` becomes `onClick.`

Jsx supports one-way data binding, in the previous example the `this.props.name` property is referenced in order to display the given name, whenever `this.props.name` changes the view will be updated an will display the new value.

The component's style is placed wright inside its top level `div`, in fact while it is possible to factor the style in a global stylesheet or in global processed style-sheets (SaSS, PostCSS...) by using [styled jsx](https://github.com/zeit/styled-jsx) it is possible to factor the style of each component inside itself that way the defined style will only impact the component that defines it.

Duplication and tediousness proper to css can be mitigated by either making string replacements inside the jsx tag thanks to the interpolated strings or by simply using plain Sass for example.

Finally, notice how we attached a click event listener in our component's top level `div`, the event handler is a method defined in the component's class and has access to the object's `this`. You may wonder what the `this.handleClick = this.handleClick.bind(this)` statement is doing, unfortunately [methods in ES6 classes are not bound by default](https://stackoverflow.com/questions/41127519/why-arent-methods-of-an-object-created-with-class-bound-to-it-in-es6) and whenever we define a method, especially a method that is referenced as a callback for an event handler, we have to bind it explicitly to make the object's `this` available inside the callback otherwise `this` will be `undefined` inside the callback.

Components that you define can also [be stateful](https://reactjs.org/docs/state-and-lifecycle.html#adding-local-state-to-a-class), have [pre-render and post-render hooks](https://reactjs.org/docs/state-and-lifecycle.html#adding-lifecycle-methods-to-a-class) and it is possible to create components [that supports levels of nesting](https://reactjs.org/docs/composition-vs-inheritance.html) that allows for rich composability. We won't go in the details here but definitely checkout the links.

## Server side rendering with Next js

### Why server side rendering ? 

When ajax appeared and people started using it, search engines were not quite able to crawl web sites that were loading their content asynchronously and one of the drawbacks of single page web applications(SPA) was that they were basically not crawalable making SEO difficult for this kind of applications.

Today in 2017, [most major search engines are able to crawl SPAs](https://webmasters.googleblog.com/2015/10/deprecating-our-ajax-crawling-scheme.html) effectively but a concern regarding SEO for SPAs [exists still](https://inbound.org/discuss/are-one-page-websites-seo-friendly) and server side rendering seems to be a less risky path to address these concerns.

It can be also useful to serve a pre-rendered page to the user instead of a page that renders progressively in an awkward manner.

### Next Js

NextJs is a lightweight server side rendering framework for React, it allows the developer to create web pages that are built by using React and its component based programming model, it integrates styled jsx by default and adds hooks to React components that allows to fetch data on the server side. 

Let's put the `Greeter` example in a specific context, suppose that the `Greeter` component is used in another component that we name `Container`:

```html
<Container />
```

The container is included in a page that we access with the following url: <br>`https://app-domain/page?userId=2149`

The `Container` component takes a user Id and fetches the user's name from a restful http resource:

{% highlight Javascript %}
class Container extends React.Component {
    constructor(props) {
        super(props);
    }
    static async getInitialProps(request) {
        let userId = request.query.userId;
        let result = await httpClient.get('https://application-domain/users/${userId}');
        let user = result.getResponseAsJson();
        
        return {userName: user.name};
    }
    render () {
        return <div className="container">
                  <Greeter name={this.props.name} />
               </div>;
    }
}
{% endhighlight %}

The `getInitialProps` static method is called on the server side in order to fetch the user's data and to make it available for the server's rendering process, when the page containing the `Container` components is requested with the `userId` argument the component will be fully rendered and served by the server.

`getInitialProps` returns a JavaScript object containing the properties that are going to be made available to the server side rendering process via `this.props`.

## Closing thoughts

I had a chance to play around with Angular 2(now 4) in the past and I must say that React is way less boiler plate oriented but also very unopinionated and allows you to build your software factory as you like by choosing each aspect(testing, state management, dependency injection...) yourself. 

The ability to factor css, html(jsx) and JavaScript into the same unit (class) can seem a bad idea at first but if we keep each component small, focused and with a single responsibility it may work out well, we will see...

Finally, I am looking forward to the form creation part in React which I did not try yet, Angular 4 has a very solid form facility and I wonder how React's form handling mechanism compares.