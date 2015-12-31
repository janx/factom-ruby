require 'bigdecimal'
require 'bitcoin'
require 'digest'
require 'json'
require 'rbnacl'
require 'rest-client'

module Factom
  module APIv1
    GetBalanceFailed = "Failed to get balance!"

    VERSION = '00'.freeze

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

    def commit_entry(chain_id, ext_ids, content)
      params = { 'CommitEntryMsg' => get_entry_commit(chain_id, ext_ids, content) }
      # TODO: will factom make response return json, for a better world?
      raw_post "/v1/commit-entry/", params.to_json, content_type: :json
    end

    def reveal_entry(chain_id, ext_ids, content)
      params = { 'Entry' => build_entry(chain_id, ext_ids, content) }
      # TODO: the same, replace raw_post with post
      raw_post "/v1/reveal-entry/", params.to_json, content_type: :json
    end

    private

    def get_entry_commit(chain_id, ext_ids, content)
      timestamp = (Time.now.to_f*1000).floor
      ts = [ timestamp ].pack('Q>').unpack('H*').first

      entry = build_entry(chain_id, ext_ids, content)
      entry_hash = get_entry_hash entry

      # FIXME: pack to unsigned char, overflow risk
      fee = [ calculate_fee(entry) ].pack('C').unpack('H*').first

      commit = "#{VERSION}#{ts[4..-1]}#{entry_hash}#{fee}"
      signature = signing_key.sign([commit].pack('H*')).unpack('H*').first

      "#{commit}#{ec_public_key}#{signature}"
    end

    def get_entry_hash(entry)
      sha512 = Digest::SHA512.hexdigest([entry].pack('H*')) + entry
      Digest::SHA256.hexdigest [sha512].pack('H*')
    end

    def build_entry(chain_id, ext_ids, content)
      len = 0
      ext_ids_hex = []
      content_hex = content.unpack('H*').first

      ext_ids.each do |id|
        len += id.size + 2
        ext_ids_hex.push uint16_to_hex(id.size)
        ext_ids_hex.push id.unpack('H*').first
      end

      "#{VERSION}#{chain_id}#{uint16_to_hex(len)}#{ext_ids_hex.join}#{content_hex}"
    end

    def calculate_fee(entry)
      fee = entry.size / 2 # count of entry bytes
      fee -= 35 # header doesn't count
      (fee+1023)/1024 # round up and divide, rate = 1 EC/KiB
    end

    def uint16_to_hex(i)
      [i].pack('n').unpack('H*').first
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

    def raw_get(path, params={}, options={})
      uri = "#{endpoint}#{path}"
      options = {accept: :json}.merge(options)
      options[:params] = params

      RestClient.get uri, options
    end

    def get(path, params={}, options={})
      JSON.parse raw_get(path, params, options)
    end

    def raw_post(path, params={}, options={})
      uri = "#{endpoint}#{path}"
      options = {accept: :json}.merge(options)

      RestClient.post uri, params, options
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

    # ed25519 private key
    def signing_key
      @signing_key ||= RbNaCl::SigningKey.new([@ec_private_key].pack('H*'))
    end

  end
end
