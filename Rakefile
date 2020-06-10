desc 'Create ZIP archive for Lambda'
task :package do
  `zip -r function.zip function.rb vendor`
end

desc 'Upload ZIP archive to lambda'
task :publish do
  `aws lambda update-function-code --function-name #{ENV['LAMBDA_FUNCTION']} --zip-file fileb://function.zip`
end
