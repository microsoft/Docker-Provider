require "socket"
require 'json'

socket = UNIXSocket.new('/var/run/docker.sock')

socket.write("GET /info HTTP/1.1\r\nHost: localhost\r\n\r\n")
myresponse = ""
loop do
mystring = socket.recv(4096)
myresponse = myresponse + mystring
#puts "--------------------------------"
break if mystring.length < 4096
end
puts myresponse
myjson = myresponse.match( /{.+}/ )[0]
myjson = "["+myjson+"]"
myparsedjson = JSON.parse(myjson)
puts "Hostname-" + myparsedjson[0]['Name']

#puts "==== Sending"
socket.write("GET /images/json?all=0 HTTP/1.1\r\nHost: localhost\r\n\r\n")

#socket.write("GET /info HTTP/1.1\r\nHost: localhost\r\n\r\n")

#socket.write("info HTTP/1.1\r\nHost: localhost\r\n\r\n")

#puts "==== Getting Response"
#puts socket

#puts socket.recvfrom(1024)

#puts socket.gets

#puts socket.recv.body

myresponse = ""
loop do
mystring = socket.recv(4096)
myresponse = myresponse + mystring
#puts "--------------------------------"
break if mystring.length < 4096
end

#puts myresponse
#puts "-----------------------------------------------------"

myjson = myresponse.match( /{.+}/ )[0]
myjson = "["+myjson+"]"
#puts myjson


myparsedjson = JSON.parse(myjson)
puts"---------------------------"
puts"IMAGES"
puts"---------------------------"
myparsedjson.each do |items|
 puts items['Id']
end
#while socket.recvfrom(1024)
# puts socket.recvfrom(1024)
#end

#puts "here"
#puts "==== Sending"
socket.write("GET /containers/json?all=1 HTTP/1.1\r\nHost: localhost\r\n\r\n")
#puts "==== Getting Response"

myresponse = ""
loop do
mystring = socket.recv(4096)
myresponse = myresponse + mystring
#puts "--------------------------------"
break if mystring.length < 4096
end
myjson = myresponse.match( /{.+}/ )[0]
myjson = "["+myjson+"]"
myparsedjson = JSON.parse(myjson)
#puts myparsedjson
puts"---------------------------"
puts"CONTAINERS"
puts"---------------------------"
myparsedjson.each do |items|
 puts items['Id']
end
socket.close