var timer;
var returning = false;

$(window).scroll(function(e) {
	window.clearTimeout(timer);
	console.log(e.originalEvent);
	if (returning === false) {
		timer = window.setTimeout(move, 250);
	} else {
		returning = false;
	}
	console.log("set " + timer);
});

var move = function() {
	returning = true;
	var scroll = $(window).scrollTop();
	console.log(returning);
	for (var i = 0; i < 100; i++) {
		console.log("heyo");
		var time2 = window.setTimeout($(window).scrollTop(scroll - 1), 1000);
	}
	console.log("done");
};

var log = function(text) {
	console.log(text);
};