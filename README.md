# gostream-youtube-project

## Deploy the CI stack on `pis07`

The CI playbook installs Docker Engine and the Compose plugin from Docker's APT
repository, then builds and starts the services in [infra/ci/compose.yaml](infra/ci/compose.yaml).
Add future CI services and their build files under `infra/ci/`. Jenkins currently
pulls `jenkins/jenkins:lts-jdk21` on each deployment and listens on `127.0.0.1:8080`.
The stack uses the existing Compose project `jenkins` under `/opt/jenkins` on the
VM. Jenkins loads its jobs, credentials, and build history from `/opt/jenkins/data`.
Ansible reads `JENKINS_SSH_USER` from the workstation environment and uses it
for both `pis07.ii.pw.edu.pl` and the SSH jump host `galera.ii.pw.edu.pl`.
Run the following commands from the repository root on your workstation.

You need Ansible Core 2.14 or newer and OpenSSH on your workstation. The VM needs
Debian or Ubuntu with systemd, Python 3, sudo access for your SSH user, and access to
its APT repositories, `download.docker.com`, and Docker Hub. Use a Debian or
Ubuntu release supported by Docker and Docker Engine 28 or newer for loopback
port publishing. The Docker installation stops if APT would have to remove
existing packages, such as `docker.io` or `containerd`.

1. If you don't have a local `.env`, run `cp .env.example .env` and set
   `JENKINS_SSH_USER` to your SSH username in `.env`. Git ignores `.env`.
   Load it in each terminal where you'll run Ansible or SSH directly.

   ```sh
   set -a
   . ./.env
   set +a
   ```

2. Verify SSH access and check the VM's OS and Python.

   ```sh
   ssh -J "${JENKINS_SSH_USER}@galera.ii.pw.edu.pl" \
     "${JENKINS_SSH_USER}@pis07.ii.pw.edu.pl" 'cat /etc/os-release; python3 --version'
   ```

   If `galera` requires an interactive password, set a `ControlPath` for it in
   `~/.ssh/config` so Ansible can reuse an authenticated jump-host connection.
   If you already have a `Host galera.ii.pw.edu.pl` entry, use its existing
   `ControlPath` or add the option there.

   ```sshconfig
   Host galera.ii.pw.edu.pl
       ControlPath ~/.ssh/jenkins-jump-%C
   ```

   Then run `ssh -MN "${JENKINS_SSH_USER}@galera.ii.pw.edu.pl"` in a separate terminal and
   leave it open while running Ansible. If `pis07` also requires a password,
   add `--ask-pass` to the Ansible commands.

   ```sh
   ansible -i infra/ansible/inventory.yml ci -m ansible.builtin.ping
   ```

3. Run the CI playbook for a fresh deployment or to update the stack. Omit
   `--ask-become-pass` if sudo is passwordless. If you deployed with a custom
   `jenkins_image` or `jenkins_port`, pass the same overrides to keep those settings.

   ```sh
   ansible-playbook -i infra/ansible/inventory.yml infra/ansible/ci.yml --ask-become-pass
   ```

4. Run the CI helper to open the Jenkins tunnel. It loads `.env` automatically.
   Leave it running and open `http://127.0.0.1:8080` in your browser.

   ```sh
   ./infra/helpers/ci.sh jenkins
   ```

   If port `8080` is busy on your workstation, run `./infra/helpers/ci.sh jenkins 8081` and
   open `http://127.0.0.1:8081`. If you deployed Jenkins to a different VM port,
   pass that as the second port, for example `./infra/helpers/ci.sh jenkins 8080 8090`.

5. For a fresh install, read the unlock password from the container and enter it
   in the Jenkins setup wizard.

   ```sh
   ssh -t -J "${JENKINS_SSH_USER}@galera.ii.pw.edu.pl" "${JENKINS_SSH_USER}@pis07.ii.pw.edu.pl" \
     'sudo docker compose --project-directory /opt/jenkins exec -T jenkins cat /var/jenkins_home/secrets/initialAdminPassword'
   ```

### Check the stack on `pis07`

```sh
sudo docker compose --project-directory /opt/jenkins ps
sudo docker compose --project-directory /opt/jenkins logs --tail 100 jenkins
```
