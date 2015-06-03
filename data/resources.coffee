marginClasses = ['margin-x-narrow', 'margin-narrow', 'margin-medium', 'margin-wide', 'margin-x-wide']
fontsizeClasses = ['size-x-small', 'size-small', 'size-medium', 'size-large', 'size-x-large']
styleClasses = ['style-newspaper', 'style-novel', 'style-ebook', 'style-terminal']

# Listen for Escape keypress
listenForKeystroke = () ->
	listener = window.addEventListener 'keyup', (event) ->
		if event.keyCode is 27 #ESCAPE KEY
			window.location.reload()

find_matching = (items, fct) ->
	for item in items
		return item  if fct item
	null

switch_class = (item, oldClass, newClass) ->
	item.classList.remove oldClass
	item.classList.add newClass

# Size
augmentSize = ->
	index = fontsizeClasses.indexOf getSize()
	if index < fontsizeClasses.length - 1
		oldClass = fontsizeClasses[index]
		newClass = fontsizeClasses[index + 1]
		switch_class document.body, oldClass, newClass
		self.port.emit 'style', {rule: 'size', value: newClass}

reduceSize = ->
	index = fontsizeClasses.indexOf getSize()
	if index > 0
		oldClass = fontsizeClasses[index]
		newClass = fontsizeClasses[index - 1]
		switch_class document.body, oldClass, newClass
		self.port.emit 'style', {rule: 'size', value: newClass}

getSize = ->
	innerClasses = document.body.className.split(' ')
	find_matching innerClasses, (klass) -> klass.indexOf('size-') > -1

# Margin
augmentMargin = ->
	index = marginClasses.indexOf getMargin()
	if index < marginClasses.length - 1
		oldClass = marginClasses[index]
		newClass = marginClasses[index + 1]
		switch_class document.body, oldClass, newClass
		self.port.emit 'style', {rule: 'margin', value: newClass}

reduceMargin = () ->
	index = marginClasses.indexOf getMargin()
	if index > 0
		oldClass = marginClasses[index]
		newClass = marginClasses[index - 1]
		switch_class document.body, oldClass, newClass
		self.port.emit 'style', {rule: 'margin', value: newClass}

getMargin = ->
	innerClasses = document.body.className.split(' ')
	find_matching innerClasses, (klass) -> klass.indexOf('margin-') > -1

# Styles
getStyle = ->
	bodyClasses = document.body.className.split(' ');
	find_matching bodyClasses, (klass) -> klass.indexOf('style-') > -1

setStyle = (newClass) ->
	oldClass = getStyle()
	switch_class document.body, oldClass, newClass
	self.port.emit 'style', {rule: 'style', value: newClass}

self.port.on 'click', (urls) ->
	# Is the CSS available yet ?
	unless document.getElementById('readability-link')?
		link = content.document.createElement 'link'
		link.rel = 'stylesheet'
		link.id = 'readability-link'
		link.href = urls.css
		link.type = 'text/css'
		link.media = 'all'
		if content.document.createElement('div').insertAdjacentHTML?
			document.querySelector('head').insertAdjacentHTML 'beforeend', new XMLSerializer().serializeToString link
		else
			document.querySelector('head').appendChild link
		listenForKeystroke()

	#Is the plugin active ?
	if document.body.className.search(/enjoy-reading/) < 0
		self.port.emit 'ready'
		window.addEventListener 'click', (event) ->
			switch event.target.id
				when 'augment-size' then augmentSize()
				when 'reduce-size' then reduceSize()
				when 'augment-margin' then augmentMargin()
				when 'reduce-margin' then reduceMargin()
				when 'newspaper' then setStyle 'style-newspaper'
				when 'novel' then setStyle 'style-novel'
				when 'ebook' then setStyle 'style-ebook'
				when 'terminal' then setStyle 'style-terminal'
	else
		window.location.reload()
