この記事は Aizu Advent Calendar 2016 2日目の記事です。

前の人は、@hnjkさん、次の人は @misoton665 さんです。

## はじめに
この記事では汎用的な音楽ファイル形式であるWAVファイルについて、BPM解析を行うプログラムを作成します。
今回は手軽に書けるのと、最近あまり注力して書いてないのでリハビリ、という名目でRubyを使って書きました。

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

だそうです。時間変化の周波数成分と聞くとフーリエ解析が思い浮かびますが、
取り敢えずは先ほど求めた配列に対して、以下の数式を適用すれば良いです。フーリエ解析の理論の説明は長くなりそうなので割愛。
