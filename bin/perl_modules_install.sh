#!/bin/bash

# perl -MCPAN -e 'install T/TI/TIMB/DBI-1.30.tar.gz'
perl -MCPAN -e 'install DBI'

# DBD is often already installed from an rpm
# perl -MCPAN -e 'install DBD::Pg'

perl -MCPAN -e 'install Spreadsheet::ParseExcel'
perl -MCPAN -e 'install IO::Stringy'
perl -MCPAN -e 'install OLE::Storage_Lite'
perl -MCPAN -e 'install AppConfig'

# Without the surrounding "" this generates an error. Dunno why.
perl -MCPAN -e 'install "Compress::Zlib"'

perl -MCPAN -e 'install PDF::API2'
perl -MCPAN -e 'install Net::Ping'
perl -MCPAN -e 'install Test::Harness'

# On Red Hat 8 system this is likely to fail
# due to a failed test 3. Run the force install.
# Gisle Aas says that this is a known bug in Perl 5.8.0, 
# "You can safely ignore this test failure and install the module regardless."
# perl -MCPAN -e 'force install Digest::SHA1'
perl -MCPAN -e 'install Digest::SHA1'

perl -MCPAN -e 'install Digest::HMAC'
perl -MCPAN -e 'install Test::Simple'
perl -MCPAN -e 'install Net::DNS'
perl -MCPAN -e 'install Mail::CheckUser'
perl -MCPAN -e 'install M/MA/MARKOV/MailTools-1.58.tar.gz'
perl -MCPAN -e 'install Email::Valid'


