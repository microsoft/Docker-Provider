FROM python:3.6

RUN pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org pytest pytest-xdist filelock requests kubernetes adal msrestazure

RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash \
    && helm version

RUN apt-get update && apt-get -y upgrade && \
    apt-get -f -y install curl apt-transport-https lsb-release gnupg python3-pip python-pip && \
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.asc.gpg && \
    CLI_REPO=$(lsb_release -cs) && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ ${CLI_REPO} main" \
    > /etc/apt/sources.list.d/azure-cli.list && \
    apt-get update && \
    apt-get install -y azure-cli && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install junit_xml

COPY --from=lachlanevenson/k8s-kubectl:v1.20.5 /usr/local/bin/kubectl /usr/local/bin/kubectl

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
