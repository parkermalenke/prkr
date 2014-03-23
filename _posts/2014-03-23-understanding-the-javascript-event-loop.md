---
title: Understanding the Javascript Event Loop
layout: words
description: Working through the details of eventing in Javascript.
category: words
---

I've been working on a [backbone.js](http://backbonejs.com) website lately and one of the major paradigms of this framework is that events play an important role in driving the application logic (for example, a model is changed and subsequently emits an event informing a view of the need to update). To this end, all the major Backbone classes integrate a custom event system that allows objects to listen for events on other objects or to trigger their own events.

Event programming isn't always the most intuitive, so I wanted to do a little research on how exactly events work in Javascript before sinking a bunch of time into the paradigm. This post collects my findings about events and the Javascript event loop, mainly for my own reference, but perhaps others will find it useful as well. Since I'm definitely not an expert on javascript, some of this may be incorrect---I will attempt to point out all areas where my understanding is fuzzy and provide code examples to illustrate my findings.

## Say Hello to the Stack
Every time you call a function, the JS runtime (I believe this would be something like V8 in Chrome, Nitro in Safari, or whatever your browser implements) adds a *frame* to the stack. This is a last-in-first-out (LIFO) structure that manages all the functions you call. A frame consists of the arguments for the function, all its local variables, and the code contained in its block.

When you invoke a script the runtime will retrieve the first frame and start executing it. When it gets to another function call it pauses execution of the current frame, adds a frame for the internal function to the stack, and starts executing the new frame (the last in is the first out). Consider the example code in the figure below. The stack starts off empty because no functions have been called. When `a` is invoked a frame is created for it and added to the stack. In this example, the runtime will log a message to the console, and then come to the invocation of `b`. At this point it pauses execution of `a`, creates a frame for `b`, adds it to the stack, and begins executing `b`. Once `b` has completed the runtime will clear that frame off the stack and return to the frame for `a`. Once the last function completes the stack will be completely empty.

![](/assets/photos/events-fig1.png)

We can test this by adding some status messages to the code:

{% highlight javascript %}
console.log('starting...');

function a() {
    console.log('added a to the stack');
    b('hello from b');
    console.log('removing a from the stack');
}

function b(msg) {
    console.log('added b to the stack');
    console.log(msg);
    console.log('removing b from the stack');
}

a();
console.log('...done')
{% endhighlight %}

This produce the following output:

{% highlight html %}
[Log] starting... (index.html, line 9)
[Log] added a to the stack (index.html, line 12)
[Log] added b to the stack (index.html, line 18)
[Log] hello from b (index.html, line 19)
[Log] removing b from the stack (index.html, line 20)
[Log] removing a from the stack (index.html, line 14)
[Log] ...done (index.html, line 24)
{% endhighlight %}

