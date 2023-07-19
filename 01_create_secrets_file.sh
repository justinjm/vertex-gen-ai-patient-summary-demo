#!/bin/bash

FILE="./secrets/.secrets.R"

if [ -e "$FILE" ]; then
    while true; do
        read -p "The file $FILE exists. Do you want to overwrite it? (yes/no) " yn
        case $yn in
            [Yy]* ) 
                break
                ;;
            [Nn]* ) 
                echo "Aborted."
                exit
                ;;
            * ) 
                echo "Please answer yes or no."
                ;;
        esac
    done
fi

cat << EOF > $FILE
# secrets.R
## google cloud platform
Sys.setenv(GAR_AUTH_EMAIL = "")
Sys.setenv(PROJECT_ID = "")
Sys.setenv(REGION = "")
## bigquery
Sys.setenv(DATASET_ID = "")
## firebase
Sys.setenv(FIREBASE_API_KEY = "")
Sys.setenv(FIREBASE_PROJECT_ID = "")
Sys.setenv(FIREBASE_AUTH_DOMAIN = "")
Sys.setenv(FIREBASE_STORAGE_BUCKET = "")
Sys.setenv(FIREBASE_APP_ID = "")
Sys.setenv(FIREBASE_DATABASE_URL = "")
EOF

echo "File $FILE has been written."
