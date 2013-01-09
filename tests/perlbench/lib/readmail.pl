##---------------------------------------------------------------------------##
##  File:
##	$Id: readmail.pl,v 2.33 2003/08/02 06:04:47 ehood Exp $
##  Author:
##      Earl Hood       mhonarc@mhonarc.org
##  Description:
##      Library defining routines to parse MIME e-mail messages.  The
##	library is designed so it may be reused for other e-mail
##	filtering programs.  The default behavior is for mail->html
##	filtering, however, the defaults can be overridden to allow
##	mail->whatever filtering.
##
##	Public Functions:
##	----------------
##	$data 		= MAILdecode_1522_str($str);
##	($data, @files) = MAILread_body($fields_hash_ref, $body_ref);
##	$hash_ref 	= MAILread_file_header($handle);
##	$hash_ref 	= MAILread_header($mesg_str_ref);
##
##	($disp, $file, $raw, $html_name)  =
##			  MAILhead_get_disposition($fields_hash_ref, $do_html);
##	$boolean 	= MAILis_excluded($content_type);
##	$parm_hash_ref  = MAILparse_parameter_str($header_field);
##	$parm_hash_ref  = MAILparse_parameter_str($header_field, 1);
##
##---------------------------------------------------------------------------##
##    Copyright (C) 1996-2002	Earl Hood, mhonarc@mhonarc.org
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

package readmail;

###############################################################################
##	Private Globals							     ##
###############################################################################

my $Url	          = '(\w+://|\w+:)';

my @_MIMEAltPrefs = ();
my %_MIMEAltPrefs = ();

###############################################################################
##	Public Globals							     ##
###############################################################################

##---------------------------------------------------------------------------##
##	Constants
##

##  Constants for use as second argument to MAILdecode_1522_str().
sub JUST_DECODE() { 1; }
sub DECODE_ALL()  { 2; }
sub TEXT_ENCODE() { 3; }

##---------------------------------------------------------------------------##

##---------------------------------------------------------------------------##
##	Scalar Variables
##

##  Flag if message headers are decoded in the parse header routines:
##  MAILread_header, MAILread_file_header.  This only affects the
##  values of the field hash created.  The original header is still
##  passed as the return value.
##
##  The only 1522 data that will be decoded is data encoded with charsets
##  set to "-decode-" in the %MIMECharSetConverters hash.

$DecodeHeader	= 0;

##---------------------------------------------------------------------------##
##	Variables for holding information related to the functions used
##	for processing MIME data.  Variables are defined in the scope
##	of main.

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMEDecoders is the associative array for storing functions for
##  decoding mime data.
##
##	Keys => content-transfer-encoding (should be in lowercase)
##	Values => function name.
##
##  Function names should be qualified with package identifiers.
##  Functions are called as follows:
##
##	$decoded_data = &function($data);
##
##  The value "as-is" may be used to allow the data to be passed without
##  decoding to the registered filter, but the decoded flag will be
##  set to true.

%MIMEDecoders			= ()
    unless defined(%MIMEDecoders);
%MIMEDecodersSrc		= ()
    unless defined(%MIMEDecodersSrc);

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMECharSetConverters is the associative array for storing functions
##  for converting data in a particular charset to a destination format
##  within the MAILdecode_1522_str() routine. Destination format is defined
##  by the function.
##
##	Keys => charset (should be in lowercase)
##	Values => function name.
##
##  Charset values take on a form like "iso-8859-1" or "us-ascii".
##              NOTE: Values need to be in lower-case.
##
##  The key "default" can be assigned to define the default function
##  to call if no explicit charset function is defined.
##
##  The key "plain" can be set to a function for decoded regular text not
##  encoded in 1522 format.
##
##  Function names are name of defined perl function and should be
##  qualified with package identifiers. Functions are called as follows:
##
##	$converted_data = &function($data, $charset);
##
##  A function called "-decode-" implies that the data should be
##  decoded, but no converter is to be invoked.
##
##  A function called "-ignore-" implies that the data should
##  not be decoded and converted.  Ie.  For the specified charset,
##  the encoding will stay unprocessed and passed back in the return
##  string.

%MIMECharSetConverters			= ()
    unless defined(%MIMECharSetConverters);
%MIMECharSetConvertersSrc		= ()
    unless defined(%MIMECharSetConvertersSrc);

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMEFilters is the associative array for storing functions that
##  process various content-types in the MAILread_body routine.
##
##	Keys => Content-type (should be in lowercase)
##	Values => function name.
##
##  Function names should be qualified with package identifiers.
##  Functions are called as follows:
##
##	$converted_data = &function($header, *parsed_header_assoc_array,
##				    *message_data, $decoded_flag,
##				    $optional_filter_arguments);
##
##  Functions can be registered for base types.  Example:
##
##	$MIMEFilters{"image/*"} = "mypackage'function";
##
##  IMPORTANT: If a function specified is not defined when MAILread_body
##  tries to invoke it, MAILread_body will silently ignore.  Make sure
##  that all functions are defined before invoking MAILread_body.

%MIMEFilters	= ()
    unless defined(%MIMEFilters);
%MIMEFiltersSrc	= ()
    unless defined(%MIMEFiltersSrc);

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMEFiltersArgs is the associative array for storing any optional
##  arguments to functions specified in MIMEFilters (the
##  $optional_filter_arguments from above).
##
##	Keys => Either one of the following: content-type, function name.
##	Values => Argument string (format determined by filter function).
##
##  Arguments listed for a content-type will be used over arguments
##  listed for a function if both are applicable.

