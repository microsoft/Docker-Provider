FROM python:3.6

RUN pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org pytest pytest-xdist filelock requests kubernetes adal msrestazure 

RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash \
    && helm version

COPY ./core/e2e_tests.sh /
COPY ./core/pytest.ini /e2etests/
COPY ./core/conftest.py /e2etests/
COPY ./core/helper.py /e2etests/
COPY ./core/ /e2etests/
COPY ./common/ /e2etests/
COPY ./tests/ /e2etests/

RUN ["chmod", "+x", "/e2e_tests.sh"]
ENTRYPOINT ["./e2e_tests.sh"]
