
fs      = require 'fs.extra'
Promise = require 'bluebird'
path    = require 'path'
_       = require 'lodash'
utils   = require './utils'

{FileSystemConfigStorageBackend} = require './config-storage-backend-filesystem'


class ConfigController

    constructor: ({@root, @key}) ->
        console.log "Initialized with root `#{@root}`."
        @storage = new FileSystemConfigStorageBackend({@root})

    # Get the list of organizations
    getOrganizations: -> Promise.try =>
        @_checkRoot()
        .then =>
            @storage.directory.read(@root)
        .then (organizations) =>
            Promise.settle organizations.map (organization) => @_checkOrganization(organization)
        .then (results) =>
            fulfilled = _.filter results, (result) -> result.isFulfilled()
            return fulfilled.map (result) -> result.value()

    # Get an organization's config
    getConfig: (organization) -> Promise.try =>
        @_validateOrganization(organization)
        @_checkRoot()
        .then => @_checkOrganization(organization)
        .then =>
            @_readConfig(organization).catch (error) ->
                console.error("Organization `#{organization}` exists, but the config file could not be read.")
                console.error("Native error:\n", error)
                throw new ConfigFileNotFoundError({organization})
        .then (data) =>
            try
                data = @_parseConfig(data)
                return {organization, data}
            catch error
                console.error("Data deserialization error:\n#{error.toString()}")
                throw new DataDeserializationError({organization, data})

    # Write a version of a config, for a specific organization
    writeConfig: (organization, data) -> Promise.try =>
        @_validateOrganization(organization)
        @_validateData(data)
        @_checkRoot()
        .then => @_createOrganizationIfItDoesntExist(organization)
        .then =>
            filepath = @_getConfigFilepath organization
            try data = @_stringifyConfig data
            catch error then throw new DataSerializationError({organization, data})
            @storage.file.write(filepath, data).then => @getConfig(organization)

    # Deletes an organization, durr
    deleteOrganization: (organization) -> Promise.try =>
        @_validateOrganization(organization)
        @_checkRoot()
        .then =>
            @_checkOrganization(organization)
        .then =>
            orgDir = @_getOrganizationDir(organization)
            @storage.directory.delete(orgDir)

    _checkRoot: ->
        @storage.directory.exists(@root)
        .catch (error) =>
            throw new InvalidRootDirectoryError({@root})
        .then (exists) =>
            return exists or throw new RootDirectoryNotFoundError({@root})

    _createOrganizationIfItDoesntExist: (organization) ->
        orgDir = @_getOrganizationDir(organization)
        @storage.directory.create(orgDir)

    _checkOrganization: (organization) ->
        organizationDir = @_getOrganizationDir(organization)
        @storage.directory.exists(organizationDir).then (exists) ->
            return organization if exists
            throw new OrganizationNotFoundError({organization})

    _readConfig: (organization) ->
        configFilepath = @_getConfigFilepath(organization)
        @storage.file.read(configFilepath)

    _generateTimestamp: ->
        Date.now()

    _parseConfig: (data) ->
        JSON.parse data

    _stringifyConfig: (configObject) ->
        JSON.stringify configObject, null, 2

    _getOrganizationDir: (organization) ->
        utils.sandboxedPathJoin @root, organization

    _getConfigFilepath: (organization) ->
        orgDir = @_getOrganizationDir organization
        utils.sandboxedPathJoin orgDir, @_getConfigFilename()

    _getConfigFilename: -> @key

    _validateOrganization: (organization) ->
        valid = organization isnt undefined \
            and organization isnt null      \
            and (/^([a-zA-Z0-9_\-]|\.[^\.])+$/.test organization)
        return organization if valid
        throw new InvalidOrganizationError
            organization: organization
            validator: "^([a-zA-Z0-9_\-]|\.[^\.])+$"

    _validateData: (data) ->
        return data if data and _.isObject(data)
        throw new InvalidDataError({data})


class Config
    constructor: ({@descriptor, @data}) ->
    serialize: ->
        descriptor: @descriptor.serialize()
        data: @data


class ConfigControllerError extends Error
    constructor: (@message) ->
        @type = @constructor.name
        Error.captureStackTrace(@, ConfigControllerError)

class RootDirectoryNotFoundError extends ConfigControllerError
    constructor: ({@root}) ->
        super "Root directory `#{@root}` does not exist."

class OrganizationNotFoundError extends ConfigControllerError
    constructor: ({@organization}) ->
        super "Organization `#{@organization}` was not found."

class ConfigFileNotFoundError extends ConfigControllerError
    constructor: ({@organization}) ->
        super "Config file for organization `#{@organization}` was not found."

class InvalidRootDirectoryError extends ConfigControllerError
    constructor: ({@root, @error}) ->
        super "Invalid root directory `#{@root}`."

class InvalidOrganizationError extends ConfigControllerError
    constructor: ({@organization, @validator}) ->
        super "Invalid organization `#{@organization}`."

class InvalidDataError extends ConfigControllerError
    constructor: ({@organization}) ->
        super "Invalid configuration data for organization `#{@organization}`. Must be a JSON object."

class DataDeserializationError extends ConfigControllerError
    constructor: ({@organization, @data}) ->
        super "Error while deserializing config data for organization `#{@organization}`."

class DataSerializationError extends ConfigControllerError
    constructor: ({@organization, @data}) ->
        super "Error while serializing config data."


module.exports = {
    ConfigController
    models: {
        Config
    }
    errors: {
        ConfigControllerError
        RootDirectoryNotFoundError
        OrganizationNotFoundError
        ConfigFileNotFoundError
        InvalidRootDirectoryError
        InvalidOrganizationError
        InvalidDataError
        DataDeserializationError
        DataSerializationError
    }
}
