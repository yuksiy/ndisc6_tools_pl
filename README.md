# ndisc6_tools_pl

## 概要

ndisc6 の補足ツール (Perl)

## 使用方法

### ra_addr.pl

指定したインターフェイスからルータ要請メッセージを送信し、
受信した全てのルータ広告メッセージの送信元IPv6アドレスを表示します。

    # ra_addr.pl get インターフェイス名

上記で複数の送信元IPv6アドレスが表示される場合、
(例えば、自ネットワーク内に稼働中のIPv6 ルータが複数ある場合、)
送信されてきたルータ広告メッセージに含まれるプレフィックスで
結果を絞り込むには、-pオプションでそのプレフィックスを指定できます。  
(指定すべきプレフィックスの参考情報は、「rdisc6 インターフェイス名」で得られます。)

    # ra_addr.pl get -p プレフィックス インターフェイス名

### その他

* 上記で紹介したツールの詳細については、「ツール名 --help」を参照してください。

## 動作環境

OS:

* Linux

依存パッケージ または 依存コマンド:

* make (インストール目的のみ)
* ndisc6 (rdisc6コマンド等)
* perl
* [List-MoreUtils](http://search.cpan.org/dist/List-MoreUtils/)
* [NetAddr-IP](http://search.cpan.org/dist/NetAddr-IP/)
* [common_pl](https://github.com/yuksiy/common_pl)

## インストール

ソースからインストールする場合:

    (Linux の場合)
    # make install

fil_pkg.plを使用してインストールする場合:

[fil_pkg.pl](https://github.com/yuksiy/fil_tools_pl/blob/master/README.md#fil_pkgpl) を参照してください。

## インストール後の設定

環境変数「PATH」にインストール先ディレクトリを追加してください。

## 最新版の入手先

<https://github.com/yuksiy/ndisc6_tools_pl>

## License

MIT License. See [LICENSE](https://github.com/yuksiy/ndisc6_tools_pl/blob/master/LICENSE) file.

## Copyright

Copyright (c) 2015-2017 Yukio Shiiya
