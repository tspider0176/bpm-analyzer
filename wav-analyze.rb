## -*- confing: utf-8 -*-
require 'rubygems'
require 'wav-file'

# wavファイルopen
f = open("Take-Her-Heart.wav")
format = WavFile::readFormat(f)
data_chunk = WavFile::readDataChunk(f)
f.close

# 入力したwavファイルのformat出力
puts "----- wavファイルのフォーマット -----"
puts format

# サンプリング周期[s]
t = 1.0/format.hz

# バイナリからwavの波形を配列として取り出す
bit =  if format.bitPerSample == 16 then # int16_t
  's*'
elsif format.bitPerSample == 8 then # signed char
  'c*'
end
wavs = data_chunk.data.unpack(bit)

puts "----- 対象の波形配列の大きさ -----"
p wavs.size

# wavファイルを一定時間(以下フレーム)ごとに区切る。
# ここでは1フレームのサンプル数は512とする
FRAME_LEN = 512

# 剰余で余った部分は切り捨て
sample_max =  data_chunk.size - data_chunk.size % FRAME_LEN
puts "----- 解析対象のサイズ最大値 -----"
puts sample_max

frame_max = sample_max / FRAME_LEN
puts "----- 解析対象のフレーム最大値 -----"
puts frame_max

# 対象の各フレーム内の音量を取得


# amp_list   = np.array([np.sqrt(sum(x ** 2)) for x in frame_list])
