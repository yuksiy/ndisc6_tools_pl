#!/usr/bin/perl

# ==============================================================================
#   機能
#     ルータ広告のアドレス処理
#   構文
#     USAGE 参照
#
#   Copyright (c) 2015-2017 Yukio Shiiya
#
#   This software is released under the MIT License.
#   https://opensource.org/licenses/MIT
# ==============================================================================

######################################################################
# 基本設定
######################################################################
use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray :config gnu_getopt no_ignore_case);
use List::MoreUtils qw(uniq);
use NetAddr::IP;

my $s_err = "";
$SIG{__DIE__} = $SIG{__WARN__} = sub { $s_err = $_[0]; };

######################################################################
# 変数定義
######################################################################
# ユーザ変数

# システム環境 依存変数

# プログラム内部変数
my $action;

my $IFACE;

my $MATCH_PREFIX = "equal";
my $PREFIX = "";						#初期状態が「空文字」でなければならない変数
my $RETRY_NUM = "30";
my $RETRY_INTERVAL = "1";

my $RA_FIELD = "Hop limit";
my $PREFIX_FIELD = "Prefix";
my $ADDR_FIELD = "from";

my $rc;
my ($ip_prefix, $ip_prefix_first, $ip_prefix_last);
my $count;
my $cmd_line;
my @addr;
my $line;
my ($field, $value);
my %value;
my $param;
my ($ip_value_prefix, $ip_value_prefix_first, $ip_value_prefix_last);
my $addr;

######################################################################
# 関数定義
######################################################################
sub USAGE {
	print STDOUT <<EOF;
Usage:
  ra_addr.pl ACTION [OPTIONS ...] [ARGUMENTS ...]

ACTIONS:
    get [OPTIONS ...] IFACE
       Get the address assigned to the interface.

ARGUMENTS:
    IFACE : Specify the interface name.

OPTIONS:
    -m MATCH_PREFIX : {within|equal|contains}
       Default is $MATCH_PREFIX.
       (Available with: get)
    -p PREFIX
       (Available with: get)
    -t RETRY_NUM
       Specify the number of retry times. Default is $RETRY_NUM.
       Specify 0 for infinite retrying.
       (Available with: get)
    -T RETRY_INTERVAL
       Specify the interval seconds of retries. Default is $RETRY_INTERVAL.
       (Available with: get)
    --help
       Display this help and exit.
EOF
}

use Common_pl::Is_numeric;

# フィールド・値の分割
sub SPLIT_FIELD_VALUE_COLON {
	my $line = $_[0];
	my ($field, $value);

	if ($line =~ m/^ ($ADDR_FIELD .*)$/) {
		($field, $value) = split(/ /, $1, 2);
	} else {
		($field, $value) = split(/: +/, $line, 2);
		$field =~ s/^ *(.*?) *$/$1/;
		$value =~ s/^ *(.*?) *$/$1/;
	}
	return ($field, $value);
}

######################################################################
# メインルーチン
######################################################################

# ACTIONのチェック
if ( not defined($ARGV[0]) ) {
	print STDERR "-E Missing ACTION\n";
	USAGE();exit 1;
} else {
	if ( "$ARGV[0]" =~ m#^(?:get)$# ) {
		$action = "$ARGV[0]";
	} else {
		print STDERR "-E Invalid ACTION -- \"$ARGV[0]\"\n";
		USAGE();exit 1;
	}
}

# ACTIONをシフト
shift @ARGV;

