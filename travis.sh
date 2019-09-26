#!/bin/bash -e
#
# From the GitHub repository:
# https://github.com/SUSE/doc-susemanager
#
# License: MIT
#
# Written by Thomas Schraitle
# Modified by Joseph Cayouette

RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[34m'
BOLD='\e[1m'
RESET='\e[0m' # No Color

TRAVIS_FOLD_IDS=""


log() {
  # $1 - optional: string: "+" for green color, "-" for red color
  # $2 - message
  colorcode="$BLUE"
  [[ "$1" == '+' ]] && colorcode="$GREEN" && shift
  [[ "$1" == '-' ]] && colorcode="$RED" && shift
  echo -e "$colorcode${1}$RESET"
}


fail() {
  # $1 - message
  echo -e "$RED$BOLD${1}$RESET"
  exit 1
}


succeed() {
  # $1 - message
  echo -e "$GREEN$BOLD${1}$RESET"
  exit 0
}


travis_fold() {
  humanname="$1"
  type='start'
  current_id="fold_"$(( ( RANDOM % 32000 ) + 1 ))
  if [[ $1 == '--' ]]; then
    humanname=''
    type='end'
    current_id=$(echo "$TRAVIS_FOLD_IDS" | grep -oP 'fold_[0-9]+$')
    TRAVIS_FOLD_IDS=$(echo "$TRAVIS_FOLD_IDS" | sed -r "s/ $current_id\$//")
  else
    TRAVIS_FOLD_IDS+=" $current_id"
  fi
  echo -en "travis_fold:$type:$current_id\\r" && log "$humanname"
}


travis_fold "Build Lunr Docker Image"
docker build -t lunr/antora:custom -f Dockerfile.custom .
travis_fold --


travis_fold "Install Asciidoctor"
gem install asciidoctor
asciidoctor --version
travis_fold --


travis_fold "Install Asciidoctor PDF and Requirements"
gem install asciidoctor-pdf --pre
gem install rouge
gem install pygments.rb
gem install coderay
asciidoctor-pdf --version
travis_fold --


travis_fold "Install Antora Xref Validator"
npm i -g @antora/cli@2.1 @antora/site-generator-default@2.1
npm install -g gitlab:antora/xref-validator
travis_fold --


travis_fold "Build SUMA docs with Antora and Docker"
docker run -u $UID --privileged -e DOCSEARCH_ENABLED=true -e DOCSEARCH_ENGINE=lunr -v $TRAVIS_BUILD_DIR:/antora/ --rm -t lunr/antora:custom suma-site.yml --generator antora-site-generator-lunr
travis_fold --


travis_fold "Build SUMA PDFS"
make pdf-all-suma
travis_fold --


travis_fold "Tar all PDFS"
make pdf-tar-suma
travis_fold --


travis_fold "Publish content to GH Pages"
cd build ;
touch .nojekyll
git init
git config user.name "${GH_USER_NAME}"
git config user.email "${GH_USER_EMAIL}"
git add . ; git commit -m "Deploy to GitHub Pages"
git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:gh-pages > /dev/null 2>&1
travis_fold --


travis_fold "Validate XREFS"
NODE_PATH="$(npm -g root)" antora --generator @antora/xref-validator suma-site.yml
travis_fold --

succeed "We're done."
