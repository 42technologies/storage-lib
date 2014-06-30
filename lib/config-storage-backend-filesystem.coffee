
Promise = require 'bluebird'
fs      = Promise.promisifyAll(require 'fs.extra')


class FileSystemConfigStorageBackend

    constructor: ({root}) ->
        fs.mkdirpSync(root)

    file:
        read: (path) ->
            fs.readFileAsync(path)
        write: (path, data) ->
            fs.writeFileAsync(path, data)
        exists: (path) ->
            fs.statAsync(path)
            .then (stats) ->
                return true if !stats.isDirectory()
            .catch ->
                return false

    directory:
        read: (path) ->
            fs.readdirAsync(path)
        exists: (path) ->
            fs.statAsync(path)
            .then (stats) ->
                return true if stats.isDirectory()
                throw new Error("Invalid Directory.")
            .catch ->
                return false
        create: (path) ->
            fs.mkdirpAsync(path)
        delete: (path) ->
            fs.rmrfAsync(path)


module.exports = {FileSystemConfigStorageBackend}
