
path = require 'path'


exports.sandboxedPathJoin = (root, paths...) ->
    path.join root, (path.join '/', paths...)
