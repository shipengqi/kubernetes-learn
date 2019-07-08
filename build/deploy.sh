#!/bin/bash
set -e

npm run docs:build

cd ./public

# 如果是发布到自定义域名
# echo 'www.example.com' > CNAME

git init
git config user.name 'shipengqi'
git config user.email 'pooky.shipengqi@gmail.com'
git add -A
git commit -m 'deploy'

# 如果发布到 https://<USERNAME>.github.io
# git push -f git@github.com:<USERNAME>/<USERNAME>.github.io.git master

# 如果发布到 https://<USERNAME>.github.io/<REPO>
git push -f git@github.com:shipengqi/kubernetes-learn.git master:gh-pages