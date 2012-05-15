%global __find_provides ''
%global __perl_provides ''
%global __perl_requires ''

Name:           rock-runtime-perl514-local-lib
Version:        1.008004
Release:        1%{?dist}
Summary:        A tool to manage Perl 5.14 dependencies

Group:          Development/Languages
License:        GPL+ or Artistic
URL:            http://search.cpan.org/~apeiron/local-lib
Source0:        http://search.cpan.org/CPAN/authors/id/A/AP/APEIRON/local-lib-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildRequires:  rock-runtime-perl514-core-rpmbuild
Requires:       rock-runtime-perl514-core

%description
Create and use a local-lib for Perl modules with PERL5LIB.

%prep
%setup -q -n local-lib-%{version}

%build
export LD_LIBRARY_PATH="%{perl514_rootdir}%{_prefix}/lib:$LD_LIBRARY_PATH"
export PATH="%{perl514_rootdir}%{_bindir}:$PATH"

perl Makefile.PL

%install
rm -rf %{buildroot}

export LD_LIBRARY_PATH="%{perl514_rootdir}%{_prefix}/lib:$LD_LIBRARY_PATH"
export PATH="%{perl514_rootdir}%{_bindir}:$PATH"

make install PERL_INSTALL_ROOT=%{buildroot}

# probably a way to do this via the above command
mv %{buildroot}%{perl514_rootdir}%{_prefix}/lib/site_perl/5.14.2 \
   %{buildroot}%{perl514_rootdir}%{_prefix}/lib/perl5
rm -fr %{buildroot}%{perl514_rootdir}%{_prefix}/lib/site_perl

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc Changes
%{perl514_rootdir}%{_prefix}/lib/perl5
%{perl514_rootdir}%{_mandir}/man3/*.3pm

%changelog
* Mon May 14 2012 Silas Sewell <silas@sewell.org> - 1.008004-1
- Initial build