# オプションのチェック
if ( not eval { GetOptionsFromArray( \@ARGV,
	"m=s" => sub {
		$MATCH_PREFIX = $_[1];
		if ( $MATCH_PREFIX !~ m#^(?:within|equal|contains)$# ) {
			print STDERR "-E Argument to \"-m\" is invalid -- \"$MATCH_PREFIX\"\n";
			USAGE();exit 1;
		}
	},
	"p=s" => sub {
		$PREFIX = $_[1];
	},
	"t=s" => sub {
		# 指定された文字列が数値か否かのチェック
		$rc = IS_NUMERIC("$_[1]");
		if ( $rc != 0 ) {
			print STDERR "-E Argument to \"-$_[0]\" not numeric -- \"$_[1]\"\n";
			USAGE();exit 1;
		}
		if ( "-$_[0]" eq "-t" ) {
			$RETRY_NUM = "$_[1]";
		}
	},
	"T=s" => sub {
		# 指定された文字列が数値か否かのチェック
		$rc = IS_NUMERIC("$_[1]");
		if ( $rc != 0 ) {
			print STDERR "-E Argument to \"-$_[0]\" not numeric -- \"$_[1]\"\n";
			USAGE();exit 1;
		}
		if ( "-$_[0]" eq "-T" ) {
			$RETRY_INTERVAL = "$_[1]";
		}
	},
	"help" => sub {
		USAGE();exit 0;
	},
) } ) {
	print STDERR "-E $s_err\n";
	USAGE();exit 1;
}

# 引数のチェック
if ( $action =~ m#^(?:get)$# ) {
	# 第1引数のチェック
	if ( not defined($ARGV[0]) ) {
		print STDERR "-E Missing IFACE argument\n";
		USAGE();exit 1;
	} else {
		$IFACE = "$ARGV[0]";
	}
}

# 変数定義(引数のチェック後)
if ( $PREFIX ne "" ) {
	$ip_prefix = NetAddr::IP->new6($PREFIX);
	$ip_prefix_first = $ip_prefix->first;
	$ip_prefix_last = $ip_prefix->last;
}

if ( $action eq "get" ) {
	# ルータ広告のアドレスの取得
	$count = 1;
	while (1) {
		$cmd_line = "LANG=C rdisc6 $IFACE";
		if ( not defined(open(COM, '-|', $cmd_line)) ) {
			print STDERR "-E \"$cmd_line\" cannot exec: $!\n";
			exit 1;
		}
		#binmode(COM);
		# RAのループ
		@addr = ();
		RA_LINE: while ($line = <COM>) {
			chomp $line;
			($field, $value) = SPLIT_FIELD_VALUE_COLON($line);
			if ($field eq $RA_FIELD) {
				%value = ();
				# RA本体のループ
				RA_BODY_LINE: while ($line = <COM>) {
					chomp $line;
					($field, $value) = SPLIT_FIELD_VALUE_COLON($line);
					if ($field eq "") {
						last RA_BODY_LINE;
					}
					# フィールド値のハッシュへの読み込み
					READ_VALUE_PARAM: foreach $param ($PREFIX_FIELD, $ADDR_FIELD) {
						if ($field eq $param) {
							$value{$param} = $value;
							last READ_VALUE_PARAM;
						}
					}
				}
				# PREFIX オプションが指定されている場合
				if ($PREFIX ne "") {
					$ip_value_prefix = NetAddr::IP->new6($value{$PREFIX_FIELD});
					$ip_value_prefix_first = $ip_value_prefix->first;
					$ip_value_prefix_last = $ip_value_prefix->last;
					# 「MATCH_PREFIX=within」である場合
					if ($MATCH_PREFIX eq "within") {
						if ( not ( $ip_value_prefix_first->within($ip_prefix) and $ip_value_prefix_last->within($ip_prefix) ) ) {
							next RA_LINE;
						}
					# 「MATCH_PREFIX=equal」である場合
					} elsif ($MATCH_PREFIX eq "equal") {
						if ( not ( $ip_prefix == $ip_value_prefix ) ) {
							next RA_LINE;
						}
					# 「MATCH_PREFIX=contains」である場合
					} elsif ($MATCH_PREFIX eq "contains") {
						if ( not ( $ip_value_prefix->contains($ip_prefix_first) and $ip_value_prefix->contains($ip_prefix_last) ) ) {
							next RA_LINE;
						}
					}
				}
				push @addr, $value{$ADDR_FIELD};
			} else {
				next RA_LINE;
			}
		}
		close(COM);
		if ( scalar(@addr) > 0 ) {
			foreach $addr (uniq(sort(@addr))) {
				print "$addr\n";
			}
			exit 0;
		}
		$count = $count + 1;
		if ( ( $RETRY_NUM != 0 ) and ( $count > $RETRY_NUM ) ) {
			exit 1;
		}
		sleep $RETRY_INTERVAL;
	}
}

