# This can be used to upload the install script and the tarball to
# S3. Note that you will need to have ruby, rake, and the yaml and
# aws/s3 gems installed. You will also need to have your key for the
# pgfi S3 bucket in a file called ~/.aws_pgfi_key.yaml, which should
# look like the following:
#
# access_key_id: <the access key id>
# secret_access_key: <the secret access key

require 'yaml'
require 'aws/s3'

$tarball = "RUM-Pipeline-v1.12_00.tar.gz"
$installer = "rum_install.pl"
$bucket = 'pgfi.rum'

def connect()
  key_file = File.expand_path("~/.aws_pgfi_key.yaml")

  key = YAML.load_file(key_file)
  puts "Key is #{key}"
  AWS::S3::Base.establish_connection!(
    :access_key_id => key["access_key_id"],
    :secret_access_key => key["secret_access_key"])
end

task :upload => [$tarball] do |t|
  connect()
  AWS::S3::S3Object.store($tarball, open($tarball), $bucket,
                          :access => :public_read)
  AWS::S3::S3Object.store($installer, open("bin/rum_install.pl"), $bucket,
                          :access => :public_read)
end


