crypto = require "crypto"

# The key used to generate HMACs
key = process.env.key || ''

# Escape newlines as '\n' and \ as '\\'
escape = (s) -> s.toString().replace("\n", "\\n").replace('\\','\\\\')

# Generate a SHA1-HMAC for the provided dictionary
# See 'make' for more information about how this happens
hmac = (dict) ->

  # Filter, sort and escape the strings
  keys = ([k, v] for k, v of dict when k[0] != '_' && k != 'HMAC') 
  keys.sort (a,b) -> if a[0] > b[0] then 1 else if a[0] < b[0] then -1 else 0
  keys = (escape x for x in [].concat.apply [], keys)

  # Run the HMAC
  hash = crypto.createHmac 'sha1', key
  hash.update keys.join "\n"
  hash.digest 'base64'  

# Generate a proof for a dictionary :
#  - Keys that start with '_' are ignored
#  - A key named HMAC, if present, is ignored
#  - Key ordering is irrelevant
# 
# This function returns the original object, with an ISO8601
# representation of the expiration date in field 'expires' and
# the HMAC in field 'HMAC'.
#
# The 'expires' field is used to compute the HMAC
# 
# Expiration time is expressed in minutes
module.exports.make = (dict,expires = 10) ->

  # Fill in the expiration date
  now = new Date
  exp = new Date(expires * 60 * 1000 + +now)
    
  dict.expires = exp.toISOString()

  # Fill in the HMAC
  dict.HMAC = hmac dict

  dict

# If the dictionary was generated using 'make' and has not expired
# yet, return true
module.exports.check = (dict) -> 
  
  typeof dict.HMAC == 'string' &&
    typeof dict.expires == 'string' &&
    dict.expires > (new Date).toISOString() &&
    hmac(dict) == dict.HMAC


  
    
