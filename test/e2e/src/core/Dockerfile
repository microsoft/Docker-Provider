# default value can be found in internal wiki. External can use python 3.6 base image
ARG PYTHON_BASE_IMAGE=
FROM ${PYTHON_BASE_IMAGE}

RUN pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org pytest pytest-xdist filelock requests kubernetes adal msrestazure

RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash \
    && helm version

RUN apt-get update && apt-get -y upgrade && \
    apt-get -f -y install curl apt-transport-https lsb-release gnupg python3-pip && \
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.asc.gpg && \
    CLI_REPO=$(lsb_release -cs) && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ ${CLI_REPO} main" \
    > /etc/apt/sources.list.d/azure-cli.list && \
    curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y azure-cli kubectl && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install junit_xml

COPY ./core/e2e_tests.sh /
COPY ./core/setup_failure_handler.py /
COPY ./core/pytest.ini /e2etests/
COPY ./core/conftest.py /e2etests/
COPY ./core/helper.py /e2etests/
COPY ./core/ /e2etests/
COPY ./common/ /e2etests/
COPY ./tests/ /e2etests/

RUN ["chmod", "+x", "/e2e_tests.sh"]
ENTRYPOINT ["./e2e_tests.sh"]
