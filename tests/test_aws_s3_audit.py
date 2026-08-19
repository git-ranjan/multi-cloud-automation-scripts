"""Unit tests for the AWS S3 audit modules (mocked, no live AWS calls)."""

import csv
import importlib.util
import json
import unittest.mock as mock
from pathlib import Path

from botocore.exceptions import ClientError, NoCredentialsError

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
    return ClientError({"Error": {"Code": code, "Message": code}}, "TestOperation")


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


def _fake_session(account: str, s3) -> mock.MagicMock:
    """Session shim for main(): sts resolves the account, s3 handles buckets."""
    session = mock.MagicMock()

    def _client(service_name, **kwargs):
        if service_name == "sts":
            sts = mock.MagicMock()
            sts.get_caller_identity.return_value = {"Account": account}
            return sts
        return s3

    session.client.side_effect = _client
    return session


def _restricted_regional():
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
    regional.get_bucket_acl.return_value = {"Grants": []}
    return regional


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

    def test_bucket_public_via_authenticated_users_acl(self):
        regional = _restricted_regional()
        regional.get_bucket_acl.return_value = {
            "Grants": [
                {
                    "Grantee": {
                        "URI": "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
                    },
                    "Permission": "WRITE",
                }
            ]
        }

        row = audit_public_buckets.audit_bucket(_make_s3(regional), "123456789012", "open-data")

        assert row["acl_public"] is True
        assert "WRITE" in row["acl_public_permissions"]
        assert row["is_public"] is True

    def test_exposure_vector_errors_are_safe(self):
        regional = mock.MagicMock()
        regional.get_public_access_block.side_effect = _client_error(
            "NoSuchPublicAccessBlockConfiguration"
        )
        regional.get_bucket_policy_status.side_effect = _client_error("AccessDenied")
        regional.get_bucket_acl.side_effect = _client_error("AccessDenied")

        row = audit_public_buckets.audit_bucket(_make_s3(regional), "123456789012", "b")

        assert row["policy_public"] is False
        assert row["acl_public"] is False
        assert row["acl_public_permissions"] == ""
        assert row["is_public"] is True

    def test_bucket_region_resolves_explicit_location(self):
        regional = _restricted_regional()
        s3 = _make_s3(regional)
        s3.get_bucket_location.return_value = {"LocationConstraint": "ap-south-1"}

        row = audit_public_buckets.audit_bucket(s3, "123456789012", "b")

        assert row["region"] == "ap-south-1"

    def test_bucket_region_falls_back_to_us_east_1_on_error(self):
        regional = _restricted_regional()
        s3 = _make_s3(regional)
        s3.get_bucket_location.side_effect = _client_error("AccessDenied")

        row = audit_public_buckets.audit_bucket(s3, "123456789012", "b")

        assert row["region"] == "us-east-1"


