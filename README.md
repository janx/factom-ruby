# Ruby Client for Factom

A ruby client who talks to `factomd` in [Factom](http://factom.org) project.

## Features

* Encode/decode messages for you
* Independent, work without `fctwallet` and `factom-cli`
* No account management, use `factom-cli` for that purpose

## Install

```
gem i factom-ruby
```

or

Add it to your Gemfile:

```
gem 'factom-ruby'
```

## Usage

```ruby
require 'factom-ruby'

ec_private_key = '0000000000000000000000000000000000000000000000000000000000000000'
f = Factom::Client.new('http://factomd.node.ip:8088', ec_private_key)

#################
# get some info #
#################

p f.properties
p f.fee

################
# get balances #
################

fa_address = 'FAblahblah...' # Factoid address
fa_pubkey = f.address_to_pubkey fa_address
p f.fa_balance_in_decimal(fa_pubkey)

f.ec_address # EntryCredit address, calculated automatically from ec_private_key
p f.ec_balance_in_decimal # default to balance on f.ec_address

###########################################################################
# create a new chain, remember to choose a unique chain names combination #
###########################################################################

resp = f.commit_chain %w(three body problem), "the world belongs to ???"
puts "resp code: #{resp.code} body: #{resp.body}"
resp = f.reveal_chain %w(three body problem), "the world belongs to ???"
puts "resp code: #{resp.code} body: #{resp.body}"

######################
# submit a new entry #
######################

resp = f.commit_entry(some_chain_id, %w(chapter1), "once upon a time ...")
puts "resp code: #{resp.code} body: #{resp.body}"
resp = f.reveal_entry(some_chain_id, %w(chapter1), "once upon a time ...")
puts "resp code: #{resp.code} body: #{resp.body}"
```

Check [examples](examples/) directory for more examples.

## License

[MIT License](LICENSE)

