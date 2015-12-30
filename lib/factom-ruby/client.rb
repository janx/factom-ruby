require 'bigdecimal'
require 'bitcoin'
require 'digest'
require 'json'
require 'rbnacl'
require 'rest-client'

module Factom
  module APIv1
    GetBalanceFailed = "Failed to get balance!"

    DENOMINATION_FACTOID = 100000000
    DENOMINATION_ENTRY_CREDIT = 1

    def height
      json = get "/v1/directory-block-height/"
      json['Height']
    end

    def head
      json = get "/v1/directory-block-head/"
      json['KeyMR']
    end

    def block(keymr)
      get "/v1/directory-block-by-keymr/#{keymr}"
    end

    def chain_head(id)
      json = get "/v1/chain-head/#{id}"
      json['ChainHead']
    end

    def entry_block(keymr)
      get "/v1/entry-block-by-keymr/#{keymr}"
    end

    def fee
      json = get "/v1/factoid-get-fee/"
      json['Fee']
    end

    def properties
      get "/v1/properties/"
    end

    def fa_balance(pubkey)
      json = get "/v1/factoid-balance/#{pubkey}"
      raise GetBalanceFailed unless json['Success']
      json['Response']
    end

    def fa_balance_in_decimal(pubkey)
      BigDecimal.new(fa_balance(pubkey)) / DENOMINATION_FACTOID
    end

    def ec_balance(pubkey=ec_public_key)
      json = get "/v1/entry-credit-balance/#{pubkey}"
      raise GetBalanceFailed unless json['Success']
      json['Response']
    end

    def ec_balance_in_decimal(pubkey=ec_public_key)
      BigDecimal.new(ec_balance(pubkey)) / DENOMINATION_ENTRY_CREDIT
    end

    def commit_entry(chain_id, extids, content)
    end

  end

  class Client
    attr :endpoint

    PREFIX_FA = 'FA'.freeze
    PREFIX_EC = 'EC'.freeze
    ADDRESS_PREFIX = {
      PREFIX_FA => '5fb1',
      PREFIX_EC => '592a'
    }.freeze

    def initialize(endpoint, ec_private_key, version='v1')
      @endpoint = endpoint.gsub(/\/\z/, '')
      @ec_private_key = ec_private_key =~ /\A#{PREFIX_EC}/ ? address_to_pubkey(ec_private_key) : ec_private_key
      self.instance_eval { extend ::Factom.const_get("API#{version}", false) }
    end

    def get(path, params={}, options={})
      do_request :get, path, params, options
    end

    def post(path, params={}, options={})
      do_request :post, path, params, options
    end

    def ec_public_key
      @ec_public_key ||= signing_key.verify_key.to_s.unpack('H*').first
    end

    def ec_address
      @ec_address ||= pubkey_to_address ADDRESS_PREFIX[PREFIX_EC], ec_public_key
    end

    # to pubkey in hex, 32 bytes
    def address_to_pubkey(addr)
      return unless addr.size == 52

      prefix = ADDRESS_PREFIX[addr[0,2]]
      return unless prefix

      v = Bitcoin.decode_base58(addr)
      return if v[0,4] != prefix

      bytes = [v[0, 68]].pack('H*')
      sha256d = Digest::SHA256.hexdigest(Digest::SHA256.digest(bytes))
      return if v[68, 8] != sha256d[0, 8]

      v[4, 64]
    end

    def pubkey_to_address(prefix, pubkey)
      return unless pubkey.size == 64 # 32 bytes in hex

      addr = "#{prefix}#{pubkey}"
      bytes = [addr].pack('H*')
      sha256d = Digest::SHA256.hexdigest(Digest::SHA256.digest(bytes))

      Bitcoin.encode_base58 "#{addr}#{sha256d[0,8]}"
    end

    private

    def do_request(method, path, params, options)
      uri = "#{endpoint}#{path}"

      options = {accept: :json}.merge(options)
      options[:params] = params

      resp = RestClient.send method, uri, options
      JSON.parse resp
    end

    # ed25519 private key
    def signing_key
      @signing_key ||= RbNaCl::SigningKey.new([@ec_private_key].pack('H*'))
    end

  end
end
