%define  debug_package %{nil}

%global sname neondatabase-neon 
%global pgrel 14 
%global rpm_release 1
%global neoninstdir /opt
%global neonuser neonuser
%global version 1.0.0
%global git_version local

Summary:        Statistics collector for PostgreSQL
Name:           %{sname}-pg%{pgrel}
Version:        %{version} 
Release:        %{rpm_release}%{?dist}
License:        PostgreSQL
Source0:        neondatabase-neon-pg%{pgrel}-%{version}.tar.gz
URL:            https://github.com/neondatabase/neon
#BuildRequires:  postgresql%{pgrel}-devel
BuildRequires:  postgresql%{pgrel}-client
#Requires:       postgresql%{pgrel}-server
Requires:       nodejs
Provides:	neondatabase-neon-pg%{pgrel}
Conflicts:      neondatabase-neon-pg%{pgrel}
Obsoletes:      neondatabase-neon-pg%{pgrel}
Epoch:          1
Packager:       Percona Development Team <https://jira.percona.com>
Vendor:         Percona, Inc

%description
Neon is a serverless open-source alternative to AWS Aurora Postgres.
.
It separates storage and compute and substitutes the PostgreSQL storage 
layer by redistributing data across a cluster of nodes.

%prep
%setup -q -n neondatabase-neon-pg%{pgrel}-%{version}


%build
export GIT_VERSION=%{git_version}
export BUILD_TYPE=release
sed -i 's/UNAME_S := .*/UNAME_S := %{neonuser}/' Makefile
%{__make}


%install
sed -i 's/env python$/env python3/' scripts/ingest_perf_test_result.py
sed -i 's/env python$/env python3/' scripts/ingest_regress_test_result.py
sed -i 's/env python$/env python3/' vendor/postgres-v14/src/test/locale/sort-test.py
sed -i 's/env python$/env python3/' vendor/postgres-v15/src/test/locale/sort-test.py
%{__install} -d %{buildroot}%{neoninstdir}/%{sname}
mv * %{buildroot}%{neoninstdir}/%{sname}/


%clean
#%{__rm} -rf %{buildroot}


%pre
getent group %{neonuser} >/dev/null 2>&1 || /usr/sbin/groupadd -r %{neonuser} >/dev/null 2>&1
/usr/sbin/useradd -g %{neonuser} -r -d %{neoninstdir}/%{sname}/ %{neonuser}


%post
chmod a+wx %{neoninstdir}/%{sname}/
cd %{neoninstdir}/%{sname}/
/usr/sbin/runuser -l %{neonuser} -c 'cd %{neoninstdir}/%{sname}; ./target/release/neon_local init --pg-version %{pgrel}' 
/usr/sbin/runuser -l %{neonuser} -c 'cd %{neoninstdir}/%{sname}; ./target/release/neon_local start'
/usr/sbin/runuser -l %{neonuser} -c 'cd %{neoninstdir}/%{sname}; ./target/release/neon_local tenant create --pg-version %{pgrel} --set-default'
/usr/sbin/runuser -l %{neonuser} -c 'cd %{neoninstdir}/%{sname}; ./target/release/neon_local pg start --pg-version %{pgrel} main'


%postun
/usr/sbin/runuser -u %{neonuser} -- ./target/debug/neon_local stop


%files
%defattr(755,root,root,755)
%{neoninstdir}/%{sname}/*


%changelog
* Tue Feb 14 2023 Vadim Yalovets <vadim.yalovets@percona.com> - 1.0.0-1
- Initial build
