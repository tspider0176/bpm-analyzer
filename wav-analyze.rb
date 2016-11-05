require 'rubygems'
require 'wav-file'

f = open("input.wav")
format = WavFile::readFormat(f)
dataChunk = WavFile::readDataChunk(f)
f.close

puts format
