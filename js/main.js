function generateId(domElement) {
	var content = $(domElement).text().toLowerCase();
	return content
		.replace(/[^a-z0-9\s-]/g, '')
		.trim()
		.replace(/\s+/g, '-')
		.replace(/-+/g, '-');
}

function ensureUniqueId(baseId) {
	var uniqueId = baseId;
	var suffix = 2;

	while (document.getElementById(uniqueId)) {
		uniqueId = baseId + '-' + suffix;
		suffix += 1;
	}

	return uniqueId;
}

function getHeadingLinkTarget() {
	return window.location.href.split('#')[0];
}

function copyHeadingLink(linkUrl) {
	if (navigator.clipboard && navigator.clipboard.writeText) {
		return navigator.clipboard.writeText(linkUrl);
	}

	var temporaryInput = document.createElement('input');
	temporaryInput.value = linkUrl;
	temporaryInput.setAttribute('readonly', 'readonly');
	temporaryInput.style.position = 'absolute';
	temporaryInput.style.left = '-9999px';
	document.body.appendChild(temporaryInput);
	temporaryInput.select();
	document.execCommand('copy');
	document.body.removeChild(temporaryInput);
	return Promise.resolve();
}

function addHeadingLinkIcon(elem) {
	var heading = $(elem);
	if (heading.find('.heading-anchor-link').length > 0) {
		return;
	}

	heading.addClass('has-heading-anchor');
	heading.append(' <a class="heading-anchor-link" href="#' + heading.attr('id') + '" aria-label="Copy link to section" title="Copy link to section"><i class="fa fa-link" aria-hidden="true"></i></a>');
	heading.find('.heading-anchor-link').on('click', function (event) {
		event.preventDefault();
		event.stopPropagation();

		var linkUrl = getHeadingLinkTarget() + '#' + heading.attr('id');
		history.replaceState(null, '', '#' + heading.attr('id'));
		copyHeadingLink(linkUrl).catch(function () {
			return null;
		});
	});
}

$(document).ready(function () {
	if ($('div#outline') && !($('span.no-outline'))) {
		if ($('article.post div.content h2').length > 4) {
			$('article.post div.content h2').each(function (index, elem) {
				var title = $(elem).html();
				var title_id = $(elem).attr('id') || ensureUniqueId(generateId(elem));
				$(elem).attr('id', title_id);
				addHeadingLinkIcon(elem);
				$('div#outline ul').append('<li><a href="#' + title_id + '">'+ title +'</a></li>');
				$('div#outline').show();
			});
		}
	}

	$('article.post div.content h2, article.post div.content h3').each(function (index, elem) {
		var heading = $(elem);
		if (!heading.attr('id')) {
			heading.attr('id', ensureUniqueId(generateId(elem)));
		}
		addHeadingLinkIcon(elem);
	});
	
	if ($('#disqus_thread').children().length == 0) {
		$('#disqus_thread').append('<p class="comment-error-message">Your browser settings(Tracking Protection) are maybe blocking the comment section !</p>')
	}
});