It's possible to put too many functions/frames on the stack at once (the infamous 'stack overflow'); this can happen if you call a recursive function on an input that's too large and spawns too many sub calls. Sounds like ES6 [might be getting proper tail calls](http://bbenvie.com/articles/2013-01-06/JavaScript-ES6-Has-Tail-Call-Optimization) that would enable recursion over larger data sets.

## Events
Alright, now back to the topic at hand. The first major point to realize is that there are two kinds of events in Javascript: *synchronous* and *asynchronous*. Most browser events are asynchronous, although a few are synchronous (such as [DOM mutation and Nested Dom events](http://javascript.info/tutorial/events-and-timing-depth#synchronous-events)). Any custom event handling, such as the events module built into backbone.js, another custom solution like [EventEmitter](https://github.com/Wolfy87/EventEmitter), or jQuery's [`.trigger()`](http://api.jquery.com/trigger/) function, is going to be a synchronous implementation. So what's the difference between these types of events?

### Synchronous Events
Synchronous events are basically another way of invoking functions. Emission of these events essentially involves walking through a list of listener/handler functions and calling them. Consider the following sample implementation:

{% highlight javascript %}
var EventManager = (function() {
    var _events = {}; // private storage for events and their listeners

    return {
        // if the event already exists, add the callback
        // otherwise create it with the given callback
        on: function(event, callback) {
            if (_events[event]) {
                _events[event].push(callback);
            } else {
                _events[event] = [callback];
            }
        },

        // invoke all the functions registered with an event
        trigger: function(event) {
            var ev = _events[event] || [];

            for (var i = 0; i < ev.length; i++) {
                ev[i].call();
            }
        }
    };
})();
{% endhighlight %}

So synchronous event systems are really just a way to invoke one or more functions without knowing what those functions are at the point when the event is triggered. Calling `EventManager.trigger()` pauses execution of whatever block you're in and then sequentially invokes each of the listeners, adding and removing them from the stack until the list is exhausted, at which point control is returned to the context that emitted the event.

Consider this example:

{% highlight javascript %}
// Make a plan for a martian landing
function tellThePublic() {
    console.log('The martians are coming!');
}
EventManager.on('martians:landed', tellThePublic);

function react() {
    console.log('Head for the hills!');
}
EventManager.on('martians:landed', react);

console.log('Our plan is now in place');


// later...
EventManager.trigger('martians:landed');
console.log('Plan executed');
{% endhighlight %}

This will output:

{% highlight html %}
[Log] Our plan is now in place
[Log] The martians are coming!
[Log] Head for the hills!
[Log] Plan executed
{% endhighlight %}

Notice that when the event was triggered, execution of the main script was paused while all the listeners were invoked (i.e. 'Plan executed' wasn't logged until the plan was actually carried out). In this case execution followed these steps:

1. Triggering the `'martians:landed'` event pauses the main context
2. `tellThePublic()` is added to the stack
3. `tellThePublic()` is pulled off and executed
4. `react()` is added to the stack
5. `react()` is pulled off and executed
6. Main context resumes and `'Plan executed'` is logged

### Asynchronous Events
Instead of acting as a shortcut for adding frames to the stack, triggering async events adds messages to a queue. This behavior can't be simulated with third party code (at least not that I'm aware of). Before discussing the queue, what kind of events are asynchronous? In my research it sounds like pretty much any event that comes from the browser, or in node any event that comes from a built in object. Clicks on elements, `window.setTimeout` callbacks, mouseovers, keypresses, `XMLHttpResponse`'s `readyState`, etc. all behave in an asynchronous fashion.

#### The Event Queue
In addition to the stack, javascript runtimes include a structure known as the *queue*. This is similar, except that it operates on a first-in-first-out (FIFO) basis. Whenever you register an event handler for an async event the runtime makes a note associating the provided function with the specified event. When an event is triggered the runtime looks through its list of handlers to see if any are associated with the current event. If so, it creates a *message*, which references the handler function, and adds it to the queue. How are messages from the queue invoked? That's the job of the event loop.

#### The Event Loop
Whenever the stack is empty, the runtime will ask the event loop for the next available message. If one exists, the event loop hands the associated function off to the runtime, which creates a corresponding frame, adds it to the stack, and executes it. Note the major difference versus synchronous events here: *Async event handlers are only ever invoked when the stack is empty.*

Here is a figure illustrating the sequence of events (zing!) that happens when dealing with an async event:
![](/assets/photos/events-fig3.png)

#### Code Example
Okay, let's look at some code. Here's an example that will hopefully make this clearer.

{% highlight javascript %}
// create a handler function and add it to the click event
function broadcast() {
    console.log('A click event was fired!');
}
document.addEventListener('click', broadcast);
{% endhighlight %}

If you were to run this example and start clicking around you'd see the message would be logged to the console pretty much in real time as you click the document. Note that in this case the stack is basically empty this whole time. Now let's try it with a stack that has more stuff to do.

{% highlight javascript %}
// here's a long running function
function runFor(ms) {
    ms += new Date().getTime();
    while (new Date() < ms){}
    // yes this is very hacky
}

// now run this on the stack while we're listening for the click event
function broadcast() {
  console.log('A click event was fired!');
}
document.addEventListener('click', broadcast);

runFor(5000);
{% endhighlight %}

Now if you run this and start clicking on the document you'll see that nothing is logged for 5 seconds and then all of a sudden a bunch of strings are logged. This is because the `runFor()` function stays on the stack for 5 seconds. No messages from the event queue can be handled until the stack is clear. Once it finally clears all the messages are handled in sequential order. To check that messages are handled in a FIFO manner try the example with a different handler:

{% highlight javascript %}
var broadcastCounter = (function() {
    var _count = 1;
    return function() {
        console.log('Click number: ' + _count);
        _count++;
    }
})();
document.addEventListener('click', broadcastCounter);
{% endhighlight %}

You should see that the strings are printed in sequential order starting at 1 and going up.

#### Remaining Questions
At this point I feel like I have a pretty good handle on the event loop and asynchronous events. There are still a few points that aren't entirely clear, but I have some guesses at what the answers are.

*Is a call to `addEventListener()` blocking?*  
Functions that register async event handlers tend to return pretty much instantaneously. My guess is that in a strictly single threaded environment these functions will block the execution of a script until the runtime finishes recording the event and respective handler (step 2 in the diagram). I suppose it's possible that some of the runtime maintenance tasks like this could also occur in a separate thread/process.

*Is the message enqueueing process blocking?*  
When an async event is triggered, does the runtime pause execution of the script while it looks up the relevant handler and adds it to the event queue? Again, I think this would work as a concurrent process, but it's not required.

*Do async processes ever occur simultaneously?*  
The examples I had in mind were file reads in node.js or ajax requests in the client. I'm pretty sure ajax requests can occur concurrently, with something along the lines of:

1. You create an XMLHttpRequest object, this blocks the main thread while telling the browser where to get the resource, what headers to use, etc.
2. Once the browser gets all this info, your function returns and execution continues.
3. *While your execution is continuing* the browser has started a request in another thread. Your continuing execution might start additional ajax requests, which might also occur concurrently if the browser supports multiple http requests (I think they all do these days).
4. When that request returns an event is fired and your callback is added to the event queue.
5. The stack empties at some point and your callback is taken off the event loop and executed with the results of the request.

I'm not sure about file reads in node.js. My guess is that it's a similar process, except that a file read kicks off a separate thread at the OS level that then returns with the results of the file. In this manner you could have your js executing in one thread, a file read executing in another thread, and an ajax request executing in a third thread. So you can have concurrent execution with javascript, it's just that only one script is ever executing at a time (the other threads are in the browser or at the OS level).

## Conclusion
So that's my brief foray into javascript events and the event loop. For functions that don't take too long to execute it probably doesn't matter if you're using synchronous or asynchronous events, but if you have anything that could hold up the main thread for very long or are attaching an event handler that could take a while to clear it's good to know the differences.

### Takeaways
* Asynchronous event handlers will be blocked by anything on the stack. Design your script to leave the stack empty whenever possible. Try moving things into messages in the queue instead.
* Synchronous event handlers will block the main thread. This has the potential to lock up the browser if you run anything too intensive in them.
* Javascript never executes in parallel, but it can kick off other threads/processes in the browser, OS, runtime, etc. (I think.)
* Asynchronous events means that your script doesn't have to block while it waits for these other threads to return. You can keep doing something else, and then once the other thread returns *and* you're not doing anything else you can handle the results of whatever process you started.
* Custom events (backbone.js's event model, jQuery's `.trigger()`, other third party custom event libraries) are not asynchronous. Instead they're just a handy way of organizing your function invocations.

### Resources
* [Concurrency model and Event Loop (MDN)](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/EventLoop)
* [The JavaScript Event Loop: Explained](http://blog.carbonfive.com/2013/10/27/the-javascript-event-loop-explained/)
* [Events and Timing In-Depth](http://javascript.info/tutorial/events-and-timing-depth#asynchronous-events)
* [Handling Events with jQuery](https://www.inkling.com/read/javascript-definitive-guide-david-flanagan-6th/chapter-19/handling-events-with-jquery)
* [Creating and Triggering Events (MDN)](https://developer.mozilla.org/en-US/docs/Web/Guide/Events/Creating_and_triggering_events)
* [The Javascript Event Loop](https://thomashunter.name/blog/the-javascript-event-loop-presentation/)

### Examples
* <http://codepen.io/anon/pen/Aeivq>
* <http://codepen.io/anon/pen/Hgziy>
