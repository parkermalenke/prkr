$(document).ready(function() {
	$('.suggest-edit').click(function(e) {
		e.preventDefault();
		$(this).siblings('.edit-form').toggle();
	});

	$('#saveForm').click(function(e) {
		alert("i've been clicked");
		$(this).parents('.edit-form').toggle();
	});
});