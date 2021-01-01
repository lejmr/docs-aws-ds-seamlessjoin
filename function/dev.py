import sys
import json 
import main

with open(sys.argv[1], 'r') as f:
    j = json.loads(f.read())

    r = main.lambda_handler(j, None)

    print(r)