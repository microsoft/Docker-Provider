#listify <sup>[![Version Badge][npm-version-svg]][npm-url]</sup>

[![Build Status][travis-svg]][travis-url]
[![dependency status][deps-svg]][deps-url]
[![dev dependency status][dev-deps-svg]][dev-deps-url]

Turn an array into a list of comma-separated values, appropriate for use in an English sentence.

## Example

```js
var listify = require('listify');

assert(listify([1, 2]) === '1 and 2');
assert(listify([1, 2, 3]) === '1, 2, and 3');
assert(listify([1, 2, 3, 4]) === '1, 2, 3, and 4');
assert(listify([1, 2, 3], { separator: '… ' }) === '1… 2… and 3');
assert(listify([1, 2, 3], { finalWord: false }) === '1, 2, 3');
assert(listify([1, 2, 3], { separator: '… ', finalWord: 'or' }) === '1… 2… or 3');
```

## Tests
Simply clone the repo, `npm install`, and run `npm test`

[npm-url]: https://npmjs.org/package/listify
[npm-version-svg]: http://versionbadg.es/ljharb/listify.svg
[travis-svg]: https://travis-ci.org/ljharb/listify.svg
[travis-url]: https://travis-ci.org/ljharb/listify
[deps-svg]: https://david-dm.org/ljharb/listify.svg
[deps-url]: https://david-dm.org/ljharb/listify
[dev-deps-svg]: https://david-dm.org/ljharb/listify/dev-status.svg
[dev-deps-url]: https://david-dm.org/ljharb/listify#info=devDependencies

