.PHONY: build run xpi clean
.DEFAULT_GOAL := xpi
OBJECTS =

%.js: %.coffee
	coffee -bc "$<"

%.css: %.scss
	sass --sourcemap=none "$<" "$@"

build: data/resources.js data/readability.js data/readability.css

enjoy-reading.xpi: build \
	data/readability.js data/readability.css \
	data/resources.js data/images pkg/lib/main.js
	~/.npm/bin/jpm xpi

run: build
	~/.npm/bin/jpm run --profile=dev

xpi: enjoy-reading.xpi

clean:
	rm data/resources.js data/readability.js data/readability.css

