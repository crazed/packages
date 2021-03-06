#!/usr/bin/env bash

set -e

# Constants
ARCHS=( i386 amd64 )
ALL_ARCH=i386
DISTS=( precise )
ROOT_DIR=/root/rock-build
PBUILDER_DIR=${ROOT_DIR}/pbuilder
PBUILDER_MOUNT=${ROOT_DIR}/apt
VAR_DIR=${ROOT_DIR}/build

export DEBEMAIL=packages@rockstack.org
export DEBFULLNAME=RockStack
export PBUILDFOLDER=$PBUILDER_DIR

# Paths
cd $( dirname $0 )
package_root=$( pwd )
packages=$( cat $package_root/build.list )

usage() {
  echo "Usage: $( basename $0 ) [-p package -d distribution -a architecture]"
  exit 0
}

display() {
  echo "-----> $1"
}

setup_env() {
  dist=$1
  arch=$2

  pbuilder_name=$dist
  if [ "$arch" == 'i386' ]; then
    pbuilder_name=${pbuilder_name}-${arch}
  fi

  pbuilder_result_mount="${PBUILDER_DIR}/${pbuilder_name}_result"
  pbuilder_package_mount="${PBUILDER_MOUNT}/${dist}"
  pbuilder_name=${pbuilder_name}-base.tgz

  mkdir -p $pbuilder_package_mount
cat << EOF > $pbuilder_package_mount/D05deps
#!/usr/bin/env bash

echo "deb file://$pbuilder_package_mount ./" >> /etc/apt/sources.list
apt-get update
EOF

  chmod +x $pbuilder_package_mount/D05deps
  pbuilder_create_args=''
  pbuilder_create_args="$pbuilder_args --debootstrapopts --variant=buildd"

  pbuilder_size=$( du $PBUILDER_DIR/$pbuilder_name | awk '{print $1}' )
  if [ ! -e "$PBUILDER_DIR/$pbuilder_name" ] || [ "$pbuilder_size" == 0 ]; then
    display "Environment $dist-$arch does not exist, creating..."
    display "Running: pbuilder-dist $dist $arch create $pbuilder_args"
    pbuilder-dist $dist $arch create $pbuilder_create_args
  fi

  apt_packages=$pbuilder_package_mount/Packages
}

build() {
  # args
  package=$1
  dist=$2
  arch=$3

  # values
  cd $package_root/$package
  package_dist=$( dpkg-parsechangelog | grep Distribution: | awk '{print $2}' )
  package_version=$( dpkg-parsechangelog | grep Version: | awk '{print $2}' )
  package_arch=$( grep Architecture debian/control | head -1 | awk '{print $2}' )

  case $dist in
  squeeze)
    package_suffix='~bp6.0+'
    package_debiandist=stable
    ;;
  wheezy)
    package_suffix='~bp7.0+'
    package_debiandist=testing
    ;;
  *)
    package_suffix="~${dist}"
    package_debiandist=$dist
    ;;
  esac

  # Setup env
  if [ "$package_arch" == 'all' ]; then
    setup_env $dist $ALL_ARCH
    package_arch=all
  else
    setup_env $dist $arch
    package_arch=$arch
  fi

  deb_search=${package}_${package_version}${package_suffix}*_${package_arch}.deb
  match_deb=$( find $pbuilder_package_mount -type f -name "$deb_search" )

  if [ -n "$match_deb" ]; then
    display "$match_deb found, skipping"
    return
  fi

  # Create working directory
  build_dir=$VAR_DIR/$package-$dist-$arch
  rm -rf $build_dir
  mkdir -p $build_dir
  cp -rf $package_root/$package/ $build_dir/package/

  cd $build_dir/package
  display "Building package: $package"
  if [ "$package_dist" != "$dist" ]; then
    dch -l $package_suffix -D $package_debiandist "Backport to $dist"
  fi

  if [ -e 'debian/watch' ]; then
    debian/rules get-orig-source
  fi

  # Build dsc
  debuild -S -us -uc

  # Update local packages
  cd $pbuilder_package_mount
  apt-ftparchive packages .  > $apt_packages

  # Build
  pbuilder_args="--hookdir $pbuilder_package_mount --allow-untrusted --bindmounts $PBUILDER_MOUNT"
  pbuilder-dist $dist $arch build $pbuilder_args $build_dir/$package_$version*.dsc

  # Move result to target
  mkdir -p $pbuilder_package_mount
  mv $pbuilder_result_mount/*.deb $pbuilder_package_mount/
}

main() {
  dist=all
  arch=all
  package=all

  while getopts "hd:a:p:" opt; do
    case $opt in
      h)
        usage
        exit 0
        ;;
      d)
        [ -n "$OPTARG" ] && dist="$OPTARG"
        ;;
      a)
        [ -n "$OPTARG" ] && arch="$OPTARG"
        ;;
      p)
        [ -n "$OPTARG" ] && package="$OPTARG"
        ;;
      \?)
        usage
        exit 1
        ;;
      :)
        echo "$OPTARG requires an argument"
        exit 1
        ;;
    esac
  done

  # Ensure build deps are installed
  display "Ensuring build tools are installed..."
  apt-get install ubuntu-dev-tools debhelper dh-make reprepro debootstrap pbuilder libcrypt-ssleay-perl -y

  # Ensure local apt is available
  mkdir -p $PBUILDER_MOUNT

  # Ensure local var dir is available
  mkdir -p $VAR_DIR

  # Process
  if [ "$package" == 'all' ]; then
    selected_packages=${packages[@]}
  else
    selected_packages=$package
  fi

  if [ "$dist" == 'all' ]; then
    selected_dists=${DISTS[@]}
  else
    selected_dists=$dist
  fi

  if [ "$arch" == 'all' ]; then
    selected_archs=${ARCHS[@]}
  else
    selected_archs=$arch
  fi

  for d in ${selected_dists[@]}; do
    for a in ${selected_archs[@]}; do
      for p in ${selected_packages[@]}; do
        display "Processing: $p-$d-$a"
        build $p $d $a
      done
    done
  done
}

main $@
