# TODO: can we get rid of this global flag
$in_unit_test = true

Dir.glob("*_test.rb") do |filename|
    require_relative filename
end
