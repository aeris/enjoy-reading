.PHONY: build run xpi clean
OBJECTS =

%.js: %.coffee
	coffee -bc "$<"

%.css: %.scss
	sass --sourcemap=none "$<" "$@"

pkg:
	mkdir "$@" "$@/data" "$@/lib"

pkg/%: % pkg
	cp -r "$<" "$@"

build: data/resources.js data/readability.js data/readability.css

enjoy-reading.xpi: build \
	pkg/data/readability.js pkg/data/readability.css \
	pkg/data/resources.js pkg/data/images pkg/lib/main.js \
	pkg/package.json
	cfx xpi --pkgdir=pkg

run: build
	cfx run --profiledir=~/.mozilla/firefox/test

xpi: enjoy-reading.xpi

clean:
	rm data/resources.js data/readability.js data/readability.css
	rm -r pkg

