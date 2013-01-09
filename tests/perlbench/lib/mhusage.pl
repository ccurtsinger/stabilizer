##---------------------------------------------------------------------------##
##  File:
##      $Id: mhusage.pl,v 2.23 2003/08/02 06:15:37 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Usage output.  Just require the file to have usage info
##	printed to STDOUT.
##---------------------------------------------------------------------------##
##    MHonArc -- Internet mail-to-HTML converter
##    Copyright (C) 1995-1999   Earl Hood, mhonarc@mhonarc.org
##
##    This program is free software; you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation; either version 2 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with this program; if not, write to the Free Software
##    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
##    02111-1307, USA
##---------------------------------------------------------------------------##

package mhonarc;

sub mhusage {
    my($usefh, $close);
# CPU2006
#    local(*PAGER);
#    PAGERCHECK: {
#	if ($UNIX &&
#		(-t STDOUT) &&
#		(($ENV{'PAGER'} && open(PAGER, "| $ENV{'PAGER'}")) ||
#		 (open(PAGER, '| more')))) {
#	    $usefh = \*PAGER;
#	    $close = 1;
#	    last PAGERCHECK;
#	}
	$usefh = \*STDOUT;
	$close = 0;
#    }
    my($curfh) = select($usefh);

    print <<EndOfUsage;
Usage:  $PROG [<options>] <mailfolder> ...
        $PROG -rmm [<options>] <msg> ...
        $PROG -annotate [-notetext <text>] <msg> ...

Description:
  MHonArc is a highly customizable Perl program for converting mail,
  encoded with MIME, into HTML archives.  MHonArc supports the conversion
  of UUCP-style mailbox files and MH style mail folders.  The -single
  option can be used to convert a single mail message to standard output.

  Read the full documentation included with the distribution, or at
  <http://www.mhonarc.org/>, for more complete usage information.

Options:
  Only command-line options are summarized here.  See documentation
  for information about resource file elements and environment variables.

  -add                     : Add message(s) to archive
  -afs                     : Skip archive directory permission check
  -addressmodifycode <exp> : Perl expressions for modifying addresses
  -annotate                : Add an annotation to message(s)
  -archive                 : Generate archive related files (the default)
  -authsort                : Sort messages by author
  -checknoarchive          : Check for "no archive" flags in messages
  -conlen                  : Honor Content-Length fields
  -datefields <list>       : Fields to determine the date of a message
  -decodeheads             : Decode decode-only charset data when reading mail
  -definevar <varlist>     : Define custom resource variables
  -dbfile <name>           : Name of MHonArc database file
  -dbfileperms <octal>     : File permissions for database file
                             (def: "0660" -- UMASK is still applied)
  -doc                     : Print link to doc at end of index page
  -docurl <url>            : URL to MHonArc documentation
                             (def: "http://www.mhonarc.org/")
  -editidx                 : Edit/change index page(s) and messages, only
  -expiredate <date>       : Message cut-off date
  -expireage <secs>        : Time from current when messages expire
  -fileperms <octal>       : File permissions for archive files
                             (def: "0666" -- UMASK is still applied)
  -folrefs                 : Print links to follow-ups/references
  -force                   : Perform archive operations even if unable to lock
  -fromfields <list>       : Fields to detemine whom the message is from
  -genidx                  : Output index to stdout based upon archive contents
  -gmtdatefmt <fmt>        : Format for GMT date
  -gzipexe <file>          : Pathname of Gzip executable
                             (def: "gzip")
  -gzipfiles               : Gzip files
  -gziplinks               : Add ".gz" to filenames in links
  -help                    : This message
  -htmlext <ext>           : Filename extension for generated HTML files
                             (def: "html")
  -iconurlprefix <url>     : Prefix for icon URLs
			     (def: "")
  -idxfname <name>         : Name of index page
                             (def: "maillist.html")
  -idxprefix <string>      : Filename prefix for multi-page main index
                             (def: "mail")
  -idxsize <#>             : Maximum number of messages shown in indexes
  -keeponrmm               : Do not delete message files when message is
                             removed from archive.
  -lang <locale>           : Set locale/language.
  -localdatefmt <fmt>      : Format for local date
  -lock                    : Do archive locking (default)
  -lockdelay <#>           : Time delay, in seconds, between lock tries
                             (def: "3")
  -locktries <#>           : Maximum number of tries in locking an archive
                             (def: "10")
  -mailtourl <url>         : URL to use for e-mail address hyperlinks
                             (def: "mailto:\$TO\$")
  -main                    : Create a main index
  -maxsize <#>             : Maximum number of messages allowed in archive
  -mhpattern <exp>         : Perl expression for message files in a directory
                             (def: "^\\d+\$")
  -modifybodyaddresses     : ADDRESSMODIFYCODE applies to text entities
  -modtime                 : Set modification time on files to message date
  -months <list>           : Month names
  -monthsabr <list>        : Abbreviated month names
  -msgpgs                  : Create message pages (the default)
  -msgprefix <prefix>      : Filename prefix for message HTML files
                             (def: "msg")
  -msgexcfilter <exp>      : Perl expression(s) for selective message exclusion
  -msgsep <exp>            : Message separator (Perl) regex for mbox files
                             (def: "^From ")
  -multipg                 : Generate multi-page indexes
  -news                    : Add links to newsgroups (the default)
  -noarchive               : Do not generate archive related files
  -noauthsort              : Do not sort messages by author
  -nochecknoarchive        : Ignore "no archive" flags in messages
  -noconlen                : Ignore Content-Length fields (the default)
  -nodecodeheads           : Leave message headers "as is" when read
  -nodoc                   : Do not print link to doc at end of index page
  -nofolrefs               : Do not print links to follow-ups/references
  -nogzipfiles             : Do not Gzip files (the default)
  -nogziplinks             : Do not add ".gz" to filenames in links
  -nokeeponrmm             : Delete message files when message is removed
                             from archive.
  -nolock                  : Do not lock archive
  -nomailto                : Do not add in mailto links for e-mail addresses
  -nomain                  : Do not create a main index
  -nomodtime               : Do not set mod time on files to message date
  -nomsgpgs                : Do not create message pages
  -nomultipg               : Do not generate multi-page indexes
  -nonews                  : Do not add links to newsgroups
  -noposixstrftime         : Do not use POSIX::strftime() to process time
                             format (the default)
  -noreconvert             : Do not reconvert existing messages (the default)
  -noreverse               : List messages in normal order (the default)
  -nosaveresources         : Do not save resource values in DB
  -nosort                  : Do not sort messages
  -nospammode              : Do not obfuscate addresses
  -nosubjectthreads        : Do not check subjects for threads
  -nosubjecttxt <text>     : Text to use if message has no subject
  -nosubsort               : Do not sort messages by subject
  -notetext <text>         : Text data of annotation if -annotation specified
  -nothread                : Do not create threaded index
  -notreverse              : List threads in order (the default)
  -notsort                 : List threads by ordered processed
  -notsubsort              : Do not list threads by subject
  -nourl                   : Do not make URL hyperlinks
  -otherindex <files>      : Other rcfile for extra index
  -outdir <path>           : Destination/location of HTML mail archive
                             (def: ".")
  -pagenum <page>          : Output specified page if -genidx and -multipg
  -perlinc <list>          : List of paths to search for MIME filters
  -posixstrftime           : Use POSIX::strftime() to process time formats
  -quiet                   : Suppress status messages during execution
  -rcfile <file>           : Resource file for MHonArc
  -reconvert               : Reconvert existing messages
  -reverse                 : List messages in reverse order
  -rmm                     : Remove messages from archive
  -savemem                 : Write message data while processing
  -saveresources           : Save resource values in DB (the default)
  -scan                    : List out archive contents to stdout
  -single                  : Convert a single message to HTML (no archive ops)
  -sort                    : Sort messages by date (the default)
  -spammode                : Obfuscate addresses
  -stderr <file>           : File to send stderr messages to
  -stdin <file>            : File to treat as standard input
  -stdout <file>           : File to send stdout messages to
  -subjectarticlerxp <rxp> : Regex for leading articles in subjects
  -subjectreplyrxp <rxp>   : Regex for leading reply string in subjects
  -subjectstripcode <exp>  : Perl expressions for modifying subjects
  -subjectthreads          : Check subjects for threads
  -subsort                 : Sort message by subject
  -thread                  : Create threaded index (the default)
  -tidxfname <name>        : Filename of threaded index page
                             (def: "threads.html")
  -tidxprefix <string>     : Filename prefix for multi-page thread index
                             (def: "thrd")
  -time                    : Print to stderr CPU time used to process mail
  -title <string>          : Title of main index page
                             (def: "Mail Index")
  -tlevels <#>             : Maximum # of nested lists in threaded index
                             (def: "3")
  -treverse                : List threads in reverse order
  -tslice <#:#:#>          : Set size of thread slice listing
  -tslicelevels <#>        : Maximum # of nested lists in thread slices
                             (def: TLEVELS resource value)
  -tsort                   : List threads by date (the default)
  -tsubsort                : List threads by subject
  -ttitle <string>         : Title of thread index page
                             (def: "Mail Thread Index")
  -umask <umask>           : Umask of MHonArc process (Unix only)
  -url                     : Make URL hyperlinks (the default)
  -v                       : Print version information
  -varregex <regex>        : Perl regex matching resource variables
  -weekdays <list>         : Weekday names
  -weekdaysabr <list>      : Abbreviated weekday names

  The following options can be specified multiple times: -definevar,
  -notetext, -otherindex, -perlinc, -rcfile.

Version:
$VINFO
EndOfUsage

    close($usefh)  if $close;
    select($curfh);
}

##---------------------------------------------------------------------------##
1;
