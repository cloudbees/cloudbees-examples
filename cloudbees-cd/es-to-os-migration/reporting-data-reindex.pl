#!/usr/bin/env cb-perl

use v5.32.0;
use strict;
use warnings;
use Getopt::Long;
use Time::Duration;
use POSIX qw(strftime);

use ElectricCommander;
use ElectricCommander::Util;

use Data::Dumper;

$Time::Duration::MILLISECOND = 1;

$::gLogger = \*STDOUT;

$::gCommander = new ElectricCommander({abortOnError => 0, debug => 0});

$::gVersion = '2024.06.0';

#  2  - trace
#  1  - debug
#  0  - info
# -1  - error
# -2  - critical
$::gDebug = 0;
$::gShowHelp = 0;
$::gShowVersion = 0;

$::gSourceUrl = undef;
$::gSourceAuthUser = 'reportuser';
$::gSourceAuthPassword = undef;
$::gSourceAuthCertificateFile = undef;
$::gSourceAuthCertificateKeyFile = undef;
$::gDestinationUrl = undef;
$::gDestinationAuthUser = 'reportuser';
$::gDestinationAuthPassword = undef;
$::gDestinationAuthCertificateFile = undef;
$::gDestinationAuthCertificateKeyFile = undef;
$::gAllowMismatchedIndices = 0;
$::gShowStatistics = 0;

%::gOptions = (
    "version|v" => \$::gShowVersion,
    "help|h"    => \$::gShowHelp,
    "debug=i"   => \$::gDebug,

    "sourceUrl=s"                         => \$::gSourceUrl,
    "sourceAuthUser=s"                    => \$::gSourceAuthUser,
    "sourceAuthPassword=s"                => \$::gSourceAuthPassword,
    "destinationUrl=s"                    => \$::gDestinationUrl,
    "destinationAuthUser=s"               => \$::gDestinationAuthUser,
    "destinationAuthPassword=s"           => \$::gDestinationAuthPassword,

    "allowMismatchedIndices=i"            => \$::gAllowMismatchedIndices,

    "showStatistics=i"                    => \$::gShowStatistics,
);

%::gCommanderOptions = (
    "Allow Mismatched Indices"        => \$::gAllowMismatchedIndices,
    "Source URL"                      => \$::gSourceUrl,
    "Destination URL"                 => \$::gDestinationUrl,
    "Source Credential/userName"      => \$::gSourceAuthUser,
    "Source Credential/password"      => \$::gSourceAuthPassword,
    "Destination Credential/userName" => \$::gDestinationAuthUser,
    "Destination Credential/password" => \$::gDestinationAuthPassword,
    "Show Statistics"                 => \$::gShowStatistics,
    "Debug"                           => \$::gDebug,
);

$::gEnvironmentVarPrefix = "CBCD_RDRT_";

$::gProgramName = "reporting-data-reindex.pl";

$::gBanner = "Reporting data reindex tool for CloudBees Software Delivery Automation Analytics Server version $::gVersion\n"
    . "Copyright (C) 2009-" . (1900 + (localtime())[5])
    . " CloudBees, Inc.\n"
    . "All rights reserved.\n\n";

$::gHelpMessage = "
Usage: $::gProgramName --sourceUrl=<url> --destinationUrl=<url> [options]

  --sourceUrl=<url>           Specifies the URL for the data source for reindexing
  --sourceAuthUser=<username> Specifies the user name on the data source server
                              for reindexing
  --sourceAuthPassword=<password>
                              Specifies the password for the user name on the data
                              source server for reindexing
  --destinationUrl=<url>      Specifies the URL for the data recipient for
                              reindexing
  --destinationAuthUser=<username>
                              Specifies the user name on the data recipient server
                              for reindexing
  --destinationAuthPassword=<password>
                              Specifies the password for the user name on the data
                              recipient server for reindexing
  --allowMismatchedIndices=<1|0>
                              Allow (1) or disable (0) processing of mismatched
                              indices on the data recipient server
  --showStatistics=<1|0>      If set to (1) then the utility will work in a dry run mode
                              showing index statistics on the data source server
                              without starting data migration.
";

