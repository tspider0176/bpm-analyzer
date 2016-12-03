この記事は [Aizu Advent Calendar 2016](http://qiita.com/advent-calendar/2016/aizu) 4日目の記事です。

前の人は、@hnjkさん、次の人は @misoton665 さんです。

## はじめに
この記事では汎用的な音楽ファイル形式であるWAVファイルについて、BPM解析を行うプログラムを作成します。
今回は手軽に書けるのと、最近あまり注力して書いてないのでリハビリという名目で、Rubyを使って書きました。

```
$ ruby -v
-> ruby 2.2.3p173
```

プログラムを作成して行く思考過程に重点を置いて記事を書いたら、結構な文量になってしまいました…。アッこの人こういう思考経路でプログラムを書いていくんだなーと思っていただければ幸いです。
作成したプログラムへの指摘は大歓迎です。

## Wavファイル形式について
BPMを解析するプログラムだとかアルゴリズムだとかを調べる前に、まず今回解析の対象とするWAVファイルの形式について、基礎知識から調べました。

> WAVまたはWAVE（ウェーブ、ウェブ） (RIFF waveform Audio Format) は、マイクロソフトとIBMにより開発された音声データ記述のためのフォーマットである。RIFFの一種。主としてWindowsで使われるファイル形式である。ファイルに格納した場合の拡張子は、.wav。
WAV - Wikipedia, https://ja.wikipedia.org/wiki/WAV

ここでRIFFとは？と思いさらに調べると

> Resource Interchange File Format（RIFF、「資源交換用ファイル形式」の意味）は、タグ付きのデータを格納するための汎用メタファイル形式である。
Resource Interchange File Format - Wikipedia, https://ja.wikipedia.org/wiki/Resource_Interchange_File_Format

とのこと。Wikiの内容を簡単にまとめると、RIFFに基づいているファイルは小さなチャンクから構成されており、それぞれINFOチャンク、DATAチャンクなどから構成されている模様。つまりRIFFの一種であるWAVファイルも同じようなチャンクから成る構成をしているということ。  
では具体的にそのチャンクの内容とはどうなっているんでしょうか。WAV形式の構成について調べてみたところ、以下のようなサイトを見つけました。

http://sky.geocities.jp/kmaedam/directx9/waveform.html

このサイトの説明によると、RIFF形式通り最初の数バイトはINFO情報を含み、更にその後に続くnバイトでDATA本体を表しているようです。それぞれの情報が取り出せれば解析は出来そう。

## BPM解析手法
http://hp.vector.co.jp/authors/VA046927/tempo/tempo.html
理論的にはこのサイトでかなり詳しく説明されているようなのでこの場で込み入った説明はしません。サイトから引用すると、WAVファイルのBPMを求めるまでの手順は、

* WAVファイルを一定時間(以下フレーム)ごとに区切る。
* フレームごとの音量を求める。
* 隣り合うフレームの音量の増加量を求める。
* 増加量の時間変化の周波数成分を求める。
* 周波数成分のピークを検出する。
* ピークの周波数からテンポを計算する。

となるそうです。なるほど。
上の処理は大きく分けて前半と後半に分けることが出来そうです。具体的には、WAVファイルに対して計測を行う

> WAVファイルを一定時間(以下フレーム)ごとに区切る。
> フレームごとの音量を求める。
> 隣り合うフレームの音量の増加量を求める。

このパートと、実際に計測によって得られた結果から

> 増加量の時間変化の周波数成分を求める。
> 周波数成分のピークを検出する。
> ピークの周波数からテンポを計算する。

以上の項目を導出して行くパートです。
実際に次の実装の節では二つに分けて実装して行きます。

## 実装
### 前半
では実際に上で挙げたBPM解析の手法に基づいてプログラムを書いて行きましょう。一からWAVを解析するようなプログラムを書いている程時間がなかったので、Wavファイルを扱える[wav-file](http://shokai.org/blog/archives/5408)と言うgemを使用。早速導入。

```
gem install wav-file
```

このライブラリでは、WAV形式のINFOチャンク部分とDATAチャンク部分を分けて出力出来るようだったので、[適当な曲](https://soundcloud.com/tom-jonkers-1/syrin-nuwa-take-her-heart-free-release)を拾って来て実行してみました。

```rb
require 'wav-file'

f = open("./Take-Her-Heart.wav")
format = WavFile::readFormat(f)
f.close

puts format
```
これだけでWAVファイルのINFOチャンクから情報を読み取り、出力してくれるそう。実際に実行してみると、

<img width="322" alt="スクリーンショット 2016-12-03 10.22.50.png" src="https://qiita-image-store.s3.amazonaws.com/0/146476/2577b57a-62d4-6e5b-8a9f-e581df6fd8ea.png">

ちゃんと出力されました。すごい簡単。
動作が確認できた所で、実際に手法を実装して行ってみます。まず最初は、

> wavファイルを一定時間(以下フレーム)ごとに区切る。

との事でした。[wav-fileを開発している方のブログ記事](http://shokai.org/blog/archives/5408)によると、WAVファイルのDATAチャンクバイナリから、WAVの波形を配列 *wavs* として取得するには、

```rb
f = open("input.wav")
format = WavFile::readFormat(f)
dataChunk = WavFile::readDataChunk(f)
f.close

dataChunk = WavFile::readDataChunk(f)
bit = 's*' if format.bitPerSample == 16 # int16_t
bit = 'c*' if format.bitPerSample == 8 # signed char
wavs = dataChunk.data.unpack(bit) # read binary
```

と書くそうなので、DATAチャンクを一定フレーム数（ここでは1024にしています）に区切るプログラムは以下のように書けるはずです。

```rb
FRAME_LEN = 1024

def bit_per_sample(format)
  # ここでは16bitか8bitしか対象にして居ないので三項演算子で表現
  format.bitPerSample == 16 ? 's*' : 'c*'
end

def get_wav_array(data_chunk, format)
  data_chunk.data.unpack(bit_per_sample(format))
end

f = open("./tempo_120.wav") # BPM120のメトロノーム音が入ったWAVファイル
data_chunk = WavFile::readDataChunk(f)
format = WavFile::readFormat(f)
f.close()

get_wav_array(data_chunk, format)
      .take(@wavs.size - @wavs.size % FRAME_LEN)
      .each_slice(FRAME_LEN).to_a
```

ここでは、Array#takeメソッドを使いフレーム数に満たない余ったサンプル切り捨て、
Enumerable#each_sliceとto_aメソッドでフレーム毎の配列の配列へと変換しています。

注：Enumerable#each_sliceメソッドは便利なメソッドだけど、Arrayの高階関数として呼び出す事が出来ても戻り値の型がEnumerable型なので、メソッドチェーンを繋げていく場合はいちいちto_aしないとダメで結構面倒。どうにかならないかな。

次に行きましょう。

> フレームごとの音量を求める。

今までに書いたコードより、サンプルをフレーム毎に区切った配列

```
[[フレーム1], [フレーム2], [フレーム3], ..., [フレームn]]
```

が手に入っている状況ですので、ここでそれぞれのフレームに対して、そのフレーム内の二乗平均平方根（Root Mean Square, RMS）を計算する事でフレームごとの音量を求めたいと思います。注：二乗平均平方根についての説明は[コチラ](https://ja.wikipedia.org/wiki/%E4%BA%8C%E4%B9%97%E5%B9%B3%E5%9D%87%E5%B9%B3%E6%96%B9%E6%A0%B9)。
先ほどの *get_wav_array(data_chunk, format)* に続けて、

```rb
get_wav_array(data_chunk, format).take(@wavs.size - @wavs.size % FRAME_LEN)
      .each_slice(FRAME_LEN).to_a
      .map{|arr| Math.sqrt(arr.map{|elem| elem ** 2}.inject(:+) / arr.size)}
```

と書く事が出来るでしょう。Array#mapの中身の

```rb
Math.sqrt(arr.map{|elem| elem ** 2}.inject(:+) / arr.size)
```

この部分が、

![](https://wikimedia.org/api/rest_v1/media/math/render/svg/f47488d55c3628bf8711cc9fa5a0b0e920a93ece)

この数式の右辺と対応しています。
これで

```
[フレーム1のRMS値, フレーム2のRMS値, フレーム3のRMS値, ..., フレームnのRMS値]
```

が手に入りました。
どんどん行きます。次にやるべきことは、

> 隣り合うフレームの音量の増加量を求める。

とのことでした。つまり、先ほどの配列を、

```
[フレーム1と2のRMS値差, フレーム2と3のRMS値差, ..., フレームn-1とnのRMS値差]
```

という形に変換すれば良い訳です。ここで、変換前と変換後で配列の要素数が1つ減少している点に注意です。1つ前のstepで手に入った配列を、 *diff_arr* としておきましょう。すると、

```rb
diff_arr[0..-2].zip(diff_arr[1..-1]).map{|f,x| f - x}
```

と書けます。上のプログラムは単純に、今得られている配列 *diff_arr* の1番目の要素からn-1番目の要素から、同じく *diff_arr* の2番目の要素からn番目の要素を引き算しているだけです。

注：Rubyにはvector演算を行うメソッドが存在しないので、Array#zipで二つの配列をまとめ、mapでまとめられた値に対する演算を書く方式が主流のようです。
\# しかしここまでメソッドチェーンを繋げた以上、キリの良いところまで繋げたかった…！

長々と書きましたが、一旦ここまでをまとめると以下になります。

```rb
diff_arr = @wavs.take(@wavs.size - @wavs.size % FRAME_LEN)
      .each_slice(FRAME_LEN).to_a
      .map{|arr| Math.sqrt(arr.map{|elem| elem ** 2}.inject(:+) / arr.size)}

diff_arr[0..-2].zip(diff_arr[1..-1]).map{|f,x| f - x}
```

### 後半
ここから少し理論的に難しくなっていきます。まず

> 増加量の時間変化の周波数成分を求める

だそうです。サイトによると、n番目のフレームの音量の増加量をD(n)、フレームのサンプリング周波数をsとすると、各BPMのマッチ度Rbpmは以下で表されるとのこと。
<img width="262" alt="スクリーンショット 2016-12-03 12.08.27.png" src="https://qiita-image-store.s3.amazonaws.com/0/146476/efd77b3b-4ba6-316b-a849-94d5fbee8bb7.png">

この数式をRubyに落とし込みましょう。
まず最初に今回対象としているBPMの幅は60~240なので、BPMをキーとして、値がそのBPMのマッチ度となるようなハッシュを作成しておく。

```rb
(60..240).inject({}){|acc, bpm|
      acc[bpm] = calc_bpm_match(data, bpm)
      acc
}
```

ハッシュを作成する過程で呼び出されているcalc_bpm_match関数は、渡されたbpmとdata（前半で取得したフレーム毎のRMS差配列）のマッチ度を求める関数です。
以下で順番に書いて行ってみましょう。

まず最初に、
<img width="192" alt="スクリーンショット 2016-12-03 12.21.19.png" src="https://qiita-image-store.s3.amazonaws.com/0/146476/1ade7627-15eb-3884-d5f4-4f69b5f4333c.png">
こちらに注目。
これは簡単で、Ruby上では以下のように表すことができるでしょう。

```rb
Math.sqrt(a_bpm ** 2 + b_bpm ** 2)
```

では、次に *a_bpm* と *b_bpm* について考えてみましょう。
数式は、


となっていますが、大きな差異は無く、cosとsinのみが違っている定義になっています。
ここで、cosとsinの偏角部分の数式が少々複雑になっているので、 *a_bpm* と *b_bpm* を定義する前に、三角関数用のlambda式を定義しておくことにしましょう。

```rb
phase_cos = lambda{|m| Math.cos(2 * Math::PI * f_bpm * m / SAMPLE_F_PER_FRAME)}
phase_sin = lambda{|m| Math.sin(2 * Math::PI * f_bpm * m / SAMPLE_F_PER_FRAME)}
```

これらはそれぞれ必要な時に *.apply(m)* も若くは *.(m)* によって呼び出して利用することにします。
さて、それでは *a_bpm* と *b_bpm* の定義に移りましょう。Ruby上の数式に直すと以下のようになると考えられます。

```rb
a_bpm = (0..data.size-1)
      .map{|m| phase_cos.(m)}
      .zip(data)
      .map{|x,y| x * y}
      .inject(:+) / data.size

a_bpm = (0..data.size-1)
      .map{|m| phase_sin.(m)}
      .zip(data)
      .map{|x,y| x * y}
      .inject(:+) / data.size
```
ここで、先ほども出たように、ベクトル同士の乗算が出てきますが、ここでもベクトル同士の演算を行う際にはzipしてmapして演算しています。しかしこれを書くのが二回目となると流石に気になってきましたので、呟いてみると…

なんとzipWithをRubyで実装している方がいらっしゃいました。
記事内容によると、Enumerableモジュールに自前のメソッドを追加する事で実現しているようです。

```
module Enumerable
  def zip_with(*others, &block)
    zip(*others).map &block
  end
end
```

ここで定義したzip_withを利用すると、上で定義した *a_bpm* と *b_bpm* は、以下のように書き換えられます。
注：追加した後にrequire_relative "enumerable"を忘れないように！！！

```rb
a_bpm = (0..data.size-1)
      .map{|m| phase_cos.(m)}
      .zip_with(data){|x,y| x * y}
      .inject(:+) / data.size

b_bpm = (0..data.size-1)
      .map{|m| phase_sin.(m)}
      .zip_with(data){|x,y| x * y}
      .inject(:+) / data.size
```

大してコード量が少なくなったわけでもないですが、個人的に可読性も上がって満足。
以上を全て組み合わせ、最終的なcalc_bpm_match関数は以下のようになります。

```rb
def calc_bpm_match(data, bpm)
      f_bpm = bpm / 60.0

      phase_cos = lambda{|m| Math.cos(2 * Math::PI * f_bpm * m / SAMPLE_F_PER_FRAME)}
      phase_sin = lambda{|m| Math.sin(2 * Math::PI * f_bpm * m / SAMPLE_F_PER_FRAME)}

      a_bpm = (0..data.size-1)
        .map{|m| phase_cos.(m)}
        .zip_with(data){|x,y| x * y}
        .inject(:+) / data.size

      b_bpm = (0..data.size-1)
        .map{|m| phase_sin.(m)}
        .zip_with(data){|x,y| x * y}
        .inject(:+) / data.size

      Math.sqrt(a_bpm ** 2 + b_bpm ** 2)
end
```

コード量が増え、結構まとまりが無い雰囲気が漂って来たので、次のステップに移る前にclassにまとめてしまいます。

```rb
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
      .each_slice(FRAME_LEN).to_a
      .map{|arr| Math.sqrt(arr.map{|elem| elem ** 2}.inject(:+) / arr.size)}

    diff_arr[0..-2].zip(diff_arr[1..-1]).map{|f,x| f - x}

    @res = calc_match(diff_arr)
  end

  def to_s
    "BPM,Match rate\n" + @res.map{|k, v| "#{k},#{v}"}.join("\n") if @res != nil
  end

private
  def bit_per_sample(format)
    format.bitPerSample == 16 ? 's*' : 'c*'
  end

  def get_wav_array(data_chunk, format)
    data_chunk.data.unpack(bit_per_sample(format))
  end

  def calc_bpm_match(data, bpm)
      f_bpm = bpm / 60.0

      phase_cos = lambda{|m| Math.cos(2 * Math::PI * f_bpm * m / SAMPLE_F_PER_FRAME)}
      phase_sin = lambda{|m| Math.sin(2 * Math::PI * f_bpm * m / SAMPLE_F_PER_FRAME)}

      a_bpm = (0..data.size-1).map{|m| phase_cos.(m)}.zip_with(data){|x,y| x * y}.inject(:+) / data.size
      b_bpm = (0..data.size-1).map{|m| phase_sin.(m)}.zip_with(data){|x,y| x * y}.inject(:+) / data.size

      Math.sqrt(a_bpm ** 2 + b_bpm ** 2)
  end

  def calc_match(data)
      (60..240).inject({}){|acc, bpm|
        acc[bpm] = calc_bpm_match(data, bpm)
        acc
      }
  end
end
```

さて、オブジェクトの形に直したところで次のSTEPに移りましょう。

> 周波数成分のピークを検出する。
> ピークの周波数からテンポを計算する。

この項目は内容がほぼほぼ被っているので一気にやってしまいましょう。先ほど作成した60から240までのBPMと、そのマッチ度を利用してピークを検出します。コードは以下のように書きました。

```rb
# add public method to BPMAnalyzer class
def get_wav_array(data_chunk, format)
    data_chunk.data.unpack(bit_per_sample(format))
end
```

```rb
analyzer = BPMAnalyzer.new(ARGV[0])
analyzer.run
puts analyzer.get_max_rate
```

この時点での出力は、
<img width="466" alt="スクリーンショット 2016-12-03 15.35.49.png" src="https://qiita-image-store.s3.amazonaws.com/0/146476/182b2f01-d664-b15e-1bcf-4ac0b41d5975.png">
となりました。どうやら正しくBPMが検出されているようです。

試しに幾つかの曲を解析してみます。

* うるさい曲
Malice - Fu#kin die (BPM 155)
<iframe width="100%" height="450" scrolling="no" frameborder="no" src="https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/291015339&amp;auto_play=false&amp;hide_related=false&amp;show_comments=true&amp;show_user=true&amp;show_reposts=false&amp;visual=true"></iframe>

<img width="696" alt="スクリーンショット 2016-12-03 16.12.03.png" src="https://qiita-image-store.s3.amazonaws.com/0/146476/2b93a222-5040-a8dc-ecbe-9ede52d49a27.png">

成功。音圧の違いで検出がしやすいのかと考え、静かめの曲で再実行

* 静かめの曲
Stringamp - Winter Morning (BPM 100)
<iframe width="100%" height="450" scrolling="no" frameborder="no" src="https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/295938921&amp;auto_play=false&amp;hide_related=false&amp;show_comments=true&amp;show_user=true&amp;show_reposts=false&amp;visual=true"></iframe>

<img width="456" alt="スクリーンショット 2016-12-03 15.55.31.png" src="https://qiita-image-store.s3.amazonaws.com/0/146476/0b4a65c7-a740-131d-f28e-7461e7e79b0e.png">

大人しめの、激しい音圧の上下が無い曲でも無事正しく検出できました。

## まとめ
BPM検出プログラムをRubyで、なるべく手続き的にならないように書いた。
プログラムにもまだまだ改善の余地がありそうなのと、今回の結果を利用してBPMが変わる曲とかも判別できたら面白いかな、と思った。正直理論は全く思い浮かばない。
PioneerのDJ機材とか見てると、最近の機材は曲の調の割り出し機能とかあったりして…今回の実装が何か取っ掛かりになれば良いかなぁと考えてます。

AIZU ADVENT CALENDAR 2016 明日は @misoton665 さんです。よろしくお願いします。
