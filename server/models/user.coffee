bcrypt = require 'bcrypt'
crypto = require 'crypto'
mongoose = require 'mongoose'
uniqueValidator = require 'mongoose-unique-validator'
db = require '../lib/database'

Schema = mongoose.Schema

userSchema = new Schema
  name: 
    type: String
    required: true
  email: 
    type: String
    required: true
    lowercase: true
    trim: true
    unique: true
  password:
    type: String
    required: true
    set: (password) ->
      return unless password
      salt = bcrypt.genSaltSync()
      bcrypt.hashSync password, salt
  activated: 
    type: Boolean
    default: false
  last_active:
    type: Date
    default: Date.now
  date_created:
    type: Date
    default: Date.now

userSchema.methods.authenticate = (password, callback) ->
  bcrypt.compareSync password, @password

userSchema.virtual('email_hash').get ->
  crypto.createHash('md5').update(@email).digest('hex') if @email

userSchema.path('password').validate (value) ->
  /^(?=[^\d_].*?\d)\w(\w|[!@#$%]){5,20}/.test value
, 'Your password must be between 6–20 characters, start with a letter, and include a number.'

userSchema.plugin uniqueValidator, message: '“{VALUE}” is already a user.'

userSchema.set 'toJSON', virtuals: true

module.exports = db.model 'User', userSchema