sub mesg {
    my $level_title;
    my $level = @_ > 1 ? shift : "info";
    my $message = shift;

    if ( $level =~ /^crit|^crt/i ) {
        $level = -2;
        $level_title = "CRIT ";
    } elsif ( $level =~ /^err/i ) {
        $level = -1;
        $level_title = "ERROR";
    } elsif ( $level =~ /^inf/i ) {
        $level = 0;
        $level_title = "INFO ";
    } elsif ( $level =~ /^deb|^dbg/i ) {
        $level = 1;
        $level_title = "DEBUG";
    } elsif ( $level =~ /^tra|^trc/i ) {
        $level = 2;
        $level_title = "TRACE";
    } elsif ( $level =~ /^raw/i ) {
        $level = 99;
    } else {
        mesg("CRIT", "Unknown log level: $level");
    }

    if ( $level == 99 ) {
        printf($message . "\n", @_);
    } elsif ( $level <= $::gDebug ) {
        my $oldfh = select($::gLogger);
        local $| = 1;
        printf("%s [%s] %s\n", ElectricCommander::Util::timestamp(), $level_title, $message);
        select($oldfh);
    }

    if ( $level <= -2 ) {
        commanderSetJobResult($message);
        exit 1;
    }
}

{
    package ReportingServer;
    use LWP::UserAgent;
    use URI;
    use JSON;
    use Data::Dumper;

    sub new {
        my ($class, $config) = @_;
        my $self;

        if ( defined($config)) {
            if ( ref($config) eq "HASH" ) {
                $self = $config;
            } else {
                $self = {};
            }
        } else {
            $self = {};
        }
        bless $self;

        $self->{serverTitle} //= 'unknown';
        $self->{port} //= 9200;
        $self->{host} //= 'localhost';
        $self->{secure} //= 1;

        return $self;
    }

    sub validate {
        my ($self, $type_expected) = @_;
        my $errmsg;

        if ( $self->{secure} ) {
            if ( defined($self->{username}) && defined($self->{password}) ) {
                # nothing to do there
            } elsif ( defined($self->{certFile}) && defined($self->{keyFile}) ) {
                $self->_validateCertificate();
            } else {
                $self->mesg("CRIT", "validate", "The specified server requires authentication. Please specify the correct method of authentication.");
            }
        }

        my $info = $self->getInfo();

        if ( !defined($info) ) {
            if ( !$self->{secure} ) {
                $errmsg = "Failed to connect to the remote server: ";
            } elsif ( defined($self->{password}) ) {
                $errmsg = "Failed to connect and authenticate to the remote server using the credentials provided: ";
            } else {
                $errmsg = "Failed to connect and authenticate to the remote server using the provided certificate: ";
            }
            $self->mesg("CRIT", "validate", $errmsg . $self->getLastErrorMessage());
        }

        my $type_current = $self->getServerType();

        if ( $type_current eq "unknown" ) {
            $errmsg = "The specified server does not look like an Elasticsearch or OpenSearch server. Please specify the correct server.";
        } elsif ( $type_current ne $type_expected ) {
            if ( $type_expected eq "elasticsearch" ) {
                $errmsg = "The specified server does not look like an Elasticsearch server. Please specify the correct source server.";
            } else {
                $errmsg = "The specified server does not look like an OpenSearch server. Please specify the correct destination server.";
            }
        }

        $self->mesg("CRIT", "validate", $errmsg) if ( defined($errmsg) );

    }

    sub _validateCertificate {
        my $self = shift;

        my $errmsg = undef;

        if ( !defined($self->{certFile}) ) {
            $errmsg = "The reindex certificate file is not specified";
        } elsif ( !defined($self->{keyFile}) ) {
            $errmsg = "The reindex certificate private key file is not specified";
        } elsif ( ! -r $self->{certFile} ) {
            $errmsg = "The reindex certificate file was not found or not readable: " . $self->{certFile};
        } elsif ( ! -r $self->{keyFile} ) {
            $errmsg = "The reindex certificate private key file was not found or not readable: " . $self->{keyFile};
        }

        $self->mesg("CRIT", "validate", $errmsg) if ( defined($errmsg) );
    }

    sub configure {
        my ($self, $config) = @_;
        while(my($k, $v) = each %$config) {
            $self->{$k} = $v;
        }
    }

    sub mesg {
        my ($self, $level, $method, $message) = @_;
        ::mesg($level, $method . " [$self->{serverTitle}] " . $message);
    }

    sub getServerType {
        my $self = shift;
        my $info = $self->getInfo();
        if (
            defined($info->{version}) &&
            defined($info->{version}->{number}) &&
            defined($info->{version}->{build_flavor}) &&
            $info->{version}->{build_flavor} eq "default" &&
            defined($info->{tagline}) &&
            $info->{tagline} eq "You Know, for Search"
        ) {
            return "elasticsearch";
        }
        if (
            defined($info->{version}) &&
            defined($info->{version}->{number}) &&
            defined($info->{version}->{distribution}) &&
            $info->{version}->{distribution} eq "opensearch"
        ) {
            return "opensearch";
        }
        return "unknown";
    }

    sub getLastErrorMessage {
        my $self = shift;
        if ( !defined($self->{'cache,last_error_message'}) ) {
            return "No last reported error";
        }
        return $self->{'cache,last_error_message'};
    }

    sub getInfo {
        my $self = shift;
        $self->{'cache,info'} //= $self->_sendRequest("GET", "");
        return $self->{'cache,info'};
    }

    sub getServerUrl {
        my $self = shift;
        return ($self->{secure} ? "https" : "http") .
            "://" . $self->{host} . ':' . $self->{port};
    }

    sub getServerDescription {
        my $self = shift;
        my $server_type = $self->getServerType();
        my $info = $self->getInfo();
        if ( $server_type eq "elasticsearch" ) {
            return "Elasticsearch version " . $info->{version}->{number};
        } elsif ( $server_type eq "opensearch" ) {
            return "OpenSearch version " . $info->{version}->{number};
        } else {
            return "Unknown version unknown";
        }
    }

    sub getClusterHealth {
        my ($self, $level) = @_;
        return $self->_sendRequest("GET", "_cluster/health", { level => $level });
    }

    sub createIndex {
        my ($self, $index) = @_;
        return $self->_sendRequest("PUT", "$index");
    }

    sub removeIndex {
        my ($self, $index) = @_;
        return $self->_sendRequest("DELETE", "$index");
    }

    sub setIndexMapping {
        my ($self, $index, $m) = @_;
        $m = encode_json($m);
        return $self->_sendRequest("PUT", "$index/_mapping", $m, $m);
    }

    sub getIndexCount {
        my ($self, $index) = @_;
        return $self->_sendRequest("GET", "$index/_count");
    }

    sub getIndexMapping {
        my ($self, $index) = @_;
        return $self->_sendRequest("GET", "$index/_mapping");
    }

    sub getIndexMappingES {
        my ($self, $index) = @_;
        my $s = $self->{username};
        $self->{username} = "kibanauser";
        my $res = $self->_sendRequest("GET", "$index/_mapping");
        $self->{username} = $s;
        return $res;
    }

    sub getDiskUsage {
        my ($self) = @_;
        return $self->_sendRequest("GET", "_cat/allocation");
    }

    sub getConnectionInfo {
        my $self = shift;
        return {
            host => $self->getServerUrl(),
            username => $self->{username},
            password => $self->{password}
        };
    }

    sub reindex {
        my ($self, $indexSource, $indexDestination) = @_;
        my $data = {
            source => {
                index => $indexSource
            },
            dest => {
                index => $indexDestination
            }
        };
        return $self->_sendRequest("POST", "_reindex", {
                wait_for_completion => "true",
                refresh => "true",
                timeout => "180m"
            }, encode_json($data), encode_json($data));
    };

    sub reindexRemote {
        my ($self, $indexSource, $indexDestination, $destination, $options) = @_;
        my $dst_host = $destination->{host};
        my $dst_auth_user = $destination->{username};
        my $dst_auth_pass = $destination->{password};
        my $opt_pipeline = $options->{pipeline};
        my $opt_op_type = $options->{op_type};

        my $data = {
            source => {
                index => $indexSource,
                remote => {
                    host => $dst_host,
                    username => $dst_auth_user,
                    password => $dst_auth_pass
                }
            },
            dest => {
                index => $indexDestination,
                pipeline => $opt_pipeline,
                op_type => $opt_op_type
            }
        };

        my $data_debug = {
            source => {
                index => $indexSource,
                remote => {
                    host => $dst_host,
                    username => $dst_auth_user,
                    password => "<hidden>"
                }
            },
            dest => {
                index => $indexDestination,
                pipeline => $opt_pipeline,
                op_type => $opt_op_type
            }
        };

        return $self->_sendRequest("POST", "_reindex", {
                wait_for_completion => "true",
                refresh => "true",
                timeout => "180m"
            }, encode_json($data), encode_json($data_debug));
    }

    sub _sendRequest {
        my $self = shift;

        my ($method, $path, $query, $body, $body_debug) = @_;

        $body_debug //= $body;

        my $uri = URI->new($self->getServerUrl() . '/' . $path);

        if ( $query ) {
            $uri->query_form($query);
        }

        my $req = HTTP::Request->new;
        $req->uri($uri);
        $req->method($method);
        $req->header(
            'Content-Type'    => 'application/json',
            'Accept'          => 'application/json',
            'Accept-Encoding' => 'identity',
        );

        $self->mesg("DBG", "sendRequest", $method . ": " . $uri);

        if ( defined($self->{username}) && defined($self->{password}) ) {
            $req->authorization_basic($self->{username}, $self->{password});
            $self->mesg("DBG", "sendRequest", "using basic auth; " .
                "username: '" . $self->{username} . "'; " .
                "password: <hidden>;");
        }

        if ( defined($body) ) {
            if ( $method eq "GET" ) {
                $self->mesg("CRIT", "sendRequest", "body parameter is not supported in GET request");
            }
            $req->content($body);
            $self->mesg("DBG", "sendRequest", "data: $body_debug");
        }

        # set timeout to 30 mins
        my $ua = LWP::UserAgent->new(
            ssl_opts => {
                verify_hostname => 0,
                SSL_verify_mode => 0
            },
            timeout => 30 * 60
        );

        if ( defined($self->{certFile}) && defined($self->{keyFile}) ) {
            $ua->ssl_opts(
                SSL_cert_file => $self->{certFile},
                SSL_key_file  => $self->{keyFile}
            );
            $self->mesg("DBG", "sendRequest", "SSL certificate; " .
                "certificate: '" . $self->{certFile} . "'; " .
                "key: '" . $self->{keyFile} . "';");
        }

        my $resp = $ua->request($req);
        $self->mesg("DBG", "sendRequest", "response status: " . $resp->status_line());

        my $content = $resp->decoded_content();
        $self->mesg("DBG", "sendRequest", "response data:\n" . $content);

        if ( $resp->code() != 200 ) {

            if ( $resp->code() >= 500 && $resp->code() <= 599 ) {
                # internal server error
                $self->{'cache,last_error_message'} = $resp->status_line();
            } elsif ( $resp->code() >= 401 && $resp->code() <= 499 ) {
                # authorization error
                $self->{'cache,last_error_message'} = $resp->status_line();
            } elsif ( $resp->code() == 400 ) {
                # 400 Bad Request
                my $result = decode_json($content);
                if ( defined($result->{failures}) ) {
                    $self->{'cache,last_error_message'} = encode_json($result->{failures});
                } elsif ( defined($result->{error}) ) {
                    if ( defined($result->{error}->{root_cause}) ) {
                        $self->{'cache,last_error_message'} = encode_json($result->{error}->{root_cause});
                    } else {
                        $self->{'cache,last_error_message'} = encode_json($result->{error});
                    }
                } else {
                    $self->{'cache,last_error_message'} = $content;
                }
            } else {
                $self->{'cache,last_error_message'} = "Unknown error";
            }

            return undef;

        }

        $self->{'cache,last_error_message'} = undef if ( defined($self->{'cache,last_error_message'}) );

        my $result = decode_json($content);

        return $result;
    }

}

