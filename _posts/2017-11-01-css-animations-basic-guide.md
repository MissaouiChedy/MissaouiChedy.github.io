---
layout: post
title: "CSS animations basic guide"
date: 2017-11-01
categories: article
comments: true
---

[CSS3](https://www.w3schools.com/css/css3_intro.asp) with its animations support has been out there for quite sometime now and every now and then I find myself in need to put together some animations on a web page.

For quite some time as well I was confusing the two animation mechanisms that are available in CSS3 namely [transitions](https://www.w3schools.com/css/css3_transitions.asp) and [key-frame animations](https://www.w3schools.com/css/css3_animations.asp).

In this post, I would like to lay out my understanding of the two mechanisms.

## Transitions

Transition based animation offers a way to specify *which property changes should be smoothly animated*, let's consider a simple a example.

We have a very simple `<p>` element:
```html
<p class="texty">Hello there!</p>
```

And here is the style applied to the `texty` class:
```css
.texty {
    font-size: 1em;
    transition: font-size 3s ease;
}
```

The `font-size` property is initially set to `1em` and in the `transition` property we indicate that changes to the `font-size` property should be animated with a 3 seconds duration, in addition the `ease` time function should be used in the animation.

Let's now introduce some change to the `font-size` property via the `:hover` pseudo selector:
```css
.texty:hover {
    font-size: 3em;
}
```
And here is what happens:

<iframe width="100%" height="110" src="//jsfiddle.net/Chedy2149/6uuqtnbu/embedded/result/" allowfullscreen="allowfullscreen" frameborder="0"></iframe>

Hovering with the mouse(sorry mobile readers) over the text makes it become bigger **progressively.** 

When using this animation mechanism, we can factor the animation specification in CSS and use JavaScript only to manipulate the CSS properties either directly or via class toggling.  

Even if it is possible to specify *transitions* on multiple properties simultaneously, I think that the key-frames mechanism is more powerful and we are going to see why in the next section.

## Key-frames

It is possible to create a named animation and to specify what happens exactly on multiple steps in the CSS, consider the following:
```css
@keyframes colorAnimation {
    0% {
        color: black;
    }
    25% {
        color: red;
    }
    50% {
        color: green;
    }
    75% {
        color: blue;
    }
    100% {
        color: black;
    }
}
```

In the previous, we defined the `colorAnimation` by using the `@keyframes` keyword. Note how we can define what the element should look like at each percentage of the unfolding of the animation.

The ability to specify steps(in percentages) allows us to create arbitrary animations, this is more powerful than simply specifying transitions.

The animations defined via `@keyframes` can be used as follows, here we are using the same simple `<p>` element from the previous section:

```css
.texty {
    animation: colorAnimation 7s ease infinite;     
}
 
```

The previous applies the `colorAnimation` on the `texty` class with a 7 seconds duration and the `ease` time function. In addition, we specified that the animation should loop indefinitely via the `infinite` keyword. 

Here is what it looks like:

<script async src="//jsfiddle.net/Chedy2149/85wf6fv7/2/embed/result/"></script>

Usually, it is useful to trigger an animation when an event such as a button click occurs, this can be achieved with JavaScript by toggling classes or by directly manipulating the `animation` property. 

Furthermore, it can be useful to detect in JavaScript the end of an animation in order to remove eventual added classes or to simply chain one animation after the other. This is achieved by attaching a handler for the `animationend` event on the animated DOM element:

```js
let element = document.getElementById('myElement');

element.addEventListener('animationend', (event) => {
    if (event.animationName === 'myAnimation') {
        // Clean up toggled classes
        // Chain another animation
    }
});
```

As you can see the `event` object passed to the callback contains useful information about the animation that ended.

## To sum it up

In CSS3, we have two mechanisms that allows us to specify animations:
- *Transitions* which allows to specify smooth transitions when certain CSS properties change
- *Key-frames* which allows to define arbitrary animations and to apply them on elements statically in CSS or dynamically via JavaScript

These mechanisms allows us to **keep the details of the animation in the CSS code** and to use JavaScript only for controlling the occurrence of the animations.


