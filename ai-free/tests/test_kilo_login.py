import os
import sys
import tempfile
import unittest
from pathlib import Path
from typing import cast
from unittest.mock import MagicMock, patch

import requests

sys.path.insert(0, os.fspath(Path(__file__).resolve().parent.parent))

from kilo_login import (  # noqa: E402
    KILO_API_BASE,
    _read_env_file,
    _write_env_file,
    device_authorization,
    env_file_exists,
    login,
    poll_for_token,
    test_auth,
)


class WriteEnvTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.tmp_path = Path(self.dir.name) / ".kilo.env"

    def tearDown(self):
        self.dir.cleanup()

    def test_writes_default_lines_without_api_key(self):
        _write_env_file(self.tmp_path)
        content = self.tmp_path.read_text(encoding="utf-8")
        for expected in [
            "LLM_PROVIDER=kilo",
            f"KILO_API_URL={KILO_API_BASE}",
            "LLM_MODEL=kilo-auto/free",
        ]:
            self.assertIn(expected, content)
        self.assertNotIn("KILO_API_KEY=", content)

    def test_includes_api_key_when_provided(self):
        _write_env_file(self.tmp_path, api_key="kilo-token")
        self.assertIn("KILO_API_KEY=kilo-token", self.tmp_path.read_text(encoding="utf-8"))


class ReadEnvTests(unittest.TestCase):
    def test_returns_empty_when_file_missing(self):
        with tempfile.TemporaryDirectory() as td:
            self.assertEqual({}, _read_env_file(Path(td) / ".kilo.env"))

    def test_reads_key_value_pairs(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / ".kilo.env"
            path.write_text("KILO_API_KEY=abc\n# comment\nLLM_PROVIDER=kilo\n", encoding="utf-8")
            data = _read_env_file(path)
        self.assertEqual({"KILO_API_KEY": "abc", "LLM_PROVIDER": "kilo"}, data)


class EnvFileExistsTests(unittest.TestCase):
    def test_true_when_file_present(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / ".kilo.env"
            path.write_text("KILO_API_KEY=abc\n", encoding="utf-8")
            self.assertTrue(env_file_exists(path))

    def test_false_when_missing(self):
        with tempfile.TemporaryDirectory() as td:
            self.assertFalse(env_file_exists(Path(td) / ".missing.env"))


class DeviceAuthorizationTests(unittest.TestCase):
    def test_happy_path(self):
        response = MagicMock()
        response.status_code = 200
        response.json.return_value = {
            "device_code": "d1",
            "user_code": "u1",
            "verification_uri": "https://kilo.ai/device",
            "expires_in": 120,
            "interval": 5,
        }
        with patch("kilo_login.requests.post", return_value=response) as post:
            result = device_authorization(base_url="https://api.example.test")
            post.assert_called_once()
            self.assertEqual("d1", result["device_code"])

    def test_missing_keys_raises(self):
        response = MagicMock()
        response.status_code = 200
        response.json.return_value = {"device_code": "d1"}
        with (
            patch("kilo_login.requests.post", return_value=response),
            self.assertRaises(ValueError),
        ):
            device_authorization(base_url="https://api.example.test")

    def test_http_error_raises(self):
        response = MagicMock()
        response.status_code = 500
        response.raise_for_status.side_effect = requests.HTTPError("server error")
        with (
            patch("kilo_login.requests.post", return_value=response),
            self.assertRaises(requests.HTTPError),
        ):
            device_authorization(base_url="https://api.example.test")


class PollForTokenTests(unittest.TestCase):
    def test_returns_token_on_success(self):
        response_success = MagicMock()
        response_success.status_code = 200
        response_success.json.return_value = {
            "access_token": "token-1",
            "expires_in": 3600,
        }
        with patch("kilo_login.requests.post", return_value=response_success):
            token = poll_for_token(
                base_url="https://api.example.test",
                device_code="device-code",
                timeout=1,
            )
        self.assertIsNotNone(token)
        self.assertEqual("token-1", cast(dict, token)["access_token"])

    def test_returns_none_when_pending_then_success_after_polls(self):
        pending = MagicMock()
        pending.status_code = 400
        pending.json.return_value = {"error": "authorization_pending"}

        success = MagicMock()
        success.status_code = 200
        success.json.return_value = {"access_token": "token-2"}

        with patch("kilo_login.requests.post", side_effect=[pending, success]):
            token = poll_for_token(
                base_url="https://api.example.test",
                device_code="device-code",
                timeout=20,
                poll_interval=0.01,
            )
        self.assertIsNotNone(token)
        self.assertEqual("token-2", cast(dict, token)["access_token"])

    def test_returns_none_on_expired_token(self):
        response = MagicMock()
        response.status_code = 400
        response.json.return_value = {"error": "expired_token"}
        with patch("kilo_login.requests.post", return_value=response):
            token = poll_for_token(
                base_url="https://api.example.test",
                device_code="device-code",
                timeout=1,
            )
        self.assertIsNone(token)

    def test_returns_none_on_access_denied(self):
        response = MagicMock()
        response.status_code = 400
        response.json.return_value = {"error": "access_denied"}
        with patch("kilo_login.requests.post", return_value=response):
            token = poll_for_token(
                base_url="https://api.example.test",
                device_code="device-code",
                timeout=1,
            )
        self.assertIsNone(token)


class LoginTests(unittest.TestCase):
    def test_login_writes_env_file_and_env_vars(self):
        device_resp = MagicMock()
        device_resp.status_code = 200
        device_resp.json.return_value = {
            "device_code": "d",
            "user_code": "u",
            "verification_uri": "https://kilo.ai/device",
            "expires_in": 120,
            "interval": 0.01,
        }

        token_resp = MagicMock()
        token_resp.status_code = 200
        token_resp.json.return_value = {
            "access_token": "final-token",
            "refresh_token": "refresh",
            "expires_in": 3600,
        }

        with tempfile.TemporaryDirectory() as td:
            env_path = Path(td) / ".kilo.env"
            with patch("builtins.input", return_value="final-token"):
                api_key = login(base_url="https://api.example.test", env_path=env_path)

            self.assertEqual("final-token", api_key)
            self.assertEqual("final-token", os.environ.get("KILO_API_KEY"))
            self.assertEqual("kilo", os.environ.get("LLM_PROVIDER"))
            self.assertEqual("https://api.example.test", os.environ.get("KILO_API_URL"))
            self.assertEqual("kilo-auto/free", os.environ.get("LLM_MODEL"))
            self.assertIn("KILO_API_KEY=final-token", env_path.read_text(encoding="utf-8"))


class TestAuthTests(unittest.TestCase):
    def test_true_when_status_ok(self):
        response = MagicMock()
        response.status_code = 200
        with patch("kilo_login.requests.get", return_value=response):
            self.assertTrue(test_auth(api_key="good"))

    def test_false_when_bad_status(self):
        response = MagicMock()
        response.status_code = 401
        with patch("kilo_login.requests.get", return_value=response):
            self.assertFalse(test_auth(api_key="bad"))

    def test_false_when_no_api_key(self):
        self.assertFalse(test_auth(api_key=None))

    def test_false_when_request_raises(self):
        import requests

        with patch("kilo_login.requests.get", side_effect=requests.RequestException("boom")):
            self.assertFalse(test_auth(api_key="any"))


if __name__ == "__main__":
    unittest.main()
