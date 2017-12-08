Name:          swift-BinaryEncoding
Version:       %{__version}
Release:       %{!?__release:1}%{?__release}%{?dist}
Summary:       Encoding/decoding of numbers, strings and arrays into binary buffers

Group:         Development/Libraries
License:       MIT
URL:           https://github.com/my-mail-ru/%{name}
Source0:       https://github.com/my-mail-ru/%{name}/archive/%{version}.tar.gz#/%{name}-%{version}.tar.gz
BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires: swift >= 4
BuildRequires: swift-packaging >= 0.9

%swift_find_provides_and_requires

%description
The BinaryEncoding library is designed to simplify encoding/decoding of native Swift types and their sequences into binary data buffers.

%{?__revision:Built from revision %{__revision}.}


%prep
%setup -q
%swift_patch_package


%build
%swift_build


%install
rm -rf %{buildroot}
%swift_install
%swift_install_devel


%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
%{swift_libdir}/*.so


%package devel
Summary:  Encoding/decoding of numbers, strings and arrays into binary buffers
Requires: %{name} = %{version}-%{release}

%description devel
The BinaryEncoding library is designed to simplify encoding/decoding of native Swift types and their sequences into binary data buffers.

%{?__revision:Built from revision %{__revision}.}


%files devel
%defattr(-,root,root,-)
%{swift_moduledir}/*.swiftmodule
%{swift_moduledir}/*.swiftdoc