%MIMEFiltersArgs	= ()
    unless defined(%MIMEFiltersArgs);

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMEExcs is the associative array listing which data types
##  should be auto-excluded during parsing:
##
##	Keys => content-type, or base-type
##	Values => <should evaluate to a true expression>
##
##  For purposes of efficiency, content-types, or base-types, should
##  be specified in lowercase.  All key lookups are done in lowercase.

%MIMEExcs			= ()
    unless defined(%MIMEExcs);

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##  %MIMECharsetAliases is a mapping of charset names to charset names.
##  The MAILset_charset_aliases() routine should be used to set the
##  values of this hash.
##
##	Keys => charset name
##	Values => real charset name
##
%MIMECharsetAliases = ()
    unless defined(%MIMECharsetAliases);

##---------------------------------------------------------------------------
##	Text entity-related variables
##

##  Default character set if none specified.
$TextDefCharset = 'us-ascii'
    unless defined($TextDefCharset);

##  Destination character encoding for text entities.
$TextEncode = undef
    unless defined($TextEncode);
##  Text encoding function.
$TextEncoderFunc = undef
    unless defined($TextEncodingFunc);
##  Text encoding function source file.
$TextEncoderSrc = undef
    unless defined($TextEncodingSrc);

##  Prefilter function
$TextPreFilter  = undef
    unless defined($TextPreFilter);

##---------------------------------------------------------------------------
##	Variables holding functions for generating processed output
##	for MAILread_body().  The default functions generate HTML.
##	However, the variables can be set to functions that generate
##	a different type of output.
##
##	$FormatHeaderFunc has no default, and must be defined by
##	the calling program.
##
##  Function that returns a message when failing to process a part of a
##  a multipart message.  The content-type of the message is passed
##  as an argument.

$CantProcessPartFunc		= \&cantProcessPart
    unless(defined($CantProcessPartFunc));

##  Function that returns a message when a part is excluded via %MIMEExcs.

$ExcludedPartFunc	= \&excludedPart
    unless(defined($ExcludedPartFunc));

##  Function that returns a message when a part is unrecognized in a
##  multipart/alternative message.  I.e. No part could be processed.
##  No arguments are passed to function.

$UnrecognizedAltPartFunc	= \&unrecognizedAltPart
    unless(defined($UnrecognizedAltPartFunc));

##  Function that returns a string to go before any data generated generating
##  from processing an embedded message (message/rfc822 or message/news).
##  No arguments are passed to function.

$BeginEmbeddedMesgFunc		= \&beginEmbeddedMesg
    unless(defined($BeginEmbeddedMesgFunc));

##  Function that returns a string to go after any data generated generating
##  from processing an embedded message (message/rfc822 or message/news).
##  No arguments are passed to function.

$EndEmbeddedMesgFunc		= \&endEmbeddedMesg
    unless(defined($EndEmbeddedMesgFunc));

##  Function to return a string that is a result of the functions
##  processing of a message header.  The function is called for
##  embedded messages (message/rfc822 and message/news).  The
##  arguments to function are:
##
##   1.	Pointer to associative array representing message header
##	contents with the keys as field labels (in all lower-case)
##	and the values as field values of the labels.
##
##   2. Pointer to associative array mapping lower-case keys of
##	argument 1 to original case.
##
##  Prototype: $return_data = &function(*fields, *lower2orig_fields);

$FormatHeaderFunc		= undef
    unless(defined($FormatHeaderFunc));

###############################################################################
##	Public Routines							     ##
###############################################################################
##---------------------------------------------------------------------------##
##	MAILdecode_1522_str() decodes a string encoded in a format
##	specified by RFC 1522.  The decoded string is the return value.
##	If no MIMECharSetConverters is registered for a charset, then
##	the decoded data is returned "as-is".
##
##	Usage:
##
##	    $ret_data = &MAILdecode_1522_str($str, $dec_flag);
##
##	If $dec_flag is JUST_DECODE, $str will be decoded for only
##	the charsets specified as "-decode-".  If it is equal to
##	DECODE_ALL, all encoded data is decoded without any conversion.
##	If $dec_flag is TEXT_ENCODE, then all data will be converted
##	and encoded according to $readmail::TextEncode and
##	$readmail::TextEncoderFunc.
##
sub MAILdecode_1522_str {
    my $str      = shift;
    my $dec_flag = shift || 0;
    my $ret      = ('');
    my($charset,
       $encoding,
       $pos,
       $dec,
       $charcnv,
       $real_charset,
       $plaincnv,
       $plain_real_charset,
       $strtxt,
       $str_before);

    # Get text encoder
    my $encfunc  = undef;
    if ($dec_flag == TEXT_ENCODE) {
	$encfunc = load_textencoder();
	if (!defined($encfunc)) {
	    $encfunc = undef  unless defined($encfunc);
	    $dec_flag = 0;
	}
    }

    # Get plain converter
    ($plaincnv, $plain_real_charset) = MAILload_charset_converter('plain');
    $plain_real_charset = 'us-ascii'  if $plain_real_charset eq 'plain';

    # Decode string
    my $firsttime = 1;
    while ($str =~ /(=\?([^?]+)\?(.)\?([^?]*)\?=)/g) {
	# Grab components
	$pos = pos($str);
	($charset, $encoding, $strtxt) = (lc($2), lc($3), $4);
	$str_before = substr($str, 0, $pos-length($1));
	substr($str, 0, $pos) = '';
	pos($str) = 0;

	# Check encoding method and grab proper decoder
	if ($encoding eq 'b') {
	    $dec = &load_decoder('base64');
	} else {
	    $dec = &load_decoder('quoted-printable');
	}

	# Convert before (unencoded) text
	if ($firsttime || $str_before =~ /\S/) {
	    if (defined($encfunc)) {			# encoding
		&$encfunc(\$str_before, $plain_real_charset, $TextEncode);
		$ret .= $str_before;
	    } elsif ($dec_flag) {			# ignore if just decode
		$ret .= $str_before;
	    } elsif (defined(&$plaincnv)) {		# decode and convert
		$ret .= &$plaincnv($str_before, $plain_real_charset);
	    } else {					# ignore
		$ret .= $str_before;
	    }
	}
	$firsttime = 0;

	# Encoding text
	if (defined($encfunc)) {
	    $real_charset = $MIMECharsetAliases{$charset}
			    ? $MIMECharsetAliases{$charset} : $charset;
	    $strtxt =~ s/_/ /g;
	    $strtxt =  &$dec($strtxt);
	    &$encfunc(\$strtxt, $charset, $TextEncode);
	    $ret   .= $strtxt;

	# Regular conversion
	} else {
	    if ($dec_flag == DECODE_ALL) {
		$charcnv = '-decode-';
	    } else {
		($charcnv, $real_charset) =
		    MAILload_charset_converter($charset);
	    }
	    # Decode only
	    if ($charcnv eq '-decode-') {
		$strtxt =~ s/_/ /g;
		$ret .= &$dec($strtxt);

	    # Ignore if just decoding
	    } elsif ($dec_flag) {
		$ret .= "=?$charset?$encoding?$strtxt?=";

	    # Decode and convert
	    } elsif (defined(&$charcnv)) {
		$strtxt =~ s/_/ /g;
		$ret .= &$charcnv(&$dec($strtxt), $real_charset);

	    # Fallback is to ignore
	    } else {
		$ret .= "=?$charset?$encoding?$strtxt?=";
	    }
	}
    }

    # Convert left-over unencoded text
    if (defined($encfunc)) {			# encoding
	&$encfunc(\$str, $plain_real_charset, $TextEncode);
	$ret .= $str;
    } elsif ($dec_flag) {			# ignore if just decode
	$ret .= $str;
    } elsif (defined(&$plaincnv)) {		# decode and convert
	$ret .= &$plaincnv($str, $plain_real_charset);
    } else {					# ignore
	$ret .= $str;
    }

    $ret;
}

