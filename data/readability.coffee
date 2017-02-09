dbg = if console? then (s) -> console.log("Readability: #{s}") else () -> return

###
Readability. An Arc90 Lab Experiment.
Website: http://lab.arc90.com/experiments/readability
Source: http://code.google.com/p/arc90labs-readability

"Readability" is a trademark of Arc90 Inc and may not be used without explicit permission.

Copyright (c) 2010 Arc90 Inc
Readability is licensed under the Apache License, Version 2.0.
###
readability =
	# constants
	FLAG_STRIP_UNLIKELYS: 0x1
	FLAG_WEIGHT_CLASSES: 0x2
	FLAG_CLEAN_CONDITIONALLY: 0x4

	version: '1.7.1'
	iframeLoads: 0
	reversePageScroll: false # If they hold shift and hit space, scroll up
	flags: this.FLAG_STRIP_UNLIKELYS | this.FLAG_WEIGHT_CLASSES | this.FLAG_CLEAN_CONDITIONALLY # Start with all flags set.
	sizeClass: 'size-medium'
	marginClass: 'margin-medium'
	styleClass: 'style-clean'
	tagsToScore: ['SECTION', 'H2', 'H3', 'H4', 'H5', 'H6', 'P', 'TD', 'PRE']

	###
	All of the regular expressions in use within readability.
	Defined up here so we don't instantiate them repeatedly in loops.
	###
	regexps:
		unlikelyCandidates: /combx|comment|community|disqus|extra|foot|header|menu|remark|rss|shoutbox|sidebar|sponsor|ad-break|agegate|pagination|pager|popup|tweet|twitter|xiti|pub|outbrain|track|socia/i
		okMaybeItsACandidate: /and|article|body|column|main|shadow/i
		positive: /article|body|content|entry|hentry|main|page|pagination|post|text|blog|story/i
		negative: /combx|comment|com-|contact|foot|footer|footnote|masthead|media|meta|outbrain|promo|related|scroll|shoutbox|sidebar|sponsor|shopping|tags|tool|widget/i
		extraneous: /print|archive|comment|discuss|e[\-]?mail|share|reply|all|login|sign|single/i
		divToPElements: /<(a|blockquote|dl|div|img|ol|p|pre|table|ul)/i
		replaceBrs: /(<br[^>]*>[ \n\r\t]*){2,}/gi
		replaceFonts: /<(\/?)font[^>]*>/gi
		trim: /^\s+|\s+$/g
		normalize: /\s{2,}/g
		videos: /http:\/\/(www\.)?(youtube|vimeo)\.com/i
		skipFootnoteLink: /^\s*(\[?[a-z0-9]{1,2}\]?|^|edit|citation needed)\s*$/i
		nextLink: /(next|weiter|continue|>([^\|]|$)|»([^\|]|$))/i # Match: next, continue, >, >>, » but not >|, »| as those usually mean last.
		prevLink: /(prev|earl|old|new|<|«)/i

	###
	Runs readability.

	Workflow:
	1. Prep the document by removing script tags, css, etc.
	2. Build readability's DOM tree.
	3. Grab the article content from the current dom tree.
	4. Replace the current DOM tree with the new one.
	5. Read peacefully.

	@return void
	###
	init: ->
		# Before we do anything, remove all scripts that are not readability.
		window.onload = window.onunload = ->

		this.prepDocument()

		# Build readability's DOM tree
		article = document.createElement 'article'

		[header, title] = this.getArticleHeader()
		article.appendChild header
		article.appendChild child for child in this.grabArticle()
		article.appendChild this.getArticleFooter()

		t = document.createElement 'title'
		t.textContent = title

		style = document.createElement 'link'
		style.rel = 'stylesheet'
		style.href = 'resource://enjoy-reading/readability.css'
		style.type = 'text/css'
		style.media = 'all'

		#js = document.createElement 'script'

		head = document.createElement 'head'
		head.appendChild t
		head.appendChild style

		body = document.createElement 'body'
		body.className = "#{this.styleClass} #{this.marginClass} #{this.sizeClass} enjoy-reading"
		body.appendChild article
		body.appendChild this.getArticleTools()

		this.clearNode document.documentElement
		document.documentElement.appendChild head
		document.documentElement.appendChild body

		###
		Smooth scrolling *
		###
		document.onkeydown = (e) ->
			code = e.keyCode
			if code is 16
				this.reversePageScroll = true
			else if code is 32
				this.curScrollStep = 0
				windowHeight = if window.innerHeight then window.innerHeight else (if document.documentElement.clientHeight then document.documentElement.clientHeight else document.body.clientHeight)
				if this.reversePageScroll
					this.scrollTo this.scrollTop(), this.scrollTop() - (windowHeight - 50), 20, 10
				else
					this.scrollTo this.scrollTop(), this.scrollTop() + (windowHeight - 50), 20, 10

		document.onkeyup = (e) ->
			code = e.keyCode
			if code is 16
				this.reversePageScroll = false

	###
	Run any post-process modifications to article content as necessary.

	@param Element
	@return void
	###
	postProcessContent: (articleContent) ->
		this.fixImageFloats articleContent

	###
	Some content ends up looking ugly if the image is too large to be floated.
	If the image is wider than a threshold (currently 55%), no longer float it,
	center it instead.

	@param Element
	@return void
	###
	fixImageFloats: (articleContent) ->
		imageWidthThreshold = Math.min(articleContent.offsetWidth, 800) * 0.55
		for image in articleContent.getElementsByTagName 'img'
			image.className += ' blockImage' if image.offsetWidth > imageWidthThreshold
		return

	###
	Get the article tools Element that has buttons like reload, print, email.

	@return void
	###
	getArticleTools: ->
		tools = document.createElement 'footer'
		tools.className = 'enjoy-reading-tools'
		items =
			'augment-size': 'Augment font size',
			'reduce-size': 'Reduce font size',
			'augment-margin': 'Augment margin',
			'reduce-margin': 'Reduce margin',
			'style-clean': 'Clean style',
			'style-solarized-light': 'Light solarized style'
			'style-solarized-dark': 'Dark solarized style',
		for id, text of items
			a = document.createElement 'a'
			a.href = '#'
			a.id = id
			a.title = a.textContent = text
			tools.appendChild a

		a = document.createElement 'a'
		a.href = '#'
		a.id = 'print-page'
		a.title = a.textContent = 'Print page'
		a.onclick = -> window.print()
		tools.appendChild a

		tools

	###
	Returns the suggested direction of the string

	@return "rtl" || "ltr"
	###
	getSuggestedDirection: (text) ->
		sanitizeText = ->
			text.replace /@\w+/, ''

		countMatches = (match) ->
			matches = text.match(new RegExp(match, 'g'))
			if matches isnt null then matches.length else 0

		isRTL = ->
			count_heb = countMatches('[\\u05B0-\\u05F4\\uFB1D-\\uFBF4]')
			count_arb = countMatches('[\\u060C-\\u06FE\\uFB50-\\uFEFC]')
			# if 20% of chars are Hebrew or Arbic then direction is rtl
			(count_heb + count_arb) * 100 / text.length > 20
		text = sanitizeText(text)
		if isRTL() then 'rtl' else 'ltr'

	###
	Get the article header
	###
	getArticleHeader: ->
		cur = ''
		orig = ''
		try
			cur = orig = document.title
			# If they had an element with id "title" in their HTML
			cur = orig = this.getInnerText(document.getElementsBtbyTagName('title')[0]) if typeof cur isnt 'string'
		if cur.match RegExp ' [\\|\\-] '
			cur = orig.replace /(.*)[\|\-] .*/gi, '$1'
			cur = orig.replace /[^\|\-]*[\|\-](.*)/gi, '$1' if cur.split(' ').length < 3
		else if cur.indexOf(': ') isnt -1
			cur = orig.replace /.*:(.*)/gi, '$1'
			cur = orig.replace /[^:]*[:](.*)/gi, '$1' if cur.split(' ').length < 3
		else if cur.length > 150 or cur.length < 15
			hOnes = document.getElementsByTagName 'h1'
			cur = this.getInnerText hOnes[0] if hOnes.length is 1
		cur = cur.replace this.regexps.trim, ''
		cur = orig if cur.split(' ').length <= 4

		title = document.createElement 'h1'
		title.textContent = cur

		header = document.createElement 'header'
		header.appendChild title

		[header, cur]

	###
	Get the footer

	@return void
	###
	getArticleFooter: ->
		cite = document.createElement 'cite'
		cite.textContent = document.title

		footer = document.createElement 'footer'
		footer.className = 'enjoy-reading-footer'

		footer.appendChild document.createTextNode 'Excerpted from '
		footer.appendChild cite
		footer.appendChild document.createElement 'br'

		a = document.createElement 'a'
		a.title = document.title
		a.href = a.textContent = window.location.href
		footer.appendChild a

		footer

	###
	Prepare the HTML document for readability to scrape it.
	This includes things like stripping javascript, CSS, and handling terrible markup.
	###
	prepDocument: ->
		# In some cases a body element can't be found (if the HTML is totally hosed for example)
		# so we create a new body node and append it to the document.
		unless document.body?
			document.body = document.createElement 'body'

		# Remove all stylesheets
		styles = document.getElementsByTagName 'link'
		n = styles.length - 1
		while n > 0
			style = styles[n]
			style.parentNode.removeChild style if style?.href.lastIndexOf('readability') < 0
			--n
		styles = document.getElementsByTagName 'style'
		n = styles.length - 1
		while n > 0
			style = styles[n]
			style.parentNode.removeChild style
			--n

	###
	Prepare the article node for display. Clean out any inline styles,
	iframes, forms, strip extraneous <p> tags, etc.

	@param Element
	@return void
	###
	prepArticle: (articleContent) ->
		this.cleanAttributes articleContent

		# Clean out junk from the article content
		this.cleanConditionally articleContent, 'form'
		this.clean articleContent, 'object'
		this.clean articleContent, 'h1'

		# If there is only one h2, they are probably using it
		# as a header and not a subheader, so remove it since we already have a header.
		this.clean articleContent, 'h2' if articleContent.getElementsByTagName('h2').length is 1
		this.clean articleContent, 'iframe'
		this.cleanHeaders articleContent

		# Do these last as the previous stuff may have removed junk that will affect these
		this.cleanConditionally articleContent, 'table'
		this.cleanConditionally articleContent, 'ul'
		this.cleanConditionally articleContent, 'div'

		# Remove extra paragraphs
		articleParagraphs = articleContent.getElementsByTagName 'p'
		i = articleParagraphs.length - 1
		while i >= 0
			articleParagraph = articleParagraphs[i]
			imgCount = articleParagraph.getElementsByTagName('img').length
			embedCount = articleParagraph.getElementsByTagName('embed').length
			objectCount = articleParagraph.getElementsByTagName('object').length
			articleParagraph.parentNode.removeChild articleParagraph if imgCount is 0 and embedCount is 0 \
					and objectCount is 0 and this.getInnerText(articleParagraph, false) is ''
			--i

	###
	Initialize a node with the readability object. Also checks the
	className/id for special names to add to its score.

	@param Element
	@return void
	###
	initializeNode: (node) ->
		return if node.readability

		node.readability =
			contentScore: 0
		switch node.tagName
			when 'ARTICLE'
				node.readability.contentScore += 10
			when 'DIV'
				node.readability.contentScore += 5
			when 'PRE', 'TD', 'BLOCKQUOTE'
				node.readability.contentScore += 3
			when 'ADDRESS', 'OL', 'UL', 'DL', 'DD', 'DT', 'LI', 'FORM'
				node.readability.contentScore -= 3
			when 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'TH'
				node.readability.contentScore -= 5
		node.readability.contentScore += this.getClassWeight node

	clearNode: (node) ->
		while node.firstChild
			node.removeChild node.firstChild
		return

	replaceHTML: (node, from) ->
		readability.clearNode node
		node.appendChild from.cloneNode true

	getAncestors: (node, maxDepth) ->
		maxDepth = maxDepth || 0
		depth = 0
		ancestors = []
		while parent = node.parentNode
			ancestors.push parent
			break if maxDepth and ++depth == maxDepth
			node = parent
		ancestors

	###
	GrabArticle - Using a variety of metrics (content score, classname, element types), find the content that is
	most likely to be the stuff a user wants to read. Then return it wrapped up in a div.

	@param page a document to run upon. Needs to be a full document, complete with body.
	@return Element
	###
	grabArticle: () ->
		#First, node prepping. Trash nodes that look cruddy (like ones with the class name "comment", etc)
		nodesToScore = []
		pending = Array.prototype.slice.call document.body.childNodes
		while node = pending.pop()
			pending = pending.concat Array.prototype.slice.call node.childNodes
			continue unless node.tagName in this.tagsToScore
			# Skip unlikely candidates
			unlikelyMatchString = "#{node.className} #{node.id}"
			if unlikelyMatchString.search(this.regexps.unlikelyCandidates) >= 0 \
					and unlikelyMatchString.search(this.regexps.okMaybeItsACandidate) < 0
				dbg "Removing unlikely candidate #{this.dbgNode node}"
				continue
			nodesToScore.push node

		# Loop through all candidates, and assign a score to them based on how content-y they look.
		# Then add their score to their parent node.
		# A score is determined by things like number of commas, class names, etc. Maybe eventually link density.
		candidates = []
		for node in nodesToScore
			dbg "Node to score #{this.dbgNode node}"

			innerText = this.getInnerText node
			# If this paragraph is less than 25 characters, don't even count it.
			continue if innerText < 25

			ancestors = this.getAncestors node, 3
			continue if ancestors.length is 0
			for n in ancestors
				unless n.readability
					this.initializeNode n
					candidates.push n

			contentScore = 1 # Add a point for the paragraph itself as a base.
			contentScore += innerText.split(',').length # Add points for any commas within this paragraph
			contentScore += Math.min(Math.floor(innerText.length / 100), 3) # For every 100 characters in this paragraph, add another point. Up to 3 points.

			ancestor.readability.contentScore += contentScore / (n+1) for ancestor, n in ancestors

		# After we've calculated scores, loop through all of the possible candidate nodes we found
		# and find the one with the highest score.
		topCandidate = null
		for candidate in candidates
			# Scale the final candidates score based on link density. Good content should have a
			# relatively small link density (5% or less) and be mostly unaffected by this operation.
			candidate.readability.contentScore = candidate.readability.contentScore * (1 - readability.getLinkDensity(candidate))
			dbg "Candidate : #{this.dbgNode candidate}"
			topCandidate = candidate if not topCandidate or candidate.readability.contentScore > topCandidate.readability.contentScore

