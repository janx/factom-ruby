require_relative '../lib/factom-ruby'

ec_private_key = '0000000000000000000000000000000000000000000000000000000000000000'
f = Factom::Client.new('http://localhost:8088', ec_private_key)

chain_ids = {}

keymr = f.head
loop do
  raise StopIteration if keymr == '0000000000000000000000000000000000000000000000000000000000000000'

  block = f.block keymr
  keymr = block['Header']['PrevBlockKeyMR']

  block['EntryBlockList'].each do |ebl|
    id = ebl['ChainID']
    if !chain_ids[id] &&
        id != '000000000000000000000000000000000000000000000000000000000000000a' &&
        id != '000000000000000000000000000000000000000000000000000000000000000c' &&
        id != '000000000000000000000000000000000000000000000000000000000000000f'
      chain_ids[id] = true
    end
  end
end

puts chain_ids.keys.join("\n")
