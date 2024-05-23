#! /bin/bash

echo "::: Starting userdata script"

# config
export AWS_DEFAULT_REGION=${region}
export SECRET_ARN=${secret_arn}
GITREPO=${gitrepo}
REPODIR=${repodir}
KMS_KEY_ID=${kms_key_id}

cat <<EOF >> /root/.bashrc
export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
EOF

# bootstrap
mkdir -p /data && \
  cd /data && \
  git clone $GITREPO $REPODIR && \
  cd /data/$REPODIR/scripts && \
  AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
    SECRET_ARN=$SECRET_ARN KMS_KEY_ID=$KMS_KEY_ID \
    STOP_AFTER_STARTING_VAULT=${stop_after_starting_vault} \
    ./bootstrap.sh

exit 0
