function generateId(domElement) {
	var content = $(domElement).html();
	return content.replace(/ /g, '-');
}
$(document).ready(function () {
	if ($('div#outline')) {
		if ($('article.post div.content h2').length > 4) {
			$('article.post div.content h2').each(function (index, elem) {
				var title = $(elem).html();
				var title_id = generateId(elem);
				$(elem).attr('id', title_id);
				$('div#outline ul').append('<li><a href="#' + title_id + '">'+ title +'</a></li>');
				$('div#outline').show();
			});
		}
	}
});

