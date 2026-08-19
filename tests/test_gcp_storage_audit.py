"""Unit tests for the GCP storage audit modules (mocked, no live GCP calls)."""

import importlib.util
import json
from pathlib import Path

from google.api_core import exceptions
from google.auth import exceptions as auth_exceptions

REPO_ROOT = Path(__file__).resolve().parents[1]


def _load_module(name: str, rel_path: str):
    spec = importlib.util.spec_from_file_location(name, REPO_ROOT / rel_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


audit_public_buckets = _load_module(
    "gcp_audit_public_buckets",
    "gcp/storage/audit-public-buckets/audit_public_buckets.py",
)
audit_bucket_security = _load_module(
    "gcp_audit_bucket_security",
    "gcp/storage/audit-security-config/audit_bucket_security.py",
)


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


class _FakeClient:
    def __init__(self, buckets):
        self._buckets = buckets

    def list_buckets(self, project=None):
        return self._buckets


class TestPublicBuckets:
    def test_bucket_with_allusers_binding_is_flagged(self):
        bucket = _FakeBucket(
            "open-data",
            policy=_FakePolicy(
                [{"role": "roles/storage.objectViewer", "members": ["allUsers"]}]
            ),
        )

        row = audit_public_buckets.audit_bucket(bucket)

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

        row = audit_public_buckets.audit_bucket(bucket)

        assert row["public"] is False

    def test_iam_error_is_captured_not_raised(self):
        from google.api_core import exceptions

        bucket = _FakeBucket(
            "restricted",
            policy=None,
            get_iam_error=exceptions.Forbidden("403"),
        )

        row = audit_public_buckets.audit_bucket(bucket)

        assert row["public"] is None
        assert "403" in row["error"]

    def test_bucket_public_via_authenticated_users(self):
        bucket = _FakeBucket(
            "shared-data",
            policy=_FakePolicy(
                [
                    {
                        "role": "roles/storage.objectCreator",
                        "members": ["allAuthenticatedUsers"],
                    }
                ]
            ),
        )

        row = audit_public_buckets.audit_bucket(bucket)

        assert row["public"] is True
        assert "roles/storage.objectCreator" in row["public_roles"]
        assert "allAuthenticatedUsers" in row["public_members"]

    def test_not_found_error_is_captured_not_raised(self):
        bucket = _FakeBucket(
            "missing",
            policy=None,
            get_iam_error=exceptions.NotFound("404"),
        )

        row = audit_public_buckets.audit_bucket(bucket)

        assert row["public"] is None
        assert "404" in row["error"]


class TestPublicBucketsMain:
    def test_main_fails_fast_without_credentials(self, monkeypatch):
        def _no_creds(**kwargs):
            raise auth_exceptions.DefaultCredentialsError("no credentials")

        monkeypatch.setattr(audit_public_buckets.storage, "Client", _no_creds)
        monkeypatch.setattr(audit_public_buckets.sys, "argv", ["audit_public_buckets.py"])

        assert audit_public_buckets.main() == 2

    def test_main_reports_forbidden_listing(self, monkeypatch):
        def _forbidden(**kwargs):
            raise exceptions.Forbidden("403")

        monkeypatch.setattr(audit_public_buckets.storage, "Client", _forbidden)
        monkeypatch.setattr(audit_public_buckets.sys, "argv", ["audit_public_buckets.py"])

        assert audit_public_buckets.main() == 2

    def test_main_writes_csv_with_public_filter(self, monkeypatch, tmp_path, capsys):
        buckets = [
            _FakeBucket(
                "open-data",
                policy=_FakePolicy(
                    [{"role": "roles/storage.objectViewer", "members": ["allUsers"]}]
                ),
            ),
            _FakeBucket(
                "private-data",
                policy=_FakePolicy(
                    [{"role": "roles/storage.objectViewer", "members": ["user:me@corp.com"]}]
                ),
            ),
        ]
        monkeypatch.setattr(audit_public_buckets.storage, "Client", lambda **kwargs: _FakeClient(buckets))
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

        content = (tmp_path / "out.csv").read_text()
        assert "project_id,bucket,location" in content
        assert "open-data" in content
        assert "private-data" not in content
        assert "1 public." in capsys.readouterr().err

    def test_main_writes_json(self, monkeypatch, tmp_path):
        buckets = [
            _FakeBucket(
                "open-data",
                policy=_FakePolicy(
                    [{"role": "roles/storage.objectViewer", "members": ["allUsers"]}]
                ),
            )
        ]
        monkeypatch.setattr(audit_public_buckets.storage, "Client", lambda **kwargs: _FakeClient(buckets))
        monkeypatch.setattr(
            audit_public_buckets.sys,
            "argv",
            [
                "audit_public_buckets.py",
                "--format",
                "json",
                "--output-file",
                str(tmp_path / "out.json"),
            ],
        )

        assert audit_public_buckets.main() == 0

        data = json.loads((tmp_path / "out.json").read_text())
        assert data[0]["bucket"] == "open-data"


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

        row = audit_bucket_security.audit_bucket(bucket)

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

        row = audit_bucket_security.audit_bucket(bucket)

        assert row["public"] is True
        assert row["hardened"] is False

    def test_inherited_public_access_prevention_is_not_hardened(self):
        bucket = _FakeBucket(
            "reports",
            policy=_FakePolicy(
                [{"role": "roles/storage.objectViewer", "members": ["user:me@corp.com"]}]
            ),
            iam_configuration={
                "uniformBucketLevelAccess": {"enabled": True},
                "publicAccessPrevention": "inherited",
            },
        )

        row = audit_bucket_security.audit_bucket(bucket)

        assert row["public_access_prevention"] == "inherited"
        assert row["hardened"] is False

    def test_missing_iam_configuration_defaults_safely(self):
        bucket = _FakeBucket(
            "legacy",
            policy=_FakePolicy(
                [{"role": "roles/storage.legacyBucketReader", "members": ["user:me@corp.com"]}]
            ),
        )

        row = audit_bucket_security.audit_bucket(bucket)

        assert row["uniform_bucket_level_access"] is False
        assert row["public_access_prevention"] == "unspecified"
        assert row["hardened"] is False

    def test_report_json_serializes(self, tmp_path):
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
        audit_bucket_security.write_report(rows, "json", str(out))
        assert json.loads(out.read_text()) == rows


class TestSecurityConfigMain:
    def test_main_fails_fast_without_credentials(self, monkeypatch):
        def _no_creds(**kwargs):
            raise auth_exceptions.DefaultCredentialsError("no credentials")

        monkeypatch.setattr(audit_bucket_security.storage, "Client", _no_creds)
        monkeypatch.setattr(audit_bucket_security.sys, "argv", ["audit_bucket_security.py"])

        assert audit_bucket_security.main() == 2

    def test_main_writes_csv_with_hardened_filter(self, monkeypatch, tmp_path, capsys):
        buckets = [
            _FakeBucket(
                "prod",
                policy=_FakePolicy(
                    [{"role": "roles/storage.objectViewer", "members": ["user:me@corp.com"]}]
                ),
                iam_configuration={
                    "uniformBucketLevelAccess": {"enabled": True},
                    "publicAccessPrevention": "enforced",
                },
            ),
            _FakeBucket(
                "open-data",
                policy=_FakePolicy(
                    [{"role": "roles/storage.objectViewer", "members": ["allUsers"]}]
                ),
                iam_configuration={
                    "uniformBucketLevelAccess": {"enabled": True},
                    "publicAccessPrevention": "enforced",
                },
            ),
        ]
        monkeypatch.setattr(audit_bucket_security.storage, "Client", lambda **kwargs: _FakeClient(buckets))
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

        content = (tmp_path / "out.csv").read_text()
        assert "prod" in content
        assert "open-data" not in content
        assert "1 fully hardened." in capsys.readouterr().err