class TestPublicBucketsMain:
    def test_main_fails_fast_without_credentials(self, monkeypatch):
        def _no_creds(**kwargs):
            raise NoCredentialsError()

        monkeypatch.setattr(audit_public_buckets.boto3, "Session", _no_creds)
        monkeypatch.setattr(audit_public_buckets.sys, "argv", ["audit_public_buckets.py"])

        assert audit_public_buckets.main() == 2

    def test_main_reports_listing_errors(self, monkeypatch):
        s3 = _make_s3(_restricted_regional())
        s3.list_buckets.side_effect = _client_error("AccessDenied")
        session = _fake_session("123456789012", s3)
        monkeypatch.setattr(audit_public_buckets.boto3, "Session", lambda **kwargs: session)
        monkeypatch.setattr(audit_public_buckets.sys, "argv", ["audit_public_buckets.py"])

        assert audit_public_buckets.main() == 2

    def test_main_writes_csv_with_public_filter(self, monkeypatch, tmp_path, capsys):
        regional = _restricted_regional()
        regional.get_bucket_policy_status.side_effect = [
            {"PolicyStatus": {"IsPublic": False}},
            {"PolicyStatus": {"IsPublic": True}},
        ]
        s3 = _make_s3(regional)
        s3.list_buckets.return_value = {"Buckets": [{"Name": "safe"}, {"Name": "exposed"}]}
        session = _fake_session("123456789012", s3)
        monkeypatch.setattr(audit_public_buckets.boto3, "Session", lambda **kwargs: session)
        monkeypatch.setattr(
            audit_public_buckets.sys,
            "argv",
            [
                "audit_public_buckets.py",
                "--only-public",
                "--format",
                "csv",
                "--output-file",
                str(tmp_path / "out.csv"),
            ],
        )

        assert audit_public_buckets.main() == 0

        rows = list(csv.reader((tmp_path / "out.csv").read_text().splitlines()))
        assert rows[0] == list(audit_public_buckets.COLUMNS)
        assert [row[1] for row in rows[1:]] == ["exposed"]
        assert "1 flagged public." in capsys.readouterr().err

    def test_main_warns_about_unknown_buckets(self, monkeypatch, tmp_path, capsys):
        regional = _restricted_regional()
        s3 = _make_s3(regional)
        s3.list_buckets.return_value = {"Buckets": [{"Name": "safe"}, {"Name": "exposed"}]}
        session = _fake_session("123456789012", s3)
        monkeypatch.setattr(audit_public_buckets.boto3, "Session", lambda **kwargs: session)
        monkeypatch.setattr(
            audit_public_buckets.sys,
            "argv",
            [
                "audit_public_buckets.py",
                "--bucket",
                "safe",
                "--bucket",
                "ghost",
                "--format",
                "csv",
                "--output-file",
                str(tmp_path / "out.csv"),
            ],
        )

        assert audit_public_buckets.main() == 0
        assert "not found" in capsys.readouterr().err
        rows = list(csv.reader((tmp_path / "out.csv").read_text().splitlines()))
        assert [row[1] for row in rows[1:]] == ["safe"]


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

    def test_aes256_encryption_without_kms(self):
        regional = _restricted_regional()
        regional.get_bucket_encryption.return_value = {
            "ServerSideEncryptionConfiguration": {
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256",
                        }
                    }
                ]
            }
        }
        regional.get_bucket_versioning.return_value = {"Status": "Enabled"}

        row = audit_bucket_security.audit_bucket(_make_s3(regional), "123456789012", "b")

        assert row["default_encryption"] is True
        assert row["encryption_type"] == "AES256"
        assert row["hardened"] is True

    def test_suspended_versioning_is_not_hardened(self):
        regional = _restricted_regional()
        regional.get_bucket_encryption.return_value = {
            "ServerSideEncryptionConfiguration": {
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256",
                        }
                    }
                ]
            }
        }
        regional.get_bucket_versioning.return_value = {"Status": "Suspended"}

        row = audit_bucket_security.audit_bucket(_make_s3(regional), "123456789012", "b")

        assert row["versioning_enabled"] is False
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


class TestSecurityConfigMain:
    def test_main_fails_fast_without_credentials(self, monkeypatch):
        def _no_creds(**kwargs):
            raise NoCredentialsError()

        monkeypatch.setattr(audit_bucket_security.boto3, "Session", _no_creds)
        monkeypatch.setattr(audit_bucket_security.sys, "argv", ["audit_bucket_security.py"])

        assert audit_bucket_security.main() == 2

    def test_main_reports_listing_errors(self, monkeypatch):
        s3 = _make_s3(_restricted_regional())
        s3.list_buckets.side_effect = _client_error("AccessDenied")
        session = _fake_session("123456789012", s3)
        monkeypatch.setattr(audit_bucket_security.boto3, "Session", lambda **kwargs: session)
        monkeypatch.setattr(audit_bucket_security.sys, "argv", ["audit_bucket_security.py"])

        assert audit_bucket_security.main() == 2

    def test_main_writes_csv_with_hardened_filter(self, monkeypatch, tmp_path, capsys):
        regional = _restricted_regional()
        regional.get_bucket_encryption.side_effect = [
            {
                "ServerSideEncryptionConfiguration": {
                    "Rules": [
                        {
                            "ApplyServerSideEncryptionByDefault": {
                                "SSEAlgorithm": "AES256",
                            }
                        }
                    ]
                }
            },
            _client_error("ServerSideEncryptionConfigurationNotFoundError"),
        ]
        regional.get_bucket_versioning.return_value = {"Status": "Enabled"}
        s3 = _make_s3(regional)
        s3.list_buckets.return_value = {"Buckets": [{"Name": "prod"}, {"Name": "legacy"}]}
        session = _fake_session("123456789012", s3)
        monkeypatch.setattr(audit_bucket_security.boto3, "Session", lambda **kwargs: session)
        monkeypatch.setattr(
            audit_bucket_security.sys,
            "argv",
            [
                "audit_bucket_security.py",
                "--only-hardened",
                "--format",
                "csv",
                "--output-file",
                str(tmp_path / "out.csv"),
            ],
        )

        assert audit_bucket_security.main() == 0

        rows = list(csv.reader((tmp_path / "out.csv").read_text().splitlines()))
        assert rows[0] == list(audit_bucket_security.COLUMNS)
        assert [row[1] for row in rows[1:]] == ["prod"]
        assert "1 fully hardened." in capsys.readouterr().err
