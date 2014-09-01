# Middleware to control the rest of the requests.

async = require 'async'
hbs = require 'hbs'
pathRegexp = require 'path-to-regexp'
express = require 'express'
_ = require 'underscore'

config = require '../config'
Route = require '../models/route'

module.exports = app = express()
tplPath = config.templatePath

require('../lib/renderer')(hbs)

app.set 'views', tplPath
app.set 'view cache', off

app.use express.static config.publicPath, maxAge: 86400000 * 7 # One week

plugins = app.get 'plugins'

app.get '*', (req, res, next) ->

  # dynamic renderTime helper
  hbs.registerHelper 'renderTime', ->
    now = new Date
    (now - req.startTime) + 'ms'

  # Prepare the global template data
  templateData =
    adminSegment: config.adminSegment
    req:
      body: req.body
      path: req.path
      query: req.query unless _.isEmpty(req.query)
      params: {}
    user: req.user
    errors: []

  globalNext = null
  globalNextCalled = no
  hbs.registerHelper 'next', ->
    globalNext.called = yes
    globalNext? false

  # We could use a $where here, but it's basically the same
  # since a basic $where scans all rows (plus this gives us more flexibility)
  Route.find {}, null, sort: 'sort', (err, routes) ->
    return console.log 'Error looking up Routes.', err if err

    matchingRoutes = []

    for route in routes
      matches = route.urlPatternRegex.exec req.path

      if matches
        localTemplateData = _.clone templateData
        localTemplateData.template = route.template
        localTemplateData.req.params[key.name] = matches[i+1] for key, i in route.keys

        matchingRoutes.push localTemplateData

    # The magical, time-traveling Template lookup/renderer
    async.detectSeries matchingRoutes, (localTemplateData, callback) ->
      globalNext = callback
      globalNext.called = no
      localTemplateData = _.extend localTemplateData, templateData

      res.render localTemplateData.template, localTemplateData, (err, html) ->

        if err
          tplErr = {}
          tplErr[localTemplateData.template] = err.message
          templateData.errors.push tplErr
          callback false, "#{err.name} #{err.message}"
        else if html and not globalNext.called
          res.status(200).send html
          callback true
        else if not html
          callback false, 'The rendered page was blank.'
    , (rendered) ->
      return if rendered
      console.log 'Couldn’t match a Route, trying to render `error` template.'
      templateData.errorCode = 404
      templateData.errorText = 'Page missing'

      res.render 'error', templateData, (err, html) ->
        console.log 'Buckets caught an error trying to render the error page.', err if err

        if err
          res.status(404).end()
        else
          res.status(404).send html
