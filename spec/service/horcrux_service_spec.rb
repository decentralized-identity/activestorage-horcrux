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
  
		it "has configurations available" do
  		  expect(DISK1).not_to be nil
		  expect(DISK2).not_to be nil
		  expect(SERVICE).not_to be nil
		end

		it "can upload and download" do
		  key_generator = FixedKeyGenerator.new
		  SERVICE.upload([key_generator.generate], 1, Base64.encode64(FIXTURE_DATA))
		  expect(Base64.decode64(SERVICE.download([key_generator.generate]))).to be == FIXTURE_DATA
		end

		it "can delete" do
		  key_generator = FixedKeyGenerator.new
		  SERVICE.delete key_generator.generate
		  expect(SERVICE.exist?(key_generator.generate)).to be false
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
		  key1 = key_generator.generate
		  key2 = key_generator.generate
		  SERVICE.upload([key1,key2],2,Base64.encode64(FIXTURE_DATA))
		  secret = SERVICE.download([key1,key2])
		  [key1,key2].each do |k|
		    SERVICE.delete(k)
		  end
		  expect(Base64.decode64(secret)).to be == FIXTURE_DATA
		end

		it "can automatically split, upload, download and combine a large number of shares" do
		  key_generator = UniqueKeyGenerator.new
		  key1 = key_generator.generate
		  key2 = key_generator.generate
		  key3 = key_generator.generate
		  key4 = key_generator.generate
		  key5 = key_generator.generate
		  key6 = key_generator.generate
		  SERVICE.upload([key1,key2,key3,key4,key5,key6],2,Base64.encode64(FIXTURE_DATA))
		  secret = SERVICE.download([key1,key2,key3,key4,key5,key6])
		  [key1,key2,key3,key4,key5,key6].each do |k|
		    SERVICE.delete(k)
		  end
		  expect(Base64.decode64(secret)).to be == FIXTURE_DATA
		end

		it "can combine threshold of shares" do
		  key_generator = UniqueKeyGenerator.new
		  key1 = key_generator.generate
		  key2 = key_generator.generate
		  key3 = key_generator.generate
		  key4 = key_generator.generate
		  key5 = key_generator.generate
		  key6 = key_generator.generate
		  SERVICE.upload([key1,key2,key3,key4,key5,key6],4,Base64.encode64(FIXTURE_DATA))
		  keys = [key1,key2,key3,key4,key5,key6].sample(4).shuffle
		  secret = SERVICE.download(keys)
		  [key1,key2,key3,key4,key5,key6].each do |k|
		    SERVICE.delete(k)
		  end
		  expect(Base64.decode64(secret)).to be == FIXTURE_DATA
		end

		it "cannot combine below a threshold of shares" do
		  key_generator = UniqueKeyGenerator.new
		  key1 = key_generator.generate
		  key2 = key_generator.generate
		  key3 = key_generator.generate
		  key4 = key_generator.generate
		  key5 = key_generator.generate
		  key6 = key_generator.generate
		  SERVICE.upload([key1,key2,key3,key4,key5,key6],4,Base64.encode64(FIXTURE_DATA))
		  keys = [key1,key2,key3,key4,key5,key6].sample(3)
		  expect { SERVICE.download(keys) }.to raise_error(TSS::ArgumentError,/fewer than threshold/)
		end

		it "cannot sort different split, upload, download and combine shares" do
		  key_generator = UniqueKeyGenerator.new
		  key1ofA = key_generator.generate
		  key2ofA = key_generator.generate
		  key1ofB = key_generator.generate
		  key2ofB = key_generator.generate
		  SERVICE.upload([key1ofA,key2ofA],1,Base64.encode64(FIXTURE_DATA))
		  SERVICE.upload([key1ofB,key2ofB],1,Base64.encode64(FIXTURE_DATA))
		  expect { SERVICE.download([key1ofA,key2ofB]) }.to raise_error(TSS::ArgumentError,/do not match/)
		end

		it "can determine if shares exist for given keys" do
		  key_generator = UniqueKeyGenerator.new
		  key1ofA = key_generator.generate
		  key2ofA = key_generator.generate
		  SERVICE.upload([key1ofA,key2ofA],1,Base64.encode64(FIXTURE_DATA))
		  expect(SERVICE.exist?([key1ofA,key2ofA])).to be true
		end

		it "can determine if shares DO NOT exist for given keys" do
		  key_generator = UniqueKeyGenerator.new
		  key1ofA = key_generator.generate
		  key2ofA = key_generator.generate
		  key1ofB = key_generator.generate
		  key2ofB = key_generator.generate
		  SERVICE.upload([key1ofA,key2ofA],1,Base64.encode64(FIXTURE_DATA))
		  expect(SERVICE.exist?([key1ofB,key2ofB])).to be false
		end

		it "cannot upload IO stream" do
		  key_generator = FixedKeyGenerator.new
		  data = StringIO.new(Base64.encode64(FIXTURE_DATA))
		  expect { SERVICE.upload([key_generator.generate], 1, data) }.to raise_error(ActiveStorage::UnpreviewableError,/cannot handle/)
		end

		it "can handle download to block" do
		  key_generator = FixedKeyGenerator.new
		  SERVICE.upload([key_generator.generate], 1, Base64.encode64(FIXTURE_DATA))
		  data = ""
		  SERVICE.download([key_generator.generate]) { |s| data = Base64.decode64(s) }
		  expect(data).to be == FIXTURE_DATA
		end

		it "cannot download chunk yet" do
		  key_generator = FixedKeyGenerator.new
		  key = key_generator.generate
		  SERVICE.upload([key],1,Base64.encode64(FIXTURE_DATA))
		  expect { SERVICE.download_chunk([key],{ begin: 1, size: 100 }) }.to raise_error(ActiveStorage::UnpreviewableError,/not implement/)
		end
	end
else
  puts "Skipping Horcrux Storage Service tests because no Horcrux configuration was supplied"
end
