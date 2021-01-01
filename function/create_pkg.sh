#!/bin/bash

cd $path_cwd
mkdir -p lambda_dist_pkg

virtualenv -p $runtime env
source env/bin/activate

pwd
pip install -r requirements.txt -t lambda_dist_pkg
cp main.py lambda_dist_pkg
