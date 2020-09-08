my @newMatchers = (
    # Error information that appears in the middle of junit tests:
    #
    # [junit] Testcase: test_add_failed_port took 0.717 sec
    # [junit] Testcase: test_checkForTimeouts took 10.43 sec
    # [junit]     FAILED
    # [junit] 10218 < 1000
    # [junit] junit.framework.AssertionFailedError: 10218 < 1000
    # [junit]     at com.electriccloud.http.xxx(HTTPDispatcherTest.java:128)
    #
    # [junit] Testcase: testExecute_ok took 0.321 sec
    #
    # OR...
    #
    # [junit] Testcase: testBufferProblem took 5.827 sec
    # [junit]    Caused an ERROR
    # [junit] Read timed out
    # [junit] java.net.SocketTimeoutException: Read timed out
    # [junit]   at java.net.SocketInputStream.socketRead0(Native Method)
    # [junit]   at java.net.SocketInputStream.read(SocketInputStream.java:129)
    # [junit]
    # [junit] Testcase: testHttpHttps took 0.328 sec

    {
        id =>               "junitFailureCreateDefect",
        pattern =>          q{^\s*\[junit\]\s*(FAILED|Caused an ERROR)},
        action =>           q{PostPMatchFound();},
    },
);
push @::gMatchers, @newMatchers;

#-------------------------------------------------------------------------
# PostPMatchFound
#
#-------------------------------------------------------------------------
sub PostPMatchFound() {
    debugLog("PostPMatchFound\n");

    # First, scan back to find the "Testcase" line, and extract the
    # name of the test case.

    my $testSuiteName = "";
    my $testCaseName = "";
    my $log = "";

    my $first = backTo('\[junit\]\s+Testcase:');
    my $line = logLine($first + $::gCurrentLine);
    if ($line =~ m/\[junit\]\s*Testcase:\s*([^\s]+)/) {
        $testCaseName = $1;

        # Now scan back even further to find the name of the test suite.

        my $offset = backTo('\[junit\]\s+Testsuite:', $first-1);
        $line = logLine($offset + $::gCurrentLine);
        if ($line =~ m/\[junit\]\s+Testsuite:.*\.([^.\s]+)/) {
            $testSuiteName = $1;
        }
    }

    #$log = logLine($first + forwardTo(
    #        q{(\[junit\] Test)|^(?!.*junit)}) - 1);

    #$first = 0 unless defined($first);
    my $last = forwardTo(
            q{(\[junit\] Test)|^(?!.*junit)}) - 1;

    # Convert the range to actual line numbers and handle boundary conditions.

    $first += $::gCurrentLine;
    $last += $::gCurrentLine;
    if ($first <= $::gDiagLastLine) {
        # Don't output lines before the beginning of the log file.
        # In addition, don't output lines that are before the current
        # line and have already been output.

        if ($::gDiagLastLine < $::gCurrentLine) {
            $first = $::gDiagLastLine + 1;
        } elsif ($first < $::gCurrentLine) {
            $first = $::gCurrentLine;
        }
    }
    if ($last < $first) {
        # Make sure we output at least 1 line.

        $last = $first;
    }

    # Limit the length of diagnostic messages.

    if (($last + 1 - $first) > $::gMaxLines) {
        # Too many lines.  In truncating the message, try to retain
        # the current line.

        my $half = $::gMaxLines/2;
        if (($last - $::gCurrentLine) <= $half) {
            $first = $last - ($::gMaxLines-1);
        } elsif (($::gCurrentLine - $first) <= $half) {
            $last = $first + ($::gMaxLines-1);
        } else {
            $first = $::gCurrentLine - $half;
            $last = $first + ($::gMaxLines-1);
        }
    }

    # Collect the log lines for the new diagnostic record.

    my $message = "";
    my $current = $first;
    while ($current <= $last) {
        my $line = logLine($current);
        if (defined($line)) {
            $message .= $line;
        } else {
            # End of file: ignore anything past the end of the file.

            $last = $current - 1;
            last;
        }
        $current++;
    }

    setProperty("/myJob/ecTestFailures/Step$::gStepId-$testCaseName/stepName", "$::gJobStepName");
    setProperty("/myJob/ecTestFailures/Step$::gStepId-$testCaseName/stepId", "$::gStepId");
    setProperty("/myJob/ecTestFailures/Step$::gStepId-$testCaseName/testSuiteName", "$testSuiteName");
    setProperty("/myJob/ecTestFailures/Step$::gStepId-$testCaseName/testCaseName", "$testCaseName");
    setProperty("/myJob/ecTestFailures/Step$::gStepId-$testCaseName/testCaseResult", "Error");
    setProperty("/myJob/ecTestFailures/Step$::gStepId-$testCaseName/log", "$message");
    setProperty("/myJob/ecTestFailures/Step$::gStepId-$testCaseName/defectId", "");
    setProperty("/myJob/ecTestFailures/Step$::gStepId-$testCaseName/defectResult", "");
}
