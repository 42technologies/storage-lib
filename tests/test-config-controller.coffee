
fs     = require 'fs.extra'
rimraf = require 'rimraf'
path   = require 'path'
require("mocha-as-promised")()

chai = require 'chai'
chai.use require("chai-as-promised")
assert = chai.assert
expect = chai.expect
should = chai.should()


describe 'ConfigController:', ->

    {errors, ConfigController} = require '../lib/config-controller'

    shouldBeRejectedWith = (ErrorClass) ->
        throw new Error("Invalid ErrorClass `#{ErrorClass}`.") if not ErrorClass
        type = (new ErrorClass({})).type
        (promise) ->
            promise.then(
                (result) ->
                    console.log result.toString()
                    assert(false, "Was fulfilled. It should have been rejected with error `#{type}`.")
                (error) -> assert(type is error.type, "Was rejected, but expecting `#{type}` not `#{error.type}`.")
            )

    deleteConfigRoot = (root) -> rimraf.sync root
    createConfigRoot = (root) -> fs.mkdirpSync root

    ROOT = path.join __dirname, 'test-config'
    organization = 'bacon'
    firstConfig = {lol:'wut'}
    secondConfig = {foo:'bar'}
    configController = new ConfigController(root:ROOT, key:'config.json')


    describe 'Check Root', ->
        before -> deleteConfigRoot ROOT
        after  -> deleteConfigRoot ROOT

        it 'should fail because of missing root dir', ->
            shouldBeRejectedWith(errors.RootDirectoryNotFoundError)(
                configController._checkRoot()
            )


    describe 'Input Validation', ->

        before ->
            deleteConfigRoot ROOT
            createConfigRoot ROOT

        after ->
            deleteConfigRoot ROOT

        it '#getConfig invalid organization ', ->
            shouldBeRejectedWith(errors.InvalidOrganizationError)(
                configController.getConfig()
            )
            shouldBeRejectedWith(errors.InvalidOrganizationError)(
                configController.getConfig('/etc/passwd')
            )
        it '#writeConfig invalid organization', ->
            shouldBeRejectedWith(errors.InvalidOrganizationError)(
                configController.writeConfig()
            )
            shouldBeRejectedWith(errors.InvalidOrganizationError)(
                configController.writeConfig('/etc/passwd')
            )
        it '#writeConfig invalid data', ->
            shouldBeRejectedWith(errors.InvalidDataError)(
                configController.writeConfig(organization, 'herpderp')
            )


    describe 'CRUD', ->

        before ->
            deleteConfigRoot ROOT
            createConfigRoot ROOT

        after ->
            deleteConfigRoot ROOT

        it '#deleteConfig should not work', ->
            shouldBeRejectedWith(errors.OrganizationNotFoundError)(
                configController.deleteOrganization('dunnolol')
            )

        it '#getOrganizations should return an empty list', ->
            configController.getOrganizations().should.become []

        it '#writeConfig should create a new organization and config', ->
            configController.writeConfig(organization, firstConfig).should.be.fulfilled

        it '#getOrganizations should return only one organization', ->
            configController.getOrganizations().should.eventually.have.length 1

        it '#getConfig should get the config', ->
            expectedResult = {organization, data:firstConfig}
            configController.getConfig(organization).should.become expectedResult

        it '#writeConfig update the config', ->
            configController.writeConfig(organization, secondConfig).should.be.fulfilled

        it '#getConfig should get the updated config', ->
            expectedResult = {organization, data:secondConfig}
            configController.getConfig(organization).should.become expectedResult

        it '#deleteOrganization should delete the organization', ->
            configController.deleteOrganization(organization).should.be.fulfulled

