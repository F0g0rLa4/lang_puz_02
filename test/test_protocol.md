# Test Protocol

## Database from creator correct?

o Insure creator actually updated the db to new timestamp & consumer has it. 

## Code Changes by Platform

o Make sure databaseFactory is correct for desktop or mobile as required.

## Run *_test.dart in integration mode to see keystroke behavior complies

## Test for db missing

## Test for failure to log correctly for environment

o Desktops devel environments: app_logger.dart can log to arbitrary dir.
o But run time on cell must be to a user document dir

## Problems with other Emulators/Environments

o Force to chrome from VSC
-- flutter run -t test/widget_test.dart -d chrome
-- Relatively bullet proof testing against Chrome if problems with other emulators but has its own quirks