##---------------------------------------------------------------------------##
##	MAILread_body() parses a MIME message body.
##	Usage:
##	  ($data, @files) =
##	      MAILread_body($fields_hash_ref, $body_date_ref);
##
##	Parameters:
##	  $fields_hash_ref
##		      A reference to hash of message/part header
##		      fields.  Keys are field names in lowercase
##		      and values are array references containing the
##		      field values.  For example, to obtain the
##		      content-type, if defined, one would do:
##
##			$fields_hash_ref->{'content-type'}[0]
##
##		      Values for a fields are stored in arrays since
##		      duplication of fields are possible.  For example,
##		      the Received: header field is typically repeated
##		      multiple times.  For fields that only occur once,
##		      then array for the field will only contain one
##		      item.
##
##	  $body_data_ref
##		      Reference to body data.  It is okay for the
##		      filter to modify the text in-place.
##
##	Return:
##	  The first item in the return list is the text that should
##	  printed to the message page.	Any other items in the return
##	  list are derived filenames created.
##
##	See Also:
##	  MAILread_header(), MAILread_file_header()
##
sub MAILread_body {
    my($fields,		# Parsed header hash
       $body,		# Reference to raw body text
       $inaltArg) = @_; # Flag if in multipart/alternative

    my($type, $subtype, $boundary, $content, $ctype, $pos,
       $encoding, $decodefunc, $args, $part, $uribase);
    my(@parts) = ();
    my(@files) = ();
    my(@array) = ();
    my $ret = "";

    ## Get type/subtype
    if (defined($fields->{'content-type'})) {
	$content = $fields->{'content-type'}->[0];
    }
    $content = 'text/plain'  unless $content;
    ($ctype) = $content =~ m%^\s*([\w\-\./]+)%;	# Extract content-type
    $ctype =~ tr/A-Z/a-z/;			# Convert to lowercase
    if ($ctype =~ m%/%) {			# Extract base and sub types
	($type,$subtype) = split(/\//, $ctype, 2);
    } elsif ($ctype =~ /text/i) {
	$ctype = 'text/plain';
	$type = 'text';  $subtype = 'plain';
    } else {
	$type = $subtype = '';
    }
    $fields->{'x-mha-content-type'} = $ctype;

    ## Check if type is excluded
    if (MAILis_excluded($ctype)) {
	return (&$ExcludedPartFunc($ctype));
    }

    ## Get entity URI base
    if (defined($fields->{'content-base'}) &&
	    ($uribase = $fields->{'content-base'}[0])) {
	$uribase =~ s/['"\s]//g;
    } elsif (defined($fields->{'content-location'}) &&
		($uribase = $fields->{'content-location'}[0])) {
	$uribase =~ s/['"\s]//g;
    }
    $uribase =~ s|(.*/).*|$1|  if $uribase;

    ## Load content-type filter
    if ( (!defined($filter = &load_filter($ctype)) || !defined(&$filter)) &&
	 (!defined($filter = &load_filter("$type/*")) || !defined(&$filter)) &&
	 (!$inaltArg &&
	  (!defined($filter = &load_filter('*/*')) || !defined(&$filter)) &&
	     $ctype !~ m^\bmessage/(?:rfc822|news)\b^i &&
	     $type  !~ /\bmultipart\b/) ) {
	warn qq|Warning: Unrecognized content-type, "$ctype", |,
	     qq|assuming "application/octet-stream"\n|;
	$filter = &load_filter('application/octet-stream');
    }

    ## Check for filter arguments
    $args = get_filter_args($ctype, "$type/*", $filter);

    ## Check encoding
    if (defined($fields->{'content-transfer-encoding'})) {
	$encoding = lc $fields->{'content-transfer-encoding'}[0];
	$encoding =~ s/\s//g;
	$decodefunc = &load_decoder($encoding);
    } else {
	$encoding = undef;
	$decodefunc = undef;
    }
    my $decoded = 0;
    if (defined($decodefunc) && defined(&$decodefunc)) {
	$$body = &$decodefunc($$body);
	$decoded = 1;
    } elsif ($decodefunc =~ /as-is/i) {
	$decoded = 1;
    }

    ## Convert text encoding
    if ($type eq 'text') {
	my $charset = extract_charset($content, $subtype, $body);
	$fields->{'x-mha-charset'} = $charset;
	my $textfunc = load_textencoder();
	if (defined($textfunc)) {
	    $fields->{'x-mha-charset'} = $TextEncode
		if defined(&$textfunc($body, $charset, $TextEncode));
	}
	if (defined($TextPreFilter) && defined(&$TextPreFilter)) {
	    &$TextPreFilter($fields, $body);
	}
    } else {
	# define x-mha-charset in case text filter associated with
	# a non-text type
	$fields->{'x-mha-charset'} = $TextDefCharset;
    }

    ## A filter is defined for given content-type
    if ($filter && defined(&$filter)) {
	@array = &$filter($fields, $body, $decoded, $args);
	## Setup return variables
	$ret = shift @array;				# Return string
	push(@files, @array);				# Derived files

    ## No filter defined for given content-type
    } else {
	## If multipart, recursively process each part
	if ($type =~ /\bmultipart\b/i) {
	    local(%Cid) = ( )  unless scalar(caller) eq 'readmail';
	    my($isalt) = $subtype =~ /\balternative\b/i;

	    ## Get boundary
	    $boundary = "";
	    if ($content =~ m/\bboundary\s*=\s*"([^"]*)"/i) {
		$boundary = $1;
	    } else {
		($boundary) = $content =~ m/\bboundary\s*=\s*([^\s;]+)/i;
		$boundary =~ s/;$//;  # chop ';' if grabbed
	    }

	    ## If boundary defined, split body into parts
	    if ($boundary =~ /\S/) {
		my $found = 0;
		my $have_end = 0;
		my $start_pos = 0;
		substr($$body, 0, 0) = "\n";
		substr($boundary, 0, 0) = "\n--";
		my $blen = length($boundary);
		my $bchkstr;

		while (($pos = index($$body, $boundary, $start_pos)) > -1) {
		    # have to check for case when boundary is a substring
		    #	of another boundary, yuck!
		    $bchkstr = substr($$body, $pos+$blen, 2);
		    unless ($bchkstr =~ /\A\r?\n/ || $bchkstr =~ /\A--/) {
			# incomplete match, continue search
			$start_pos = $pos+$blen;
			next;
		    }
		    $found = 1;
		    push(@parts, substr($$body, 0, $pos));
		    $parts[$#parts] =~ s/^\r//;

		    # prune out part data just grabbed
		    substr($$body, 0, $pos+$blen) = "";

		    # check if hit end
		    if ($$body =~ /\A--/) {
			$have_end = 1;
			last;
		    }

		    # remove EOL at the beginning
		    $$body =~ s/\A\r?\n//;
		    $start_pos = 0;
		}
		if ($found) {
		    if (!$have_end) {
			warn qq/Warning: No end boundary delimiter found in /,
			     qq/message body\n/;
			push(@parts, $$body);
			$parts[$#parts] =~ s/^\r//;
			$$body = "";
		    } else {
			# discard front-matter
			shift(@parts);
		    }
		} else {
		    # no boundary separators in message!
		    warn qq/Warning: No boundary delimiters found in /,
			 qq/multipart body\n/;
		    if ($$body =~ m/\A\n[\w\-]+:\s/) {
			# remove \n added above if part looks like it has
			# headers.  we keep if it does not to avoid body
			# data being parsed as a header below.
			substr($$body, 0, 1) = "";
		    }
		    push(@parts, $$body);
		}

	    ## Else treat body as one part
	    } else {
		@parts = ($$body);
	    }

	    ## Process parts
	    my(@entity) = ();
	    my($cid, $href, $pctype);
	    my %alt_exc = ( );
	    my $have_alt_prefs = $isalt && scalar(@_MIMEAltPrefs);
	    my $partno = 0;
	    @parts = \(@parts);
	    while (defined($part = shift(@parts))) {
		$href = { };
		$partfields = $href->{'fields'} = (MAILread_header($part))[0];
		$href->{'body'} = $part;
		$href->{'filtered'} = 0;
		$partfields->{'x-mha-part-number'} = ++$partno;
		$pctype = extract_ctype(
		    $partfields->{'content-type'}, $ctype);

		## check alternative preferences
		if ($have_alt_prefs) {
		  next  if ($alt_exc{$pctype});
		  my $pos = $_MIMEAltPrefs{$pctype};
		  if (defined($pos)) {
		      for (++$pos; $pos <= $#_MIMEAltPrefs; ++$pos) {
			  $alt_exc{$_MIMEAltPrefs[$pos]} = 1;
		      }
		  }
		}

		## only add to %Cid if not excluded
		if (!&MAILis_excluded($pctype)) {
		    if ($isalt) {
			unshift(@entity, $href);
		    } else {
			push(@entity, $href);
		    }
		    $cid = $partfields->{'content-id'}[0] ||
			   $partfields->{'message-id'}[0];
		    if (defined($cid)) {
			$cid =~ s/[\s<>]//g;
			$Cid{"cid:$cid"} = $href  if $cid =~ /\S/;
		    }
		    $cid = undef;
		    if (defined($partfields->{'content-location'}) &&
			    ($cid = $partfields->{'content-location'}[0])) {
			my $partbase = $uribase;
			$cid =~ s/['"\s]//g;
			if (defined($partfields->{'content-base'})) {
			    $partbase = $partfields->{'content-base'}[0];
			}
			$cid = apply_base_url($partbase, $cid);
			if ($cid =~ /\S/ && !$Cid{$cid}) {
			    $Cid{$cid} = $href;
			}
		    }
		    if ($cid) {
			$partfields->{'content-location'} = [ $cid ];
		    } elsif (!defined($partfields->{'content-base'})) {
			$partfields->{'content-base'} = [ $uribase ];
		    }

		    $partfields->{'x-mha-parent-header'} = $fields;
		}
	    }

	    my($entity);
	    ENTITY: foreach $entity (@entity) {
		if ($entity->{'filtered'}) {
		    next ENTITY;
		}

		## If content-type not defined for part, then determine
		## content-type based upon multipart subtype.
		$partfields = $entity->{'fields'};
		if (!defined($partfields->{'content-type'})) {
		    $partfields->{'content-type'} =
		      [ ($subtype =~ /digest/) ?
			    'message/rfc822' : 'text/plain' ];
		}

		## Process part
		@array = MAILread_body(
			    $partfields,
			    $entity->{'body'},
			    $isalt);

		## Only use last filterable part in alternate
		if ($isalt) {
		    $ret = shift @array;
		    if ($ret) {
			push(@files, @array);
			$entity->{'filtered'} = 1;
			last ENTITY;
		    }
		} else {
		    if (!$array[0]) {
			$array[0] = &$CantProcessPartFunc(
					$partfields->{'content-type'}[0]);
		    }
		    $ret .= shift @array;
		}
		push(@files, @array);
		$entity->{'filtered'} = 1;
	    }

	    ## Check if multipart/alternative, and no success
	    if (!$ret && $isalt) {
		warn qq|Warning: No recognized part in multipart/alternative; |,
		     qq|will try to decode last part\n|;
		$entity = $entity[0];
		@array = &MAILread_body(
			    $entity->{'fields'},
			    $entity->{'body'});
		$ret = shift @array;
		if ($ret) {
		    push(@files, @array);
		} else {
		    $ret = &$UnrecognizedAltPartFunc();
		}
	    }

	    ## Aid garbage collection(?)
	    foreach $entity (@entity) {
		delete $entity->{'fields'}{'x-mha-parent-header'};
	    }

	## Else if message/rfc822 or message/news
	} elsif ($ctype =~ m^\bmessage/(?:rfc822|news)\b^i) {
	    $partfields = (MAILread_header($body))[0];

	    # propogate parent and part no to message/* header
	    $partfields->{'x-mha-parent-header'} =
		$fields->{'x-mha-parent-header'};
	    $partfields->{'x-mha-part-number'} =
		$fields->{'x-mha-part-number'};

	    $ret = &$BeginEmbeddedMesgFunc();
	    if ($FormatHeaderFunc && defined(&$FormatHeaderFunc)) {
		$ret .= &$FormatHeaderFunc($partfields);
	    } else {
		warn "Warning: readmail: No message header formatting ",
		     "function defined\n";
	    }
	    @array = MAILread_body($partfields, $body);
	    $ret .= shift @array ||
			&$CantProcessPartFunc(
			    $partfields->{'content-type'}[0] || 'text/plain');
	    $ret .= &$EndEmbeddedMesgFunc();

	    push(@files, @array);
	    delete $partfields->{'x-mha-parent-header'};

	## Else cannot handle type
	} else {
	    $ret = '';
	}
    }

    ($ret, @files);
}

##---------------------------------------------------------------------------##
##	MAILread_header reads (and strips) a mail message header from the
##	variable $mesg.  $mesg is a reference to the mail message in
##	a string.
##
##	$fields is a reference to a hash to put field values indexed by
##	field labels that have been converted to all lowercase.
##	Field values are array references to the values
##	for each field.
##
##	($fields_hash_ref, $header_txt) = MAILread_header($mesg_data);
##
sub MAILread_header {
    my $mesg   = shift;

    my $fields = { };
    my $label = '';
    my $header = '';
    my($value, $tmp, $pos);

    my $encfunc = load_textencoder();

    ## Read a line at a time.
    for ($pos=0; $pos >= 0; ) {
	$pos = index($$mesg, "\n");
	if ($pos >= 0) {
	    $tmp = substr($$mesg, 0, $pos+1);
	    substr($$mesg, 0, $pos+1) = "";
	    last  if $tmp =~ /^\r?$/;	# Done if blank line

	    $header .= $tmp;
	    chop $tmp;			# Chop newline
	    $tmp =~ s/\r$//;		# Delete <CR> characters
	} else {
	    $tmp = $$mesg;
	    $header .= $tmp;
	}

	## Decode text if requested
	if (defined($encfunc)) {
	    $tmp = &MAILdecode_1522_str($tmp,TEXT_ENCODE);
	} elsif ($DecodeHeader) {
	    $tmp = &MAILdecode_1522_str($tmp,JUST_DECODE);
	}

	## Check for continuation of a field
	if ($tmp =~ /^\s/) {
	    $fields->{$label}[-1] .= $tmp  if $label;
	    next;
	}

	## Separate head from field text
	if ($tmp =~ /^([^:\s]+):\s*([\s\S]*)$/) {
	    ($label, $value) = (lc($1), $2);
	    if ($fields->{$label}) {
		push(@{$fields->{$label}}, $value);
	    } else {
		$fields->{$label} = [ $value ];
	    }
	}
    }
    ($fields, $header);
}

##---------------------------------------------------------------------------##
##	MAILread_file_header reads (and strips) a mail message header
##	from the filehandle $handle.  The routine behaves in the
##	same manner as MAILread_header;
##
##	($fields_hash, $header_text) = MAILread_file_header($filehandle);
##	
sub MAILread_file_header {
    my $handle = shift;
    my $encode = shift;

    my $encfunc = load_textencoder();

    my $label  = '';
    my $header = '';
    my $fields = { };
    local $/   = "\n";

    my($value, $tmp);
# CPU2006
    #while (($tmp = <$handle>) !~ /^[\r]?$/) {
    while (($tmp = shift(@$handle)) !~ /^[\r]?$/) {
	## Save raw text
	$header .= $tmp;

	## Delete eol characters
	$tmp =~ s/[\r\n]//g;

	## Decode text if requested
	if (defined($encfunc)) {
	    $tmp = &MAILdecode_1522_str($tmp,TEXT_ENCODE);
	} elsif ($DecodeHeader) {
	    $tmp = &MAILdecode_1522_str($tmp,JUST_DECODE);
	}

	## Check for continuation of a field
	if ($tmp =~ /^\s/) {
	    $fields->{$label}[-1] .= $tmp  if $label;
	    next;
	}

	## Separate head from field text
	if ($tmp =~ /^([^:\s]+):\s*([\s\S]*)$/) {
	    ($label, $value) = (lc($1), $2);
	    if (defined($fields->{$label})) {
		push(@{$fields->{$label}}, $value);
	    } else {
		$fields->{$label} = [ $value ];
	    }
	}
    }
    ($fields, $header);
}

##---------------------------------------------------------------------------##
##	MAILis_excluded() checks if specified content-type has been
##	specified to be excluded.
##
sub MAILis_excluded {
    my $ctype = lc($_[0]) || 'text/plain';
    if ($MIMEExcs{$ctype}) {
	return 1;
    }
    if ($ctype =~ s/\/x-/\//) {
	return 1  if $MIMEExcs{$ctype};
    }
    if ($ctype =~ m|([^/]+)/|) {
	return $MIMEExcs{$1};
    }
    0;
}

##---------------------------------------------------------------------------##
##	MAILhead_get_disposition gets the content disposition and
##	filename from $hfields, $hfields is a hash produced by the
##	MAILread_header and MAILread_file_header routines.
##
sub MAILhead_get_disposition {
    my $hfields = shift;
    my $do_html = shift;

    my($disp, $filename, $raw) = ('', '', '');
    my $html_name = undef;
    local($_);

    if (defined($hfields->{'content-disposition'}) &&
	    ($_ = $hfields->{'content-disposition'}->[0])) {
	($disp)	= /^\s*([^\s;]+)/;
	if (/filename="([^"]+)"/i) {
	    $raw = $1;
	} elsif (/filename=(\S+)/i) {
	    ($raw = $1) =~ s/;\s*$//g;
	}
    }
    if (!$raw && defined($_ = $hfields->{'content-type'}[0])) {
	if (/name="([^"]+)"/i) {
	    $raw = $1;
	} elsif (/name=(\S+)/i) {
	    ($raw = $1) =~ s/;\s*$//g;
	}
    }
    $filename = MAILdecode_1522_str($raw, DECODE_ALL);
    $filename =~ s%.*[/\\:]%%;	# Remove any path component
    $filename =~ s/^\s+//;	# Remove leading whitespace
    $filename =~ s/\s+$//;	# Remove trailing whitespace
    $filename =~ tr/\0-\40\t\n\r?:*"'<>|\177-\377/_/;
				# Remove questionable/invalid characters

    # Only provide HTML display version if requested
    $html_name = MAILdecode_1522_str($raw)  if $do_html;

    ($disp, $filename, $raw, $html_name);
}

