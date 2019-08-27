#!/usr/bin/env bash

add_prereqs(){
  amazon-linux-extras install php7.3
  yum install -y php-xml php-mbstring git

  [ -f /usr/local/bin/composer ] ||
    wget -4 https://getcomposer.org/download/1.8.6/composer.phar -O /usr/local/bin/composer
  mkdir -p /local/app/.composer/cache
  php /usr/local/bin/composer config -g cache-dir "/local/app/.composer/cache"
  php /usr/local/bin/composer config -g data-dir "/local/app/.composer"
}

add_satis(){
  # clean satis install, but keep composer cache and previous builds
  rm -fr /local/app/satis
  mkdir -p /local/app/packages
  pushd /local/app || exit
  php /usr/local/bin/composer create-project composer/satis --stability=dev --keep-vcs
  popd || exit
}

add_prereqs
add_satis