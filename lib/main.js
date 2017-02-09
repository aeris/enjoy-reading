const tabs = require('sdk/tabs');
const hotkey = require('sdk/hotkeys');
const data = require('sdk/self').data;
const ss = require('sdk/simple-storage');

var onClick = function () {
	worker = tabs.activeTab.attach({
		contentScriptFile: [
			data.url('readability.js'),
			data.url('resources.js')
		]
	});

	worker.port.emit('click', {
		storage: {
			size: ss.storage.size,
			margin: ss.storage.margin,
			style: ss.storage.style
		}
	});

	worker.port.on('ready', function () {
		worker.port.emit('init');
	});

	worker.port.on('style', function (opts) {
		ss.storage[opts.rule] = opts.value;
	});
};

const { ActionButton } = require('sdk/ui/button/action');
var button = ActionButton({
	id: 'enjoy-reading',
	label: 'Enjoy Reading',
	icon: {
		16: "./images/icon16.png",
		32: "./images/icon32.png",
	},
	onClick: onClick
});

const { Hotkey } = require('sdk/hotkeys');
Hotkey({
	combo: 'accel-e',
	onPress: onClick
});
