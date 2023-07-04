#!/usr/bin/env python3

import os
import subprocess

# Get the version from the environment variable
VERSION = os.environ.get("VERSION")

# Get the name of the script file
SCRIPT = os.path.basename(__file__)

# Get the directory of the script
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

# Get the home directory of the script
SCRIPT_HOME = os.path.dirname(os.path.realpath(__file__))

# Set the flag for whether the script is running in a Docker container
DOCKERIZED = False

# Set the flag for whether the script is running on an EKS cluster
EKS = False

# Check if the AWS environment variable is set
AWS = os.environ.get("AWS", False)

# Check if the GitLab environment variable is set
GITLAB = os.environ.get("GITLAB", False)

# Check if the GitHub environment variable is set
GITHUB = os.environ.get("GITHUB", False)

# Check if the Gitea environment variable is set
GITEA = os.environ.get("GITEA", False)

# Set the flag for whether the script is running on a Kubernetes cluster
KUBE = False

# Set the path to the Kubernetes config file
KUBECONFIG = os.path.join(SCRIPT_HOME, ".kube/config")

# Set the workspace directory
WORKSPACE = os.environ.get("WORKSPACE", os.path.join(SCRIPT_HOME, "tmp"))

# Function to initialize AWS variables
def init_aws():
    global AWS, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION, AWS_REGION
    AWS = True
    AWS_ACCESS_KEY_ID = os.environ.get("AWS_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY", "")
    AWS_DEFAULT_REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
    AWS_REGION = os.environ.get("AWS_REGION", AWS_DEFAULT_REGION)

# Function to initialize Kubernetes variables
def init_k8s_vars():
    global KUBE_CONFIG, KUBE_CONTEXT
    KUBE_CONFIG = os.environ.get("KUBE_CONFIG", "")
    KUBE_CONTEXT = os.environ.get("KUBE_CONTEXT", "")

# Function to initialize Helmfile variables
def init_helmfile():
    global HELMFILE_ENVIRONMENT, HELMFILE_SELECTOR
    HELMFILE_ENVIRONMENT = os.environ.get("HELMFILE_ENVIRONMENT", "")
    HELMFILE_SELECTOR = os.environ.get("HELMFILE_SELECTOR", "")

# Function to initialize GitLab variables
def init_gitlab():
    global GITLAB, GITLAB_USERNAME, GITLAB_TOKEN
    GITLAB = True
    GITLAB_USERNAME = os.environ.get("GITLAB_USERNAME", "")
    GITLAB_TOKEN = os.environ.get("GITLAB_TOKEN", "")

# Function to initialize GitHub variables
def init_github():
    global GITHUB, WORKSPACE
    GITHUB = True
    WORKSPACE = os.environ.get("GITHUB_WORKSPACE", "")

# Function to initialize Gitea variables
def init_gitea():
    global GITEA
    GITEA = True

# Get the log level from the environment variable
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

# Function to print the environment variables
def print_env():
    print(f"version: {VERSION}")
    print(f"command: {SCRIPT_DIR}")
    try:
        helmfile_version = subprocess.check_output(["helmfile", "--version"]).decode().strip()
        print(f"helmfile: {helmfile_version}")
    except subprocess.CalledProcessError:
        pass
    print(f"user: {os.getlogin()}")
    print(f"kernel: {os.uname().release}")
    print(f"Docker: {DOCKERIZED}")
    print(f"EKS: {EKS}")
    if KUBE_CONTEXT:
        print(f"kube-context: {KUBE_CONTEXT}")

# Check if the script is running in a Docker container
if "containerd" in open("/proc/self/cgroup").read():
    DOCKERIZED = True
    EKS = True
elif os.path.isfile("/.dockerenv"):
    DOCKERIZED = True

# Function to initialize Kubernetes
def init_k8s():
    global KUBE, KUBECONFIG
    init_k8s_vars()
    os.makedirs(os.path.dirname(KUBECONFIG), exist_ok=True)
    with open(KUBECONFIG, "w") as f:
        f.write(KUBE_CONFIG)
    os.chmod(KUBECONFIG, 0o600)
    KUBE = True

# Get a list of environment variables that contain underscores
ENV_RAW = os.environ.copy()
ENV_CUT = [key for key in ENV_RAW.keys() if "_" in key]
ENV_SORT = sorted(ENV_CUT, key=lambda x: int(x.split("_")[0]))
ENV_UNIQ = list(set(ENV_SORT))

# Initialize the appropriate variables based on the environment variables
for arg in ENV_UNIQ:
    if arg == "KUBE":
        init_k8s()
    elif arg == "HELMFILE":
        init_helmfile()
    elif arg == "AWS":
        init_aws()
    elif arg == "GITLAB":
        init_gitlab()
    elif arg == "GITHUB":
        init_github()
    elif arg == "GITEA":
        init_gitea()

# Print the environment variables
print_env()

# Check if Kubernetes is not initialized
if not KUBE:
    print("something is wrong with the kubernetes config, exiting")
    exit(1)

# Set the KUBECONFIG environment variable
os.environ["KUBECONFIG"] = KUBECONFIG

# Set the report directory and filename
REPORT_DIR = os.environ.get("REPORT_DIR", os.path.join(WORKSPACE, "helmfile-report"))
REPORT_FILENAME = os.environ.get("REPORT_FILENAME", "report.txt")

# Create the report directory if it doesn't exist
os.makedirs(REPORT_DIR, exist_ok=True)

# Run the helmfile command
print("Starting helmfile command")
os.chdir(WORKSPACE)
subprocess.run(["helmfile", "-q", "--kube-context", KUBE_CONTEXT, "diff", "--suppress-secrets", "--context", "3"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, universal_newlines=True)
print("Done")

# Exit with status code 0
exit(0)
