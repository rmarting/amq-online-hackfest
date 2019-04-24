echo "Activate Batch"
oc patch address scenario1.input-batch  --patch '{"spec":{"plan":"scenario1-available-queue"}}'
oc patch address scenario1.input-online --patch '{"spec":{"plan":"scenario1-offline-queue"}}'

