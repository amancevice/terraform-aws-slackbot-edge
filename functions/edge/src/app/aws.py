import json
from io import BytesIO
from urllib.parse import parse_qsl

import boto3
import awscrt
from botocore.awsrequest import AWSRequest
from botocore.session import Session

from .env import AWS_API_HOST, AWS_EVENT_BUS_NAME, AWS_EVENT_BUS_REGION
from .logger import logger


class EventBus:
    def __init__(self, name=None, region_name=None):
        self.name = name or AWS_EVENT_BUS_NAME
        self.region_name = region_name or AWS_EVENT_BUS_REGION
        self.client = boto3.client("events", region_name=self.region_name)

    def publish(self, entry):
        params = {
            "Entries": [{"EventBusName": self.name, "Source": "slack.com", **entry}]
        }
        logger.info("events:PutEvents %s", json.dumps(params))
        return self.client.put_events(**params)


class SigV4ASigner:
    def __init__(self, session=None):
        self.session = session or Session()

    def resolve(self, request, data):
        # https://chammock.dev/posts/aws-apigw-multi-region-iam-auth/

        # Extract signing info
        uri = request["uri"]
        method = request["method"]
        querystring = request["querystring"]
        url = f"https://{AWS_API_HOST}{uri}"

        # Prepare AWS request
        awsparams = dict(parse_qsl(querystring))
        awsrequest = AWSRequest(method, url, {"host": AWS_API_HOST}, data, awsparams)
        awsrequest.prepare()

        # Setup credentials provider
        credentials = self.session.get_credentials()
        frozen_credentials = credentials.get_frozen_credentials()
        credentials_provider = awscrt.auth.AwsCredentialsProvider.new_static(
            access_key_id=frozen_credentials.access_key,
            secret_access_key=frozen_credentials.secret_key,
            session_token=frozen_credentials.token,
        )

        # Setup SigV4A signing config
        signing_config = awscrt.auth.AwsSigningConfig(
            algorithm=awscrt.auth.AwsSigningAlgorithm.V4_ASYMMETRIC,
            signature_type=awscrt.auth.AwsSignatureType.HTTP_REQUEST_HEADERS,
            credentials_provider=credentials_provider,
            region="*",
            service="execute-api",
        )

        # Create the required signing HttpHeaders/HttpRequest for the SigV4 signing method
        headers = awsrequest.headers.items()
        crt_request = awscrt.http.HttpRequest(
            method=method,
            path=uri,
            headers=awscrt.http.HttpHeaders(headers),
            body_stream=BytesIO(data.encode()),
        )

        # Sign the request and set the original request headers to include new signed headers
        awscrt.auth.aws_sign_request(crt_request, signing_config).result()
        for key, val in crt_request.headers:
            key = key.lower()
            val = {"key": key, "value": val}
            request["headers"][key] = [val]

        # Set body
        request["body"].update(action="replace", encoding="text", data=data)

        # Return result
        return request
