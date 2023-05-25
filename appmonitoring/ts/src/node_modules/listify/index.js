'use strict';

var has = Function.call.bind(Object.prototype.hasOwnProperty);
var join = Function.call.bind(Array.prototype.join);
var trim = Function.call.bind(String.prototype.trim);
var isArray = Array.isArray;
var filter = Function.call.bind(Array.prototype.filter);
var slice = Function.call.bind(Array.prototype.slice);
var concat = Function.call.bind(Array.prototype.concat);

module.exports = function listify(list) {
	if (!isArray(list)) {
		throw new TypeError('requires an array');
	}

	var options = arguments.length > 1 ? arguments[1] : null;
	if (!options) {
		options = {};
	}
	var separator = has(options, 'separator') ? options.separator : ', ';
	var finalWord = has(options, 'finalWord') ? options.finalWord : 'and';
	if (finalWord.length > 0) {
		finalWord += ' ';
	}

	var trimmed = filter(list, trim);
	var str;
	if (trimmed.length === 2 && finalWord.length > 0) {
		str = join(trimmed, ' ' + finalWord);
	} else if (trimmed.length < 3) {
		str = join(trimmed, separator);
	} else {
		str = join(concat(slice(trimmed, 0, -1), finalWord + trimmed[trimmed.length - 1]), separator);
	}
	return str;
};

