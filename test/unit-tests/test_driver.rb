# TODO: can we get rid of this global flag?
$in_unit_test = true

Dir.glob("../../source/plugins/ruby/*_test.rb") do |filename|
    require_relative filename
end

Dir.glob("../../build/linux/installer/scripts/*_test.rb") do |filename|
    require_relative filename
end