package main;

sub show_error {
    my ($errmsg) = shift;
    print(STDERR "ERROR: " . $errmsg . "\n");
    commanderSetJobResult("ERROR: " . $errmsg);
    exit(1);
}

sub parseUrl {
    my ($url) = shift;

    if ( $url !~ m/^http(s?):\/\/(.*):(\d+)$/i ) {
        mesg("CRIT", "Error: The specified URL '$url' could not be parsed. URL is expected in the form: http(s)://host:port");
    }

    return (
        "secure", $1 eq "s" || $1 eq "S" ? 1 : 0,
        "host", $2,
        "port", $3,
    );
}

sub num {
    my ($num) = shift;
    while($num =~ s/(\d+)(\d\d\d)/$1\,$2/){};
    return $num;
}

sub environmentGetOptions {
    my $debugLevel = $::ENV{$::gEnvironmentVarPrefix . 'DEBUG'};
    $::gDebug = $debugLevel if ( defined($debugLevel) && $debugLevel ne '' );

    while (my($option, $ref) = each %::gOptions) {
        $option =~ s/[=|].*$//;
        my $optionEnv = uc($option);
        my $value = $::ENV{$::gEnvironmentVarPrefix . $optionEnv};
        if ( defined($value) && $value ne '' ) {
            my $valueMessage;
            if ( $option =~ /password/i ) {
                $valueMessage = '<empty>';
            } else {
                $valueMessage = "'" . $value . "'";
            }
            ${$ref} = $value;
            mesg("DBG", "environment option: " . $option . "; value: " . $valueMessage);
        }
    }
}

