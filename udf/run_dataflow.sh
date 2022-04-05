export REGION=us-central1
gcloud dataflow flex-template run orders-cdc-template --region ${REGION} \
--template-file-gcs-location "gs://dataflow-templates/latest/flex/Cloud_Datastream_to_BigQuery" \
--service-account-email "df-tutorial@${PROJECT_ID}.iam.gserviceaccount.com" \
--parameters \
inputFilePattern="gs://${BUCKET_NAME}/",\
gcsPubSubSubscription="projects/${PROJECT_ID}/subscriptions/oracle_retail_sub",\
inputFileFormat="json",\
outputStagingDatasetTemplate="retail",\
outputDatasetTemplate="retail",\
deadLetterQueueDirectory="gs://dlq-${BUCKET_NAME}",\
autoscalingAlgorithm="THROUGHPUT_BASED",\
mergeFrequencyMinutes=1,\
javascriptTextTransformGcsPath="gs://js-${BUCKET_NAME}/utils/retail_transform.js",\
javascriptTextTransformFunctionName="process"
