require "uri"
require "tss"
require "base64"
require "active_support/core_ext/securerandom"

if SERVICE_CONFIGURATIONS[:horcrux]
	RSpec.describe ActiveStorage::Service::HorcruxService do
		DISK1 = ActiveStorage::Service.configure(:disk1, SERVICE_CONFIGURATIONS)
		DISK2 = ActiveStorage::Service.configure(:disk2, SERVICE_CONFIGURATIONS)
		SERVICE = ActiveStorage::Service.configure(:horcrux, SERVICE_CONFIGURATIONS)
		FIXTURE_DATA  = "\211PNG\r\n\032\n\000\000\000\rIHDR\000\000\000\020\000\000\000\020\001\003\000\000\000%=m\"\000\000\000\006PLTE\000\000\000\377\377\377\245\331\237\335\000\000\0003IDATx\234c\370\377\237\341\377_\206\377\237\031\016\2603\334?\314p\1772\303\315\315\f7\215\031\356\024\203\320\275\317\f\367\201R\314\f\017\300\350\377\177\000Q\206\027(\316]\233P\000\000\000\000IEND\256B`\202".dup.force_encoding(Encoding::BINARY)

		before do
		  stub_const('ActiveStorage::Blob', BlobStub)
		end
  
		it "has configurations available" do
  		  expect(DISK1).not_to be nil
		  expect(DISK2).not_to be nil
		  expect(SERVICE).not_to be nil
		end

		it "can upload and download" do
		  key_generator = FixedKeyGenerator.new
		  key = key_generator.generate
		  SERVICE.upload(key, StringIO.new(FIXTURE_DATA))
		  expect(SERVICE.download($my_blob_key)).to be == FIXTURE_DATA
		end

		it "can delete" do
		  key_generator = FixedKeyGenerator.new
		  SERVICE.upload(key_generator.generate, StringIO.new(FIXTURE_DATA))
		  SERVICE.delete $my_blob_key
		  expect(SERVICE.exist?($my_blob_key)).to be false
		end

		it "can split" do
		  shares = TSS.split(secret: 'my deep dark secret')
		  secret = TSS.combine(shares: shares)
		  expect(secret[:secret]).to be == 'my deep dark secret'
		end

		it "can split binary data" do
		  shares = TSS.split(secret: Base64.encode64(FIXTURE_DATA))
		  secret = TSS.combine(shares: shares)
		  expect(Base64.decode64(secret[:secret])).to be == FIXTURE_DATA
		end

		it "can manually split, upload, download and combine" do
		  key_generator = FixedKeyGenerator.new
		  shares = TSS.split(secret: Base64.encode64(FIXTURE_DATA),threshold:2,num_shares:2)
		  DISK1.upload(key_generator.generate,StringIO.new(shares[0]))
		  DISK2.upload(key_generator.generate,StringIO.new(shares[1]))
		  share1of2 = DISK1.download(key_generator.generate)
		  share2of2 = DISK2.download(key_generator.generate)
		  secret = TSS.combine(shares: shares)
		  DISK1.delete(key_generator.generate)
		  DISK2.delete(key_generator.generate)
		  expect(Base64.decode64(secret[:secret])).to be == FIXTURE_DATA
		end

		it "can automatically split, upload, download and combine" do
		  key_generator = UniqueKeyGenerator.new
		  key = key_generator.generate
		  SERVICE.upload(key,StringIO.new(FIXTURE_DATA))
		  secret = SERVICE.download($my_blob_key)
		  $my_blob_key.split(',').each do |k|
		    SERVICE.delete(k)
		  end
		  expect(secret).to be == FIXTURE_DATA
		end

		it "can automatically split, upload, download and combine a large number of shares" do
		  key_generator = UniqueKeyGenerator.new
		  key = key_generator.generate
		  SERVICE.upload(key,StringIO.new(FIXTURE_DATA))
		  secret = SERVICE.download($my_blob_key)
		  $my_blob_key.split(',').each do |k|
		    SERVICE.delete(k)
		  end
		  expect(secret).to be == FIXTURE_DATA
		end

		it "can combine threshold of shares" do
		  key_generator = UniqueKeyGenerator.new
		  key = key_generator.generate
		  SERVICE.upload(key,StringIO.new(FIXTURE_DATA))
		  keys = $my_blob_key.split(',').sample(4).shuffle.join(',')
		  secret = SERVICE.download(keys)
		  keys.split(',').each do |k|
		    SERVICE.delete(k)
		  end
		  expect(secret).to be == FIXTURE_DATA
		end

		it "cannot combine below a threshold of shares" do
		  key_generator = UniqueKeyGenerator.new
		  key = key_generator.generate
		  SERVICE.upload(key,StringIO.new(FIXTURE_DATA))
		  keys = $my_blob_key.split(',').sample(2).shuffle.join(',')
		  expect { SERVICE.download(keys) }.to raise_error(TSS::ArgumentError,/invalid shares, fewer than threshold/)
		end

		it "cannot sort different split, upload, download and combine shares" do
		  key_generator = UniqueKeyGenerator.new
		  key = key_generator.generate
		  notAkey = key_generator.generate
		  SERVICE.upload(key,StringIO.new(FIXTURE_DATA))
		  keys = $my_blob_key.split(',').sample(2)
		  keys << notAkey
		  expect { SERVICE.download(keys.join(',')) }.to raise_error(TSS::ArgumentError,/invalid shares, fewer than threshold/)
		end

		it "can determine if shares exist for given keys" do
		  key_generator = UniqueKeyGenerator.new
		  key = key_generator.generate
		  SERVICE.upload(key,StringIO.new(FIXTURE_DATA))
		  expect(SERVICE.exist?($my_blob_key)).to be true
		end

		it "can determine if shares DO NOT exist for given keys" do
		  key_generator = UniqueKeyGenerator.new
		  key = key_generator.generate
		  SERVICE.upload(key,StringIO.new(FIXTURE_DATA))
		  expect(SERVICE.exist?(key_generator.generate)).to be false
		end

		it "cannot upload non IO stream" do
		  key_generator = FixedKeyGenerator.new
		  expect { SERVICE.upload(key_generator.generate, FIXTURE_DATA) }.to raise_error(NoMethodError,/rewind/)
		end

		it "can handle download to block" do
		  key_generator = FixedKeyGenerator.new
		  SERVICE.upload(key_generator.generate, StringIO.new(FIXTURE_DATA))
		  data = ""
		  SERVICE.download($my_blob_key) { |s| data = s }
		  expect(data).to be == FIXTURE_DATA
		end

		it "cannot download chunk yet" do
		  key_generator = FixedKeyGenerator.new
		  key = key_generator.generate
		  SERVICE.upload(key,StringIO.new(FIXTURE_DATA))
		  expect { SERVICE.download_chunk($my_blob_key,{ begin: 1, size: 100 }) }.to raise_error(ActiveStorage::UnpreviewableError,/not implement/)
		end
	end
else
  puts "Skipping Horcrux Storage Service tests because no Horcrux configuration was supplied"
end
