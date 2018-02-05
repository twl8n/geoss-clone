Summary: Web Application for the storage and analysis of Gene Chip information
Name: geoss
Version: 2.6.1
Release: 1
License: GPL
Group: Applications
Source: http://sourceforge.net/project/showfiles.php?group_id=71073/%{name}-%{version}.tar.gz
URL: http://genes.med.virginia.edu/
Distribution: University of Virginia
Vendor: University of Virginia
Packager: Teela James <teela-virginia@peff.net>
Buildroot: %{/home/tdj4m/buildroot}/%{name}-root
Requires: postgresql >= 7.3.4, httpd >= 1.3, R >= 1.8.1-2
Provides: perl(geoss_sql_lib), perl(geoss_session_lib)

%description
GEOSS is a secure web-based application for storing and analyzing 
gene chip information.  The product currently supports MAS5 data for 
affymetrics chips. 

%prep
%setup -q

%build
make build
cd site/webdoc && make build

%install
install -d $RPM_BUILD_ROOT/etc/cron.daily
install bin/geoss_rm_inactive_users $RPM_BUILD_ROOT/etc/cron.daily/geoss_rm_inactive_users
make ROOT="$RPM_BUILD_ROOT" directories
make ROOT="$RPM_BUILD_ROOT" install
cd site/webdoc && make ROOT="$RPM_BUILD_ROOT" install

%files
%defattr(-,root,root)
/var/www/html/geoss/database
/var/www/html/geoss/site
/usr/lib/geoss
/usr/bin
/etc/cron.daily/geoss_rm_inactive_users
%defattr(-,root,apache)
/var/lib/geoss
/var/www/html/geoss/site/public_files
/var/www/html/geoss/site/logos
/var/www/html/geoss/site/icons

%clean
rm -rf $RPM_BUILD_ROOT

%changelog
