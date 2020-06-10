# See https://docs.aws.amazon.com/lambda/latest/dg/ruby-package.html

desc 'Create ZIP archive for Lambda'
task :build do
  `zip -r function.zip function.rb vendor`
end

desc 'Upload ZIP archive to lambda'
task :publish do
  `aws lambda update-function-code --function-name #{ENV['LAMBDA_FUNCTION']} --zip-file fileb://function.zip`
end

desc 'Build and publish to Lambda'
task :release => [:build, :publish]