#		# If we still have no top candidate, just use the body as a last resort.
#		# We also have to copy the body node so it is something we can modify.
#		if topCandidate is null or topCandidate.tagName is 'BODY'
#			topCandidate = document.createElement 'div'
#			topCandidate.appendChild page.cloneNode true
#			readability.clearNode page
#			page.appendChild topCandidate
#			readability.initializeNode topCandidate

		return [] unless topCandidate?
		dbg "Top candidate :  #{this.dbgNode topCandidate}"

		# Now that we have the top candidate, look through its siblings for content that might also be related.
		# Things like preambles, content split by ads that we removed, etc.
		siblingScoreThreshold = Math.max(10, topCandidate.readability.contentScore * 0.2)
		content = []
		for siblingNode in topCandidate.parentNode.childNodes
			append = false;

			dbg "Looking at sibling node: #{this.dbgNode siblingNode}"
			contentBonus = 0

			# Give a bonus if sibling nodes and top candidates have the example same classname
			contentBonus += topCandidate.readability.contentScore * 0.2 if siblingNode.className is topCandidate.className \
					and topCandidate.className isnt ''
			append = true if siblingNode.readability? and (siblingNode.readability.contentScore + contentBonus) >= siblingScoreThreshold

			if siblingNode.nodeName in ['P', 'DIV']
				linkDensity = readability.getLinkDensity siblingNode
				nodeContent = readability.getInnerText siblingNode
				nodeLength = nodeContent.length
				if nodeLength > 80 and linkDensity < 0.25
					append = true
				else if nodeLength < 80 and linkDensity is 0 and nodeContent.search(/\.( |$)/) >= 0
					append = true

			if append
				dbg "Appending node: #{this.dbgNode siblingNode}"
				this.prepArticle siblingNode
				content.push siblingNode

		content

	###
	Get the inner text of a node - cross browser compatibly.
	This also strips out any excess whitespace to be found.

	@param Element
	@return string
	###
	getInnerText: (e, normalizeSpaces) ->
		return '' unless e.textContent?
		normalizeSpaces = normalizeSpaces or true
		textContent = e.textContent.replace(readability.regexps.trim, '')
		textContent.replace this.regexps.normalize, ' ' if normalizeSpaces
		textContent

	###
	Get the number of times a string s appears in the node e.

	@param Element
	@param string - what to split on. Default is ","
	@return number (integer)
	###
	getCharCount: (e, s) ->
		s = s or ','
		readability.getInnerText(e).split(s).length - 1

	###
	Remove the style attribute on every e and under.
	@param Element
	@return void
	###
	cleanAttributes: (e) ->
		_cleanAttributes = (e) ->
			attrs = e.attributes
			i = attrs.length - 1
			while i >= 0
				attr = attrs[i].name.toLowerCase()
				e.removeAttribute attr unless attr in ['src', 'alt', 'href', 'title']
				--i

		dbg this.dbgNode e
		_cleanAttributes e
		dbg this.dbgNode e
		_cleanAttributes node for node in e.getElementsByTagName '*'
		return

	###
	Get the density of links as a percentage of the content
	This is the amount of text that is inside a link divided by the total text in the node.

	@param Element
	@return number (float)
	###
	getLinkDensity: (e) ->
		links = e.getElementsByTagName('a')
		textLength = readability.getInnerText(e).length
		linkLength = 0
		linkLength += readability.getInnerText(link).length for link in links
		linkLength / textLength

	###
	Get an elements class/id weight. Uses regular expressions to tell if this
	element looks good or bad.

	@param Element
	@return number (Integer)
	###
	getClassWeight: (e) ->
		weight = 0

		# Look for a special classname
		if typeof (e.className) is 'string' and e.className isnt ''
			weight -= 25 if e.className.search(readability.regexps.negative) >= 0
			weight += 25 if e.className.search(readability.regexps.positive) >= 0

		# Look for a special ID
		if typeof (e.id) is 'string' and e.id isnt ''
			weight -= 25 if e.id.search(readability.regexps.negative) >= 0
			weight += 25 if e.id.search(readability.regexps.positive) >= 0
		weight

	###
	Clean a node of all elements of type "tag".
	(Unless it's a youtube/vimeo video. People love movies.)

	@param Element
	@param string tag to clean
	@return void
	###
	clean: (e, tag) ->
		isEmbed = tag in ['object', 'embed']
		targetList = e.getElementsByTagName tag
		i = targetList.length - 1
		while i >= 0
			target = targetList[i]
			# Allow youtube and vimeo videos through as people usually want to see those.
			if isEmbed
				attributeValues = (attribute.value for attribute in target.attributes).join '|'
				# First, check the elements attributes to see if any of them contain youtube or vimeo
				continue if attributeValues.search(readability.regexps.videos) >= 0
				# Then check the elements inside this element for the same.
				continue if target.innerHTML.search(readability.regexps.videos) >= 0
			target.parentNode.removeChild target
			--i
		return

	###
	Clean an element of all tags of type "tag" if they look fishy.
	"Fishy" is an algorithm based on content length, classnames, link density, number of images & embeds, etc.

	@return void
	###
	cleanConditionally: (e, tag) ->
		tags = e.getElementsByTagName(tag)
		# Gather counts for other typical elements embedded within.
		# Traverse backwards so we can remove nodes at the same time without effecting the traversal.
		# TODO: Consider taking into account original contentScore here.
		i = tags.length - 1
		while i >= 0
			tag = tags[i]
			weight = readability.getClassWeight tag
			contentScore = if tag.readability? then tag.readability.contentScore else 0
			dbg "Cleaning Conditionally #{this.dbgNode tag}"
			if weight + contentScore < 0
				tag.parentNode.removeChild tag
			else if readability.getCharCount(tag, ',') < 10
				# If there are not very many commas, and the number of
				# non-paragraph elements is more than paragraphs or other ominous signs, remove the element.
				p = tag.getElementsByTagName('p').length
				img = tag.getElementsByTagName('img').length
				li = tag.getElementsByTagName('li').length - 100
				input = tag.getElementsByTagName('input').length
				embeds = tag.getElementsByTagName('embed')
				embedCount = 0
				for embed in embeds
					++embedCount unless embed.src.search(readability.regexps.videos) >= 0
				linkDensity = readability.getLinkDensity tag
				contentLength = readability.getInnerText(tag).length
				toRemove = false
				if img > p
					toRemove = true
				else if li > p and tag isnt 'ul' and tag isnt 'ol'
					toRemove = true
				else if input > Math.floor(p / 3)
					toRemove = true
				else if contentLength < 25 and (img is 0 or img > 2)
					toRemove = true
				else if weight < 25 and linkDensity > 0.2
					toRemove = true
				else if weight >= 25 and linkDensity > 0.5
					toRemove = true
				else toRemove = true if (embedCount is 1 and contentLength < 75) or embedCount > 1
				tag.parentNode.removeChild tag if toRemove
			--i
		return

	###
	Clean out spurious headers from an Element. Checks things like classnames and link density.

	@param Element
	@return void
	###
	cleanHeaders: (e) ->
		for headerIndex in [1...3]
			headers = e.getElementsByTagName("h#{headerIndex}")
			for header in headers
				if this.getClassWeight(header) < 0 or this.getLinkDensity(header) > 0.33
					header.parentNode.removeChild header
		return

	###
	Smooth scrolling logic

	easeInOut animation algorithm - returns an integer that says how far to move at this point in the animation.
	Borrowed from jQuery's easing library.

	@return integer
	###
	easeInOut: (start, end, totalSteps, actualStep) ->
		delta = end - start
		return delta / 2 * actualStep * actualStep + start if (actualStep /= totalSteps / 2) < 1
		--actualStep
		-delta / 2 * ((actualStep) * (actualStep - 2) - 1) + start


	###
	Helper function to, in a cross compatible way, get or set the current scroll offset of the document.
	@return mixed integer on get, the result of window.scrollTo on set
	###
	scrollTop: (scroll) ->
		setScroll = typeof scroll isnt 'undefined'
		return window.scrollTo(0, scroll) if setScroll
		if typeof window.pageYOffset isnt 'undefined'
			window.pageYOffset
		else if document.documentElement.clientHeight
			document.documentElement.scrollTop
		else
			document.body.scrollTop

	###
	scrollTo - Smooth scroll to the point of scrollEnd in the document.
	@return void
	###
	curScrollStep: 0
	scrollTo: (scrollStart, scrollEnd, steps, interval) ->
		if (scrollStart < scrollEnd and this.scrollTop() < scrollEnd) or (scrollStart > scrollEnd and this.scrollTop() > scrollEnd)
			++this.curScrollStep
			return if this.curScrollStep > steps
			oldScrollTop = this.scrollTop()
			this.scrollTop this.easeInOut scrollStart, scrollEnd, steps, readability.curScrollStep

			# We're at the end of the window.
			return if oldScrollTop is this.scrollTop()
			window.setTimeout (->
				this.scrollTo scrollStart, scrollEnd, steps, interval
			), interval

	dbgNode: (node) ->
		tag = node.tagName
		clazz = if node.className then " class=\"#{node.className}\"" else ''
		id = if node.id then " id=\"#{node.id}\"" else ''
		score = if node?.readability?.contentScore then " score=\"#{node.readability.contentScore}\"" else ''
		"<#{tag}#{id}#{clazz}#{score}/>"

self.port.on 'init', ->
	readability.init()
	window.focus()

self.port.on 'click', (opts) ->
	readability.sizeClass = opts.storage.size if opts.storage.size
	readability.marginClass = opts.storage.margin if opts.storage.margin
	readability.styleClass = opts.storage.style if opts.storage.style
