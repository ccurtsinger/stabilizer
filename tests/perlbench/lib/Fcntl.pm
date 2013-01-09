package Fcntl;

# Faked-up fcntl.h defines for 400.perlbench

our($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

require Exporter;
@ISA = qw(Exporter);
$VERSION = "1.00";
@EXPORT =
  qw(
	FD_CLOEXEC
	F_ALLOCSP
	F_ALLOCSP64
	F_COMPAT
	F_DUP2FD
	F_DUPFD
	F_EXLCK
	F_FREESP
	F_FREESP64
	F_FSYNC
	F_FSYNC64
	F_GETFD
	F_GETFL
	F_GETLK
	F_GETLK64
	F_GETOWN
	F_NODNY
	F_POSIX
	F_RDACC
	F_RDDNY
	F_RDLCK
	F_RWACC
	F_RWDNY
	F_SETFD
	F_SETFL
	F_SETLK
	F_SETLK64
	F_SETLKW
	F_SETLKW64
	F_SETOWN
	F_SHARE
	F_SHLCK
	F_UNLCK
	F_UNSHARE
	F_WRACC
	F_WRDNY
	F_WRLCK
	O_ACCMODE
	O_ALIAS
	O_APPEND
	O_ASYNC
	O_BINARY
	O_CREAT
	O_DEFER
	O_DIRECT
	O_DIRECTORY
	O_DSYNC
	O_EXCL
	O_EXLOCK
	O_LARGEFILE
	O_NDELAY
	O_NOCTTY
	O_NOFOLLOW
	O_NOINHERIT
	O_NONBLOCK
	O_RANDOM
	O_RAW
	O_RDONLY
	O_RDWR
	O_RSRC
	O_RSYNC
	O_SEQUENTIAL
	O_SHLOCK
	O_SYNC
	O_TEMPORARY
	O_TEXT
	O_TRUNC
	O_WRONLY
	SEEK_SET
	SEEK_CUR
	SEEK_END
     );

# Other items we are prepared to export if requested
@EXPORT_OK = qw(
	FAPPEND
	FASYNC
	FCREAT
	FDEFER
	FDSYNC
	FEXCL
	FLARGEFILE
	FNDELAY
	FNONBLOCK
	FRSYNC
	FSYNC
	FTRUNC
	LOCK_EX
	LOCK_NB
	LOCK_SH
	LOCK_UN
	S_ISUID S_ISGID S_ISVTX S_ISTXT
	_S_IFMT S_IFREG S_IFDIR S_IFLNK
	S_IFSOCK S_IFBLK S_IFCHR S_IFIFO S_IFWHT S_ENFMT
	S_IRUSR S_IWUSR S_IXUSR S_IRWXU
	S_IRGRP S_IWGRP S_IXGRP S_IRWXG
	S_IROTH S_IWOTH S_IXOTH S_IRWXO
	S_IREAD S_IWRITE S_IEXEC
	&S_ISREG &S_ISDIR &S_ISLNK &S_ISSOCK &S_ISBLK &S_ISCHR &S_ISFIFO
	&S_ISWHT &S_ISENFMT &S_IFMT &S_IMODE
);
# Named groups of exports
%EXPORT_TAGS = (
    'flock'   => [qw(LOCK_SH LOCK_EX LOCK_NB LOCK_UN)],
    'Fcompat' => [qw(FAPPEND FASYNC FCREAT FDEFER FDSYNC FEXCL FLARGEFILE
		     FNDELAY FNONBLOCK FRSYNC FSYNC FTRUNC)],
    'seek'    => [qw(SEEK_SET SEEK_CUR SEEK_END)],
    'mode'    => [qw(S_ISUID S_ISGID S_ISVTX S_ISTXT
		     _S_IFMT S_IFREG S_IFDIR S_IFLNK
		     S_IFSOCK S_IFBLK S_IFCHR S_IFIFO S_IFWHT S_ENFMT
		     S_IRUSR S_IWUSR S_IXUSR S_IRWXU
		     S_IRGRP S_IWGRP S_IXGRP S_IRWXG
		     S_IROTH S_IWOTH S_IXOTH S_IRWXO
		     S_IREAD S_IWRITE S_IEXEC
		     S_ISREG S_ISDIR S_ISLNK S_ISSOCK
		     S_ISBLK S_ISCHR S_ISFIFO
		     S_ISWHT S_ISENFMT		
		     S_IFMT S_IMODE
                  )],
);

sub S_IFMT  { @_ ? ( $_[0] & _S_IFMT() ) : _S_IFMT()  };
sub S_IMODE { $_[0] & 07777 };

sub S_ISREG    { ( $_[0] & _S_IFMT() ) == S_IFREG()   };
sub S_ISDIR    { ( $_[0] & _S_IFMT() ) == S_IFDIR()   };
sub S_ISLNK    { ( $_[0] & _S_IFMT() ) == S_IFLNK()   };
sub S_ISSOCK   { ( $_[0] & _S_IFMT() ) == S_IFSOCK()  };
sub S_ISBLK    { ( $_[0] & _S_IFMT() ) == S_IFBLK()   };
sub S_ISCHR    { ( $_[0] & _S_IFMT() ) == S_IFCHR()   };
sub S_ISFIFO   { ( $_[0] & _S_IFMT() ) == S_IFIFO()   };
sub S_ISWHT    { ( $_[0] & _S_IFMT() ) == S_IFWHT()   };
sub S_ISENFMT  { ( $_[0] & _S_IFMT() ) == S_IFENFMT() };

# These are just garbage values
*SEEK_SET = sub { 0 };
*SEEK_CUR = sub { 1 };
*SEEK_END = sub { 2 };

*O_APPEND = sub { 1 };
*O_BINARY = sub { 2 };
*O_CREAT = sub { 4 };
*O_EXCL = sub { 8 };
*O_EXLOCK = sub { 16 };
*O_LARGEFILE = sub { 32 };
*O_NDELAY = sub { 64 };
*O_NONBLOCK = sub { 128 };
*O_RDONLY = sub { 256 };
*O_RDWR = sub { 512 };
*O_SEQUENTIAL = sub { 1024 };
*O_SHLOCK = sub { 2048 };
*O_SYNC = sub { 4096 };
*O_TEMPORARY = sub { 8192 };
*O_TEXT = sub { 16384 };
*O_TRUNC = sub { 32768 };
*O_WRONLY = sub { 65536 };
*O_RANDOM = sub { 131072 };
*O_RAW = sub { 262144 };
*O_RSRC = sub { 524288 };
*O_RSYNC = sub { 1048576 };
*O_ACCMODE = sub { 2097152 };
*O_ALIAS = sub { 4194304 };
*O_ASYNC = sub { 8388608 };
*O_DEFER = sub { 16777216 };
*O_DIRECT = sub { 33554432 };
*O_DIRECTORY = sub { 67108864 };
*O_DSYNC = sub { 134217728 };
*O_NOCTTY = sub { 268435456 };
*O_NOFOLLOW = sub { 536870912 };
*O_NOINHERIT = sub { 1073741824 };

*S_ISUID = sub { 1 };
*S_ISGID = sub { 2 };
*S_ISVTX = sub { 4 };
*S_ISTXT = sub { 8 };
*_S_IFMT = sub { 16 };
*S_IFREG = sub { 32 };
*S_IFDIR = sub { 64 };
*S_IFLNK = sub { 128 };
*S_IFSOCK = sub { 256 };
*S_IFBLK = sub { 512 };
*S_IFCHR = sub { 1024 };
*S_IFIFO = sub { 2048 };
*S_IFWHT = sub { 4096 };
*S_ENFMT = sub { 8192 };
*S_IRUSR = sub { 16384 };
*S_IWUSR = sub { 32768 };
*S_IXUSR = sub { 65536 };
*S_IRWXU = sub { 131072 };
*S_IRGRP = sub { 262144 };
*S_IWGRP = sub { 524288 };
*S_IXGRP = sub { 1048576 };
*S_IRWXG = sub { 2097152 };
*S_IROTH = sub { 4194304 };
*S_IWOTH = sub { 8388608 };
*S_IXOTH = sub { 16777216 };
*S_IRWXO = sub { 33554432 };
*S_IREAD = sub { 67108864 };
*S_IWRITE = sub { 134217728 };
*S_IEXEC = sub { 268435456 };

*LOCK_EX = sub { 1 };
*LOCK_NB = sub { 2 };
*LOCK_SH = sub { 4 };
*LOCK_UN = sub { 8 };

*F_EXLCK = sub { 1 };
*F_FSYNC = sub { 2 };
*F_GETFD = sub { 4 };
*F_GETFL = sub { 8 };
*F_GETLK = sub { 16 };
*F_POSIX = sub { 32 };
*F_SETFL = sub { 64 };
*F_SETLK = sub { 128 };
*F_SETLKW = sub { 256 };
*F_SETOWN = sub { 512 };
*F_SHLCK = sub { 1024 };
*F_UNLCK = sub { 2048 };
*FD_CLOEXEC = sub { 4096 };
*F_ALLOCSP = sub { 8192 };
*F_ALLOCSP64 = sub { 16384 };
*F_COMPAT = sub { 32768 };
*F_DUP2FD = sub { 65536 };
*F_DUPFD = sub { 131072 };
*F_FREESP = sub { 262144 };
*F_FREESP64 = sub { 524288 };
*F_FSYNC64 = sub { 1048576 };
*F_GETLK64 = sub { 2097152 };
*F_GETOWN = sub { 4194304 };
*F_NODNY = sub { 8388608 };
*F_RDACC = sub { 16777216 };
*F_RDDNY = sub { 33554432 };
*F_RDLCK = sub { 67108864 };
*F_RWACC = sub { 134217728 };
*F_RWDNY = sub { 268435456 };
*F_SETFD = sub { 536870912 };
*F_SETLK64 = sub { 1073741824 };
*F_SETLKW64 = sub { 2147483648 };
*F_SHARE = sub { 0 };
*F_UNSHARE = sub { 0 };
*F_WRACC = sub { 0 };
*F_WRDNY = sub { 0 };
*F_WRLCK = sub { 0 };

*FAPPEND = sub { 1 };
*FASYNC = sub { 2 };
*FCREAT = sub { 4 };
*FDEFER = sub { 8 };
*FDSYNC = sub { 16 };
*FEXCL = sub { 32 };
*FLARGEFILE = sub { 64 };
*FNDELAY = sub { 128 };
*FNONBLOCK = sub { 256 };
*FRSYNC = sub { 512 };
*FSYNC = sub { 1024 };
*FTRUNC = sub { 2048 };

1;

