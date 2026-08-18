"""Unit tests for the GCP storage audit modules (mocked, no live GCP calls)."""

import json
import sys
import unittest.mock as mock
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "gcp" / "storage" / "audit-public-buckets"))
sys.path.insert(0, str(REPO_ROOT / "gcp" / "storage" / "audit-security-config"))

from audit_bucket_security import audit_bucket as audit_security_bucket  # noqa: E402
from audit_public_buckets import audit_bucket as audit_public_bucket  # noqa: E402


class _FakePolicy:
    def __init__(self, bindings):
        self.bindings = bindings


class _FakeBucket:
    def __init__(self, name, project="proj-1", policy=None, iam_configuration=None,
                 get_iam_error=None, location="US", storage_class="STANDARD"):
        self.name = name
        self.project = project
        self.location = location
        self.storage_class = storage_class
        self._policy = policy
        self._iam_configuration = iam_configuration
        self._get_iam_error = get_iam_error

    @property
    def iam_configuration(self):
        return self._iam_configuration

    def get_iam_policy(self):
        if self._get_iam_error:
            raise self._get_iam_error
        return self._policy


# --------------------------------------------------------------------------- #
# audit_public_buckets
# --------------------------------------------------------------------------- #

class TestPublicBuckets:
    def test_bucket_with_allusers_binding_is_flagged(self):
        bucket = _FakeBucket(
            "open-data",
            policy=_FakePolicy(
                [{"role": "roles/storage.objectViewer", "members": ["allUsers"]}]
            ),
        )

        row = audit_public_bucket(bucket)

        assert row["public"] is True
        assert "roles/storage.objectViewer" in row["public_roles"]
        assert "allUsers" in row["public_members"]

    def test_bucket_with_service_account_binding_is_private(self):
        bucket = _FakeBucket(
            "private-data",
            policy=_FakePolicy(
                [
                    {
                        "role": "roles/storage.objectViewer",
                        "members": ["serviceAccount:svc@proj-1.iam.gserviceaccount.com"],
                    }
                ]
            ),
        )

        row = audit_public_bucket(bucket)

        assert row["public"] is False

    def test_iam_error_is_captured_not_raised(self):
        from google.api_core import exceptions

        bucket = _FakeBucket(
            "restricted",
            policy=None,
            get_iam_error=exceptions.Forbidden("403"),
        )

        row = audit_public_bucket(bucket)

        assert row["public"] is None
        assert "403" in row["error"]


# --------------------------------------------------------------------------- #
# audit_bucket_security
# --------------------------------------------------------------------------- #

class TestSecurityConfig:
    def test_fully_hardened_bucket(self):
        bucket = _FakeBucket(
            "prod",
            policy=_FakePolicy(
                [{"role": "roles/storage.objectViewer", "members": ["user:me@corp.com"]}]
            ),
            iam_configuration={
                "uniformBucketLevelAccess": {"enabled": True},
                "publicAccessPrevention": "enforced",
            },
        )

        row = audit_security_bucket(bucket)

        assert row["uniform_bucket_level_access"] is True
        assert row["public_access_prevention"] == "enforced"
        assert row["public"] is False
        assert row["hardened"] is True

    def test_public_bucket_with_enforcement_is_not_hardened(self):
        bucket = _FakeBucket(
            "open-data",
            policy=_FakePolicy(
                [{"role": "roles/storage.objectViewer", "members": ["allUsers"]}]
            ),
            iam_configuration={
                "uniformBucketLevelAccess": {"enabled": True},
                "publicAccessPrevention": "enforced",
            },
        )

        row = audit_security_bucket(bucket)

        assert row["public"] is True
        assert row["hardened"] is False

    def test_report_json_serializes(self, tmp_path):
        from audit_bucket_security import write_report

        rows = [
            {
                "project_id": "proj-1",
                "bucket": "a",
                "location": "US",
                "uniform_bucket_level_access": True,
                "public_access_prevention": "enforced",
                "public": False,
                "hardened": True,
                "error": "",
            }
        ]
        out = tmp_path / "report.json"
        write_report(rows, "json", str(out))
        assert json.loads(out.read_text()) == rows