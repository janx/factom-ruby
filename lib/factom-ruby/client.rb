require 'bigdecimal'
require 'bitcoin'
require 'digest'
require 'json'
require 'rest-client'

module Factom
  module APIv1
    InvalidFactoidAddress = "Invalid factoid address!"
    InvalidEntryCreditAddress = "Invalid entry credit address!"
    GetBalanceFailed = "Failed to get balance!"

    FACTOID_ADDRESS_PREFIX = '5fb1'.freeze
    ENTRY_CREDIT_ADDRESS_PREFIX = '592a'.freeze

    FACTOID_DENOMINATION = 100000000
    ENTRY_CREDIT_DENOMINATION = 1

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

    def fa_balance(addr)
      json = get "/v1/factoid-balance/#{decode_fa_addr(addr)}"
      raise GetBalanceFailed unless json['Success']
      json['Response']
    end

    def fa_balance_in_decimal(addr)
      BigDecimal.new(fa_balance(addr)) / FACTOID_DENOMINATION
    end

    def ec_balance(addr)
      json = get "/v1/entry-credit-balance/#{decode_ec_addr(addr)}"
      raise GetBalanceFailed unless json['Success']
      json['Response']
    end

    def ec_balance_in_decimal(addr)
      BigDecimal.new(ec_balance(addr)) / ENTRY_CREDIT_DENOMINATION
    end

    def decode_fa_addr(addr)
      addr =~ /\AFA/ ? decode_address(FACTOID_ADDRESS_PREFIX, addr) : addr
    end

    def decode_ec_addr(addr)
      addr =~ /\AEC/ ? decode_address(ENTRY_CREDIT_ADDRESS_PREFIX, addr) : addr
    end

    private

    def decode_address(prefix, addr)
      return unless addr.size == 52

      v = Bitcoin.decode_base58(addr)
      return if v[0,4] != prefix

      bytes = [v[0, 68]].pack('H*')
      sha256d = Digest::SHA256.hexdigest(Digest::SHA256.digest(bytes))
      return if v[68, 8] != sha256d[0, 8]

      v[4, 64]
    end

  end

  class Client
    attr :endpoint

    def initialize(endpoint, version='v1')
      @endpoint = endpoint.gsub(/\/\z/, '')
      self.instance_eval { extend ::Factom.const_get("API#{version}", false) }
    end

    def get(path, params={}, options={})
      uri = "#{endpoint}#{path}"

      options = {accept: :json}.merge(options)
      options[:params] = params

      resp = RestClient.get uri, options
      JSON.parse resp
    end
  end
end
