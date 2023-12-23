import os
import sys
import base64
from dotenv import load_dotenv
import subprocess
import logging

class HelmfileRunner:
    def __init__(self):
        load_dotenv()

        self._dockerized = False
        self._eks = self._aws = self._gitlab = self._github = self._gitea = self._kube = False
        self._workspace = os.getenv('WORKSPACE', '')
        self._log_level = os.getenv('LOG_LEVEL', 'INFO')
        self.setup_logging()
        self._script_home = os.path.dirname(os.path.realpath(__file__))
        self._kubeconfig = f"{self._script_home}/.kube/config"
        self._kube_context = os.getenv('KUBE_CONTEXT', '') # Added here

        self.check_dockerized()

    def setup_logging(self):
        log_level = getattr(logging, self._log_level)
        logging.basicConfig(format='%(levelname)s:%(message)s', level=log_level)
    
    def check_dockerized(self):
        if 'containerd' in open('/proc/self/cgroup').read() or os.path.exists('/.dockerenv'):
            self._dockerized = True

    def init_k8s(self):
        self._kube_config_b64 = os.getenv('KUBE_CONFIG', '')
        if self._kube_config_b64:
            kube_config = base64.b64decode(self._kube_config_b64).decode()
            with open(self._kubeconfig, 'w') as f:
                f.write(kube_config)
            self._kube = True

    def init_aws(self):
        self._aws_access_key_id = os.getenv('AWS_ACCESS_KEY_ID', '')
        self._aws_secret_access_key = os.getenv('AWS_SECRET_ACCESS_KEY', '')
        self._aws_default_region = os.getenv('AWS_DEFAULT_REGION', 'us-east-1')
        self._aws_region = os.getenv('AWS_REGION', self._aws_default_region)
        self._aws = True

    # initialize other variables similarly

    def run(self):
        env_vars = {k: v for k, v in dict(os.environ).items() if '_' in k}
        
        for prefix in set(k.split('_')[0] for k in env_vars):
            if prefix == 'KUBE':
                self.init_k8s()
            elif prefix == 'HELM':
                self.init_helmfile()
            elif prefix == 'AWS':
                self.init_aws()
            elif prefix == 'GITLAB':
                self.init_gitlab()
            elif prefix == 'GITHUB':
                self.init_github()
            elif prefix == 'GITEA':
                self.init_gitea()

        if not self._kube:
            logging.error('Something is wrong with the Kubernetes config, exiting')
            sys.exit(1)

        os.environ['KUBECONFIG'] = self._kubeconfig
        _report_dir = os.getenv('REPORT_DIR', f"{self._workspace}/helmfile-report")
        _report_filename = os.getenv('REPORT_FILENAME', 'report.txt')

        os.makedirs(_report_dir, exist_ok=True)

        try:
            subprocess.run(f'cd {self._workspace} && helmfile -q --kube-context {self._kube_context} diff'
                           f'--suppress-secrets --context 3 > {_report_dir}/{_report_filename}', shell=True)
            logging.info('Done')
        except subprocess.SubprocessError as e:
            logging.error(f'Error: {e}')

if __name__ == '__main__':
    runner = HelmfileRunner()
    runner.run()
