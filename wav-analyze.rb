## -*- confing: utf-8 -*-
require 'rubygems'
require 'wav-file'

# wavファイルopen
f = open("mudai.wav")
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

puts "----- 解析対象の波形配列の大きさ -----"
p wavs.size

# wavファイルを一定時間(以下フレーム)ごとに区切る。
# ここでは1フレームのサンプル数は512とする
FRAME_LEN = 512

# 剰余で余った部分は切り捨て
sample_max =  wavs.size - wavs.size % FRAME_LEN
puts "----- 解析対象のサイズ最大値(sample_max) -----"
puts sample_max
puts "----- 余り -----"
puts data_chunk.size - sample_max

frame_max = sample_max / FRAME_LEN
puts "----- 解析対象のフレーム最大値(frame_max) -----"
puts frame_max

# 対象の各フレーム内の音量をリストで取得
# 512個の要素を含む配列の配列に変形して、最後の配列を除くそれぞれの配列について二条平均平方根を求める
# これで0フレームからframe_maxフレームまでの音量が取得できた
dbs = wavs[0..sample_max].each_slice(FRAME_LEN).to_a.map{|arr| Math.sqrt(arr.inject(0){|sum, x| sum + x * x} / arr.size)}

# 0番目と1番目の音量の差、2番目と3番目の音量の差、...と言った形で音量の差の配列を作成する
# 音量の減少は考慮に入れない為、マイナス値は0とする
diff_list = dbs.each_slice(2).to_a.map{|arr| arr[0] - arr[1] >= 0 ? arr[0] - arr[1] : 0}

def calc_bpm_match(data, bpm)
    n = data.size
    f_bpm   = bpm / 60.0
    s = 44100.0 / FRAME_LEN

    # 畳み込みして1/N倍
    n = 0
    a_bpm = data.inject(0){|sum, x|
      n = n + 1
      sum + x * Math.cos(2 * Math::PI * f_bpm * n / s)
    } / data.size

    n = 0
    b_bpm = data.inject(0){|sum, x|
      n = n + 1
      sum + x * Math.sin(2 * Math::PI * f_bpm * n / s)
    } / data.size

    Math.sqrt(a_bpm * a_bpm + b_bpm * b_bpm)
end

# 60から240までbpmのマッチ度を計算し、マッチ度のリストを返す
def calc_match(data)
    (60..240).map{|bpm|
      calc_bpm_match(data, bpm)
    }
end

res = calc_match(diff_list)
puts "----- マッチ度数の配列 -----"
res.each_with_index{|e, i| puts "#{i} #{e}"}
puts "----- マッチ度最大の数 -----"
puts res.max
puts "----- マッチ度最大値のindex + 60 -----"
puts res.index(res.max) + 60
