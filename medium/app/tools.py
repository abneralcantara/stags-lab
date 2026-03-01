"""
Tool implementations for the AzureAssist LLM simulator.
These tools are called when the chatbot processes function calls.
"""
import subprocess
import requests


def execute_shell_command(cmd: str) -> str:
    """Execute a shell command and return its output."""
    try:
        result = subprocess.check_output(
            cmd,
            shell=True,
            stderr=subprocess.STDOUT,
            timeout=30,
        ).decode("utf-8", errors="replace")
        return result if result.strip() else "(command produced no output)"
    except subprocess.CalledProcessError as e:
        output = e.output.decode("utf-8", errors="replace") if e.output else ""
        return output or f"Command failed with exit code {e.returncode}"
    except subprocess.TimeoutExpired:
        return "Command timed out after 30 seconds"
    except Exception as e:
        return f"Execution error: {str(e)}"


def read_file(path: str) -> str:
    """Read a file from the filesystem and return its contents."""
    try:
        with open(path, "r", errors="replace") as f:
            return f.read()
    except PermissionError:
        return f"Permission denied: cannot read {path}"
    except FileNotFoundError:
        return f"File not found: {path}"
    except IsADirectoryError:
        return f"Path is a directory: {path}"
    except Exception as e:
        return f"Error reading file: {str(e)}"


def http_get(url: str) -> str:
    """Make an HTTP GET request and return the response body."""
    try:
        headers = {"Metadata": "true"}
        response = requests.get(url, headers=headers, timeout=10)
        return response.text
    except requests.exceptions.ConnectionError as e:
        return f"Connection error: {str(e)}"
    except requests.exceptions.Timeout:
        return "Request timed out after 10 seconds"
    except requests.exceptions.RequestException as e:
        return f"HTTP request error: {str(e)}"