sub commanderGetOptions {
    return unless ( defined($::ENV{COMMANDER_JOBSTEPID}) );

    my $debugLevel = $::gCommander->getProperty('Debug')->findvalue("//property/value");
    $::gDebug = $debugLevel if ( defined($debugLevel) && $debugLevel ne '' );

    while (my($option, $ref) = each %::gCommanderOptions) {
        my $value;
        my ($authOption, $authField) = $option =~ /^([^\/]+)\/(.+)$/;
        if ( !defined($authOption) ) {
            $value = $::gCommander->getProperty($option)->
                findvalue("//property/value")->value();
        } else {
            $value = $::gCommander->getFullCredential($authOption)->
                findvalue("//credential/$authField")->value();
        }
        my $valueMessage;
        if ( !defined($value) ) {
            $valueMessage = 'undef';
        } elsif ( $value eq '' ) {
            $valueMessage = '<empty>';
        } else {
            if ( $option =~ /password/i ) {
                $valueMessage = '<empty>';
            } else {
                $valueMessage = "'" . $value . "'";
            }
            ${$ref} = $value;
        }
        mesg("DBG", "jobstep option: " . $option . "; value: " . $valueMessage);
    }
}

sub commanderSetJobResult {
    return unless ( defined($::ENV{COMMANDER_JOBSTEPID}) );
    my ($message) = @_;
    $::gCommander->setProperty('/myJobStep/summary', $message);
}

