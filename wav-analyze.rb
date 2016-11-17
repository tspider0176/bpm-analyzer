## -*- confing: utf-8 -*-
require 'rubygems'
require 'wav-file'
require 'singleton'

FRAME_LEN = 512
SAMPLE_F_PER_FRAME = 44100.0 / FRAME_LEN

class BPMAnalyzer
  include Singleton

  def initialize
    f = open("tempo_120.wav")
    @format = WavFile::readFormat(f)
    @data_chunk = WavFile::readDataChunk(f)
    @wavs = get_wav_array(@data_chunk, @format)
    f.close
  end

  def bit_per_sample(format)
    format.bitPerSample == 16 ? 's*' : 'c*'
  end

  def get_wav_array(data_chunk, format)
    data_chunk.data.unpack(bit_per_sample(format)) # chuck -> dataの配列へunpack
  end

  def calc_bpm_match(data, bpm)
      f_bpm   = bpm / 60.0

      phase_cos = lambda{|m| Math.cos(2 * Math::PI * f_bpm * m / SAMPLE_F_PER_FRAME)}
      phase_sin = lambda{|m| Math.sin(2 * Math::PI * f_bpm * m / SAMPLE_F_PER_FRAME)}

      a_bpm = (0..data.size-1).map{|m| phase_cos.(m)}.zip(data).map{|x,y| x * y}.inject(:+) / data.size
      b_bpm = (0..data.size-1).map{|m| phase_sin.(m)}.zip(data).map{|x,y| x * y}.inject(:+) / data.size

      Math.sqrt(a_bpm ** 2 + b_bpm ** 2)
  end

  def calc_match(data)
      (60..240).map{|bpm|
        calc_bpm_match(data, bpm)
      }
  end

  def run
    diff_arr = @wavs.take(@wavs.size - @wavs.size % FRAME_LEN)
      .each_slice(FRAME_LEN).to_a # フレーム長毎に配列を細断
      .map{|arr| Math.sqrt(arr.map{|elem| elem ** 2}.inject(:+) / arr.size)} # それぞれのフレームについて、二乗平均平方根を計算
      .each_slice(2).to_a # 隣同士の配列でペア作成
      .map{|x,y| y != nil && x - y >= 0 ? x - y : 0} # 差を計算、マイナス値は0へ

    @res = calc_match(diff_arr)
  end

  def to_s
    "BPM,Match rate\n" + @res.map.with_index{|e, i| "#{i+60},#{e}"}.join("\n") if @res != nil
  end
end

obj = BPMAnalyzer.instance
obj.run
puts obj.to_s
