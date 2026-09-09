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

function initShareControls() {
	$('.share[data-share-url]').each(function (index, elem) {
		var share = $(elem);
		var url = share.attr('data-share-url');
		var title = share.attr('data-share-title');

		var copyButton = share.find('.share-copy');
		var copyLabel = copyButton.find('.share-copy-label');
		var copyIcon = copyButton.find('i.fa');
		var defaultCopyText = copyLabel.length ? copyLabel.text() : '';
		var defaultCopyTitle = copyButton.attr('title') || 'Copy link';

		copyButton.on('click', function () {
			copyHeadingLink(url).then(function () {
				if (copyLabel.length) {
					copyLabel.text('copied!');
				}
				if (copyIcon.length) {
					copyIcon.removeClass('fa-link').addClass('fa-check');
				}
				copyButton.addClass('is-copied').attr('title', 'Copied!').attr('aria-label', 'Copied!');

				setTimeout(function () {
					if (copyLabel.length) {
						copyLabel.text(defaultCopyText);
					}
					if (copyIcon.length) {
						copyIcon.removeClass('fa-check').addClass('fa-link');
					}
					copyButton.removeClass('is-copied').attr('title', defaultCopyTitle).attr('aria-label', defaultCopyTitle);
				}, 2000);
			}).catch(function () {
				return null;
			});
		});

		// Progressive enhancement: the Web Share API (native share sheet)
		// only exists on supporting browsers, so the button stays hidden otherwise.
		if (navigator.share) {
			var nativeItem = share.find('.share-native-item');
			share.addClass('has-native-share');
			nativeItem.removeAttr('hidden');
			nativeItem.find('.share-native').on('click', function () {
				navigator.share({ title: title, url: url }).catch(function () {
					return null;
				});
			});
		}

		share.find('.share-linkedin').on('click', function (event) {
			event.preventDefault();
			window.open('https://www.linkedin.com/sharing/share-offsite/?url=' + encodeURIComponent(url), '_blank', 'noopener,noreferrer');
		});
	});
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

function trackOutlineSections() {
	var outline = document.getElementById('outline');
	if (!outline) {
		return;
	}

	var links = Array.from(outline.querySelectorAll('a[href^="#"]'));
	var sections = links.map(function (link) {
		return document.getElementById(link.getAttribute('href').slice(1));
	});
	if (!sections.length) {
		return;
	}

	var currentIndex = -1;
	var scheduled = false;
	function updateCurrentSection() {
		scheduled = false;
		if (!outline.getClientRects().length) {
			return;
		}
		var nextIndex = 0;
		var threshold = window.innerHeight * 0.2;
		sections.forEach(function (section, index) {
			if (section && section.getBoundingClientRect().top <= threshold) {
				nextIndex = index;
			}
		});
		if (nextIndex === currentIndex) {
			return;
		}
		links.forEach(function (link, index) {
			if (index === nextIndex) {
				link.setAttribute('aria-current', 'location');
			} else {
				link.removeAttribute('aria-current');
			}
		});
		currentIndex = nextIndex;
	}
	function scheduleUpdate() {
		if (!scheduled) {
			scheduled = true;
			window.requestAnimationFrame(updateCurrentSection);
		}
	}
	window.addEventListener('scroll', scheduleUpdate, { passive: true });
	window.addEventListener('resize', scheduleUpdate);
	window.addEventListener('load', scheduleUpdate);
	scheduleUpdate();
}

$(document).ready(function () {
	if ($('div#outline').length && !$('span.no-outline').length) {
		if ($('article.post div.content h2').length > 4) {
			$('article.post div.content h2').each(function (index, elem) {
				var title = $(elem).clone().children('.heading-anchor-link').remove().end().text();
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
	trackOutlineSections();
	initShareControls();
	
	if ($('#disqus_thread').children().length == 0) {
		$('#disqus_thread').append('<p class="comment-error-message">Your browser settings(Tracking Protection) are maybe blocking the comment section !</p>')
	}
});

