#!/bin/bash

source args

echo "starting build of container image in cloud build from local source code..."

gcloud builds submit --region=$REGION --tag=$IMAGE_URI --timeout=1h ./build

echo "starting deploy to cloud run..."

gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_URI \
  --region=$REGION \
  --platform="managed" \
  --port="5000" \
  --allow-unauthenticated \
  --session-affinity \
  --service-account=$SVC_ACCOUNT_EMAIL \
  --min-instances=0 \
  --max-instances=5 \
  --set-secrets="/secrets/.secrets.R=${SECRET_NAME}:latest"