sub commanderSetProgress {
    return unless ( defined($::ENV{COMMANDER_JOBSTEPID}) );
    my ($progress) = @_;
    $::gCommander->setProperty('/myJobStep/summary', "Progress: " . $progress);
}

sub showStats {
    my %indices = %{$_[0]};
    my $diskUsage = $_[1];

    my $keystr;
    my $valstr;
    my $maxkeylen;
    my $maxvallen;

    $keystr = "Node Name";
    $valstr = "Indices Size";
    $maxkeylen = length($keystr);
    $maxvallen = length($valstr);

    foreach my $stat (@{ $diskUsage }) {
        next if (!$stat->{host});
        $maxkeylen = length($stat->{node}) if (length($stat->{node}) > $maxkeylen);
    }

    mesg("RAW", "");
    mesg("RAW", "%-" . $maxkeylen . "s | %s", $keystr, $valstr);
    mesg("RAW", "%s | %s", "-" x $maxkeylen, "-" x $maxvallen);

    foreach my $stat (@{ $diskUsage }) {
        next if (!$stat->{host});
        mesg("RAW", "%-" . $maxkeylen . "s | %s", $stat->{node}, $stat->{"disk.indices"});
    }

    $keystr = "Index Name";
    $valstr = "Count";
    $maxkeylen = length($keystr);
    $maxvallen = length($valstr);

    foreach my $index (sort keys %indices) {
        $maxkeylen = length($index) if (length($index) > $maxkeylen);
    }

    mesg("RAW", "");
    mesg("RAW", "%-" . $maxkeylen . "s | %s", $keystr, $valstr);
    mesg("RAW", "%s | %s", "-" x $maxkeylen, "-" x $maxvallen);

    my $total = 0;

    foreach my $index (sort keys %indices) {
        mesg("RAW", "%-" . $maxkeylen . "s | %d", $index, $indices{$index});
        $total += $indices{$index};
    }

    mesg("RAW", "%s | %s", "-" x $maxkeylen, "-" x $maxvallen);
    mesg("RAW", "%-" . $maxkeylen . "s | %d", "Total", $total);

    exit 0;
}

