require 'rubygems'
require 'wav-file'

f = open("Take-Her-Heart.wav")
format = WavFile::readFormat(f)
dataChunk = WavFile::readDataChunk(f)
f.close

puts format
