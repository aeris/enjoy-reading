.PHONY: build run xpi clean
OBJECTS =

%.js: %.coffee
	coffee -bc "$<"

enjoy-reading.xpi: build
	cfx xpi

build: data/resources.js

run: build
	cfx run

xpi: enjoy-reading.xpi

clean:
	rm data/resources.js

