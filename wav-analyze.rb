## -*- confing: utf-8 -*-
require 'rubygems'
require 'wav-file'

FRAME_LEN = 1024

f = open("tempo_120.wav")
format = WavFile::readFormat(f)
data_chunk = WavFile::readDataChunk(f)
f.close

def get_wav_array(data_chunk)
  data_chunk.data.unpack(
    if format.bitPerSample == 16 then
      's*'
    elsif format.bitPerSample == 8 then
      'c*'
    end
  )
end

def calc_bpm_match(data, bpm)
    f_bpm   = bpm / 60.0
    s = 44100.0 / FRAME_LEN

    # 畳み込みして1/N倍
    a_bpm = (0..data.size-1).map{|m|
      Math.cos(2 * Math::PI * f_bpm * m / s)
    }.zip(data).map{|x,y| x * y}.inject(:+) / data.size

    b_bpm = (0..data.size-1).map{|m|
      Math.sin(2 * Math::PI * f_bpm * m / s)
    }.zip(data).map{|x,y| x * y}.inject(:+) / data.size

    Math.sqrt(a_bpm ** 2 + b_bpm ** 2)
end

def calc_match(data)
    (60..240).map{|bpm|
      calc_bpm_match(data, bpm)
    }
end

wavs = get_wav_array
sample_max =  wavs.size - wavs.size % FRAME_LEN

# 対象の各フレーム内の音量をリストで取得
# FRAME_LEN個の要素を含む配列の配列に変形し、最後の配列を除く(切り捨て)それぞれの配列について二条平均平方根を求める
# これで0フレームから最大フレームまでの音量が取得できる
# 次に0番目と1番目の音量の差、2番目と3番目の音量の差、...と言った形で音量の差の配列を作成する
# 音量の減少は考慮に入れない為、マイナス値は0とする
diff_arr = wavs[0..sample_max]
  .each_slice(FRAME_LEN).to_a
  .map{|arr| Math.sqrt(arr.map{|elem| elem ** 2}.inject(:+) / arr.size)}
  .each_slice(2).to_a
  .map{|x,y| y != nil && x - y >= 0 ? x - y : 0}

res = calc_match(diff_arr)
puts "BPM,Match rate"
res.each_with_index{|e, i| puts "#{i+60},#{e}"}
