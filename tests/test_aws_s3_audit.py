"""Unit tests for the AWS S3 audit modules (mocked, no live AWS calls)."""

import importlib.util
import json
import unittest.mock as mock
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def _load_module(name: str, rel_path: str):
    spec = importlib.util.spec_from_file_location(name, REPO_ROOT / rel_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


audit_public_buckets = _load_module(
    "aws_audit_public_buckets",
    "aws/s3/audit-public-buckets/audit_public_buckets.py",
)
audit_bucket_security = _load_module(
    "aws_audit_bucket_security",
    "aws/s3/audit-security-config/audit_bucket_security.py",
)


def _client_error(code: str) -> Exception:
    from botocore.exceptions import ClientError

    return ClientError(
        {"Error": {"Code": code, "Message": code}}, "TestOperation"
    )


class _FakeSession:
    """Session shim so audit functions can obtain a per-region client."""

    def __init__(self, client):
        self._client = client

    def client(self, service_name, **kwargs):
        assert service_name == "s3"
        return self._client


def _make_s3(regional_client):
    s3 = mock.MagicMock()
    s3.meta.session = _FakeSession(regional_client)
    s3.get_bucket_location.return_value = {"LocationConstraint": None}
    return s3


# --------------------------------------------------------------------------- #
# audit_public_buckets
# --------------------------------------------------------------------------- #

class TestPublicBuckets:
    def test_bucket_with_missing_public_access_block_is_flagged(self):
        regional = mock.MagicMock()
        regional.get_public_access_block.side_effect = _client_error(
            "NoSuchPublicAccessBlockConfiguration"
        )
        regional.get_bucket_policy_status.return_value = {"PolicyStatus": {"IsPublic": False}}
        regional.get_bucket_acl.return_value = {
            "Grants": [
                {"Grantee": {"ID": "canonical-user"}, "Permission": "FULL_CONTROL"}
            ]
        }

        row = audit_public_buckets.audit_bucket(_make_s3(regional), "123456789012", "legacy-data")

        assert row["public_access_block_enabled"] is False
        assert row["policy_public"] is False
        assert row["acl_public"] is False
        assert row["is_public"] is True

    def test_bucket_public_via_acl(self):
        regional = mock.MagicMock()
        regional.get_public_access_block.return_value = {
            "PublicAccessBlockConfiguration": {
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True,
            }
        }
        regional.get_bucket_policy_status.return_value = {"PolicyStatus": {"IsPublic": False}}
        regional.get_bucket_acl.return_value = {
            "Grants": [
                {
                    "Grantee": {"URI": "http://acs.amazonaws.com/groups/global/AllUsers"},
                    "Permission": "READ",
                }
            ]
        }

        row = audit_public_buckets.audit_bucket(_make_s3(regional), "123456789012", "open-data")

        assert row["acl_public"] is True
        assert row["is_public"] is True
        assert "READ" in row["acl_public_permissions"]

    def test_fully_restricted_bucket_is_private(self):
        regional = mock.MagicMock()
        regional.get_public_access_block.return_value = {
            "PublicAccessBlockConfiguration": {
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True,
            }
        }
        regional.get_bucket_policy_status.return_value = {"PolicyStatus": {"IsPublic": False}}
        regional.get_bucket_acl.return_value = {
            "Grants": [
                {"Grantee": {"ID": "canonical-user"}, "Permission": "FULL_CONTROL"}
            ]
        }

        row = audit_public_buckets.audit_bucket(_make_s3(regional), "123456789012", "private-data")

        assert row["is_public"] is False


# --------------------------------------------------------------------------- #
# audit_bucket_security
# --------------------------------------------------------------------------- #

class TestSecurityConfig:
    def test_fully_hardened_bucket(self):
        regional = mock.MagicMock()
        regional.get_public_access_block.return_value = {
            "PublicAccessBlockConfiguration": {
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True,
            }
        }
        regional.get_bucket_encryption.return_value = {
            "ServerSideEncryptionConfiguration": {
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "aws:kms",
                            "KMSMasterKeyID": "arn:aws:kms:us-east-1:123:key/abc",
                        }
                    }
                ]
            }
        }
        regional.get_bucket_versioning.return_value = {"Status": "Enabled"}

        row = audit_bucket_security.audit_bucket(_make_s3(regional), "123456789012", "prod")

        assert row["hardened"] is True
        assert row["encryption_type"].startswith("aws:kms")
        assert row["versioning_enabled"] is True

    def test_unencrypted_bucket_is_not_hardened(self):
        regional = mock.MagicMock()
        regional.get_public_access_block.return_value = {
            "PublicAccessBlockConfiguration": {
                "BlockPublicAcls": True,
                "IgnorePublicAcls": True,
                "BlockPublicPolicy": True,
                "RestrictPublicBuckets": True,
            }
        }
        regional.get_bucket_encryption.side_effect = _client_error("ServerSideEncryptionConfigurationNotFoundError")
        regional.get_bucket_versioning.return_value = {"Status": "Enabled"}

        row = audit_bucket_security.audit_bucket(_make_s3(regional), "123456789012", "unencrypted")

        assert row["default_encryption"] is False
        assert row["encryption_type"] == "NONE"
        assert row["hardened"] is False

    def test_report_json_serializes(self, tmp_path, capsys):
        rows = [
            {
                "account_id": "123",
                "bucket": "a",
                "region": "us-east-1",
                "public_access_block_enabled": True,
                "default_encryption": True,
                "encryption_type": "AES256",
                "versioning_enabled": True,
                "hardened": True,
            }
        ]

        out = tmp_path / "report.json"
        audit_bucket_security.write_report(rows, "json", str(out))
        assert json.loads(out.read_text()) == rows