##---------------------------------------------------------------------------##
##	MAILparse_parameter_str(): parses a parameter/value string.
##	Support for RFC 2184 extensions exists.  The $hasmain flag tells
##	the method if there is an intial main value for the sting.  For
##      example:
##
##          text/plain; charset=us-ascii
##      ----^^^^^^^^^^
##
##      The "text/plain" part is not a parameter/value pair, but having
##      an initial value is common among some header fields that can have
##      parameter/value pairs (egs: Content-Type, Content-Disposition).
##
##	Return Value:
##	    Reference to a hash.  Each key is the attribute name.
##	    The special key, 'x-main', is the main value if the
##	    $hasmain flag is set.
##
##	    Each hash value is a hash reference with three keys:
##	    'charset', 'lang', 'value'.  'charset' and 'lang' may be
##	    undef if character set or language information is not
##	    specified.
##
##	Example Usage:
##
##	    $content_type_field = 'text/plain; charset=us-ascii';
##	    $parms = MAILparse_parameter_str($content_type_field, 1);
##	    $ctype = $parms->{'x-main'};
##	    $mesg_body_charset = $parms->{'charset'}{'value'};
##
sub MAILparse_parameter_str {
    my $str     = shift;        # Input string
    my $hasmain = shift;        # Flag if there is a main value to extract

    require MHonArc::RFC822;

    my $parm	= { };
    my @toks    = MHonArc::RFC822::uncomment($str);
    my($tok, $name, $value, $charset, $lang, $part);

    $parm->{'x-main'} = shift @toks  if $hasmain;

    ## Loop thru token list
    while ($tok = shift @toks) {
        next if $tok eq ";";
        ($name, $value) = split(/=/, $tok, 2);
        ## Check if charset/lang specified
        if ($name =~ s/\*$//) {
            if ($value =~ s/^([^']*)'([^']*)'//) {
                ($charset, $lang) = ($1, $2);
            } else {
                ($charset, $lang) = (undef, undef);
            }
        }
        ## Check if parameter is only part
        if ($name =~ s/\*(\d+)$//) {
            $part = $1 - 1;     # we start at 0 internally
        } else {
            $part = 0;
        }
        ## Set values for parameter
        $name = lc $name;
        $parm->{$name} = {
            'charset'	=> $charset,
            'lang'   	=> $lang,
        };
        ## Check if value is next token
        if ($value eq "") {
            ## If value next token, than it must be quoted
            $value = shift @toks;
            $value =~ s/^"//;  $value =~ s/"$//;  $value =~ s/\\//g;
        }
        $parm->{$name}{'vlist'}[$part] = $value;
    }

    ## Now we loop thru each parameter and define the final values from
    ## the parts
    foreach $name (keys %$parm) {
	next  if $name eq 'x-main';
        $parm->{$name}{'value'} = join("", @{$parm->{$name}{'vlist'}});
    }

    $parm;
}

##---------------------------------------------------------------------------##
##	MAILset_alternative_prefs() is used to set content-type
##	preferences for multipart/alternative entities.  The list
##	specified will supercede the prefered format as denoted by
##	the ording of parts in the entity.
##
##	A content-type listed earlier in the array will be prefered
##	over one later.  For example:
##
##	  MAILset_alternative_prefs('text/plain', 'text/html');
##
##	States that if a multipart/alternative entity contains a
##	text/plain part and a text/html part, the text/plain part will
##	be prefered over the text/html part.
##
sub MAILset_alternative_prefs {
    @_MIMEAltPrefs = map { lc } @_;
    %_MIMEAltPrefs = ();
    my $i = 0;
    my $ctype;
    foreach $ctype (@_MIMEAltPrefs) {
	$_MIMEAltPrefs{$ctype} = $i++;
    }
}

##---------------------------------------------------------------------------##
##	MAILset_charset_aliases() is used to define name aliases for
##	charset names.
##
##	Example usage:
##	  MAILset_charset_aliases( {
##	    'iso-8859-1' =>  [ 'latin1', 'iso_8859_1', '8859-1' ],
##	    'iso-8859-15' => [ 'latin9', 'iso_8859_15', '8859-15' ],
##	  }, $override );
##	  
sub MAILset_charset_aliases {
    my $map = shift;
    my $override = shift;

    %MIMECharsetAliases = ()  if $override;
    my($charset, $aliases, $alias);
    while (($charset, $aliases) = each(%$map)) {
	$charset = lc $charset;
	foreach $alias (@$aliases) {
	    $MIMECharsetAliases{lc $alias} = $charset;
	}
    }
}

##---------------------------------------------------------------------------##
##	MAILload_charset_converter() loads the charset converter function
##	associated with given charset name.
##
##	Example usage:
##	  ($func, $real_charset) = MAILload_charset_converter($charset);
##	
##	$func is the reference to the converter function, which may be
##	undef.  $real_charset is the real charset name that should be
##	used when invoking the function.
##
sub MAILload_charset_converter {
    my $charset = lc shift;
    $charset = $MIMECharsetAliases{$charset}  if $MIMECharsetAliases{$charset};
    my $func = load_charset($charset);
    if (!defined($func) || !defined(&$func)) {
	$func = load_charset('default');
    }
    ($func, $charset);
}

###############################################################################
##	Private Routines
###############################################################################

##---------------------------------------------------------------------------##
##	Default function for unable to process a part of a multipart
##	message.
##
sub cantProcessPart {
    my($ctype) = $_[0];
    warn "Warning: Could not process part with given Content-Type: ",
	 "$ctype\n";
    "<br><tt>&lt;&lt;&lt; $ctype: Unrecognized &gt;&gt;&gt;</tt><br>\n";
}
##---------------------------------------------------------------------------##
##	Default function returning message for content-types excluded.
##
sub excludedPart {
    my($ctype) = $_[0];
    "<br><tt>&lt;&lt;&lt; $ctype: EXCLUDED &gt;&gt;&gt;</tt><br>\n";
}
##---------------------------------------------------------------------------##
##	Default function for unrecognizeable part in multipart/alternative.
##
sub unrecognizedAltPart {
    warn "Warning: No recognizable part in multipart/alternative\n";
    "<br><tt>&lt;&lt;&lt; multipart/alternative: ".
    "No recognizable part &gt;&gt;&gt;</tt><br>\n";
}
##---------------------------------------------------------------------------##
##	Default function for beggining of embedded message
##	(ie message/rfc822 or message/news).
##
sub beginEmbeddedMesg {
qq|<blockquote><small>---&nbsp;<i>Begin&nbsp;Message</i>&nbsp;---</small>\n|;
}
##---------------------------------------------------------------------------##
##	Default function for end of embedded message
##	(ie message/rfc822 or message/news).
##
sub endEmbeddedMesg {
qq|<br><small>---&nbsp;<i>End Message</i>&nbsp;---</small></blockquote>\n|;
}

##---------------------------------------------------------------------------##

sub load_charset {
    require $MIMECharSetConvertersSrc{$_[0]}
	if defined($MIMECharSetConvertersSrc{$_[0]}) &&
	   $MIMECharSetConvertersSrc{$_[0]};
    $MIMECharSetConverters{$_[0]};
}
sub load_decoder {
    my $enc = lc shift; $enc =~ s/\s//;
    require $MIMEDecodersSrc{$enc}
	if defined($MIMEDecodersSrc{$enc}) &&
	   $MIMEDecodersSrc{$enc};
    $MIMEDecoders{$enc};
}
sub load_filter {
    require $MIMEFiltersSrc{$_[0]}
	if defined($MIMEFiltersSrc{$_[0]}) &&
	   $MIMEFiltersSrc{$_[0]};
    $MIMEFilters{$_[0]};
}
sub get_filter_args {
    my $args	= '';
    my $s;
    foreach $s (@_) {
	next  unless defined $s;
	$args = $MIMEFiltersArgs{$s};
	last  if defined($args) && ($args ne '');
    }
    $args;
}
sub load_textencoder {
    return undef  unless $TextEncode;
    TRY: {
	if (!defined($TextEncoderFunc)) {
	    last TRY;
	}
	if (defined(&$TextEncoderFunc)) {
	    return $TextEncoderFunc;
	}
	if (!defined($TextEncoderSrc)) {
	    last TRY;
	}
	require $TextEncoderSrc;
	if (defined(&$TextEncoderFunc)) {
	    return $TextEncoderFunc;
	}
    }
    warn qq/Warning: Unable to load text encode for "$TextEncode"\n/;
    $TextEncode = undef;
    $TextEncoderFunc = undef;
    $TextEncoderSrc = undef;
}

##---------------------------------------------------------------------------##
##	extract_ctype() extracts the content-type specification from
##	the beginning of given string.
##
sub extract_ctype {
    if (!defined($_[0]) ||
	  (ref($_[0]) && ($_[0][0] !~ /\S/)) ||
	  ($_[0] !~ /\S/)) {
	return 'message/rfc822'
	    if (defined($_[1]) && ($_[1] eq 'multipart/digest'));
	return 'text/plain';
    }
    if (ref($_[0])) {
	$_[0][0] =~ m|^\s*([\w\-\./]+)|;
	return lc($1);
    }
    $_[0] =~ m|^\s*([\w\-\./]+)|;
    lc($1);
}

##---------------------------------------------------------------------------##

sub apply_base_url {
    my($b, $u) = @_;
    return $u  if !defined($b) || $b !~ /\S/;

    my($ret);
    $u =~ s/^\s+//;
    if ($u =~ m%^$Url%o || $u =~ m/^#/) {
	## Absolute URL or scroll link; do nothing
        $ret = $u;
    } else {
	## Relative URL
	if ($u =~ /^\./) {
	    ## "./---" or "../---": Need to remove and adjust base
	    ## accordingly.
	    $b =~ s/\/$//;
	    my @a = split(/\//, $b);
	    my $cnt = 0;
	    while ( $cnt <= scalar(@a) &&
		    $u =~ s|^(\.{1,2})/|| ) { ++$cnt  if length($1) == 2; }
	    splice(@a, -$cnt)  if $cnt > 0;
	    $b = join('/', @a, "");

	} elsif ($u =~ m%^/%) {
	    ## "/---": Just use hostname:port of base.
	    $b =~ s%^(${Url}[^/]*)/.*%$1%o;
	}
        $ret = $b . $u;
    }
    $ret;
}
##---------------------------------------------------------------------------##

sub extract_charset {
    my $content = shift;  # Content-type string of entity
    my $subtype = shift;  # Text sub-type
    my $body    = shift;  # Reference to entity text
    my $charset = $TextDefCharset;

    if ($content =~ /\bcharset\s*=\s*([^\s;]+)/i) {
	$charset =  lc $1;
	$charset =~ s/['";\s]//g;
    }

    # If HTML, check <meta http-equiv=content-type> tag since it
    # can be different than what is specified in the entity header.
    if (($subtype eq 'html' || $subtype eq 'x-html') &&
	($body =~ m/(<meta\s+http-equiv\s*=\s*['"]?
		     content-type\b[^>]*>)/xi)) {
	my $meta = $1;
	if ($meta =~ m/\bcharset\s*=\s*['"]?([\w\.\-]+)/i) {
	    $charset = lc $1;
	}
    }
    $charset = $MIMECharsetAliases{$charset}
	if $MIMECharsetAliases{$charset};

    # If us-ascii, but 8-bit chars in body, we change to iso-8859-1
    if ($charset eq 'us-ascii') {
	$charset = 'iso-8859-1'  if $$body =~ /[\x80-\xFF]/;
    }
    $charset;
}

##---------------------------------------------------------------------------##
##	gen_full_part_number creates a full part number of an entity
##	from the given entity header.
##
sub gen_full_part_number {
    my $fields = shift;
    my @number = ( );
    while (defined($fields->{'x-mha-parent-header'})) {
	unshift(@number, ($fields->{'x-mha-part-number'} || '1'));
	$fields = $fields->{'x-mha-parent-header'};
    }
    if (!scalar(@number)) {
	return $fields->{'x-mha-part-number'} || '1';
    }
    join('.', @number);
}

##---------------------------------------------------------------------------##

sub dump_header {
    my $fh	= shift;
    my $fields	= shift;
    my($key, $a, $value);
    foreach $key (sort keys %$fields) {
	$a = $fields->{$key};
	if (ref($a)) {
	    foreach $value (@$a) {
		print $fh "$key: $value\n";
	    }
	} else {
	    print $fh "$key: $a\n";
	}
    }
}

##---------------------------------------------------------------------------##
1; # for require
