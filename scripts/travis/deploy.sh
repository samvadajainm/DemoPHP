#!/bin/bash

set -eo pipefail

# Make sure the site is in Git mode.
terminus connection:set $PANTHEON_SITE_NAME.dev git

# Generate a new SSH key
ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y

# Add the SSH key to Pantheon
terminus ssh-key:add $HOME/.ssh/id_rsa.pub

# Disable host checking
echo -e "Host *.drush.in\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config

# Set Git for the site.
git remote add pantheon $(terminus connection:info $PANTHEON_SITE_NAME.dev --field=git_url)
git fetch pantheon
git checkout master

# Push the latest changes to dev.
git add -A
git commit -q -m "Pushing changes from $TRAVIS_BUILD_ID"
git push --force pantheon master --verbose

# Set the site on SFTP mode
terminus connection:set $PANTHEON_SITE_NAME.dev sftp

# Run pending database updates
terminus -n drush "$PANTHEON_SITE_NAME.dev" -- updatedb -y

# If there are any exported configuration files, then import them
if [ -f "config/system.site.yml" ] ; then
  terminus -n drush "$PANTHEON_SITE_NAME.dev" -- config-import --yes
fi

terminus -n drush "$PANTHEON_SITE_NAME.dev" -- cache-clear all

# Set the site back on Git mode after deployment.
terminus connection:set $PANTHEON_SITE_NAME.dev git

# Remove the associated SSH key
terminus ssh-key:remove $(ssh-keygen -E md5 -lf $HOME/.ssh/id_rsa.pub | cut -b 10-56)