sub main {

    my $_counter;
    my $_total;
    my $backupTimestamp = strftime("%Y%m%d%H%M%S", localtime(time()));

    print($::gBanner);

    environmentGetOptions();
    commanderGetOptions();

    if ( !GetOptions(%::gOptions) ) {
        print(STDERR $::gHelpMessage);
        exit(1);
    }

    if ($::gShowVersion) {
        exit(0);
    }

    if ( $::gShowHelp ) {
        print($::gHelpMessage);
        exit(0);
    }

    if ( !defined($::gSourceUrl) ) {
        show_error("No URL was specified for the source server for reindexing data.");
    }

    my $src;
    my $dst;

    $src = ReportingServer->new({
        parseUrl($::gSourceUrl),
        username    => $::gSourceAuthUser,
        password    => $::gSourceAuthPassword,
        certFile    => $::gSourceAuthCertificateFile,
        keyFile     => $::gSourceAuthCertificateKeyFile,
        serverTitle => "source"
    });

    $src->validate('elasticsearch');

    if ($::gShowStatistics) {

        mesg("INFO", "Index statistics from the next server will be shown::");
        mesg("INFO", "  * URL: " . $src->getServerUrl());
        mesg("INFO", "  * Server type: " . $src->getServerDescription());

    } else {

        if ( !defined($::gDestinationUrl) ) {
            show_error("No URL was specified for the destination server for reindexing data.");
        }

        $dst = ReportingServer->new({
            parseUrl($::gDestinationUrl),
            username    => $::gDestinationAuthUser,
            password    => $::gDestinationAuthPassword,
            certFile    => $::gDestinationAuthCertificateFile,
            keyFile     => $::gDestinationAuthCertificateKeyFile,
            serverTitle => "destination"
        });

        $dst->validate('opensearch');

        mesg("INFO", "As part of this migration, the indices will be migrated from the server:");
        mesg("INFO", "  * URL: " . $src->getServerUrl());
        mesg("INFO", "  * Server type: " . $src->getServerDescription());
        mesg("INFO", "to the server:");
        mesg("INFO", "  * URL: " . $dst->getServerUrl());
        mesg("INFO", "  * Server type: " . $dst->getServerDescription());

    }

    my $data;
    my $diskUsage;
    my %indices;
    my %mappings;

    if ($::gShowStatistics) {
        mesg("INFO", "Checking disk usage on the source server...");
        $diskUsage = $src->getDiskUsage();
    }

    mesg("INFO", "Checking available indices from the source server...");

    $data = $src->getClusterHealth("indices");

    if ( !defined($data) || !defined($data->{indices}) ) {
        mesg("CRIT", "Failed to get available indices from the source server: " .
            $src->getLastErrorMessage());
    }

    #mesg("TRACE", "data:\n" . ($data));

    foreach my $index (sort keys %{ $data->{indices} }) {
        if ( $index =~ /^ef-/i ) {
            $indices{$index} = 0;
        }
    }

    my $doc_count = 0;

    $_counter = 0;
    foreach my $index (sort keys %indices) {

        my $msg_prefix = sprintf("[%3i/%3i] ", ++$_counter, scalar keys %indices);
        mesg("INFO", $msg_prefix . "Checking the index '$index' ...");

        my $stats = $src->getIndexCount($index);

        if ( !defined($stats) || !defined($stats->{count}) ) {
            mesg("CRIT", "Failed to get '$index' index statistics from the source server.");
        }

        my $m = $src->getIndexMappingES($index);
        if ( !defined($m) || !defined($m->{$index}) || !defined($m->{$index}->{mappings}) ) {
            mesg("CRIT", "Failed to get '$index' index mappings from the source server.");
        }

        $indices{$index} = $stats->{count};
        $mappings{$index} = $m->{$index}->{mappings};
        $doc_count += $stats->{count};

    }

    mesg("INFO", "The source server contains " . num(scalar keys %indices) .
        " indices with " . num($doc_count) . " documents.");

    showStats(\%indices, $diskUsage) if ($::gShowStatistics);

    my $start_time = time();

    $_counter = 0;
    $_total = 0;
    foreach my $index (sort keys %indices) {

        my $msg_prefix = sprintf("[%3i/%3i] ", ++$_counter, scalar keys %indices);
        my $msg_pad = " " x length($msg_prefix);
        mesg("INFO", $msg_prefix . "Transfering the index '$index' with " .
            num($indices{$index}) . " documents...");

        my $createIndex = 1;

        my $m = $dst->getIndexMapping($index);

        if (defined($m)) {

            if (!defined($m->{$index}) || !defined($m->{$index}->{mappings}) || !defined($m->{$index}->{mappings}->{properties})) {
                mesg("CRIT", "Unexpected response when retrieving index mappings from the destination server.");
            }

            my $props = $m->{$index}->{mappings}->{properties};

            my $ok = 1;

            foreach my $prop (sort keys %{ $mappings{$index}->{properties} }) {
                my $type = $mappings{$index}->{properties}->{$prop}->{type};
                next unless defined($type);
                next unless defined($props->{$prop}) && defined($props->{$prop}->{type});
                my $dtype = $props->{$prop}->{type};
                if ($type ne $dtype) {
                    my $level = $::gAllowMismatchedIndices ? "DBG" : "CRIT";
                    mesg($level, "property '$prop' has type '$dtype' in the destination index, but it's type in source index is '$type'. The index should be re-created.");
                    $ok = 0;
                } else {
                    mesg("DBG", "property '$prop' has '$type' type on both servers");
                }
            }

            if ($ok) {
                $createIndex = 0;
            } else {
                mesg("INFO", $msg_pad . "Properties with mismatched types were found in the destination index. This index will be saved under a different name.");
                my $indexBackup = "ef-reindex_backup-" . $backupTimestamp . substr($index, index($index, '-'));
                mesg("INFO", $msg_pad . "Renaming the existing index '$index' on the destination server to the new name '$indexBackup'...");
                if (!$dst->reindex($index, $indexBackup)) {
                    mesg("CRIT", "An unexpected error occurred when renaming the existing index on the destination server.");
                }
                if (!$dst->removeIndex($index)) {
                    mesg("CRIT", "An unexpected error occurred when removing the existing index on the destination server.");
                }
            }

        }

        if ($createIndex) {

            if (!$dst->createIndex($index)) {
                mesg("CRIT", "An error occurred while creating the index on the destination server.");
            }

            if (!$dst->setIndexMapping($index, $mappings{$index})) {
                mesg("CRIT", "An error occurred while registering the index on the destination server.");
            }

        }

        my $stats = $dst->reindexRemote($index, $index,
            $src->getConnectionInfo(),
            { pipeline => "sda_analytics_reindex", op_type => "index" });

        my $errmsg;

        if ( !defined($stats) ) {
            $errmsg = $dst->getLastErrorMessage();
        } elsif ( defined($stats->{timed_out}) && $stats->{timed_out} ) {
            $errmsg = "A timeout was detected."
        }

        mesg("CRIT", "Failed to transfer the index '$index' to " .
            "the destination server: " . $errmsg) if ( defined($errmsg) );

        my $took = defined($stats->{took}) ? duration_exact($stats->{took} / 1000) : "UNKNOWN";

        my $total = "UNKNOWN";

        if ( defined($stats->{total}) ) {
            $total = num($stats->{total});
            $_total += $stats->{total};
        }

        mesg("INFO", $msg_pad . sprintf("Done %s documents in %s. (progress: %.1f%%)",
                $total, $took, 100 * $_total / $doc_count));

        my @output;

        foreach my $key (
            "created", "updated", "deleted",
            "batches", "version_conflicts", "noops"
        ) {
            my $title = $key eq "version_conflicts" ?
                "Conflicts" : ucfirst($key);
            my $value = defined($stats->{$key}) ?
                num($stats->{$key}) : "UNKNOWN";
            push(@output, "$title: $value");
        }

        mesg("INFO", $msg_pad . join("; ", @output));

        mesg("INFO", $msg_pad . "Verifying the index '$index' in the destination server...");

        my $count = $dst->getIndexCount($index);

        if ( !defined($count) || !defined($count->{count}) ) {
            mesg("ERROR", $msg_pad . "Failed to get '$index' index statistics " .
                "from the destination server.");
        } else {
            mesg("INFO", $msg_pad . "The resulting index '$index' on the destination " .
                "server contains " . num($count->{count}) . " documents.");
        }

        commanderSetProgress(sprintf("%.1f%%", 100 * $_total / $doc_count));

    }

    my $resultMessage = "Reindexing has been successfully completed. Processed $_counter indices " .
        "and " . num($_total) . " documents in " . duration_exact(time() - $start_time) . ".";

    mesg("INFO", $resultMessage);
    commanderSetJobResult($resultMessage);

}

main;

