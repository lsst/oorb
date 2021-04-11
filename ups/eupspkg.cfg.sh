# EupsPkg config file. Sourced by 'eupspkg'

_ensure_exists()
{
	hash "$1" 2>/dev/null || die "need '$1' to install this product. please install it and try again."
}

prep()
{
	default_prep
}

config()
{
	./configure conda opt --with-pyoorb
}

build()
{
	PKGROOT="$PWD"

	# Passing MAKEFLAGS can lead to odd errors in the gfortran compiler
	( unset MAKEFLAGS )

	# build OOrb and Python bindings
	( make )

	# update JPL Ephemeris files and make 405 and 430 ephemeris files
        (
            export EPH_TYPE=405
	    make ephem
        )
        (
            export EPH_TYPE=430
            make ephem
        )

	# run tests
	(
	    make test
	)

}

install()
{
	clean_old_install
	
	make PREFIX="$PREFIX" install

	install_ups
}
