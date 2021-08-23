$in_unit_test = true

script_path = __dir__
# go to the base directory of the repository
Dir.chdir(File.join(__dir__, "../.."))

Dir.glob(File.join(script_path, "../../source/plugins/ruby/*_test.rb")) do |filename|
    require_relative filename
end

Dir.glob(File.join(script_path, "../../build/linux/installer/scripts/*_test.rb")) do |filename|
    require_relative filename
end
