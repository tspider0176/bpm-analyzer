## -*- confing: utf-8 -*-
require 'rubygems'
require 'wav-file'
require_relative "enumerable"

class BPMAnalyzer
  FRAME_LEN = 512
  SAMPLE_F_PER_FRAME = 44100.0 / FRAME_LEN

  def initialize(file_name)
    f = open(file_name)
    @format = WavFile::readFormat(f)
    @data_chunk = WavFile::readDataChunk(f)
    @wavs = get_wav_array(@data_chunk, @format)
    f.close
    @res = nil
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

  def get_max_rate
    @res.map{|e| } if @res != nil
  end

private
  def bit_per_sample(format)
    format.bitPerSample == 16 ? 's*' : 'c*'
  end

  def get_wav_array(data_chunk, format)
    data_chunk.data.unpack(bit_per_sample(format)) # datachuck -> dataの配列へunpack
  end

  def phase_cos
    lambda{|m| Math.cos(2 * Math::PI * f_bpm * m / SAMPLE_F_PER_FRAME)}
  end

  def phase_sin
    lambda{|m| Math.sin(2 * Math::PI * f_bpm * m / SAMPLE_F_PER_FRAME)}
  end

  def calc_bpm_match(data, bpm)
      f_bpm = bpm / 60.0

      a_bpm = (0..data.size-1).map{|m| phase_cos.(m)}.zip_with(data){|x,y| x * y}.inject(:+) / data.size
      b_bpm = (0..data.size-1).map{|m| phase_sin.(m)}.zip_with(data){|x,y| x * y}.inject(:+) / data.size

      Math.sqrt(a_bpm ** 2 + b_bpm ** 2)
  end

  def calc_match(data)
      (60..240).map{|bpm|
        calc_bpm_match(data, bpm)
      }
  end
end

obj = BPMAnalyzer.new(ARGV[0])
obj.run
puts obj.to_s
